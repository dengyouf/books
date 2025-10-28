# Ingress NGINX Controller
在Kubernetes集群中，Nginx Ingress对集群服务（Service）中外部可访问的API对象进行管理，提供七层负载均衡能力。
## 快速部署

### 1.获取资源清单
Ingress-Nginx对 Kubernetes版本有要求，请下载[支持的版本](https://github.com/kubernetes/ingress-nginx)
```shell
wget https://ghfast.top/https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.13.1/deploy/static/provider/baremetal/deploy.yaml
```
### 2.定制资源清单
!!! warring
    修改Ingress部署模式为DaemonSet以及流量调度策略为Local以支持获取用户真实IP
```shell
cp deploy.yaml{,.ori}
---
apiVersion: v1
data:
  # 获取用户真实IP
  use-forwarded-headers: "true"
  compute-full-forwarded-for: "true"
  forwarded-for-header: X-Forwarded-For
kind: ConfigMap
---
apiVersion: v1
kind: Service
metadata:
  ...
  ports:
  - appProtocol: http
    name: http
    port: 80
    protocol: TCP
    targetPort: http
    nodePort: 30080
  - appProtocol: https
    name: https
    port: 443
    protocol: TCP
    targetPort: https
    nodePort: 30443
  selector:
    app.kubernetes.io/component: controller
    app.kubernetes.io/instance: ingress-nginx
    app.kubernetes.io/name: ingress-nginx
  type: NodePort
  # 修改集群流量策略
  externalTrafficPolicy: Local
---
apiVersion: apps/v1
# 使用DaemonSet方式
kind: DaemonSet
metadata:
  ...
```

### 3.应用资源清单

```shell
~# kubectl  apply -f deploy.yaml
~# kubectl  get pod -n ingress-nginx
NAME                             READY   STATUS    RESTARTS   AGE
ingress-nginx-controller-94rrj   1/1     Running   0          28s
ingress-nginx-controller-gbj44   1/1     Running   0          28s
ingress-nginx-controller-lkdd2   1/1     Running   0          28s
~# kubectl  get svc -n ingress-nginx
NAME                                 TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)                      AGE
ingress-nginx-controller             NodePort    10.106.139.128   <none>        80:30080/TCP,443:30443/TCP   3m36s
ingress-nginx-controller-admission   ClusterIP   10.102.44.229    <none>        443/TCP                      3m36s
```

### 4.验证

```shell
# 定义Deployment跟Service资源
~# echo "
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: stable
  labels:
    app: stable
spec:
  replicas: 3
  selector:
    matchLabels:
      app: stable
  template:
    metadata:
      labels:
        app: stable
    spec:
      containers:
      - name: myapp-v1
        image: ikubernetes/myapp:v1
        ports:
        - name: http
          protocol: TCP
          containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: stable
  labels:
    app: stable
spec:
  ports:
  - name: http
    port: 80
    targetPort: 80
  selector:
    app: stable
" | tee stable.yaml|kubectl apply -f -
# 创建Ingress规则
~# echo "---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: stable-ingress
spec:
  rules:
  - host: www.linux.io
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: stable
            port:
              number: 80
  ingressClassName: nginx"|tee stable-ingress.yaml|kubectl apply -f -
~# kubectl  get ingress
NAME             CLASS   HOSTS          ADDRESS                                     PORTS   AGE
stable-ingress   nginx   www.linux.io   192.168.1.121,192.168.1.122,192.168.1.123   80      53s
# 通过域名访问
~# curl -k -H "Host: www.linux.io"   192.168.1.111:30080
Hello MyApp | Version: v1 | <a href="hostname.html">Pod Name</a>
~# curl -k -H "Host: www.linux.io"   192.168.1.121:30080
Hello MyApp | Version: v1 | <a href="hostname.html">Pod Name</a>
~# curl -k -H "Host: www.linux.io"   192.168.1.122:30080
Hello MyApp | Version: v1 | <a href="hostname.html">Pod Name</a>
~# curl -k -H "Host: www.linux.io"   192.168.1.123:30080
Hello MyApp | Version: v1 | <a href="hostname.html">Pod Name</a>
```
## 使用案例
### 1.TLS证书访问

```shell
kubectl create secret  tls xsreops.xyz-ingress-tls \
  --key=ssl/xsreops.xyz.key \
  --cert=ssl/xsreops.xyz.pem

cat stable-tls-ingress.yaml
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: stable-tls-ingress
  namespace: default
spec:
  ingressClassName: nginx
  rules:
  - host: xsreops.xyz
    http:
      paths:
      - backend:
          service:
            name: stable
            port:
              number: 80
        path: /
        pathType: ImplementationSpecific
  tls:
  - hosts:
    - xsreops.xyz
    secretName: xsreops.xyz-ingress-tls
```
