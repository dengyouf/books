# GitOps

GitOps 是 Weaveworks 提出的一种持续交付方式，核心思想是将应用系统的声明式基础架构和应用程序存放到git版本库中。**将 Git 作为交付流水线的核心**， 通过对git仓库资源的提交拉取请求，实现Kubernetes应用程序的额部署和运维工作。

- 安全的云原生CI/CD流水线模型
- 更快的部署和恢复时间
- 稳定且可重现的回滚
- 与监控和柯丝滑工具结合，对已经部署的应用进行全方位监控

## ArgoCD

ArgoCD 遵循 GitOps 理念的持续部署工具，它实现在Git版本库变更时自动同步和部署应用到目标Kubernetes集群。

### 安装

```shell
# https://github.com/argoproj/argo-cd/releases
kubectl create namespace argocd
kubectl apply -n argocd --server-side --force-conflicts -f https://raw.githubusercontent.com/argoproj/argo-cd/v3.3.0/manifests/install.yaml

kubectl  get pod -n argocd
NAME                                                READY   STATUS    RESTARTS   AGE
argocd-application-controller-0                     1/1     Running   0          3m5s
argocd-applicationset-controller-7d69687ddf-zlm9k   1/1     Running   0          3m6s
argocd-dex-server-698498699d-nszmh                  1/1     Running   0          3m6s
argocd-notifications-controller-77b75d9496-9cmhp    1/1     Running   0          3m6s
argocd-redis-7c5f9bd9b9-d5xt2                       1/1     Running   0          3m6s
argocd-repo-server-69c76b749b-zqnwd                 1/1     Running   0          3m5s
argocd-server-6457dd59df-zzrtr                      1/1     Running   0          3m5s
```

### 访问ArgoCD

使用 NodePort 方式暴漏服务访问

```shell
 kubectl  patch svc  argocd-server  -p '{"spec":{"type":"NodePort"}}' -n argocd
service/argocd-server patched (no change)
root@u24-k8s-master01:~# kubectl  get svc -n argocd
NAME                                      TYPE        CLUSTER-IP    EXTERNAL-IP   PORT(S)                      AGE
argocd-applicationset-controller          ClusterIP   10.96.3.186   <none>        7000/TCP,8080/TCP            8m25s
argocd-dex-server                         ClusterIP   10.96.2.68    <none>        5556/TCP,5557/TCP,5558/TCP   8m25s
argocd-metrics                            ClusterIP   10.96.3.174   <none>        8082/TCP                     8m25s
argocd-notifications-controller-metrics   ClusterIP   10.96.2.217   <none>        9001/TCP                     8m25s
argocd-redis                              ClusterIP   10.96.0.157   <none>        6379/TCP                     8m25s
argocd-repo-server                        ClusterIP   10.96.2.222   <none>        8081/TCP,8084/TCP            8m25s
argocd-server                             NodePort    10.96.2.251   <none>        80:31773/TCP,443:32670/TCP   8m25s
argocd-server-metrics                     ClusterIP   10.96.1.244   <none>        8083/TCP                     8m25s
```

默认用户名为admin，通过下面的方式获取访问密码

```shell
kubectl  get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" -n argocd|base64  -d && echo
yoCBltLTd6f4r4Nl
```

### 安装ArgoCD CLI

```shell
wget https://github.com/argoproj/argo-cd/releases/download/v3.3.0/argocd-linux-amd64
mv argocd-linux-amd64  /usr/local/bin/argocd
chmod +x /usr/local/bin/argocd
```
```shell
# 登陆
argocd login 192.168.2.111:31773
WARNING: server certificate had error: error creating connection: tls: failed to verify certificate: x509: cannot validate certificate for 192.168.2.111 because it doesn't contain any IP SANs. Proceed insecurely (y/n)? y
Username: admin
Password:
'admin:login' logged in successfully
Context '192.168.2.111:31773' updated

# 列出集群，没有交付任何应用所以为Unknown
 argocd  cluster list
SERVER                          NAME        VERSION  STATUS   MESSAGE                                                  PROJECT
https://kubernetes.default.svc  in-cluster           Unknown  Cluster has no applications and is not being monitored.
```

### 配置集群

```shell
# 李处集群上下文
kubectl  config get-contexts -o name
kubernetes-admin@kubernetes
# 添加集群
argocd cluster add kubernetes-admin@kubernetes
WARNING: This will create a service account `argocd-manager` on the cluster referenced by context `kubernetes-admin@kubernetes` with full cluster level privileges. Do you want to continue [y/N]? y
{"level":"info","msg":"ServiceAccount \"argocd-manager\" already exists in namespace \"kube-system\"","time":"2026-02-07T12:34:15+08:00"}
{"level":"info","msg":"ClusterRole \"argocd-manager-role\" updated","time":"2026-02-07T12:34:15+08:00"}
{"level":"info","msg":"ClusterRoleBinding \"argocd-manager-role-binding\" updated","time":"2026-02-07T12:34:15+08:00"}
{"level":"info","msg":"Using existing bearer token secret \"argocd-manager-long-lived-token\" for ServiceAccount \"argocd-manager\"","time":"2026-02-07T12:34:15+08:00"}
Cluster 'https://192.168.2.111:6443' added
```

### 创建应用

```shell
argocd repo add http://192.168.2.160/gitops/argocd-example-apps.git \
  --username root \
  --password dy6545286
# 默认是手动同步
argocd app create guestbook \
  --repo http://192.168.2.160/gitops/argocd-example-apps.git \
  --path guestbook \
  --dest-server https://192.168.2.111:6443 \
  --dest-namespace default \
  --project default


~# argocd app list
NAME              CLUSTER                     NAMESPACE  PROJECT  STATUS     HEALTH   SYNCPOLICY  CONDITIONS  REPO                                                 PATH       TARGET
argocd/guestbook  https://192.168.2.111:6443  default    default  OutOfSync  Missing  Manual      <none>      http://192.168.2.160/gitops/argocd-example-apps.git  guestbook
# 同步
argocd app sync argocd/guestbook
```

### Appication


### ApplicationSet






