# Zabbix Server 6.0 安装指南（Ubuntu ARM 架构）

## 系统要求

- **操作系统**: Ubuntu 20.04+ (ARM64/aarch64)
- **内存**: 至少 2GB RAM（推荐 4GB+）
- **磁盘空间**: 至少 10GB 可用空间
- **网络**: 能够访问 Docker Hub 或镜像仓库

## 安装方式

### 方式一：使用自动化安装脚本（推荐）

这是最简单快捷的安装方式，脚本会自动完成所有配置。

```bash
# 1. 进入配置目录
cd zabbix-k8s-monitoring

# 2. 运行安装脚本（需要 root 权限）
sudo ./install-zabbix-server.sh
```

安装脚本会自动：
- ✅ 检测系统架构
- ✅ 安装 Docker 和 Docker Compose
- ✅ 创建必要的目录结构
- ✅ 生成数据库密码
- ✅ 启动所有服务（数据库、Server、Web、Agent）

### 方式二：手动安装

如果需要更多控制，可以手动执行以下步骤：

#### 步骤 1: 安装 Docker

```bash
# 更新系统
sudo apt-get update

# 安装依赖
sudo apt-get install -y \
    ca-certificates \
    curl \
    gnupg \
    lsb-release

# 添加 Docker 官方 GPG 密钥
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

# 设置 Docker 仓库
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# 安装 Docker Engine
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# 启动 Docker 服务
sudo systemctl start docker
sudo systemctl enable docker

# 验证安装
docker --version
docker compose version
```

#### 步骤 2: 创建目录和配置文件

```bash
# 创建 Zabbix 目录
sudo mkdir -p /opt/zabbix
sudo mkdir -p /etc/zabbix

# 复制配置文件
sudo cp docker-compose-zabbix.yml /opt/zabbix/docker-compose.yml
sudo cp env.example /opt/zabbix/.env

# 编辑环境变量（修改密码）
sudo nano /opt/zabbix/.env
```

#### 步骤 3: 配置环境变量

编辑 `/opt/zabbix/.env` 文件，修改以下内容：

```bash
# 数据库密码（请修改为强密码）
DB_PASSWORD=your_strong_password_here
DB_ROOT_PASSWORD=your_root_password_here

# PHP 时区
PHP_TZ=Asia/Shanghai
```

#### 步骤 4: 启动服务

```bash
cd /opt/zabbix

# 启动数据库（先启动数据库，等待初始化完成）
sudo docker compose up -d zabbix-db

# 等待数据库就绪（约 30 秒）
sleep 30

# 启动所有服务
sudo docker compose up -d

# 查看服务状态
sudo docker compose ps
```

#### 步骤 5: 验证安装

```bash
# 检查服务状态
sudo docker compose ps

# 查看日志
sudo docker compose logs -f zabbix-server

# 检查 Web 界面是否可访问
curl -I http://localhost
```

## 访问 Zabbix Web 界面

安装完成后，可以通过以下方式访问：

- **URL**: `http://<服务器IP>` 或 `http://localhost`
- **默认用户名**: `Admin`
- **默认密码**: `zabbix`

**⚠️ 重要**: 首次登录后请立即修改默认密码！

### 修改默认密码

1. 登录 Zabbix Web 界面
2. 点击右上角用户图标 → **Profile**
3. 在 **Password** 部分输入新密码
4. 点击 **Update** 保存

## 服务管理

### 启动服务

```bash
cd /opt/zabbix
sudo docker compose up -d
```

### 停止服务

```bash
cd /opt/zabbix
sudo docker compose down
```

### 重启服务

```bash
cd /opt/zabbix
sudo docker compose restart
```

### 查看日志

```bash
cd /opt/zabbix

# 查看所有服务日志
sudo docker compose logs -f

# 查看特定服务日志
sudo docker compose logs -f zabbix-server
sudo docker compose logs -f zabbix-web
sudo docker compose logs -f zabbix-db
```

### 查看服务状态

```bash
cd /opt/zabbix
sudo docker compose ps
```

## 端口说明

默认端口映射：

- **80**: Zabbix Web 界面（HTTP）
- **443**: Zabbix Web 界面（HTTPS，如果配置）
- **10051**: Zabbix Server（Agent 连接端口）
- **10050**: Zabbix Agent 2
- **3306**: MySQL/MariaDB 数据库

