# Jenkins With Kubernetes

## Jenkins安装

### 1.准备rbac文件

```shell
cat > jenkins-rbac.yaml << 'EOF'
apiVersion: v1
kind: Namespace
metadata:
  name: jenkins
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: jenkins
  namespace: jenkins
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  annotations:
    rbac.authorization.kubernetes.io/autoupdate: "true"
  labels:
    kubernetes.io/bootstrapping: rbac-defaults
  name: jenkins
rules:
- apiGroups:
  - '*'
  resources:
  - statefulsets
  - services
  - replicationcontrollers
  - replicasets
  - podtemplates
  - podsecuritypolicies
  - pods
  - pods/log
  - pods/exec
  - podpreset
  - poddisruptionbudget
  - persistentvolumes
  - persistentvolumeclaims
  - jobs
  - endpoints
  - deployments
  - deployments/scale
  - daemonsets
  - cronjobs
  - configmaps
  - namespaces
  - events
  - secrets
  verbs:
  - create
  - get
  - watch
  - delete
  - list
  - patch
  - update
- apiGroups:
  - ""
  resources:
  - nodes
  verbs:
  - get
  - list
  - watch
  - update
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  annotations:
    rbac.authorization.kubernetes.io/autoupdate: "true"
  labels:
    kubernetes.io/bootstrapping: rbac-defaults
  name: jenkins
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: jenkins
subjects:
- apiGroup: rbac.authorization.k8s.io
  kind: Group
  name: system:serviceaccounts:jenkins
EOF
kubectl apply -f jenkins-rbac.yaml
```
### 2.准备Jenkins持久卷

```shell
cat > jenkins-pvc.yaml << 'EOF'
---
apiVersion: v1
kind:  PersistentVolumeClaim
metadata:
  name: jenkins-home
  namespace: jenkins
spec:
  storageClassName: "nfs-client"
  accessModes: [ReadWriteOnce]
  resources:
    requests:
      storage: 2Ti
EOF
kubectl apply -f jenkins-pvc.yaml
```
### 3.部署Jenkins

```shell
# 1.将
kubectl  label node k8s-worker03 jenkins=jenkins

cat > jenkins-deployment.yaml << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: jenkins
  namespace: jenkins
  labels:
    app: jenkins
spec:
  replicas: 1
  selector:
    matchLabels:
      app: jenkins
  template:
    metadata:
      labels:
        app: jenkins
    spec:
      nodeSelector:
        jenkins: jenkins
      containers:
      - name: jenkins
        # image: jenkins/jenkins:2.532-jdk21
        image: swr.cn-north-4.myhuaweicloud.com/ddn-k8s/docker.io/jenkins/jenkins:2.532-jdk21
        imagePullPolicy: IfNotPresent
        resources:
          limits:
            cpu: "2"
            memory: "4Gi"
          requests:
            cpu: "1"
            memory: "2Gi"
        securityContext:
          runAsUser: 0
        ports:
        - containerPort: 8080
          name: web
          protocol: TCP
        - containerPort: 50000
          name: agent
          protocol: TCP
        env:
        - name: LIMITS_MEMORY
          valueFrom:
            resourceFieldRef:
              resource: limits.memory
              divisor: 1Mi
        - name: JAVA_OPTS
          value: -Dhudson.security.csrf.GlobalCrumbIssuerConfiguration.DISABLE_CSRF_PROTECTION=true
        volumeMounts:
        - name: jenkins-home
          mountPath: /var/jenkins_home
        - mountPath: /etc/localtime
          name: localtime
      volumes:
      - name: jenkins-home
        persistentVolumeClaim:
          claimName: jenkins-home
      - name: localtime
        hostPath:
          path: /etc/localtime
EOF
kubectl apply -f jenkins-deployment.yaml
```

### 4.暴露Jenkins访问

```shell
cat > jenkins-svc.yaml << 'EOF'
apiVersion: v1
kind: Service
metadata:
  name: jenkins
  namespace: jenkins
  labels:
    app: jenkins
spec:
  selector:
    app: jenkins
  type: NodePort
  ports:
  - name: web
    nodePort: 32080
    port: 8080
    targetPort: web
  - name: agent
    nodePort: 32050
    port: 50000
    targetPort: agent
EOF
kubectl apply -f jenkins-svc.yaml
kubectl  get svc -n jenkins
NAME      TYPE       CLUSTER-IP       EXTERNAL-IP   PORT(S)                          AGE
jenkins   NodePort   10.104.225.175   <none>        8080:32080/TCP,50000:32050/TCP   2m18s
```

