# 基于 Docker Compose 的 Elasticsearch 8.x 三节点安全集群部署实践


使用docker-compose 安装三节点的 elasticsearch 集群，操作系统为Rocky Linux release 9.7，用到的各相关程序版本如下:

- docker: v29.1.3
- elasticsearch: v8.19.9

**集群要求**

- 节点间通信使用 TLS（transport SSL）
- HTTP/REST 使用 HTTPS
- 开启 xpack.security 认证，使用 elastic 用户登录

| 主机名            | IP           |
|----------------|--------------|
| rocky97-node01 | 192.168.2.67 |
| rocky97-node02 | 192.168.2.68 |
| rocky97-node03 | 192.168.2.69 |


## 安装集群
### 生成证书

在 192.168.2.67 上生成 TLS 证书

```shell
~]# mkdir -p /opt/es/certs
~]# cd /opt/es/certs
~]# chown 1000.1000 /opt/es/ -R
```

创建实例描述文件

```shell
cat > instances.yml <<'EOF'
instances:
  - name: es-node-1
    ip:
      - 192.168.2.67
  - name: es-node-2
    ip:
      - 192.168.2.68
  - name: es-node-3
    ip:
      - 192.168.2.69
EOF
```

使用 elasticsearch-certutil 生成 CA 和节点证书

```shell
certs]# docker run --rm -it   -v "$PWD":/tmp   elasticsearch:8.19.9   bash
~$ elasticsearch-certutil ca --pem --silent --out /tmp/elastic-stack-ca.zip
~$ unzip /tmp/elastic-stack-ca.zip -d /tmp/elastic-stack-ca
~$ elasticsearch-certutil cert --silent --pem   \
  --in /tmp/instances.yml   \
  --out /tmp/certs.zip   \
  --ca-cert /tmp/elastic-stack-ca/ca/ca.crt \
  --ca-key /tmp/elastic-stack-ca/ca/ca.key
~$ unzip /tmp/certs.zip  -d /tmp/
~$ exit

certs]# tree .
.
├── certs.zip
├── elastic-stack-ca
│   └── ca
│       ├── ca.crt
│       └── ca.key
├── elastic-stack-ca.zip
├── es-node-1
│   ├── es-node-1.crt
│   └── es-node-1.key
├── es-node-2
│   ├── es-node-2.crt
│   └── es-node-2.key
├── es-node-3
│   ├── es-node-3.crt
│   └── es-node-3.key
├── hsperfdata_elasticsearch
└── instances.yml
```
> 注意：ca.key 请妥善保管，不要泄露。

### 分发证书

```shell
# 在 68 / 69 上准备目录
ssh root@192.168.2.68 "mkdir -p /opt/es/certs"
ssh root@192.168.2.69 "mkdir -p /opt/es/certs"

# 分发 CA
scp -r /opt/es/certs/elastic-stack-ca root@192.168.2.68:/opt/es/certs/
scp -r /opt/es/certs/elastic-stack-ca root@192.168.2.69:/opt/es/certs/

# 分发各自节点证书
scp -r /opt/es/certs/es-node-2 root@192.168.2.68:/opt/es/certs/
scp -r /opt/es/certs/es-node-3 root@192.168.2.69:/opt/es/certs/
```

### 调整内核参数

所有节点调整内核参数

```shell
sudo sysctl -w vm.max_map_count=262144
echo "vm.max_map_count=262144" | sudo tee /etc/sysctl.d/99-elasticsearch.conf
```

### 创建数据目录

```shell
mkdir /opt/es/node-data && chown -R 1000.1000 /opt/es/
ssh root@192.168.2.68 "mkdir /opt/es/node-data && chown -R 1000.1000 /opt/es/"
ssh root@192.168.2.69 "mkdir /opt/es/node-data && chown -R 1000.1000 /opt/es/"
```

### docker-compose.yml 文件

