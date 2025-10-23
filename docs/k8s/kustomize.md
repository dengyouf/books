# Kuberentes原生配置管理

Kustomize 引入了一种无需模板即可自定义应用程序配置的方法，从而简化了现成应用程序的使用。

## 基础入门

- 组织目录结构

```shell
~]# tree base
base
├── deployment.yaml
├── kustomization.yaml
└── service.yaml
```
- deployment.yaml

```shell
cat > deployment.yaml << 'EOF'
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp
spec:
  selector:
    matchLabels:
      app: myapp
  replicas: 3
  template:
    metadata:
      labels:
        app: myapp
    spec:
      containers:
      - name: myapp
        image: ikubernetes/myapp:v1
        ports:
        - name: http-80
          containerPort: 80
          protocol: TCP
EOF
```
- service.yaml

```shell
cat > service.yaml << 'EOF'
---
apiVersion: v1
kind: Service
metadata:
  name: myapp
spec:
  type: ClusterIP
  selector:
    app: myapp
  ports:
  - name: http-80
    port: 80
    targetPort: 80
EOF
```
- kustomization.yaml

```shell
cat > kustomization.yaml << 'EOF'
---
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - deployment.yaml
  - service.yaml
EOF
```
- 查看渲染效果

```shell
# 安装 kustomize
~# curl -s "https://ghfast.top/https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh"  | bash
v5.7.1
~# mv kustomize  /usr/local/bin/
~# kustomize version
v5.7.1
~# kustomize build .
```
- 应用资源清单

```shell
base# kubectl  apply -k .
service/myapp created
deployment.apps/myapp created
```
##