### 5.访问并安装Jenkins

 访问地址 http://192.168.1.111:32080 设置账号密码为 admin/admin123

### 6.安装插件

| 插件                                 | 说明   |
|------------------------------------|------|
| Localization: Chinese (Simplified) | 汉化插件，将 Jenkins 的界面和提示信息翻译成简体中文，方便中文用户使用   |
| Pipeline                           | Jenkins 核心流水线插件，支持通过 Jenkinsfile 定义流水线（Pipeline）作业，包括多阶段、多步骤和条件执行等功能。|
| Kubernetes                         |  允许 Jenkins 在 Kubernetes 集群上动态创建 Agent Pod 来执行构建任务，方便弹性扩展 CI/CD |
| Git                                | Git 源码管理插件，支持从 Git 仓库检出代码。是 Jenkins 最基础的 SCM 插件之一。|
| Git Parameter                      | 为 Jenkins 构建提供基于 Git 的参数化选项，例如选择分支、Tag、Commit ID 等作为构建参数。|
| GitLab                             |集成 GitLab 的插件，支持 GitLab webhook 触发 Jenkins 构建、显示 MR 状态等。 |
| Config FIle Provider               | 提供集中管理配置文件的能力，例如 Maven settings.xml、Gradle properties、Kubeconfig 等，并在构建时注入使用。|
| Extended Choice Parameter          | 扩展 Jenkins 构建参数类型，支持多选列表、复选框、下拉框等，常用于复杂的参数化构建。|
| SSH Pipeline Steps                 | 在 Pipeline 中通过 SSH 执行远程命令、传输文件或管理远程主机。常用于运维型流水线。|
| Pipeline: Stage View               | 提供流水线可视化视图，可以在 Jenkins 界面看到每个 Stage 的执行情况、状态和时间。 |
| Role-based Authorization Strategy  |基于角色的权限管理插件，允许为不同用户或组分配不同的操作权限，更灵活地控制 Jenkins 安全策略。|
| DingTalk                           | 钉钉通知插件，支持在 Jenkins 构建状态变化时发送钉钉消息通知相关人员。|

## Jenkins实践

### 1.kubernetes-plugin设置

#### 1.1.配置[kubernetes-plugin](https://github.com/jenkinsci/kubernetes-plugin)插件

- 名称: k8s-dev-cluster
- Kubernetes 地址: https://kubernetes.default.svc.cluster.local
- Kubernetes 命名空间: jenkins
- Jenkins 地址: http://jenkins.jenkins.svc.cluster.local:8080
- Jenkins 通道: jenkins.jenkins.svc.cluster.local:50000

#### 1.2.创建Job验证插件配置

```shell
pipeline {
    agent {
        kubernetes {
            cloud 'k8s-dev-cluster'
        }
    }
    stages {
        stage('Testing...') {
            steps {
                sh 'java -version'
            }
        }
    }
}
```

### 2.准备基础工具镜像

#### 2.1. maven
```shell
cat > Dockerfile  << 'EOF'
FROM maven:3-openjdk-17
ADD ./aliyun-maven-settings.xml /usr/share/maven/conf/settings.xml
RUN /bin/cp  /usr/share/zoneinfo/Asia/Shanghai /etc/localtime  && \
    echo 'Asia/Shanghai' > /etc/timezone
EOF
docker build -t harbor.devops.io/library/maven:3.8.6-aliyun .
docker push harbor.devops.io/library/maven:3.8.6-aliyun
```
#### 2.2.sonar

````shell
docker pull emeraldsquad/sonar-scanner:4
docker tag emeraldsquad/sonar-scanner:4 harbor.devops.io/library/sonar-scanner:4
docker push harbor.devops.io/library/sonar-scanner:4
````

#### 2.3.node

```shell
docker pull node:18.20.2
docker tag docker pull node:18.20.2^C
docker tag node:18.20.2 harbor.devops.io/library/node:18.20.2
docker push harbor.devops.io/library/node:18.20.2
```

#### 2.4.docker

```shell
docker pull docker:20.10
docker tag docker:20.10 harbor.devops.io/library/docker:20.10
docker push harbor.devops.io/library/docker:20.10
```