=== "192.168.2.67"

    ```bash
    cd /opt/es && cat > docker-compose.yml << 'EOF'
    version: "3.8"

    services:
      es-node-1:
        image: elasticsearch:8.19.9
        # image: arm64v8/elasticsearch:8.19.9
        container_name: es-node-1
        environment:
          - node.name=es-node-1
          - cluster.name=dev-cluster
          - discovery.seed_hosts=192.168.2.67:9300,192.168.2.68:9300,192.168.2.69:9300
          - cluster.initial_master_nodes=es-node-1,es-node-2,es-node-3
          - network.host=0.0.0.0
          - network.publish_host=192.168.2.67
          - ES_JAVA_OPTS=-Xms1g -Xmx1g -Duser.timezone=Asia/Shanghai
          - TZ=Asia/Shanghai

          - xpack.security.enabled=true
          - xpack.security.transport.ssl.enabled=true
          - xpack.security.transport.ssl.verification_mode=certificate
          - xpack.security.transport.ssl.client_authentication=required
          - xpack.security.transport.ssl.certificate_authorities=/usr/share/elasticsearch/config/certs/elastic-stack-ca/ca/ca.crt
          - xpack.security.transport.ssl.certificate=/usr/share/elasticsearch/config/certs/es-node-1/es-node-1.crt
          - xpack.security.transport.ssl.key=/usr/share/elasticsearch/config/certs/es-node-1/es-node-1.key

          - xpack.security.http.ssl.enabled=true
          - xpack.security.http.ssl.certificate_authorities=/usr/share/elasticsearch/config/certs/elastic-stack-ca/ca/ca.crt
          - xpack.security.http.ssl.certificate=/usr/share/elasticsearch/config/certs/es-node-1/es-node-1.crt
          - xpack.security.http.ssl.key=/usr/share/elasticsearch/config/certs/es-node-1/es-node-1.key

          - ELASTIC_PASSWORD=My_Sup3r_Str0ng_Pass!

        ulimits:
          memlock:
            soft: -1
            hard: -1

        volumes:
          - /opt/es/node-data:/usr/share/elasticsearch/data
          - /opt/es/certs:/usr/share/elasticsearch/config/certs:ro
          - /etc/localtime:/etc/localtime:ro
          - /etc/timezone:/etc/timezone:ro

        ports:
          - "9200:9200"
          - "9300:9300"

        restart: unless-stopped
    EOF
    ```

=== "192.168.2.68"

    ```bash
    cd /opt/es && cat > docker-compose.yml << 'EOF'
    version: "3.8"

    services:
      es-node-2:
        image: elasticsearch:8.19.9
        # image: arm64v8/elasticsearch:8.19.9
        container_name: es-node-2
        environment:
          - node.name=es-node-2
          - cluster.name=dev-cluster
          - discovery.seed_hosts=192.168.2.67:9300,192.168.2.68:9300,192.168.2.69:9300
          - cluster.initial_master_nodes=es-node-1,es-node-2,es-node-3
          - network.host=0.0.0.0
          - network.publish_host=192.168.2.68
          - ES_JAVA_OPTS=-Xms1g -Xmx1g -Duser.timezone=Asia/Shanghai
          - TZ=Asia/Shanghai

          - xpack.security.enabled=true
          - xpack.security.transport.ssl.enabled=true
          - xpack.security.transport.ssl.verification_mode=certificate
          - xpack.security.transport.ssl.client_authentication=required
          - xpack.security.transport.ssl.certificate_authorities=/usr/share/elasticsearch/config/certs/elastic-stack-ca/ca/ca.crt
          - xpack.security.transport.ssl.certificate=/usr/share/elasticsearch/config/certs/es-node-2/es-node-2.crt
          - xpack.security.transport.ssl.key=/usr/share/elasticsearch/config/certs/es-node-2/es-node-2.key

          - xpack.security.http.ssl.enabled=true
          - xpack.security.http.ssl.certificate_authorities=/usr/share/elasticsearch/config/certs/elastic-stack-ca/ca/ca.crt
          - xpack.security.http.ssl.certificate=/usr/share/elasticsearch/config/certs/es-node-2/es-node-2.crt
          - xpack.security.http.ssl.key=/usr/share/elasticsearch/config/certs/es-node-2/es-node-2.key

          - ELASTIC_PASSWORD=My_Sup3r_Str0ng_Pass!

        ulimits:
          memlock:
            soft: -1
            hard: -1

        volumes:
          - /opt/es/node-data:/usr/share/elasticsearch/data
          - /opt/es/certs:/usr/share/elasticsearch/config/certs:ro
          - /etc/localtime:/etc/localtime:ro
          - /etc/timezone:/etc/timezone:ro
        ports:
          - "9200:9200"
          - "9300:9300"

        restart: unless-stopped
    EOF
    ```

