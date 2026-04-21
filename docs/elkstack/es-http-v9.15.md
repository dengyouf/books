# Elasticsearch 9.x 三节点集群部署实践

## 环境概述

本文详细记录了基于 RPM 包部署 Elasticsearch 9.x 三节点集群的完整过程，包括 HTTPS 安全模式和非 HTTPS 模式两种部署方式。

### 环境信息

- **操作系统**: Rocky Linux release 10.1
- **Elasticsearch 版本**: 9.1.5
- **部署方式**: RPM 包安装

### 节点规划

| 主机名 | IP 地址 | 角色 |
|--------|---------|------|
| node01 | 192.168.122.16 | 主节点 |
| node02 | 192.168.122.17 | 数据节点 |
| node03 | 192.168.122.18 | 数据节点 |

---

## 一、环境初始化

在所有节点上执行以下初始化操作：

```bash
# 1. 主机名解析
cat >> /etc/hosts << 'EOF'
192.168.122.16 node01
192.168.122.17 node02
192.168.122.18 node03
EOF

# 2. 关闭防火墙和 SELinux
systemctl disable firewalld
setenforce 0 && sed -i "s@SELINUX=enforcing@SELINUX=disabled@g" /etc/selinux/config

# 3. 关闭 swap 分区
swapoff -a && sed -i '/swap/d' /etc/fstab

# 4. 内核参数优化
sysctl -w vm.max_map_count=1048576 && echo vm.max_map_count=1048576 >> /etc/sysctl.d/elastic-sysctl.conf && sysctl --system
sysctl -w fs.file-max=65535 && echo "fs.file-max=65535" >> /etc/sysctl.d/elastic-sysctl.conf && sysctl --system
echo "never" > /sys/kernel/mm/transparent_hugepage/enabled

# 5. 设置系统资源限制
cat >> /etc/security/limits.conf << 'EOF'
*                soft    core            unlimited
*                hard    core            unlimited
*                soft    nproc           1000000
*                hard    nproc           1000000
*                soft    nofile          1000000
*                hard    nofile          1000000
*                soft    memlock         1000000
*                hard    memlock         1000000
*                soft    msgqueue        1000000
*                hard    msgqueuq        1000000
EOF


## 二、安装 Elasticsearch

### 下载并安装 RPM 包

```
# 下载 Elasticsearch 9.1.5 RPM 包
wget https://mirrors.huaweicloud.com/elasticsearch/9.1.5/elasticsearch-9.1.5-x86_64.rpm

# 安装 RPM 包
rpm -ivh elasticsearch-9.1.5-x86_64.rpm
警告：elasticsearch-9.1.5-x86_64.rpm: 头 V4 RSA/SHA512 Signature, 密钥 ID d88e42b4: NOKEY
Verifying...                          ################################# [100%]
准备中...                          ################################# [100%]
Creating elasticsearch group... OK
Creating elasticsearch user... OK
正在升级/安装...
   1:elasticsearch-0:9.1.5-1          ################################# [100%]
--------------------------- Security autoconfiguration information ------------------------------

Authentication and authorization are enabled.
TLS for the transport and HTTP layers is enabled and configured.

The generated password for the elastic built-in superuser is : 7V491zBlop2luX4UVP=5

If this node should join an existing cluster, you can reconfigure this with
'/usr/share/elasticsearch/bin/elasticsearch-reconfigure-node --enrollment-token <token-here>'
after creating an enrollment token on your existing cluster.

You can complete the following actions at any time:

Reset the password of the elastic built-in superuser with
'/usr/share/elasticsearch/bin/elasticsearch-reset-password -u elastic'.

Generate an enrollment token for Kibana instances with
 '/usr/share/elasticsearch/bin/elasticsearch-create-enrollment-token -s kibana'.

Generate an enrollment token for Elasticsearch nodes with
'/usr/share/elasticsearch/bin/elasticsearch-create-enrollment-token -s node'.

-------------------------------------------------------------------------------------------------
### NOT starting on installation, please execute the following statements to configure elasticsearch service to start automatically using systemd
 sudo systemctl daemon-reload
 sudo systemctl enable elasticsearch.service
### You can start elasticsearch service by executing
 sudo systemctl start elasticsearch.service
