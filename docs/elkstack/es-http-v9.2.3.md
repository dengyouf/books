# Elasticsearch 9.x 三节点集群部署实践

## 环境概述

本文详细记录了基于通用二进制包部署 Elasticsearch 9.x 三节点集群的完整过程，包括 HTTPS 安全模式和非 HTTPS 模式两种部署方式。

## 1.环境初始化
### 1.1. 主机名解析

```
cat >> /etc/hosts << 'EOF'
192.168.122.16 node01
192.168.122.17 node02
192.168.122.18 node03
EOF
```

### 1.2 关闭防火墙和 SELinux

```
# 关闭防火墙
systemctl stop firewalld
systemctl disable firewalld

# 关闭 SELinux
setenforce 0
sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
```

### 1.3 关闭 Swap 分区

```
swapoff -a
sed -i '/swap/d' /etc/fstab
# 验证 swap 已关闭
free -h
```

### 1.4 时间同步配置

```
# 安装 chrony
dnf install chrony -y

# 配置国内 NTP 服务器
cat > /etc/chrony.conf << 'EOF'
server ntp.aliyun.com iburst
server ntp.tencent.com iburst
driftfile /var/lib/chrony/drift
makestep 1.0 3
rtcsync
logdir /var/log/chrony
EOF

# 启动服务
systemctl enable chronyd --now
systemctl restart chronyd

# 验证时间同步
chronyc sources -v
```

### 1.5 内核参数优化

```
# 设置 vm.max_map_count（Elasticsearch 必需）
cat > /etc/sysctl.d/99-elasticsearch.conf << 'EOF'
vm.max_map_count = 1048576
fs.file-max = 65536
net.core.somaxconn = 1024
net.ipv4.tcp_retries2 = 5
EOF

# 应用配置
sysctl -p /etc/sysctl.d/99-elasticsearch.conf

# 禁用透明大页（THP）
echo never > /sys/kernel/mm/transparent_hugepage/enabled

# 持久化 THP 配置
cat > /etc/systemd/system/disable-thp.service << 'EOF'
[Unit]
Description=Disable Transparent Huge Pages
After=sysinit.target local-fs.target
[Service]
Type=oneshot
ExecStart=/bin/sh -c "echo never > /sys/kernel/mm/transparent_hugepage/enabled"
[Install]
WantedBy=basic.target
EOF

systemctl enable disable-thp.service --now
```

### 1.6 系统资源限制配置

```
cat > /etc/security/limits.d/99-elasticsearch.conf << 'EOF'
elasticsearch soft nofile 65536
elasticsearch hard nofile 65536
elasticsearch soft nproc 4096
elasticsearch hard nproc 4096
elasticsearch soft memlock unlimited
elasticsearch hard memlock unlimited
elasticsearch soft core unlimited
elasticsearch hard core unlimited
EOF
```

## 2. Elasticsearch 安装

### 2.1 创建专用用户

```
# 所有节点执行
# 创建 elasticsearch 用户和组
groupadd -r -g 2024 elasticsearch
useradd -r -u 2024 -g elasticsearch -m -d /data/apps/elasticsearch -s /bin/bash elasticsearch
echo "elasticsearch:elasticPwd" | chpasswd
```

### 2.2 创建安装目录

```
mkdir -p /data/apps
```

### 2.3 下载并解压 Elasticsearch

```
# 下载 Elasticsearch 9.2.3（华为云镜像）
cd /tmp
wget https://mirrors.huaweicloud.com/elasticsearch/9.2.3/elasticsearch-9.2.3-linux-x86_64.tar.gz

# 解压到安装目录
tar -xzf elasticsearch-9.2.3-linux-x86_64.tar.gz -C /data/apps/

# 创建软链接
ln -sv /data/apps/elasticsearch-9.2.3 /data/apps/elasticsearch

# 验证安装
mkdir -pv /data/apps/elasticsearch/{data,logs}
ls -la /data/apps/elasticsearch/
```

### 2.4 配置 JVM 堆内存

```
vim /data/apps/elasticsearch/config/jvm.options
-Xms2g
-Xmx2g
-XX:+UseG1GC
-XX:G1ReservePercent=25
-XX:InitiatingHeapOccupancyPercent=30
-XX:+AlwaysPreTouch

```

### 2.5 设置目录权限

