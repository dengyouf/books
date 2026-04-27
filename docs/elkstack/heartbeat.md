# HeartBeat

## 部署

```
# 下载解压所包
wget https://artifacts.elastic.co/downloads/beats/heartbeat/heartbeat-9.2.3-linux-x86_64.tar.gz
tar -xf heartbeat-9.2.3-linux-x86_64.tar.gz  -C /data/apps/
ln -sv /data/apps/heartbeat-9.2.3-linux-x86_64/ /data/apps/heartbeat
```

```
# 从 p12 文件中提取 CA 证书（需要输入 p12 的密码）
openssl pkcs12 -in \
  /data/apps/elasticsearch/config/certs/node03/node03.p12 \
  -cacerts \
  -nokeys \
  -out /data/apps/elasticsearch/config/certs/ca.crt
```
```
# 配置
cat >> /data/apps/heartbeat/heartbeat.yml << 'EOF'
heartbeat.config.monitors:
  path: ${path.config}/monitors.d/*.yml
  reload.enabled: false
  reload.period: 5s
heartbeat.monitors:
- type: icmp
  id: ping-es-nodes
  name: elasticnode
  hosts: ["192.168.122.16", "192.168.122.17", "192.168.122.18"]
  schedule: '*/5 * * * * * *'
- type: tcp
  id: tcp-nginx-port
  name: nginxport
  hosts: ["192.168.122.131:80"]
  check:
    receive: "HTTP/1."
  schedule: '@every 5s'
- type: http
  enabled: false
  id: my-monitor
  name: My Monitor
  urls: ["http://192.168.122.131:80"]
  schedule: '@every 10s'
setup.template.settings:
  index.number_of_shards: 1
  index.codec: best_compression
setup.kibana:
output.elasticsearch:
  hosts: ["192.168.122.16:9200","192.168.122.17:9200", "192.168.122.18:9200"]
  preset: balanced
  protocol: "https"
  username: "elastic"
  password: "elasticPwd123"
  ssl.certificate_authorities: ["/data/apps/metricbeat/certs/ca.crt"]
processors:
  - add_observer_metadata:
EOF
# 测试配置语法
./metricbeat test config
# 测试连接
metricbeat test output
# 启动服务
./heartbeat -e -c heartbeat.yml
```


## Kibana操作

### 1. 创建数据视图

Management -> Stack Management -> Kibana -> 数据视图 （heartbeat）

### 2.可视化

Observability -> 运行时间 -> 监测