```
> ⚠️ 重要提示: 安装过程中会自动生成 elastic 超级用户密码，请务必妥善保存。示例中的密码为 7V491zBlop2luX4UVP=5。

### JVM 堆内存配置

```
vim /etc/elasticsearch/jvm.options

# 设置堆内存大小（建议为系统内存的一半，但不超过 31GB）
-Xms4g
-Xmx4g
```

## 三、HTTPS 模式集群部署（安全模式）

### 3.1 配置主节点（node01）

```
grep -v "#" /etc/elasticsearch/elasticsearch.yml | grep -v "^$"
cluster.name: dev-cluster
node.name: node01
path.data: /var/lib/elasticsearch
path.logs: /var/log/elasticsearch
network.host: 0.0.0.0
http.port: 9200
discovery.seed_hosts: ["192.168.122.16"]
cluster.initial_master_nodes: ["node01"]
xpack.security.enabled: true
xpack.security.enrollment.enabled: true
xpack.security.http.ssl:
  enabled: true
  keystore.path: certs/http.p12
xpack.security.transport.ssl:
  enabled: true
  verification_mode: certificate
  keystore.path: certs/transport.p12
  truststore.path: certs/transport.p12
```
### 3.2 启动主节点并验证

```
# 启动 Elasticsearch 服务
systemctl start elasticsearch

# 验证节点状态
curl -k -u elastic:7V491zBlop2luX4UVP=5 https://192.168.122.16:9200/_cat/nodes
192.168.122.16 50 99 2 0.64 0.31 0.17 cdfhilmrstw * node01
```

### 3.3 生成节点加入 Token

```
/usr/share/elasticsearch/bin/elasticsearch-create-enrollment-token -s node
eyJ2ZXIiOiI4LjE0LjAiLCJhZHIiOlsiMTkyLjE2OC4xMjIuMTY6OTIwMCJdLCJmZ3IiOiI5MjJhZGJjOTM2MjI0MjcxOGE3ZmFiZTlmOGVhMmMwNzM3ZmM5MWFlYzg4MDc2MjlhNTQzNjlkMjY3MjkyZmY3Iiwia2V5IjoicDVzR3NaMEJxOWFRc3VxdWZTeWk6cGxlTjNvTXM2Z3pkMndwRUp6ZS1UQSJ9
```
### 3.4 添加数据节点（node02）

```
# 安装 Elasticsearch（必须使用 RPM 安装，不要使用 YUM）
rpm -ivh elasticsearch-9.1.5-x86_64.rpm

# 使用 token 重新配置节点加入集群
/usr/share/elasticsearch/bin/elasticsearch-reconfigure-node --enrollment-token eyJ2ZXIiOiI4LjE0LjAiLCJhZHIiOlsiMTkyLjE2OC4xMjIuMTY6OTIwMCJdLCJmZ3IiOiI0NTY1YmI1YzQ4ZjlkZDVmZjlmN2Q4M2IwOGQyMjQ5ZTgxZDIzYjZkMTUyNGZjNGQxNjg0NTFhNDRmM2QyMzU2Iiwia2V5IjoiUllfdHNKMEJuNmFEMmJPaWxITlo6Ui05WG11RUF1MTBaTEVYWGI4cW5pUSJ9
This node will be reconfigured to join an existing cluster, using the enrollment token that you provided.
This operation will overwrite the existing configuration. Specifically:
  - Security auto configuration will be removed from elasticsearch.yml
  - The [certs] config directory will be removed
  - Security auto configuration related secure settings will be removed from the elasticsearch.keystore
Do you want to continue with the reconfiguration process [y/N] y
# 添加集群名称配置
echo "cluster.name: dev-cluster" >> /etc/elasticsearch/elasticsearch.yml

# 启动 Elasticsearch 服务
systemctl start elasticsearch
```
### 3.5 添加数据节点（node03）

在 node03 上执行相同的操作：

```
# 安装 Elasticsearch
rpm -ivh elasticsearch-9.1.5-x86_64.rpm

# 使用 token 重新配置节点加入集群
/usr/share/elasticsearch/bin/elasticsearch-reconfigure-node --enrollment-token eyJ2ZXIiOiI4LjE0LjAiLCJhZHIiOlsiMTkyLjE2OC4xMjIuMTY6OTIwMCJdLCJmZ3IiOiI0NTY1YmI1YzQ4ZjlkZDVmZjlmN2Q4M2IwOGQyMjQ5ZTgxZDIzYjZkMTUyNGZjNGQxNjg0NTFhNDRmM2QyMzU2Iiwia2V5IjoiUllfdHNKMEJuNmFEMmJPaWxITlo6Ui05WG11RUF1MTBaTEVYWGI4cW5pUSJ9