```
# 修改所有相关目录的属主
chown -R elasticsearch:elasticsearch /data/apps/elasticsearch*
```

## 3. 证书生成（仅在 node01 执行)

### 3.1 切换到 elasticsearch 用户并生成 CA 证书

```
su - elasticsearch
cd /data/apps/elasticsearch

# 创建证书目录
mkdir -p config/certs

# 生成 CA 证书（设置密码，请记住该密码）
./bin/elasticsearch-certutil ca \
  --out config/certs/elastic-stack-ca.p12 \
  --pass "elastic123"
```

### 3.2 生成 Transport 层证书

```
./bin/elasticsearch-certutil cert \
  --ca config/certs/elastic-stack-ca.p12 \
  --ca-pass "elastic123" \
  --dns localhost,node01,node02,node03 \
  --ip 192.168.122.16,192.168.122.17,192.168.122.18,127.0.0.1 \
  --out config/certs/transport.p12 \
  --pass "elastic123"

```

### 3.3 生成 HTTP 层证书

```
创建 instances.yml 配置文件
cat > config/certs/instances.yml << 'EOF'
instances:
  - name: "node01"
    dns: ["localhost", "node01", "192.168.122.16"]
    ip: ["192.168.122.16", "127.0.0.1"]
  - name: "node02"
    dns: ["localhost", "node02", "192.168.122.17"]
    ip: ["192.168.122.17", "127.0.0.1"]
  - name: "node03"
    dns: ["localhost", "node03", "192.168.122.18"]
    ip: ["192.168.122.18", "127.0.0.1"]
EOF
# 2. 生成 HTTP 证书
./bin/elasticsearch-certutil cert \
  --ca config/certs/elastic-stack-ca.p12 \
  --ca-pass "elastic123" \
  --multiple \
  --in config/certs/instances.yml \
  --out config/certs/http-certs.zip \
  --pass "elastic123"
# 解压后得到每个节点的独立证书
~]$ unzip config/certs/http-certs.zip -d config/certs/
tree  /data/apps/elasticsearch/config/certs/
/data/apps/elasticsearch/config/certs/
├── ca
│   ├── ca.crt
│   └── ca.key
├── elastic-stack-ca.p12
├── http-certs.zip
├── instances.yml
├── node01
│   └── node01.p12
├── node02
│   └── node02.p12
├── node03
│   └── node03.p12
└── transport.p12

5 directories, 9 files
```
### 3.4 分发证书到其他节点

```
# 从 node01 分发证书到 node02、node03
for node in node02 node03; do
  scp -r config/certs $node:/data/apps/elasticsearch/config
done
```

## 4. 集群配置

### 4.1 安全模式 + HTTPS 配置（生产环境推荐）

####  4.1.1 配置文件

=== "node01"

    ```
    cat > /data/apps/elasticsearch/config/elasticsearch.yml << 'EOF'
    # 集群配置
    cluster.name: dev-cluster
    node.name: node01
    node.roles: ["master", "data"]
    # 设置标签，进行冷热数据存储
    node.attr.temperature: hot
    # 路径配置
    path.data: /data/apps/elasticsearch/data
    path.logs: /data/apps/elasticsearch/logs
    # 网络配置
    network.host: 0.0.0.0
    http.port: 9200
    transport.port: 9300
    # 发现和集群初始化
    discovery.seed_hosts: ["node01:9300", "node02:9300", "node03:9300"]
    cluster.initial_master_nodes: ["node01", "node02", "node03"]
    # 安全配置
    xpack.security.enabled: true
    xpack.security.enrollment.enabled: true
    # HTTP 层 SSL 配置
    xpack.security.http.ssl.enabled: true
    xpack.security.http.ssl.keystore.path: /data/apps/elasticsearch/config/certs/node01/node01.p12
    xpack.security.http.ssl.truststore.path: /data/apps/elasticsearch/config/certs/node01/node01.p12
    # Transport 层 SSL 配置
    xpack.security.transport.ssl.enabled: true
    xpack.security.transport.ssl.verification_mode: certificate
    xpack.security.transport.ssl.keystore.path: /data/apps/elasticsearch/config/certs/transport.p12
    xpack.security.transport.ssl.truststore.path: /data/apps/elasticsearch/config/certs/transport.p12
    [elasticsearch@node01 ~]$ cat /data/apps/elasticsearch/config/elasticsearch.yml
    # 集群配置
    cluster.name: dev-cluster
    node.name: node01
    node.roles: ["master", "data"]
    # 路径配置
    path.data: /data/apps/elasticsearch/data
    path.logs: /data/apps/elasticsearch/logs
    # 网络配置
    network.host: 0.0.0.0
    http.port: 9200
    transport.port: 9300
    # 发现和集群初始化
    discovery.seed_hosts: ["node01:9300", "node02:9300", "node03:9300"]
    cluster.initial_master_nodes: ["node01", "node02", "node03"]
    # 安全配置
    xpack.security.enabled: true
    xpack.security.enrollment.enabled: true
    # HTTP 层 SSL 配置
    xpack.security.http.ssl.enabled: true
    xpack.security.http.ssl.keystore.path: /data/apps/elasticsearch/config/certs/node01/node01.p12
    xpack.security.http.ssl.truststore.path: /data/apps/elasticsearch/config/certs/node01/node01.p12
    # Transport 层 SSL 配置
    xpack.security.transport.ssl.enabled: true
    xpack.security.transport.ssl.verification_mode: certificate
    xpack.security.transport.ssl.keystore.path: /data/apps/elasticsearch/config/certs/transport.p12
    xpack.security.transport.ssl.truststore.path: /data/apps/elasticsearch/config/certs/transport.p12
    EOF
    ```

