## 从私有仓库拉取镜像

### 1. docker-registry-ui

#### HTTP协议-[Docker Registry](https://github.com/Joxit/docker-registry-ui/tree/main/examples/ui-as-standalone)

```shell
git clone https://ghfast.top/https://github.com/Joxit/docker-registry-ui.git
cd docker-registry-ui/examples/ui-as-standalone/

cat > credentials.yml << EOF
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
    #ports:
    #  - 80:80
    environment:
      - REGISTRY_TITLE=My Private Docker Registry
      - NGINX_PROXY_PASS_URL=http://registry:5000
      - DELETE_IMAGES=true
      - SHOW_CATALOG_NB_TAGS=true
      - TAGLIST_PAGE_SIZE=100
      - SINGLE_REGISTRY=true
      - REGISTRY_SECURED=true  # 添加认证信息
      - REGISTRY_AUTH=basic
      - REGISTRY_USER=registry
      - REGISTRY_PASS=ui
      - DELETE_IMAGES=true
      - CATALOG_MIN_BRANCHES=1
      - CATALOG_MAX_BRANCHES=1
      - TAGLIST_PAGE_SIZE=100
        #- SHOW_CONTENT_DIGEST=true
    depends_on:
      - registry

  nginx:
    image: nginx:1.25
    ports:
      - "80:80"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf:ro
    depends_on:
      - registry
      - ui
EOF

cat > nginx.conf << EOF
events {}

http {
  server {
    listen 80;
    server_name 172.16.30.7;

    # ===== Docker Registry API =====
    location /v2/ {

      # 关键：OPTIONS 预检请求直接 204 返回
      if ($request_method = OPTIONS) {
        add_header 'Access-Control-Allow-Origin' 'http://172.16.30.7' always;
        add_header 'Access-Control-Allow-Methods' 'GET, POST, PUT, PATCH, DELETE, OPTIONS' always;
        add_header 'Access-Control-Allow-Headers' 'Authorization, Content-Type, Accept, Range, Docker-Distribution-Api-Version' always;
        add_header 'Access-Control-Allow-Credentials' 'true' always;
        add_header 'Access-Control-Max-Age' 1728000 always;
        return 204;
      }

      proxy_pass http://registry:5000;
      proxy_set_header Host $host;
      proxy_set_header X-Real-IP $remote_addr;
      proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
      proxy_set_header X-Forwarded-Proto $scheme;

      # CORS headers（正常请求）
      add_header 'Access-Control-Allow-Origin' 'http://172.16.30.7' always;
      add_header 'Access-Control-Allow-Credentials' 'true' always;
      add_header 'Access-Control-Expose-Headers' 'Docker-Content-Digest, Content-Length, Content-Range' always;
    }

    # ===== Registry UI =====
    location / {
      proxy_pass http://ui:80;
      proxy_set_header Host $host;
      proxy_set_header X-Real-IP $remote_addr;
      proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }
  }
EOF

cat  > registry-config/credentials.yml << EOF
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
auth:
  htpasswd:
    realm: basic-realm
    path: /etc/docker/registry/htpasswd
EOF

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
    "insecure-registries": ["172.16.30.7:5000"]
}

systemctl restart docker

docker login -u registry -p ui 172.16.30.7:5000
WARNING! Using --password via the CLI is insecure. Use --password-stdin.
Login Succeeded

docker tag jenkins/jenkins:lts 172.16.30.7:5000/jenkins/jenkins:lts
docker push 172.16.30.7:5000/jenkins/jenkins:lts
```


#### Containerd 上传镜像

```shell
# 添加配置，不需要修改配置文件
mkdir -pv /etc/containerd/certs.d/172.16.30.7:5000/
cat > /etc/containerd/certs.d/172.16.30.7\:5000/hosts.toml  << 'EOF'
server = "http://172.16.30.7:5000"
[host."http://172.16.30.7:5000"]
  capabilities = ["pull", "resolve", "push"]
[host.auth]
username = "registry"
password = "ui"
EOF

ctr --namespace k8s.io images pull \
  --plain-http --user registry:ui \
  172.16.30.7:5000/jenkins/jenkins:lts
```

### 2.使用私有镜像

```shell
kubectl create secret docker-registry regcred \
  --docker-server=172.16.30.7:5000 \
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
        image: 172.16.30.7:5000/dengyouf/nginx:v1.24
```
