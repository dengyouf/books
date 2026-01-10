# Sealos 安装 Kubernetes v1.28.7(Containerd)

使用Sealos快速部署Kubernetes集群，支持在线和离线安装，适用于amd64和arm64架构。轻松管理节点，安装分布式应用，支持Containerd和Docker运行时。

以下是一些基本的安装要求：

- 每个集群节点应该有不同的主机名。主机名不要带下划线。
- 所有节点的时间需要同步。
- 需要在 K8s 集群的第一个 master 节点上运行 sealos run 命令，目前集群外的节点不支持集群安装。
- 建议使用干净的操作系统来创建集群。不要自己装 Docker！
- 支持大多数 Linux 发行版，例如：Ubuntu、CentOS、Rocky linux。
- 支持 Docker Hub 中的所有 Kubernetes 版本。
- 支持使用 Containerd 作为容器运行时。
- 在公有云上安装请使用私有 IP。

## 主机环境准备
使用Sealos快速部署Kubernetes集群，操作系统为Ubuntu 24.04.2 LTS(noble)，用到的各相关程序版本如下:

- Kubernetes: v1.28.7
- Contianerd: v1.7.27
- cilium: v1.14.7

| 主机名         | IP            | 角色     |
|-------------|---------------|--------|
| k8smaster01 | 192.168.2.211 | master |
| k8sworker01 | 192.168.2.221 | worker |
| k8sworker02 | 192.168.2.222 | worker |
| k8sworker03 | 192.168.2.223 | worker |


## 下载 Sealos 命令行工具

```shell
# 获取版本列表
curl --silent "https://api.github.com/repos/labring/sealos/releases" | jq -r '.[].tag_name'
# 设置VERSION环境变量为指定版本号
VERSION=v5.0.1
# 设置github代理
export PROXY_PREFIX=https://ghfast.top
# 下载指定版本
curl -sfL ${PROXY_PREFIX}/https://raw.githubusercontent.com/labring/sealos/main/scripts/install.sh | PROXY_PREFIX=${PROXY_PREFIX} sh -s ${VERSION} labring/sealos
sealos version
SealosVersion:
  buildDate: "2024-10-09T02:18:27Z"
  compiler: gc
  gitCommit: 2b74a1281
  gitVersion: 5.0.1
  goVersion: go1.20.14
  platform: linux/amd64
```

## 查看[集群镜像](https://github.com/labring-actions/cluster-image-docs)