=== "node02"

    ```
    cat > /data/apps/elasticsearch/config/elasticsearch.yml << 'EOF'
    # 集群配置
    cluster.name: dev-cluster
    node.name: node02
    node.roles: ["master", "data"]
    # 设置标签，进行冷热数据存储
    node.attr.temperature: hot
    # 路径配置
    path.data: /data/apps/elasticsearch/data
    path.logs: /data/apps/elasticsearch/logs
    # 网络配置
    network.host: 0.0.0.0
    http.port: 9200
    transport.port: 9300
    # 发现和集群初始化
    discovery.seed_hosts: ["node01:9300", "node02:9300", "node03:9300"]
    cluster.initial_master_nodes: ["node01", "node02", "node03"]
    # 安全配置
    xpack.security.enabled: true
    xpack.security.enrollment.enabled: true
    # HTTP 层 SSL 配置
    xpack.security.http.ssl.enabled: true
    xpack.security.http.ssl.keystore.path: /data/apps/elasticsearch/config/certs/node02/node02.p12
    xpack.security.http.ssl.truststore.path: /data/apps/elasticsearch/config/certs/node02/node02.p12
    # Transport 层 SSL 配置
    xpack.security.transport.ssl.enabled: true
    xpack.security.transport.ssl.verification_mode: certificate
    xpack.security.transport.ssl.keystore.path: /data/apps/elasticsearch/config/certs/transport.p12
    xpack.security.transport.ssl.truststore.path: /data/apps/elasticsearch/config/certs/transport.p12
    EOF
    ```

=== "node03"

    ```
    # 集群配置
    cluster.name: dev-cluster
    node.name: node03
    node.roles: ["master", "data"]
    # 设置标签，进行冷热数据存储
    node.attr.temperature: hot
    # 路径配置
    path.data: /data/apps/elasticsearch/data
    path.logs: /data/apps/elasticsearch/logs
    # 网络配置
    network.host: 0.0.0.0
    http.port: 9200
    transport.port: 9300
    # 发现和集群初始化
    discovery.seed_hosts: ["node01:9300", "node02:9300", "node03:9300"]
    cluster.initial_master_nodes: ["node01", "node02", "node03"]
    # 安全配置
    xpack.security.enabled: true
    xpack.security.enrollment.enabled: true
    # HTTP 层 SSL 配置
    xpack.security.http.ssl.enabled: true
    xpack.security.http.ssl.keystore.path: /data/apps/elasticsearch/config/certs/node03/node03.p12
    xpack.security.http.ssl.truststore.path: /data/apps/elasticsearch/config/certs/node03/node03.p12
    # Transport 层 SSL 配置
    xpack.security.transport.ssl.enabled: true
    xpack.security.transport.ssl.verification_mode: certificate
    xpack.security.transport.ssl.keystore.path: /data/apps/elasticsearch/config/certs/transport.p12
    xpack.security.transport.ssl.truststore.path: /data/apps/elasticsearch/config/certs/transport.p12
    EOF
    ```