=== "192.168.2.69"

    ```bash
    cd /opt/es && cat > docker-compose.yml << 'EOF'
    version: "3.8"

    services:
      es-node-3:
        image: elasticsearch:8.19.9
        # image: arm64v8/elasticsearch:8.19.9
        container_name: es-node-3
        environment:
          - node.name=es-node-3
          - cluster.name=dev-cluster
          - discovery.seed_hosts=192.168.2.67:9300,192.168.2.68:9300,192.168.2.69:9300
          - cluster.initial_master_nodes=es-node-1,es-node-2,es-node-3
          - network.host=0.0.0.0
          - network.publish_host=192.168.2.69
          - ES_JAVA_OPTS=-Xms1g -Xmx1g -Duser.timezone=Asia/Shanghai
          - TZ=Asia/Shanghai

          - xpack.security.enabled=true
          - xpack.security.transport.ssl.enabled=true
          - xpack.security.transport.ssl.verification_mode=certificate
          - xpack.security.transport.ssl.client_authentication=required
          - xpack.security.transport.ssl.certificate_authorities=/usr/share/elasticsearch/config/certs/elastic-stack-ca/ca/ca.crt
          - xpack.security.transport.ssl.certificate=/usr/share/elasticsearch/config/certs/es-node-3/es-node-3.crt
          - xpack.security.transport.ssl.key=/usr/share/elasticsearch/config/certs/es-node-3/es-node-3.key

          - xpack.security.http.ssl.enabled=true
          - xpack.security.http.ssl.certificate_authorities=/usr/share/elasticsearch/config/certs/elastic-stack-ca/ca/ca.crt
          - xpack.security.http.ssl.certificate=/usr/share/elasticsearch/config/certs/es-node-3/es-node-3.crt
          - xpack.security.http.ssl.key=/usr/share/elasticsearch/config/certs/es-node-3/es-node-3.key

          - ELASTIC_PASSWORD=My_Sup3r_Str0ng_Pass!

        ulimits:
          memlock:
            soft: -1
            hard: -1
        volumes:
          - /opt/es/node-data:/usr/share/elasticsearch/data
          - /opt/es/certs:/usr/share/elasticsearch/config/certs:ro
          - /etc/localtime:/etc/localtime:ro
          - /etc/timezone:/etc/timezone:ro
        ports:
          - "9200:9200"
          - "9300:9300"

        restart: unless-stopped
    EOF
    ```

| 配置项目                                                                                                                                                       | 说明                  |
|------------------------------------------------------------------------------------------------------------------------------------------------------------|---------------------|
| **通用环境变量**                                                                                                                                                 |                     |
| cluster.name                                                                                                                                               | 集群名称                |
| discovery.seed_hosts                                                                                                                                       | 集群节点                |
| cluster.initial_master_nodes                                                                                                                               | 主节点候选列表             |
| network.host                                                                                                                                               | 监听所有地址              |
| network.publish_host                                                                                                                                       | 对外公告使用的 IP，一般为当前节点IP |
| ES_JAVA_OPTS                                                                                                                                               | JVM 堆大小（可按机器内存调整）   |
| network.publish_host                                                                                                                                       | 对外公告使用的 IP，一般为当前节点IP |
| ELASTIC_PASSWORD                                                                                                                                           | elastic 用户密码        |
| **安全相关**                                                                                                                                                        |                     |
| xpack.security.enabled                                                                                                                                     | 开启安全                |
| xpack.security.transport.ssl.enabled<br>xpack.security.transport.ssl.verification_mode<br>xpack.security.transport.ssl.client_authentication               | 传输层 SSL（节点间通信）      |
| xpack.security.http.ssl.enabled<br>xpack.security.http.ssl.certificate_authorities<br>xpack.security.http.ssl.certificate<br>  xpack.security.http.ssl.key | HTTP 层 HTTPS        |

## 启动集群

```shell
cd /opt/es
docker compose up -d
```

## 验证集群

```shell
~]# curl --cacert /opt/es/certs/elastic-stack-ca/ca/ca.crt -u elastic:My_Sup3r_Str0ng_Pass! https://192.168.2.68:9200/_cat/health
1767682170 06:49:30 dev-cluster green 3 3 6 3 0 0 0 0 0 - 100.0%

~$ curl -k -u elastic:My_Sup3r_Str0ng_Pass!  https://192.168.2.67:9200
{
  "name" : "es-node-1",
  "cluster_name" : "dev-cluster",
  "cluster_uuid" : "BfFB0eWITWqSMPR6Qbuyog",
  "version" : {
    "number" : "8.19.9",
    "build_flavor" : "default",
    "build_type" : "docker",
    "build_hash" : "f60dd5fdef48c4b6cf97721154cd49b3b4794fb0",
    "build_date" : "2025-12-16T22:07:42.115850075Z",
    "build_snapshot" : false,
    "lucene_version" : "9.12.2",
    "minimum_wire_compatibility_version" : "7.17.0",
    "minimum_index_compatibility_version" : "7.0.0"
  },
  "tagline" : "You Know, for Search"
}
~$ curl -k -u elastic:My_Sup3r_Str0ng_Pass!  https://192.168.2.67:9200/_cat/nodes
192.168.2.67 25 95  8 0.06 0.14 0.07 cdfhilmrstw - es-node-1
192.168.2.69 49 94 10 0.06 0.13 0.06 cdfhilmrstw * es-node-3
192.168.2.68 25 93  8 0.06 0.12 0.06 cdfhilmrstw - es-node-2
```