# 添加集群名称配置
echo "cluster.name: dev-cluster" >> /etc/elasticsearch/elasticsearch.yml

# 启动 Elasticsearch 服务
systemctl start elasticsearch
```

### 3.6 验证集群状态

```
curl -k -u elastic:7V491zBlop2luX4UVP=5 https://192.168.122.16:9200/_cat/nodes
192.168.122.17 40 99  4 0.12 0.15 0.11 cdfhilmrstw - node02
192.168.122.16 11 97  4 0.07 0.09 0.11 cdfhilmrstw * node01
192.168.122.18 35 99 39 0.73 0.23 0.13 cdfhilmrstw - node03
```

## 四、非 HTTPS 模式集群部署

如果需要部署不使用 SSL/TLS 加密的集群（适用于开发测试环境），按以下步骤操作：

### 4.1 停止服务并清理数据

**在所有节点上执行:**

```
# 停止 Elasticsearch 服务
systemctl stop elasticsearch

# 清理数据目录
rm -rf /var/lib/elasticsearch/*
```
### 4.2 修改配置文件

编辑 /etc/elasticsearch/elasticsearch.yml：

```
cluster.name: dev-cluster
node.name: node01
path.data: /var/lib/elasticsearch
path.logs: /var/log/elasticsearch
network.host: 0.0.0.0
http.port: 9200
discovery.seed_hosts: ["192.168.122.16"]
cluster.initial_master_nodes: ["node01"]
xpack.security.enabled: false
xpack.security.enrollment.enabled: false
```

### 4.3 清理密钥库中的 SSL 配置

```
# 列出所有 keystore 条目
/usr/share/elasticsearch/bin/elasticsearch-keystore list

# 删除所有 SSL 相关的密码条目
/usr/share/elasticsearch/bin/elasticsearch-keystore remove xpack.security.http.ssl.keystore.secure_password
/usr/share/elasticsearch/bin/elasticsearch-keystore remove xpack.security.http.ssl.truststore.secure_password
/usr/share/elasticsearch/bin/elasticsearch-keystore remove xpack.security.transport.ssl.keystore.secure_password
/usr/share/elasticsearch/bin/elasticsearch-keystore remove xpack.security.transport.ssl.truststore.secure_password

# 验证清理结果（应该为空或没有 SSL 相关条目）
/usr/share/elasticsearch/bin/elasticsearch-keystore list
```

### 启动非 HTTPS 集群

```
# 在所有节点上启动服务
systemctl start elasticsearch

# 验证集群状态（注意使用 HTTP 协议）
curl -u elastic:7V491zBlop2luX4UVP=5 http://192.168.122.16:9200/_cat/nodes
192.168.122.16 46 96  3 0.03 0.13 0.11 cdfhilmrstw * node01
192.168.122.18 30 98  3 0.09 0.13 0.09 cdfhilmrstw - node03
192.168.122.17 27 98 45 0.47 0.20 0.10 cdfhilmrstw - node02
```

## 五、常用运维命令

### 集群管理

```
# 查看集群健康状态
curl -k -u elastic:password https://localhost:9200/_cluster/health

# 查看节点列表
curl -k -u elastic:password https://localhost:9200/_cat/nodes

# 查看集群统计信息
curl -k -u elastic:password https://localhost:9200/_cluster/stats

# 查看节点信息
curl -k -u elastic:password https://localhost:9200/_nodes
```

### 索引管理

```
# 查看所有索引
curl -k -u elastic:password https://localhost:9200/_cat/indices

# 创建索引
curl -k -u elastic:password -X PUT https://localhost:9200/my_index

# 删除索引
curl -k -u elastic:password -X DELETE https://localhost:9200/my_index
```

### 安全管理

```
# 重置 elastic 用户密码
/usr/share/elasticsearch/bin/elasticsearch-reset-password -u elastic

# 生成 Kibana 接入 token
/usr/share/elasticsearch/bin/elasticsearch-create-enrollment-token -s kibana

# 生成新节点接入 token
/usr/share/elasticsearch/bin/elasticsearch-create-enrollment-token -s node
```