### 4.2 使用 elasticsearch-keystore 配置证书密码

```
# 在所有节点执行
chown -R elasticsearch:elasticsearch /data/apps/elasticsearch*
su - elasticsearch
cd /data/apps/elasticsearch
# 创建 keystore（如果不存在）
./bin/elasticsearch-keystore create 2>/dev/null

# 添加证书密码
echo "elastic123" | ./bin/elasticsearch-keystore add -x "xpack.security.http.ssl.keystore.secure_password"
echo "elastic123" | ./bin/elasticsearch-keystore add -x "xpack.security.http.ssl.truststore.secure_password"
echo "elastic123" | ./bin/elasticsearch-keystore add -x "xpack.security.transport.ssl.keystore.secure_password"
echo "elastic123" | ./bin/elasticsearch-keystore add -x "xpack.security.transport.ssl.truststore.secure_password"

# 验证 keystore 条目
./bin/elasticsearch-keystore list
```

## 5. 启动集群

```
 1. 启动时记录PID（参考命令）
./bin/elasticsearch -d -p ./es.pid
# 2. 停止时，从文件中读取PID并优雅终止
pkill -F ./es.pid
```

## 6. 集群验证

### 6.1 安全模式 + HTTPS 验证

```
# 重置 elastic 用户密码（首次启动后执行）
 /data/apps/elasticsearch/bin/elasticsearch-reset-password -u elastic -i
This tool will reset the password of the [elastic] user.
You will be prompted to enter the password.
Please confirm that you would like to continue [y/N]y
Enter password for [elastic]:  elasticPwd123
Re-enter password for [elastic]: elasticPwd123
Password for the [elastic] user successfully reset.
# 验证集群健康状态
curl -k -u elastic:elasticPwd123 https://node01:9200/_cluster/health?pretty
{
  "cluster_name" : "dev-cluster",
  "status" : "green",
  "timed_out" : false,
  "number_of_nodes" : 3,
  "number_of_data_nodes" : 3,
  "active_primary_shards" : 3,
  "active_shards" : 6,
  "relocating_shards" : 0,
  "initializing_shards" : 0,
  "unassigned_shards" : 0,
  "unassigned_primary_shards" : 0,
  "delayed_unassigned_shards" : 0,
  "number_of_pending_tasks" : 0,
  "number_of_in_flight_fetch" : 0,
  "task_max_waiting_in_queue_millis" : 0,
  "active_shards_percent_as_number" : 100.0

# 查看节点列表
curl -k -u elastic:elasticPwd123 https://node01:9200/_cat/nodes?v
ip             heap.percent ram.percent cpu load_1m load_5m load_15m node.role master name
192.168.122.17           13          99   1    0.04    0.03     0.02 dm        *      node02
192.168.122.16           55          99   1    0.03    0.07     0.08 dm        -      node01
192.168.122.18           43          96   1    0.03    0.05     0.05 dm        -      node03

# 查看集群信息
curl -k -u elastic:elasticPwd123 https://node01:9200/
```

## 7. 添加节点

### 7.1  环境初始化