- [registry.cn-shanghai.aliyuncs.com/labring/kubernetes:v1.28.7](https://github.com/labring-actions/cluster-image-docs/blob/main/docs/aliyun-shanghai/rootfs.md)
- [registry.cn-shanghai.aliyuncs.com/labring/cilium:v1.14.7](https://github.com/labring-actions/cluster-image-docs/blob/main/docs/aliyun-shanghai/apps.md)
- [registry.cn-shanghai.aliyuncs.com/labring/helm:v3.9.4](https://github.com/labring-actions/cluster-image-docs/blob/main/docs/aliyun-shanghai/apps.md)

## 安装依赖

```shell
apt install -y \
  curl \
  wget \
  socat \
  ebtables \
  ethtool \
  conntrack \
  iptables \
  iproute2 \
  ipset \
  jq \
  tar \
  bash-completion \
  openssl
```
## 安装集群

```shell
sealos  run registry.cn-shanghai.aliyuncs.com/labring/kubernetes:v1.28.7 \
            registry.cn-shanghai.aliyuncs.com/labring/cilium:v1.14.7 \
            registry.cn-shanghai.aliyuncs.com/labring/helm:v3.9.4 \
            --masters 192.168.2.211 \
            --nodes 192.168.2.221,192.168.2.222 \
            -u root \
            -p passw0rd
  ...
ℹ️  Using Cilium version 1.14.7
🔮 Auto-detected cluster name: kubernetes
🔮 Auto-detected kube-proxy has been installed
2025-12-05T21:16:55 info succeeded in creating a new cluster, enjoy it!
2025-12-05T21:16:55 info
      ___           ___           ___           ___       ___           ___
     /\  \         /\  \         /\  \         /\__\     /\  \         /\  \
    /::\  \       /::\  \       /::\  \       /:/  /    /::\  \       /::\  \
   /:/\ \  \     /:/\:\  \     /:/\:\  \     /:/  /    /:/\:\  \     /:/\ \  \
  _\:\~\ \  \   /::\~\:\  \   /::\~\:\  \   /:/  /    /:/  \:\  \   _\:\~\ \  \
 /\ \:\ \ \__\ /:/\:\ \:\__\ /:/\:\ \:\__\ /:/__/    /:/__/ \:\__\ /\ \:\ \ \__\
 \:\ \:\ \/__/ \:\~\:\ \/__/ \/__\:\/:/  / \:\  \    \:\  \ /:/  / \:\ \:\ \/__/
  \:\ \:\__\    \:\ \:\__\        \::/  /   \:\  \    \:\  /:/  /   \:\ \:\__\
   \:\/:/  /     \:\ \/__/        /:/  /     \:\  \    \:\/:/  /     \:\/:/  /
    \::/  /       \:\__\         /:/  /       \:\__\    \::/  /       \::/  /
     \/__/         \/__/         \/__/         \/__/     \/__/         \/__/

                  Website: https://www.sealos.io/
                  Address: github.com/labring/sealos
                  Version: 5.0.1-2b74a1281
~# kubectl  get nodes
NAME          STATUS   ROLES           AGE     VERSION
k8smaster01   Ready    control-plane   2m39s   v1.28.7
k8sworker01   Ready    <none>          2m19s   v1.28.7
k8sworker02   Ready    <none>          2m14s   v1.28.7
root@k8smaster01:~# kubectl  get pod -A
NAMESPACE     NAME                                  READY   STATUS    RESTARTS   AGE
kube-system   cilium-545dt                          1/1     Running   0          2m18s
kube-system   cilium-8mpmc                          1/1     Running   0          2m18s
kube-system   cilium-gpl89                          1/1     Running   0          2m18s
kube-system   cilium-operator-64b8744fc5-7xnwf      1/1     Running   0          2m18s
kube-system   coredns-5dd5756b68-6stxl              1/1     Running   0          2m29s
kube-system   coredns-5dd5756b68-jpzkx              1/1     Running   0          2m29s
kube-system   etcd-k8smaster01                      1/1     Running   0          2m42s
kube-system   kube-apiserver-k8smaster01            1/1     Running   0          2m42s
kube-system   kube-controller-manager-k8smaster01   1/1     Running   0          2m42s
kube-system   kube-proxy-dkl4z                      1/1     Running   0          2m26s
kube-system   kube-proxy-l6g2k                      1/1     Running   0          2m29s
kube-system   kube-proxy-zp7fn                      1/1     Running   0          2m21s
kube-system   kube-scheduler-k8smaster01            1/1     Running   0          2m43s
kube-system   kube-sealos-lvscare-k8sworker01       1/1     Running   0          2m8s
kube-system   kube-sealos-lvscare-k8sworker02       1/1     Running   0          2m3s
```
```shell
~# kubeadm  version
kubeadm version: &version.Info{Major:"1", Minor:"28", GitVersion:"v1.28.7", GitCommit:"c8dcb00be9961ec36d141d2e4103f85f92bcf291", GitTreeState:"clean", BuildDate:"2024-02-14T10:39:01Z", GoVersion:"go1.21.7", Compiler:"gc", Platform:"linux/amd64"}
~# cilium version
cilium-cli: v0.15.23 compiled with go1.22.0 on linux/amd64
cilium image (default): v1.15.0
cilium image (stable): v1.18.4
cilium image (running): 1.14.7
~# helm version
version.BuildInfo{Version:"v3.9.4", GitCommit:"dbc6d8e20fe1d58d50e6ed30f09a04a77e4c68db", GitTreeState:"clean", GoVersion:"go1.17.13"}
```

## [节点管理命令](https://sealos.run/docs/k8s/reference/sealos/commands)

- add：将节点添加到集群中。
- delete：从集群中删除节点。

```shell
sealos  add --nodes 192.168.2.223 --port 22 -u root -p passw0rd
 kubectl  get nodes -o wide
NAME          STATUS   ROLES           AGE     VERSION   INTERNAL-IP     EXTERNAL-IP   OS-IMAGE             KERNEL-VERSION     CONTAINER-RUNTIME
k8smaster01   Ready    control-plane   8m34s   v1.28.7   192.168.2.211   <none>        Ubuntu 24.04.3 LTS   6.8.0-88-generic   containerd://1.7.27
k8sworker01   Ready    <none>          8m14s   v1.28.7   192.168.2.221   <none>        Ubuntu 24.04.3 LTS   6.8.0-88-generic   containerd://1.7.27
k8sworker02   Ready    <none>          8m9s    v1.28.7   192.168.2.222   <none>        Ubuntu 24.04.3 LTS   6.8.0-88-generic   containerd://1.7.27
k8sworker03   Ready    <none>          58s     v1.28.7   192.168.2.223   <none>        Ubuntu 24.04.3 LTS   6.8.0-88-generic   containerd://1.7.27
```

## 部署WordPress

### 1. 创建命名空间

```shell
kubectl  create ns wp
```

Welcome to Material for MkDocs.

!!! note "Important Note"
    You can customize the title here.

!!! warning inline end "Warning: Collapsed by Default"
    This block is collapsible.
aaa
