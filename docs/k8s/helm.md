# Helm
Helm 是 Kubernetes 的包管理器。其通过Helm Charts定义、安装和升级负载的Kubernetes应用程序，Charts是Kubernetes资源清单的模版文件，通过Charts可以简化维护应用程序的YAML资源清单文件。此外，Charts支持版本管理、分享、发布。

- Helm: CLI工具
- Charts：组织部署清单的模版文件组合，静态文件
- Release: 应用Charts生成的对象资源，例如运行的Deployment，SVC资源等

## [Helm安装](https://github.com/helm/helm/releases)

```shell
~# wget https://get.helm.sh/helm-v3.18.3-linux-amd64.tar.gz
~# tar -xf helm-v3.18.3-linux-amd64.tar.gz
~# cp linux-amd64/helm /usr/bin/
~# helm version
version.BuildInfo{Version:"v3.18.3", GitCommit:"6838ebcf265a3842d1433956e8a622e3290cf324", GitTreeState:"clean", GoVersion:"go1.24.4"}
```

## helm基础使用

### 1.添加[charts](https://mirror.azure.cn/kubernetes/charts/)仓库

```shell
~# helm repo add stable http://mirror.azure.cn/kubernetes/charts/
~# helm repo add bitnami https://charts.bitnami.com/bitnami
~# helm repo ls
NAME   	URL
stable 	http://mirror.azure.cn/kubernetes/charts/
bitnami	https://charts.bitnami.com/bitnami
```
### 2.搜索charts
```shell
~# helm search repo bitnami
```

### 3.安装Chart
```shell
~# helm repo update
~# helm install stable/mysql --generate-name --set persistence.enabled=false
```
```shell
~# kubectl  get all -l release=mysql-1761113274
~# helm list
```
### 4.卸载Release
```shell
~# helm uninstall mysql-1761113274
~# helm del mysql-1761113274 -n default
```

### 5.查看包信息
```shell
~# helm show chart stable/mysql
~# helm show values stable/mysql
~# helm show all stable/mysql
```

### 6.获取release的部署清单信息
```shell
~# helm get manifest mmysql-1761113274
```
### 7.定制安装

- 定制values.yaml

```shell
~# helm search repo stable/mysql
NAME            	CHART VERSION	APP VERSION	DESCRIPTION
stable/mysql    	1.6.9        	5.7.30     	DEPRECATED - Fast, reliable, scalable, and easy...
stable/mysqldump	2.6.2        	2.4.1      	DEPRECATED! - A Helm chart to help backup MySQL...
# 获取charts
~# helm pull stable/mysql --version 1.6.9 --untar
~# helm fetch stable/mysql --version 1.6.9 --untar
~# cd mysql
# 定制values.yaml
~# vim mysql/values.yaml
...
persistence:
  enabled: false
...
nodeSelector:
  kubernetes.io/hostname: k8s-worker02
~/mysql# helm install mysql57 . -f mysql/values.yaml
# 强制更新,重新部署 Pod
~/mysql# helm upgrade --install mysql57 . -f values.yaml --force --recreate-pods
```

- `--set定制安装`

```shell
~# helm install stable/mysql --generate-name --set persistence.enabled=false --set nodeSelector."kubernetes\.io/hostname"=k8s-worker02
```
### 8.回滚

```shell
~# helm install mysql57 stable/mysql --set persistence.enabled=false
~# helm upgrade mysql57 stable/mysql --set persistence.enabled=false --set imageTag=5.7.38
~# helm history mysql57
REVISION	UPDATED                 	STATUS    	CHART      	APP VERSION	DESCRIPTION
1       	Wed Oct 22 15:00:46 2025	superseded	mysql-1.6.9	5.7.30     	Install complete
2       	Wed Oct 22 15:02:34 2025	deployed  	mysql-1.6.9	5.7.30     	Upgrade complete
~# helm rollback mysql57 1
Rollback was a success! Happy Helming!
```

### 9.渲染输出清单

```shell
~# helm template mysql57 stable/mysql --set persistence.enabled=false --set imageTag=5.7.38
```

## Charts解析

Helm 使用一种名为charts的包格式。一个Charts是描述一组相关的Kubernets部署资源清单文件集合。Charts是创建在特定目录下面的文件集合，然后可以将它们打包到一个版本化的存档中来部署。

- [Go模版函数](https://masterminds.github.io/sprig/)

```shell
~# tree -L 2 mysql
mysql
├── Chart.yaml      # 包含当前 chart 信息的 YAML 文件
├── README.md       # 可选：一个可读性高的 README 文件
├── templates       # 模板目录，与 values 结合使用时，将渲染生成 Kubernetes 资源清单文件
│   ├── configurationFiles-configmap.yaml
│   ├── deployment.yaml
│   ├── _helpers.tpl
│   ├── initializationFiles-configmap.yaml
│   ├── NOTES.txt   # 可选: 包含简短使用使用的文本文件
│   ├── pvc.yaml
│   ├── secrets.yaml
│   ├── serviceaccount.yaml
│   ├── servicemonitor.yaml
│   ├── svc.yaml
│   └── tests
└── values.yaml
```

## Helm实践

### 1. 初始化charts模版

```shell
~# helm create myapp
```

### 2. 定制values.yaml

```shell
replicaCount: 3
image:
  repository: harbor.devops.io/baseimages/myapp
  pullPolicy: IfNotPresent
  tag: "v1"
imagePullSecrets:
  - name: harbor-secret

resources:
  limits:
    cpu: 100m
    memory: 128Mi
  requests:
    cpu: 100m
    memory: 128Mi
```

### 3. 定制Charts.yaml

```shell
~# sed -i 's@appVersion: "1.16.0"@appVersion: "v1"@' myapp/Chart.yaml
~# helm upgrade --install  myapp myapp --set image.tag="v2"
```

### 4.测试安装

```shell
~# helm upgrade --install  myapp myapp
~# helm ls
NAME   	NAMESPACE	REVISION	UPDATED                                	STATUS  	CHART      	APP VERSION
myapp  	default  	1       	2025-10-23 14:44:59.809403967 +0800 CST	deployed	myapp-0.1.0	v1
```

### 5.升级安装

```shell
~# sed -i 's@appVersion: "v1"@appVersion: "v2"@g' myapp/Chart.yaml
```

### 6.回滚

```shell
~# helm history myapp
REVISION	UPDATED                 	STATUS    	CHART      	APP VERSION	DESCRIPTION
1       	Thu Oct 23 14:44:59 2025	superseded	myapp-0.1.0	v1         	Install complete
2       	Thu Oct 23 14:49:46 2025	deployed  	myapp-0.1.0	v2         	Upgrade complete
#
~# helm rollback myapp 1
```

### 7.打包

```shell
~# helm package myapp --version 0.0.1
Successfully packaged chart and saved it to: /root/myapp-0.0.1.tgz
```

### 8.推送到harbor仓库

```shell
cp  /etc/containerd/certs.d/harbor.devops.io/ca.crt  /usr/local/share/ca-certificates/harbor.devops.io.crt
update-ca-certificates
export HELM_EXPERIMENTAL_OCI=1
helm registry login harbor.devops.io -u admin -p Harbor12345
~# helm push myapp-0.0.1.tgz  oci://harbor.devops.io/charts
```

### 9.使用charts

```shell
~# helm install myapp oci://harbor.devops.io/charts/myapp  --version 0.0.1
~# helm pull oci://harbor.devops.io/charts/myapp --version 0.0.1 --untar
```
