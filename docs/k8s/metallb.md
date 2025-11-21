# MetalLB
MetalLB 是一个用于裸机 Kubernetes 集群的负载均衡器实现，使用标准路由协议。

## [MetalLB安装](https://metallb.io/installation/)

### 1.启用严格的 ARP

```shell
kubectl edit configmap -n kube-system kube-proxy
...
apiVersion: kubeproxy.config.k8s.io/v1alpha1
kind: KubeProxyConfiguration
mode: "ipvs"
ipvs:
  strictARP: true
```

### 2.资源清单部署

```shell
wget https://raw.githubusercontent.com/metallb/metallb/v0.15.2/config/manifests/metallb-native.yaml
kubectl apply -f metallb-native.yaml
kubectl  get pod -n metallb-system
NAME                          READY   STATUS    RESTARTS   AGE
controller-589cbf5c44-kdhkv   1/1     Running   0          4m8s
speaker-8snbd                 1/1     Running   0          4m8s
speaker-bbxb2                 1/1     Running   0          4m8s
speaker-ds6gr                 1/1     Running   0          4m8s
speaker-q6nz6                 1/1     Running   0          4m8s
```

## MetalLB配置

MetalLB 有 Layer2 模式和 BGP 模式，任选一种模式进行配置即可。因为 BGP 对路由器有要求，因此建议测试时使用 Layer2 模式。

### Layer 2 模式配置
#### 1. 创建地址池

多个实例IP地址池可以共存,并且地址可以由CIDR定义， 按范围分配，并且可以分配IPV4和IPV6地址。

```shell
cat <<EOF > IPAddressPool.yaml
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: first-pool
  namespace: metallb-system
spec:
  addresses:
  # 可分配的 IP 地址,可以指定多个，包括 ipv4、ipv6
  - 192.168.122.140-192.168.122.150
EOF

kubectl apply -f IPAddressPool.yaml
kubectl  get ipaddresspools  -n metallb-system
NAME         AUTO ASSIGN   AVOID BUGGY IPS   ADDRESSES
first-pool   true          false             ["192.168.122.140-192.168.122.150"]
```

#### 2.创建 L2Advertisement

L2 模式不要求将 IP 绑定到网络接口 工作节点。它的工作原理是响应本地网络 arp 请求，以将计算机的 MAC 地址提供给客户端。 如果不设置关联到 IPAdressPool，那默认 L2Advertisement 会关联上所有可用的 IPAdressPool。

```shell
cat <<EOF > L2Advertisement.yaml
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: example
  namespace: metallb-system
spec:
  ipAddressPools:
  - first-pool # 通过名字进行关联
EOF

kubectl apply -f L2Advertisement.yaml
```

## 验证 MetalLB 可用性

```shell
kubectl create deployment demoapp --image=ikubernetes/demoapp:v1.0 --replicas=2
kubectl create service loadbalancer demoapp --tcp=80:80

kubectl get svc demoapp
NAME      TYPE           CLUSTER-IP      EXTERNAL-IP       PORT(S)        AGE
demoapp   LoadBalancer   10.106.186.31   192.168.122.140   80:30608/TCP   38s

curl 192.168.122.140
iKubernetes demoapp v1.0 !! ClientIP: 10.244.32.128, ServerName: demoapp-75bb448dc5-sf65l, ServerIP: 10.244.69.197!
```

## 集成Ingress

### nginx-ingress

#### 1.部署ingress-nginx

修改kube-apiserver的 service监听端口范围含80和443端口,部署结果如果如下：

```shell
vim /etc/kubernetes/manifests/kube-apiserver.yaml
apiVersion: v1
kind: Pod
metadata:
  name: kube-apiserver
  namespace: kube-system
spec:
  containers:
  - command:
    - kube-apiserver
    - --service-node-port-range=80-32767 # 添加这行
```

调整ingress-controller的service类型为LoadBalancer类型

```shell
kubectl  get svc -n ingress-nginx
NAME                                 TYPE           CLUSTER-IP      EXTERNAL-IP       PORT(S)                 AGE
ingress-nginx-controller             LoadBalancer   10.108.94.77    192.168.122.141   80:80/TCP,443:443/TCP   5m54s
```

#### 2.定义ingress规则验证

```shell
cat > demoapp.yaml << 'EOF'
---
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    app: demoapp
  name: demoapp
spec:
  replicas: 2
  selector:
    matchLabels:
      app: demoapp
  template:
    metadata:
      labels:
        app: demoapp
    spec:
      containers:
      - name: demoapp
        image: ikubernetes/demoapp:v1.0
---
apiVersion: v1
kind: Service
metadata:
  labels:
    app: demoapp
  name: demoapp
spec:
  ports:
  - name: 80-80
    port: 80
    protocol: TCP
    targetPort: 80
  selector:
    app: demoapp
  type: ClusterIP
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: demoappingress
spec:
  ingressClassName: "nginx"
  rules:
  - host: demoapp.linux.io
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: demoapp
            port:
              number: 80
EOF
kubectl apply -f demoapp.yaml
 kubectl  get ingress
NAME             CLASS   HOSTS              ADDRESS                                           PORTS   AGE
demoappingress   nginx   demoapp.linux.io   192.168.122.121,192.168.122.122,192.168.122.123   80      84s
```

```shell
curl -H 'Host: demoapp.linux.io' 192.168.122.141
iKubernetes demoapp v1.0 !! ClientIP: 10.244.79.70, ServerName: demoapp-75bb448dc5-7tcjl, ServerIP: 10.244.69.199!
```