```
# 其他节点
echo 192.168.122.19 node04 >> /etc/hosts
# node04
# 主机名解析
cat >> /etc/hosts << 'EOF'
192.168.122.16 node01
192.168.122.17 node02
192.168.122.18 node03
192.168.122.19 node04
EOF
# 关闭防火墙
systemctl stop firewalld
systemctl disable firewalld
# 关闭 SELinux
setenforce 0
sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
swapoff -a
sed -i '/swap/d' /etc/fstab
# 验证 swap 已关闭
free -h
# 安装 chrony
dnf install chrony -y

# 配置国内 NTP 服务器
cat > /etc/chrony.conf << 'EOF'
server ntp.aliyun.com iburst
server ntp.tencent.com iburst
driftfile /var/lib/chrony/drift
makestep 1.0 3
rtcsync
logdir /var/log/chrony
EOF
# 启动服务
systemctl enable chronyd --now
systemctl restart chronyd
# 验证时间同步
chronyc sources -v
# 设置 vm.max_map_count（Elasticsearch 必需）
cat > /etc/sysctl.d/99-elasticsearch.conf << 'EOF'
vm.max_map_count = 1048576
fs.file-max = 65536
net.core.somaxconn = 1024
net.ipv4.tcp_retries2 = 5
EOF
# 应用配置
sysctl -p /etc/sysctl.d/99-elasticsearch.conf
# 禁用透明大页（THP）
echo never > /sys/kernel/mm/transparent_hugepage/enabled
# 持久化 THP 配置
cat > /etc/systemd/system/disable-thp.service << 'EOF'
[Unit]
Description=Disable Transparent Huge Pages
After=sysinit.target local-fs.target
[Service]
Type=oneshot
ExecStart=/bin/sh -c "echo never > /sys/kernel/mm/transparent_hugepage/enabled"
[Install]
WantedBy=basic.target
EOF
systemctl enable disable-thp.service --now
cat > /etc/security/limits.d/99-elasticsearch.conf << 'EOF'
elasticsearch soft nofile 65536
elasticsearch hard nofile 65536
elasticsearch soft nproc 4096
elasticsearch hard nproc 4096
elasticsearch soft memlock unlimited
elasticsearch hard memlock unlimited
elasticsearch soft core unlimited
elasticsearch hard core unlimited
EOF
# 创建 elasticsearch 用户和组
groupadd -r -g 2024 elasticsearch
useradd -r -u 2024 -g elasticsearch -m -d /data/apps/elasticsearch -s /bin/bash elasticsearch
echo "elasticsearch:elasticPwd" | chpasswd
mkdir -p /data/apps
cd /tmp
wget https://mirrors.huaweicloud.com/elasticsearch/9.2.3/elasticsearch-9.2.3-linux-x86_64.tar.gz
# 解压到安装目录
tar -xzf elasticsearch-9.2.3-linux-x86_64.tar.gz -C /data/apps/
ln -sv /data/apps/elasticsearch-9.2.3 /data/apps/elasticsearch
# 验证安装
mkdir -pv /data/apps/elasticsearch/{data,logs}
ls -la /data/apps/elasticsearch/
# 修改所有相关目录的属主
chown -R elasticsearch:elasticsearch /data/apps/elasticsearch*
```

### 7.2  给 node04 生成独立 HTTP 证书

集群已经有统一 CA，新节点必须使用同一套证书体系才能加入集群。

```
# 在 node01 执行
su - elasticsearch
cd /data/apps/elasticsearch

# 只给 node04 生成证书，不影响其他节点
cat > config/certs/add_node04.yml << 'EOF'
instances:
  - name: "node04"
    dns: ["localhost", "node04", "192.168.122.19"]
    ip: ["192.168.122.19", "127.0.0.1"]
EOF

# 只生成 node04 的证书
./bin/elasticsearch-certutil cert \
  --ca config/certs/elastic-stack-ca.p12 \
  --ca-pass "elastic123" \
  --multiple \
  --in config/certs/add_node04.yml \
  --out config/certs/node04.zip \
  --pass "elastic123"

# 解压并只分发 node04
unzip -o config/certs/node04.zip -d config/certs/
# 分发给 node04
scp -r config/certs node04:/data/apps/elasticsearch/config/
```
### 7.3  node04配置证书密码（keystore）

```
su - elasticsearch
cd /data/apps/elasticsearch

# 创建 keystore
./bin/elasticsearch-keystore create 2>/dev/null

# 写入证书密码（你的密码是 elastic123）
echo "elastic123" | ./bin/elasticsearch-keystore add -x "xpack.security.http.ssl.keystore.secure_password"
echo "elastic123" | ./bin/elasticsearch-keystore add -x "xpack.security.http.ssl.truststore.secure_password"
echo "elastic123" | ./bin/elasticsearch-keystore add -x "xpack.security.transport.ssl.keystore.secure_password"
echo "elastic123" | ./bin/elasticsearch-keystore add -x "xpack.security.transport.ssl.truststore.secure_password"

# 验证
./bin/elasticsearch-keystore list

# 删除密码
```

### 7.4 提供node04配置

