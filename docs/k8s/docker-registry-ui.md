## 从私有仓库拉取镜像

### 1. docker-registry-ui

#### HTTP协议-[Docker Registry](https://github.com/Joxit/docker-registry-ui/tree/main/examples/ui-as-standalone)

```shell
git clone https://ghfast.top/https://github.com/Joxit/docker-registry-ui.git
cd docker-registry-ui/examples/ui-as-standalone/

cat credentials.yml
version: '2.0'
services:
  registry:
    image: registry:2.7
    ports:
      - 5000:5000
    volumes:
      - ./registry-data:/var/lib/registry
      - ./registry-config/credentials.yml:/etc/docker/registry/config.yml
      - ./registry-config/htpasswd:/etc/docker/registry/htpasswd

  ui:
    image: joxit/docker-registry-ui:latest
    ports:
      - 80:80
    environment:
      - REGISTRY_TITLE=My Private Docker Registry
      - REGISTRY_URL=http://172.16.235.251:5000 # 修改为IP地址
      - SINGLE_REGISTRY=true
      - REGISTRY_SECURED=true  # 添加认证信息
      - REGISTRY_AUTH=basic
      - REGISTRY_USER=registry
      - REGISTRY_PASS=ui
    depends_on:
      - registry

cat registry-config/credentials.yml
version: 0.1
log:
  fields:
    service: registry
storage:
  delete:
    enabled: true
  cache:
    blobdescriptor: inmemory
  filesystem:
    rootdirectory: /var/lib/registry
http:
  addr: :5000
  headers:
    X-Content-Type-Options: [nosniff]
    Access-Control-Allow-Origin: ['http://172.16.235.251'] # 解决跨域问题
    Access-Control-Allow-Methods: ['HEAD', 'GET', 'OPTIONS', 'DELETE']
    Access-Control-Allow-Headers: ['Authorization', 'Accept']
    Access-Control-Max-Age: [1728000]
    Access-Control-Allow-Credentials: [true]
    Access-Control-Expose-Headers: ['Docker-Content-Digest']
auth:
  htpasswd:
    realm: basic-realm
    path: /etc/docker/registry/htpasswd

docker compose -f credentials.yml  up -d
```
#### HTTPS协议-[Docker Registry](https://github.com/Joxit/docker-registry-ui/tree/main/examples/issue-20)

```shell
cd docker-registry-ui/examples/issue-20/

```


#### Docker 上传镜像

```shell
cat /etc/docker/daemon.json
{
    "exec-opts": ["native.cgroupdriver=systemd"],
    "registry-mirrors": [
         "https://o4uba187.mirror.aliyuncs.com",
         "https://docker.1ms.run",
         "https://docker.1panel.live"
    ],
    "insecure-registries": ["172.16.235.251:5000"] #
}

systemctl restart docker

docker login -u registry -p ui 172.16.235.251:5000
WARNING! Using --password via the CLI is insecure. Use --password-stdin.
Login Succeeded

docker tag jenkins/jenkins:lts 172.16.235.251:5000/jenkins/jenkins:lts
docker push 172.16.235.251:5000/jenkins/jenkins:lts
```

![img.png](images/img.png)

#### Containerd 上传镜像

```shell
# 添加配置，不需要修改配置文件
mkdir -pv /etc/containerd/certs.d/172.16.235.251:5000/
cat > /etc/containerd/certs.d/172.16.235.251\:5000/hosts.toml  << 'EOF'
server = "http://172.16.235.251:5000"
[host."http://172.16.235.251:5000"]
  capabilities = ["pull", "resolve", "push"]
[host.auth]
username = "registry"
password = "ui"
EOF

ctr --namespace k8s.io images pull \
  --plain-http --user registry:ui \
  172.16.235.251:5000/jenkins/jenkins:lts
```

### 2.使用私有镜像

```shell
kubectl create secret docker-registry regcred \
  --docker-server=172.16.235.251:5000 \
  --docker-username=registry \
  --docker-password=ui \
  --docker-email=1071102039@qq.com


cat web.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    app: web
  name: web
spec:
  replicas: 3
  selector:
    matchLabels:
      app: web
  template:
    metadata:
      labels:
        app: web
    spec:
      imagePullSecrets:
      - name: regcred
      containers:
      - name: nginx
        image: 172.16.235.251:5000/dengyouf/nginx:v1.24
```
