# MetricBeat

收集系统和服务的指标。从 CPU 到内存，从 Redis 到 NGINX 等，Metricbeat 是一种轻量级的系统和服务统计数据传输方式。

## 部署

```
# 下载解压缩包
wget https://artifacts.elastic.co/downloads/beats/metricbeat/metricbeat-9.2.3-linux-x86_64.tar.gz
tar -xf metricbeat-9.2.3-linux-x86_64.tar.gz  -C /data/apps/
ln -sv /data/apps/metricbeat-9.2.3-linux-x86_64/ /data/apps/metricbeat
```
```
# 提取ca证书
# 1. 从 p12 文件中提取 CA 证书（需要输入 p12 的密码）
openssl pkcs12 -in \
  /data/apps/elasticsearch/config/certs/node03/node03.p12 \
  -cacerts \
  -nokeys \
  -out /data/apps/elasticsearch/config/certs/ca.crt
```
```
# 配置
cat > /data/apps/metricbeat/metricbeat.yml << 'EOF'
metricbeat.config.modules:
  path: ${path.config}/modules.d/*.yml
  reload.enabled: false
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
  - add_host_metadata: ~
  - add_cloud_metadata: ~
  - add_docker_metadata: ~
  - add_kubernetes_metadata: ~
EOF
# 测试配置语法
./metricbeat test config
# 测试连接
metricbeat test output
```
