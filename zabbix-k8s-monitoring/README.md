# Zabbix 6.0 监控 Kubernetes 1.31.6 配置指南

## 概述

本配置方案用于通过 Zabbix 6.0 监控 Kubernetes 1.31.6 集群，主要通过 Kubernetes API Server 进行监控。

## 架构说明

- **Zabbix Server**: 6.0 版本
- **Kubernetes**: 1.31.6 版本
- **监控方式**: 通过 Kubernetes API Server 进行监控
- **认证方式**: ServiceAccount Token 或 Kubeconfig

## 前置条件

1. **Ubuntu ARM 架构系统**（aarch64/arm64）
2. 已安装并运行 Zabbix Server 6.0（如果未安装，请参考下面的安装步骤）
3. 已安装 Zabbix Agent 2（支持 Kubernetes 监控）
4. 拥有 Kubernetes 集群的访问权限（API Server 地址和认证信息）
5. 在 Kubernetes 集群中创建了 ServiceAccount 并授予相应权限

## Zabbix Server 安装（Ubuntu ARM 架构）

如果还没有安装 Zabbix Server，可以使用提供的安装脚本进行安装。

### 方式一：使用安装脚本（推荐）

```bash
# 运行安装脚本（需要 root 权限）
sudo ./install-zabbix-server.sh
```

安装脚本会自动完成：
- 安装 Docker 和 Docker Compose
- 创建必要的目录结构
- 配置环境变量
- 启动 Zabbix Server、Web、Agent 和数据库服务

### 方式二：手动安装

1. **安装 Docker 和 Docker Compose**

```bash
# 更新系统
sudo apt-get update

# 安装 Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# 启动 Docker 服务
sudo systemctl start docker
sudo systemctl enable docker
```

2. **配置环境变量**

```bash
# 复制环境变量示例文件
cp env.example .env

# 编辑 .env 文件，修改数据库密码
nano .env
```

3. **启动 Zabbix 服务**

```bash
# 使用 docker-compose 启动
sudo docker compose -f docker-compose-zabbix.yml up -d
```

4. **访问 Zabbix Web 界面**

- 访问地址: `http://<服务器IP>`
- 默认用户名: `Admin`
- 默认密码: `zabbix`

**重要**: 首次登录后请立即修改默认密码！

### 验证安装

```bash
# 检查服务状态
cd /opt/zabbix
sudo docker compose ps

# 查看日志
sudo docker compose logs -f
```

### 服务管理

```bash
cd /opt/zabbix

# 启动服务
sudo docker compose up -d

# 停止服务
sudo docker compose down

# 重启服务
sudo docker compose restart

# 查看日志
sudo docker compose logs -f zabbix-server
```

## 目录结构

```
zabbix-k8s-monitoring/
├── README.md                          # 本文档
├── QUICKSTART.md                      # 快速开始指南
├── docker-compose-zabbix.yml          # Zabbix Server Docker Compose 配置
├── install-zabbix-server.sh           # Zabbix Server 安装脚本
├── env.example                        # 环境变量配置示例
├── zabbix-agent2.conf                 # Zabbix Agent 2 配置文件
├── k8s-monitoring-template.xml        # Zabbix 监控模板（XML 格式）
├── k8s-serviceaccount.yaml            # Kubernetes ServiceAccount 配置
├── k8s-clusterrole.yaml               # Kubernetes ClusterRole 配置
├── k8s-clusterrolebinding.yaml         # Kubernetes ClusterRoleBinding 配置
├── deploy.sh                          # Kubernetes 监控部署脚本
└── test-connection.sh                 # 连接测试脚本
```

## 完整部署流程

### 步骤 0: 安装 Zabbix Server（如果未安装）

如果还没有安装 Zabbix Server，请先运行：

```bash
sudo ./install-zabbix-server.sh
```

安装完成后，访问 Zabbix Web 界面（默认地址: http://<服务器IP>），使用默认账号登录：
- 用户名: `Admin`
- 密码: `zabbix`

**重要**: 首次登录后请立即修改密码！

### 步骤 1: 在 Kubernetes 集群中创建监控账户

```bash
# 应用 ServiceAccount 和权限配置
kubectl apply -f k8s-serviceaccount.yaml
kubectl apply -f k8s-clusterrole.yaml
kubectl apply -f k8s-clusterrolebinding.yaml

# 获取 ServiceAccount Token
kubectl get secret zabbix-monitoring-sa-token -n kube-system -o jsonpath='{.data.token}' | base64 -d > /etc/zabbix/k8s-token
chmod 600 /etc/zabbix/k8s-token
```

### 2. 配置 Zabbix Agent 2

编辑 `zabbix-agent2.conf` 文件，设置以下参数：

- `Kubernetes.API.Server`: Kubernetes API Server 地址
- `Kubernetes.API.TokenFile`: ServiceAccount Token 文件路径
- `Kubernetes.API.CAFile`: Kubernetes CA 证书路径（如果使用自签名证书）

### 3. 导入监控模板

在 Zabbix Web 界面中：
1. 进入 **配置** → **模板**
2. 点击 **导入**
3. 选择 `k8s-monitoring-template.xml` 文件
4. 点击 **导入**

### 4. 配置主机和监控项

1. 在 Zabbix 中创建新主机
2. 关联导入的 Kubernetes 监控模板
3. 配置主机宏：
   - `{$K8S.API.SERVER}`: Kubernetes API Server 地址
   - `{$K8S.API.TOKEN}`: ServiceAccount Token（如果使用 Token 方式）