#### 2.5.kubectl

```shell
cat > Dockerfile << 'EOF'
FROM alpine:3.20

RUN apk add --no-cache curl bash

# 安装 kubectl
RUN curl -LO https://rancher-mirror.rancher.cn/kubectl/v1.26.4/linux-amd64-v1.26.4-kubectl \
    && install -o root -g root -m 0755 linux-amd64-v1.26.4-kubectl /usr/local/bin/kubectl

COPY .kube /root/.kube
WORKDIR /root
EOF
docker build -t harbor.devops.io/library/kubectl:v1.26.4 .
docker push  harbor.devops.io/library/kubectl:v1.26.4
~# docker run -it harbor.devops.io/library/kubectl:v1.26.4 kubectl get nodes
NAME           STATUS   ROLES           AGE   VERSION
k8s-master01   Ready    control-plane   10d   v1.30.12
k8s-worker01   Ready    <none>          10d   v1.30.12
k8s-worker02   Ready    <none>          10d   v1.30.12
k8s-worker03   Ready    <none>          10d   v1.30.12
```

### 3.部署应用到K8s集群

```shell
pipeline {
    agent {
        kubernetes {
            cloud 'k8s-dev-cluster'
            yaml '''
            apiVersion: v1
            kind: Pod
            spec:
              containers:
              - name: maven
                image: harbor.devops.io/library/maven:3.8.6-aliyun
                command: ["cat"]
                tty: true
              - name: sonar
                image: harbor.devops.io/library/sonar-scanner:4
                command: ["cat"]
                tty: true
              - name: nodejs
                image: harbor.devops.io/library/node:18.20.2
                command: ["cat"]
                tty: true
              - name: docker
                image: harbor.devops.io/library/docker:20.10
                command: ["cat"]
                env:
                - name: DOCKER_HOST
                  value: "tcp://192.168.1.130:2375"
                tty: true
              - name: kubectl
                image: harbor.devops.io/library/kubectl:v1.26.4
                command: ["cat"]
                tty: true
            '''
        }
    }
    environment {
      BRANCH_NAME = "${env.BUILD_ID}"
      PROJECT_KEY = "${env.JOB_NAME}"
      APP_NAME = "${PROJECT_KEY}"
      HARBOR_URL = "harbor.devops.io"
      PROJECT_NAME = "microservice"
      TAG = "${env.BUILD_ID}"
      DOCKER_IMAGE = "${HARBOR_URL}/${PROJECT_NAME}/${APP_NAME}:${TAG}"
    }
    stages {
        stage('Checkout Repo') {
          steps {
            container('maven') {
              checkout scmGit(
                  branches: [[name: '*/main']],
                  extensions: [],
                  userRemoteConfigs: [
                      [
                          credentialsId: 'gitlab-password-for-root',
                          url: 'http://192.168.1.132/devops/springboot-app.git'
                      ]
                  ]
              )
            }
          }
       }
       stage('Build Code') {
          steps {
            container('maven') {
              sh """
                  mvn package -DskipTests
              """
            }
          }
       }
      stage('Build and Push Docker Image') {
        steps {
          writeFile file: 'Dockerfile', text: '''\
              |FROM eclipse-temurin:17-jdk-jammy
              |WORKDIR /apps
              |COPY target/helloword-0.0.1-SNAPSHOT.jar /apps/
              |EXPOSE 8080
              |CMD ["java", "-jar", "/apps/helloword-0.0.1-SNAPSHOT.jar"]'''.stripMargin()
          container('docker') {
              withCredentials([usernamePassword(credentialsId: 'password-for-harbor-by-admin', usernameVariable: 'HarborUsername', passwordVariable: 'HarborPassword')]) {
                    sh """
                        docker login ${HARBOR_URL} -u ${HarborUsername} -p ${HarborPassword}
                        docker build -t ${DOCKER_IMAGE} .
                        docker push ${DOCKER_IMAGE}
                    """
              }
            }
          }
       }
       stage('Deploy Application to Cluster') {
          steps {
            container('kubectl') {
                sh """
                  sed -i 's@"__IMAGE__"@"${DOCKER_IMAGE}"@g' manifests/deployment.yaml
                  kubectl apply -f manifests -n default
                """
            }
          }
       }
    }
}
```

### 4.优化缓存构建

```shell

```
