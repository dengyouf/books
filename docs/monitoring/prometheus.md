# Prometheus Server

## 二进制安装

```shell
# wget https://github.com/prometheus/prometheus/releases/download/v2.47.0/prometheus-2.47.0.linux-amd64.tar.gz
wget https://ghfast.top/https://github.com/prometheus/prometheus/releases/download/v2.47.0/prometheus-2.47.0.linux-amd64.tar.gz
tar -xf prometheus-2.47.0.linux-amd64.tar.gz  -C /usr/local/
cd /usr/local/prometheus-2.47.0.linux-amd64/
useradd --no-create-home --shell /bin/false prometheus
chown -R prometheus:prometheus /usr/local/prometheus-2.47.0.linux-amd64/
cat > /etc/systemd/system/prometheus.service << 'EOF'
[Unit]
Description=Prometheus
Wants=network-online.target
After=network-online.target

[Service]
User=prometheus
Group=prometheus
Type=simple
ExecStart=/usr/local/prometheus-2.47.0.linux-amd64/prometheus \
  --config.file=/usr/local/prometheus-2.47.0.linux-amd64/prometheus.yml \
  --storage.tsdb.path=/usr/local/prometheus-2.47.0.linux-amd64/data \
  --web.console.templates=/usr/local/prometheus-2.47.0.linux-amd64/consoles \
  --web.console.libraries=/usr/local/prometheus-2.47.0.linux-amd64/console_libraries \
  --web.enable-lifecycle \
  --storage.tsdb.retention.time=180d \
  --storage.tsdb.retention.size=100GB \
  --web.listen-address=0.0.0.0:9090 \
  --storage.tsdb.wal-compression
ExecReload=/bin/kill -HUP $MAINPID
TimeoutStopSec=20s
SendSIGKILL=no
LimitNOFILE=8192

[Install]
WantedBy=multi-user.target
EOF
systemctl  daemon-reload && systemctl  enable  prometheus --now
```

## 配置Prometheus

### 1.静态target
```shell
scrape_configs:
  # The job name is added as a label `job=<job_name>` to any timeseries scraped from this config.
  - job_name: "prometheus-server"
    static_configs:
      - targets: ["localhost:9090"]
  - job_name: "grafana-server"
    static_configs:
      - targets: ["192.168.1.254:3000"]
  - job_name: "node_exporter"
    static_configs:
      - targets: ["192.168.1.254:9100"]
        labels:
          enviroment: 'prod'
          role: "appServer"
# 重载prometheus
~# curl -X POST http://192.168.1.254:9090/-/reload
```