### 5. 启动 Zabbix Agent 2

```bash
# 使用部署脚本
./deploy.sh

# 或手动启动
systemctl restart zabbix-agent2
systemctl enable zabbix-agent2
```

## 监控指标说明

### 集群级别指标

- **节点状态**: 节点数量、就绪节点数、不可用节点数
- **Pod 状态**: 总 Pod 数、运行中 Pod 数、失败 Pod 数
- **资源使用**: CPU/内存请求和限制使用率
- **API Server 健康**: API Server 响应时间、可用性

### 节点级别指标

- **节点信息**: CPU、内存、磁盘、网络
- **节点状态**: Ready、NotReady、Unknown
- **节点资源**: 可分配资源、已使用资源

### Pod 级别指标

- **Pod 状态**: Running、Pending、Failed、Succeeded
- **Pod 资源**: CPU/内存使用率
- **容器状态**: 容器重启次数、状态

### 工作负载指标

- **Deployment**: 副本数、就绪副本数、可用副本数
- **StatefulSet**: 副本数、就绪副本数
- **DaemonSet**: 期望副本数、当前副本数、就绪副本数
- **Job/CronJob**: 完成数、失败数

## 配置参数说明

### Zabbix Agent 2 配置参数

| 参数 | 说明 | 示例值 |
|------|------|--------|
| `Kubernetes.API.Server` | Kubernetes API Server 地址 | `https://k8s-api.example.com:6443` |
| `Kubernetes.API.TokenFile` | ServiceAccount Token 文件路径 | `/etc/zabbix/k8s-token` |
| `Kubernetes.API.CAFile` | Kubernetes CA 证书路径 | `/etc/zabbix/k8s-ca.crt` |
| `Kubernetes.API.Timeout` | API 请求超时时间（秒） | `10` |

### Kubernetes 权限要求

ServiceAccount 需要以下权限：

- `nodes`: get, list, watch
- `pods`: get, list, watch
- `deployments`: get, list, watch
- `statefulsets`: get, list, watch
- `daemonsets`: get, list, watch
- `jobs`: get, list, watch
- `cronjobs`: get, list, watch
- `services`: get, list, watch
- `endpoints`: get, list, watch
- `events`: get, list, watch

## 测试连接

运行测试脚本验证配置：

```bash
./test-connection.sh
```

脚本会检查：
- Kubernetes API Server 连接性
- 认证是否成功
- 权限是否足够
- Zabbix Agent 2 是否正常运行

## 故障排查

### 问题 1: 无法连接到 Kubernetes API Server

**检查项**:
- API Server 地址是否正确
- 网络连接是否正常
- 防火墙规则是否允许访问

**解决方案**:
```bash
# 测试 API Server 连接
curl -k https://<API_SERVER>:6443/version

# 检查 DNS 解析
nslookup <API_SERVER>
```

### 问题 2: 认证失败

**检查项**:
- Token 文件是否存在且可读
- Token 是否有效
- ServiceAccount 是否已创建

**解决方案**:
```bash
# 验证 Token
kubectl get secret zabbix-monitoring-sa-token -n kube-system

# 重新获取 Token
kubectl get secret zabbix-monitoring-sa-token -n kube-system -o jsonpath='{.data.token}' | base64 -d
```

### 问题 3: 权限不足

**检查项**:
- ClusterRole 是否正确配置
- ClusterRoleBinding 是否绑定到正确的 ServiceAccount

**解决方案**:
```bash
# 检查权限
kubectl auth can-i get nodes --as=system:serviceaccount:kube-system:zabbix-monitoring-sa

# 重新应用权限配置
kubectl apply -f k8s-clusterrole.yaml
kubectl apply -f k8s-clusterrolebinding.yaml
```

### 问题 4: Zabbix Agent 2 无法获取数据

**检查项**:
- Agent 2 是否正常运行
- 配置参数是否正确
- 日志中是否有错误信息

**解决方案**:
```bash
# 检查 Agent 2 状态
systemctl status zabbix-agent2

# 查看日志
journalctl -u zabbix-agent2 -f

# 测试 Agent 2 连接
zabbix_agent2 -t kubernetes.discovery
```

## 性能优化建议

1. **调整采集间隔**: 根据实际需求调整监控项的数据采集间隔
2. **使用主动模式**: 对于大规模集群，建议使用 Zabbix Agent 2 主动模式
3. **过滤不必要指标**: 只监控关键指标，减少 API Server 负载
4. **使用缓存**: 对于不经常变化的数据，使用 Zabbix 的缓存机制

## 安全建议

1. **最小权限原则**: 只授予监控所需的最小权限
2. **Token 安全**: 妥善保管 ServiceAccount Token，定期轮换
3. **网络隔离**: 限制对 Kubernetes API Server 的访问
4. **TLS 加密**: 使用 TLS 加密 API Server 通信
5. **审计日志**: 启用 Kubernetes 审计日志，监控异常访问

## 参考资源

- [Zabbix 官方文档](https://www.zabbix.com/documentation/6.0/manual)
- [Zabbix Agent 2 Kubernetes 监控](https://www.zabbix.com/documentation/6.0/manual/config/items/itemtypes/zabbix_agent/active_passive)
- [Kubernetes API 文档](https://kubernetes.io/docs/reference/kubernetes-api/)
- [Kubernetes RBAC 文档](https://kubernetes.io/docs/reference/access-authn-authz/rbac/)

## 更新日志

- **2024-XX-XX**: 初始版本，支持 Zabbix 6.0 和 Kubernetes 1.31.6

