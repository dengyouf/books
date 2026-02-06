# Lock Stack

使用 Loki + Promtail + Grafana 采集Kuberentes集群日志，并将数据持久化 Minio 对象存储。

## Minio 存储

### 1. 启动Minio

使用 docker compose 启动 minio

```shell
mkdir minio
cd minio && cat > docker-compose.yml << 'EOF'
version: '3.8'
services:
  minio:
    container_name: minio
    #image: minio/minio:RELEASE.2025-04-03T14-56-28Z
    image: swr.cn-north-4.myhuaweicloud.com/ddn-k8s/quay.io/minio/minio:RELEASE.2025-04-22T22-12-26Z-linuxarm64
    ports:
      - "9000:9000" # MinIO API and Console port
      - "9001:9001" # MinIO Console port (optional, if separate)
    volumes:
      - ./data:/data # Persist data to a local directory
    environment:
      MINIO_ROOT_USER: "minio_admin" # Your desired root username
      MINIO_ROOT_PASSWORD: "adminPwd" # Your desired root password
    command: server /data --console-address ":9001" # Start MinIO server and specify console address
EOF
docker compose up -d
```

### 2. 配置Minio

访问登陆minio UI(http://IP:9001/)， 创建 Access Key 和 Secret Key和一些必要的Bucket

- Access Key
- Secret Key
- Enpoint: IP:9000
- chunks(存储时序数据块): chunks-dev-cluster
- ruler(存储告警规则): ruler-dev-cluster
- admin(存储管理元数据): admin-dev-cluster

## Loki Stack

使用 helm 分别安装 Loki， Promtail, Grafana， 添加Charts仓库

```shell
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update
```


### Loki

```shell
helm pull grafana/loki --version=6.51.0
tar -xf loki-6.51.0.tgz
cd loki && cp distributed-values.yaml prod-value.yaml

vim prod-value.yaml
loki:
  limits_config:
    # 单次 LogQL 查询的时间跨度
    max_query_length: 180d
    # 能不能查那么“久远”的数据
    max_query_lookback: 360d
  ingester:
    chunk_encoding: snappy
    # 将日志块刷写到 S3 存储的频率，这里是低流量/测试环境场景，生产应调大
    chunk_idle_period: 30s      # 30 秒没新日志就刷， 生产推荐1m
    max_chunk_age: 1m           #允许更大的内存块， 生产推荐5m
  ...
  # 配置用 S3 兼容对象存储Minio 作为后端的存储
  storage:
    type: s3
    bucketNames:
      chunks: chunks-dev-cluster
      ruler: ruler-dev-cluster
      admin: admin-dev-cluster
    s3:
      endpoint: 172.16.30.1:9000
      accessKeyId: nC0mUg6Gq4whYUdpGXvw
      secretAccessKey: Q7BlxRuKKANW5fzOFuFrdnELqOZlJE1ZBnq0eCdI
      s3ForcePathStyle: true
      insecure: true
  ...
# 禁用内置的minio
minio:
  enabled: false
```

```shell
helm install loki . -f prod-value.yaml -n logging
(base) ➜  loki kubectl get pod -n logging
NAME                                    READY   STATUS    RESTARTS   AGE
loki-canary-qh2v9                       1/1     Running   0          73s
loki-canary-tbr6w                       1/1     Running   0          73s
loki-canary-v8dl5                       1/1     Running   0          73s
loki-chunks-cache-0                     2/2     Running   0          37s
loki-compactor-0                        1/1     Running   0          71s
loki-distributor-67d8bbb966-b9kt9       1/1     Running   0          72s
loki-distributor-67d8bbb966-k4fd7       1/1     Running   0          72s
loki-distributor-67d8bbb966-mh6wq       1/1     Running   0          73s
loki-gateway-6b58cb5d75-tdf4s           1/1     Running   0          73s
loki-index-gateway-0                    1/1     Running   0          72s
loki-index-gateway-1                    1/1     Running   0          38s
loki-ingester-zone-a-0                  1/1     Running   0          72s
loki-ingester-zone-b-0                  1/1     Running   0          72s
loki-ingester-zone-c-0                  1/1     Running   0          71s
loki-querier-7d5fcf667b-dzv96           1/1     Running   0          72s
loki-querier-7d5fcf667b-hztr5           1/1     Running   0          73s
loki-querier-7d5fcf667b-xclxn           1/1     Running   0          72s
loki-query-frontend-654bb979bf-rb2vk    1/1     Running   0          73s
loki-query-frontend-654bb979bf-rp5rv    1/1     Running   0          72s
loki-query-scheduler-75d4b98459-6dsb7   1/1     Running   0          73s
loki-query-scheduler-75d4b98459-tvn22   1/1     Running   0          72s
loki-results-cache-0                    2/2     Running   0          72s
```

### Promtail

```shell
helm pull grafana/promtail --version=6.17.1
tar -xf promtail-6.17.1.tgz
cd promtail && cp values.yaml prod-values.yaml
vim prod-values.yaml

...
  clients:
    - url: http://loki-gateway/loki/api/v1/push
      # 开启多租户标识
      tenant_id: dev
 scrapeConfigs: |
        ...
        kubernetes_sd_configs:
          - role: pod
        relabel_configs:
        # 采集指定namespace下Pod日志
          - source_labels:
              - __meta_kubernetes_namespace
            regex: ^(envoy-gateway-system|kube-system|test)$
            action: keep
```
```shell
helm install promtail . -f prod-values.yaml -n logging
kubectl get pod -n logging -l app.kubernetes.io/name=promtail
NAME             READY   STATUS    RESTARTS   AGE
promtail-95kpr   1/1     Running   0          34s
promtail-hkw2q   1/1     Running   0          34s
promtail-pw42m   1/1     Running   0          34s
promtail-q6l6d   1/1     Running   0          34s
```

### Grafana

```shell
helm pull grafana/grafana --version=10.5.15
tar xf grafana-10.5.15.tgz
cd grafana && cp values.yaml prod-values.yaml

vim prod-values.yaml

...
adminUser: admin
adminPassword: adminPwd
...
datasources:
  datasources.yaml:
    apiVersion: 1
    datasources:
    - name: Loki-dev
      type: loki
      # Loki Gateway 服务地址
      url: http://loki-gateway.logging.svc.cluster.local
      access: proxy
      # 多租户配置
      jsonData:
        httpHeaderName1: "X-Scope-OrgID"
      secureJsonData:
        httpHeaderValue1: "dev"
      # 其他可选配置
      editable: true
      isDefault: true
      version: 1
  ...
service:
  enabled: true
  type: NodePort
```
```shell
helm install grafana . -f prod-values.yaml  -n logging
```

## LogQL

受PromSQL启发，Loki提供了转门用于日志查询的语言LogQL,他支持两种类型的查询

- 日志查询：返回查询的日志条目
- 指标查询：基于过滤规则，在日志查询得到的日志条目中执行过滤操作

```shell
# 行过滤器， 对消息中的关键字进行过滤
{namespace="test"} |= "error"

# 标签过滤器 ，通过json 过滤器，可以将json格式的日志抽取为临时标签，然后对标签进行过滤
#{":authority":"www.xsreops.xyz","appId":null,"appKey":null,"bytes_received":0,"bytes_sent":1141,"connection_termination_details":null,"downstream_local_address":"10.0.3.69:10443","downstream_remote_address":"172.16.30.1:64410","duration":160,"method":"GET","protocol":"HTTP/2","requested_server_name":null,"response_code":200,"response_code_details":"via_upstream","response_flags":"-","route_name":"httproute/test/backend-https/rule/0/match/0/www_xsreops_xyz","start_time":"2026-02-05T03:07:12.323Z","upstream_cluster":"httproute/test/backend-https/rule/0","upstream_host":"10.0.3.156:3000","upstream_local_address":"10.0.3.69:38738","upstream_transport_failure_reason":null,"user-agent":"Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36","x-envoy-origin-path":null,"x-envoy-upstream-service-time":null,"x-forwarded-for":"172.16.30.1","x-request-id":"fd742b12-076a-4512-a90a-6c2563baa107"}
{namespace="envoy-gateway-system"} | json| appId = "1111111"


# pattern解析器，从文本日志内容中，通过pattern匹配的方式，提取字段创建新的标签
#10.0.2.33 - - [05/Feb/2026:03:09:23 +0000] "GET / HTTP/1.1" 200 612 "-" "curl/8.5.0" "-"
{namespace="test"}| pattern "<clientIP> - - [<timestamp>] \"<method> <url> <version>\" <status> <length> \"<_>\" \"<broser>\" \"<>\""|url="/hello.txt"

# 所有URL的请求速率
sum by (url) (
  rate({namespace="test"}
    | pattern "<clientIP> - - [<timestamp>] \"<method> <url> <version>\" <status> <length> \"<_>\" \"<broser>\" \"<>\""
    [3m])
)

# 只显示请求最多的前10个URL
topk(10,
  sum by (url) (
    rate({namespace="test"}
      | pattern "<clientIP> - - [<timestamp>] \"<method> <url> <version>\" <status> <length> \"<_>\" \"<broser>\" \"<>\""
      [3m])
  )
)

# 按URL和HTTP方法分组
sum by (url, method) (
  rate({namespace="test"}
    | pattern "<clientIP> - - [<timestamp>] \"<method> <url> <version>\" <status> <length> \"<_>\" \"<broser>\" \"<>\""
    [3m])
)

# 特定API端点的请求速率
sum by (url) (
  rate({namespace="test"}
    | pattern "<clientIP> - - [<timestamp>] \"<method> <url> <version>\" <status> <length> \"<_>\" \"<broser>\" \"<>\""
    | url =~ "/hello.*"
    [3m])
)
# 按URL模式聚合（如按路径前缀）
sum by (url_prefix) (
  rate({namespace="test"}
    | pattern "<clientIP> - - [<timestamp>] \"<method> <url> <version>\" <status> <length> \"<_>\" \"<broser>\" \"<>\""
    | regexp "\\s(?P<url_prefix>/[^/]+)"  # 提取第一级路径
    [3m])
)
```

## MinIO保存策略

任何 365 天前写入的对象，MinIO 自动删除

```shell
mc alias set minio http://172.16.30.1:9000  nC0mUg6Gq4whYUdpGXvw Q7BlxRuKKANW5fzOFuFrdnELqOZlJE1ZBnq0eCdI
# 监控 MinIO bucket 大小
mc du minio/chunks-dev-cluster
6.6MiB	3952 objects	chunks-dev-cluster
# chrunk 保留365 day
mc ilm add minio/chunks-dev-cluster \
  --expire-days 365
mc ilm ls minio/chunks-dev-cluster
┌───────────────────────────────────────────────────────────────────────────────────────┐
│ Expiration for latest version (Expiration)                                            │
├──────────────────────┬─────────┬────────┬──────┬────────────────┬─────────────────────┤
│ ID                   │ STATUS  │ PREFIX │ TAGS │ DAYS TO EXPIRE │ EXPIRE DELETEMARKER │
├──────────────────────┼─────────┼────────┼──────┼────────────────┼─────────────────────┤
│ d6263saqe25014rh38l0 │ Enabled │ -      │ -    │            365 │ false               │
└──────────────────────┴─────────┴────────┴──────┴────────────────┴─────────────────────┘

# 删除策略
mc ilm rm minio/chunks-dev-cluster
```