如需修改端口，编辑 `docker-compose-zabbix.yml` 文件中的端口映射。

## 数据持久化

所有数据存储在 Docker volumes 中：

- `zabbix-db-data`: 数据库数据
- `zabbix-server-data`: Zabbix Server 数据（脚本、模块等）

查看 volumes：

```bash
docker volume ls | grep zabbix
```

备份数据：

```bash
# 备份数据库
docker compose exec zabbix-db mysqldump -u zabbix -p zabbix > zabbix_backup.sql

# 备份 volumes
docker run --rm -v zabbix-db-data:/data -v $(pwd):/backup alpine tar czf /backup/zabbix-db-backup.tar.gz /data
```

## 故障排查

### 问题 1: 服务无法启动

**检查项**:
- Docker 服务是否运行: `sudo systemctl status docker`
- 端口是否被占用: `sudo netstat -tulpn | grep -E '80|10051|3306'`
- 磁盘空间是否充足: `df -h`

**解决方案**:
```bash
# 查看详细日志
cd /opt/zabbix
sudo docker compose logs

# 检查容器状态
sudo docker compose ps -a
```

### 问题 2: 无法访问 Web 界面

**检查项**:
- 防火墙是否开放 80 端口
- 服务是否正常运行
- 网络连接是否正常

**解决方案**:
```bash
# 检查服务状态
sudo docker compose ps

# 检查端口监听
sudo netstat -tulpn | grep 80

# 测试本地连接
curl http://localhost

# 查看 Web 服务日志
sudo docker compose logs zabbix-web
```

### 问题 3: 数据库连接失败

**检查项**:
- 数据库容器是否运行
- 环境变量配置是否正确
- 数据库密码是否正确

**解决方案**:
```bash
# 检查数据库容器
sudo docker compose ps zabbix-db

# 查看数据库日志
sudo docker compose logs zabbix-db

# 测试数据库连接
sudo docker compose exec zabbix-db mysql -u zabbix -p
```

### 问题 4: ARM 架构镜像问题

如果遇到镜像架构不匹配的问题：

**解决方案**:
1. 确保使用支持多架构的镜像标签
2. 检查 Docker 是否支持多架构: `docker buildx ls`
3. 如果需要，可以手动指定 ARM 镜像

## 性能优化

### 调整数据库配置

对于大型环境，可以调整数据库配置：

```bash
# 编辑 docker-compose-zabbix.yml
# 在 zabbix-db 服务中添加环境变量
environment:
  - innodb_buffer_pool_size=1G
  - max_connections=200
```

### 调整 Zabbix Server 配置

可以通过环境变量调整 Server 配置：

```yaml
environment:
  - ZBX_STARTREPORTWRITERS=5
  - ZBX_STARTPOLLERS=5
```

## 安全建议

1. **修改默认密码**: 首次登录后立即修改
2. **使用强密码**: 数据库密码应使用强密码
3. **限制网络访问**: 生产环境建议限制 Web 界面访问
4. **定期备份**: 定期备份数据库和配置
5. **更新镜像**: 定期更新到最新版本
6. **使用 HTTPS**: 生产环境建议配置 HTTPS

## 升级指南

升级到新版本：

```bash
cd /opt/zabbix

# 1. 备份数据
docker compose exec zabbix-db mysqldump -u zabbix -p zabbix > backup.sql

# 2. 停止服务
docker compose down

# 3. 更新 docker-compose.yml 中的镜像版本

# 4. 拉取新镜像
docker compose pull

# 5. 启动服务
docker compose up -d
```

## 卸载

如果需要完全卸载：

```bash
cd /opt/zabbix

# 停止并删除容器
sudo docker compose down

# 删除 volumes（会删除所有数据！）
sudo docker volume rm zabbix-db-data zabbix-server-data

# 删除目录
sudo rm -rf /opt/zabbix
```

## 下一步

安装完成后，可以继续：

1. 配置 Kubernetes 监控（运行 `./deploy.sh`）
2. 导入监控模板
3. 配置告警规则
4. 添加更多监控项

## 参考资源

- [Zabbix 官方文档](https://www.zabbix.com/documentation/6.0)
- [Docker 官方文档](https://docs.docker.com/)
- [Zabbix Docker 镜像](https://hub.docker.com/u/zabbix)