```
cat > /data/apps/elasticsearch/config/elasticsearch.yml << 'EOF'
# 集群配置
cluster.name: dev-cluster
node.name: node04
node.roles: ["master", "data"]
node.attr.temperature: warm
# 路径配置
path.data: /data/apps/elasticsearch/data
path.logs: /data/apps/elasticsearch/logs
# 网络配置
network.host: 0.0.0.0
http.port: 9200
transport.port: 9300
# 发现和集群初始化
discovery.seed_hosts: ["node01:9300", "node02:9300", "node03:9300"]
# 注意：集群已经初始化完成，新节点 必须删除/注释掉 cluster.initial_master_nodes！！
# cluster.initial_master_nodes: ["node01", "node02", "node03"]
# 安全配置 - HTTPS 模式
xpack.security.enabled: true
xpack.security.enrollment.enabled: true
# HTTP 层 SSL 配置
xpack.security.http.ssl:
enabled: true
keystore.path: /data/apps/elasticsearch/config/certs/node04/node04.p12
truststore.path: /data/apps/elasticsearch/config/certs/node04/node04.p12
# Transport 层 SSL 配置
xpack.security.transport.ssl:
enabled: true
verification_mode: certificate
keystore.path: /data/apps/elasticsearch/config/certs/transport.p12
truststore.path: /data/apps/elasticsearch/certs/transport.p12
EOF
```

### 7.5 启动服务

```
./bin/elasticsearch -d -p ./es.pid
# 2. 停止时，从文件中读取PID并优雅终止
pkill -F ./es.pid
```

### 7.6 验证

```
curl -k -u elastic:elasticPwd123 https://192.168.122.16:9200/_cat/nodes?v
ip             heap.percent ram.percent cpu load_1m load_5m load_15m node.role master name
192.168.122.17           56          95   1    0.08    0.05     0.01 dm        -      node02
192.168.122.19           45          99   1    0.13    0.12     0.07 dm        -      node04
192.168.122.16           12          96   1    0.02    0.02     0.00 dm        *      node01
192.168.122.18           20          97   0    0.02    0.01     0.00 dm        -      node03
```

## 8. 对接kibana

### 8.1 生成token

```
 curl -ks -u elastic:elasticPwd123   -X POST https://192.168.122.16:9200/_security/service/elastic/kibana/credential/token|jq
{
  "created": true,
  "token": {
    "name": "token_OqH6v50BzUH9a-mWzWCZ",
    "value": "AAEAAWVsYXN0aWMva2liYW5hL3Rva2VuX09xSDZ2NTBCelVIOWEtbVd6V0NaOnQtQ1pjYkdtUm1TbmlWYy1ZSUFkUVE"
  }
}
```

### 8.2 提取 CA 证书（推荐）

```
# 1. 从 p12 文件中提取 CA 证书（需要输入 p12 的密码）
openssl pkcs12 -in /data/apps/elasticsearch/config/certs/node03/node03.p12 -cacerts -nokeys -out /data/apps/elasticsearch/config/certs/ca.crt
```

### 8.3 配置kibana

```
mkdir /opt/kibana/ &&  cd /opt/kibana/ && cat  > kibana.yml << 'EOF'
server.name: kibana
server.host: 0.0.0.0

elasticsearch.hosts:
  - https://192.168.2.67:9200
  - https://192.168.2.68:9200
  - https://192.168.2.69:9200

elasticsearch.serviceAccountToken: "AAEAAWVsYXN0aWMva2liYW5hL3Rva2VuX0EwMHJrcHNCQ1lpclktQmZFUmowOkhpNERpN1FrUjlxNThSczZoR0V6NEE"

elasticsearch.ssl.certificateAuthorities:
  - /usr/share/kibana/config/certs/ca.crt

elasticsearch.ssl.verificationMode: full
i18n.locale: zh-CN
EOF
```

### 8.4 启动kibana

```
cat > docker-compose.yml << 'EOF'
version: '3'
services:
  kibana:
    image: kibana:8.19.9
    # image: arm64v8/kibana:8.19.9
    container_name: kibana
    environment:
      - SERVER_NAME=kibana
      - SERVER_HOST=0.0.0.0
      - ELASTICSEARCH_SSL_CERTIFICATEAUTHORITIES=/usr/share/kibana/config/certs/ca.crt
      - ELASTICSEARCH_SSL_VERIFICATIONMODE=full
      - TZ=Asia/Shanghai
    volumes:
      - /opt/kibana/kibana.yml:/usr/share/kibana/config/kibana.yml:ro
      - /opt/es/certs/elastic-stack-ca/ca/ca.crt:/usr/share/kibana/config/certs/ca.crt:ro
      - /etc/localtime:/etc/localtime:ro
    ports:
      - 5601:5601
EOF
docker compose up -d
```


