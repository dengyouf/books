# Zabbix 6.0 监控 Kubernetes 1.31.6 快速开始指南

## 快速部署步骤

### 0. 安装 Zabbix Server（如果未安装）

如果还没有安装 Zabbix Server，请先运行安装脚本：

```bash
# 进入配置目录
cd zabbix-k8s-monitoring

# 运行安装脚本（需要 root 权限）
sudo ./install-zabbix-server.sh
```

安装完成后：
- 访问 Zabbix Web 界面: `http://<服务器IP>`
- 默认用户名: `Admin`
- 默认密码: `zabbix`
- **重要**: 首次登录后请立即修改密码！

### 1. 前置检查

确保已满足以下条件：
- ✅ 已安装 Zabbix Server 6.0（如果未安装，请先执行步骤 0）
- ✅ 已安装 Zabbix Agent 2（通常随 Zabbix Server 一起安装）
- ✅ 已安装 kubectl 并配置好 kubeconfig
- ✅ 拥有 Kubernetes 集群的管理权限

### 2. 一键部署 Kubernetes 监控

```bash
# 进入配置目录
cd zabbix-k8s-monitoring

# 运行部署脚本（需要 root 权限）
sudo ./deploy.sh
```

部署脚本会自动完成：
- 创建 Kubernetes ServiceAccount 和权限
- 获取并保存 Token
- 配置 Zabbix Agent 2
- 重启 Zabbix Agent 2 服务

### 3. 导入监控模板

1. 登录 Zabbix Web 界面
2. 进入 **配置** → **模板**
3. 点击 **导入** 按钮
4. 选择 `k8s-monitoring-template.xml` 文件
5. 点击 **导入**

### 4. 创建监控主机

1. 进入 **配置** → **主机**
2. 点击 **创建主机**
3. 填写主机信息：
   - **主机名称**: Kubernetes Cluster
   - **可见的主机名**: Kubernetes Cluster
   - **群组**: 选择或创建群组
4. 在 **模板** 标签页：
   - 添加模板: `Kubernetes API Server Monitoring`
5. 在 **宏** 标签页配置宏：
   - `{$K8S.API.SERVER}`: Kubernetes API Server 地址
     - 示例: `https://k8s-api.example.com:6443`
     - 或集群内: `https://kubernetes.default.svc:443`
   - `{$K8S.API.TOKEN}`: ServiceAccount Token（如果模板需要）
     - 从 `/etc/zabbix/k8s-token` 文件读取
6. 点击 **添加** 保存

### 5. 验证监控

运行测试脚本验证配置：

```bash
./test-connection.sh
```

脚本会检查：
- ✅ Kubernetes API Server 连接
- ✅ ServiceAccount 权限
- ✅ Zabbix Agent 2 状态

### 6. 查看监控数据

1. 进入 **监测中** → **最新数据**
2. 选择创建的主机
3. 查看监控项数据

## 常见问题

### Q: 部署脚本提示权限不足？

A: 确保使用 root 权限运行，或使用 sudo：
```bash
sudo ./deploy.sh
```

### Q: 无法连接到 Kubernetes API Server？

A: 检查：
1. kubectl 是否可以正常连接集群
2. API Server 地址是否正确
3. 网络连接是否正常

### Q: Token 获取失败？

A: 手动获取 Token：
```bash
kubectl get secret zabbix-monitoring-sa-token -n kube-system -o jsonpath='{.data.token}' | base64 -d
```

### Q: Zabbix Agent 2 无法启动？

A: 检查：
1. 配置文件语法是否正确
2. 日志文件权限
3. 查看日志: `journalctl -u zabbix-agent2 -f`

## 下一步

- 根据实际需求调整监控项采集间隔
- 配置告警规则和通知
- 添加更多自定义监控项
- 配置 Grafana 可视化（可选）

## 获取帮助

- 查看完整文档: [README.md](README.md)
- Zabbix 官方文档: https://www.zabbix.com/documentation/6.0
- Kubernetes API 文档: https://kubernetes.io/docs/reference/kubernetes-api/

