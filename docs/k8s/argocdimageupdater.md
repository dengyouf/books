
# ArgoCD Image Update

ArgoCD Image Update 会定期轮训 ArgoCD 中配置的应用程序，并查询相应的惊喜仓库以获取可能的新版本。如果仓库中找到的新版本满足版本约束，ArgoCD Image Update将知识ArgoCD使用心得版本更新应用程序。

ArgoCD Image Update通过读取ArgoCD应用资源中的 annotations 来工作，这些注解指定应更新哪些惊喜。检查镜像版本库中是否有较新的标签。如果它们与预定义的模式或者规则相匹配，则使用新标签更新应用程序清单，此自动化过程可确保应用程序始终运行最新的版本，遵循GitOps的一致性和可追溯原则。

- Annotation配置：开发人员注解ArgoCD硬哟哦那个程序以高速Image Updater要跟着哪些镜像，包括标签过滤和更新策略的规则
- 自动更新：当满足新镜像满足标签规则是，会自动更新应用程序，并提交到Git仓库
- 同步变更：ArgoCD检测到提交的更改，同步更新的清单，并将他们应用到目标集群

| 更新策略    | 说明                    |
|---------|-----------------------|
| semver  | 根据给定的镜像约束更新到允许的最高版本   |
| latest  | 更新到最近创建的镜像标签          |
| name    | 更新到按照字母顺序排序列表中的最后一个标签 |
| diggest | 更新到可变标签的最新推送版本标签      |

## 安装

```shell
#
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj-labs/argocd-image-updater/stable/config/install.yaml
kubectl  get pod -n argocd
argocd-image-updater-controller-5db64f5795-bwjr9    1/1     Running   0          78s
```

## 配置 harbor信息
```shell
kubectl create secret docker-registry harbor-secret   \
    --docker-server=harbor.devops.io   \
    --docker-username=admin   \
    --docker-password=Harbor12345   \
    --docker-email=harbro@devops.com \
    -n argocd

cat  > argocd-image-updater-config.yaml << EOF
apiVersion: v1
kind: ConfigMap
metadata:
  labels:
    app.kubernetes.io/name: argocd-image-updater-config
    app.kubernetes.io/part-of: argocd-image-updater-controller
  name: argocd-image-updater-config
  namespace: argocd
data:
  registries.conf: |
    registries:
      # Harbor 私有仓库配置
      - name: devops-harbor
        api_url: https://harbor.devops.io
        # 凭据格式：pullsecret:<namespace>/<secret-name>
        credentials: pullsecret:argocd/harbor-secret
        defaultns: library
        default: true
        # 可选：跳过 TLS 验证（如果是自签名证书）
        insecure: true
EOF
# coredns 解析
kubectl  edit cm coredns -n kube-system
  Corefile: |
    ...
        kubernetes cluster.local in-addr.arpa ip6.arpa {
           pods insecure
           fallthrough in-addr.arpa ip6.arpa
           ttl 30
        }
        hosts {
          192.168.2.170 harbor.devops.io
          fallthrough
        }
        prometheus :9153
       ...
    }
kubectl  rollout restart deploy  coredns -n kube-system
kubectl apply -f argocd-image-updater-config.yaml
kubectl  rollout restart deploy  argocd-image-updater-controller -n argocd
```
