# Node Exporter

## 二进制安装

```shell
#wget https://github.com/prometheus/node_exporter/releases/download/v1.6.1/node_exporter-1.6.1.linux-amd64.tar.gz
wget https://ghfast.top/https://github.com/prometheus/node_exporter/releases/download/v1.6.1/node_exporter-1.6.1.linux-amd64.tar.gz
tar -xf node_exporter-1.6.1.linux-amd64.tar.gz  -C /usr/local/
useradd -r -s /bin/false node_exporter
chown node_exporter:node_exporter  /usr/local/node_exporter-1.6.1.linux-amd64/ -R
cat > /etc/systemd/system/node_exporter.service << 'EOF'
[Unit]
Description=Node Exporter
Wants=network-online.target
After=network-online.target

[Service]
User=node_exporter
Group=node_exporter
Type=simple
ExecStart=/usr/local/node_exporter-1.6.1.linux-amd64/node_exporter \
  --collector.ntp \
  --collector.mountstats \
  --collector.systemd \
  --collector.ethtool \
  --collector.tcpstat
ExecReload=/bin/kill -HUP $MAINPID
TimeoutStopSec=20s
Restart=always

[Install]
WantedBy=multi-user.target
EOF
systemctl  daemon-reload && systemctl  enable node_exporter --now
```

## docker-compose 安装

```shell
mkdir -pv /data/apps/node_exporter && cd /data/apps/node_exporter
cat > docker-compose.yml << 'EOF'
version: '3.8'

networks:
  monitoring:
    driver: bridge
services:
  node-exporter:
    image: swr.cn-north-4.myhuaweicloud.com/ddn-k8s/quay.io/prometheus/node-exporter:v1.9.1
    volumes:
      - /proc:/host/proc:ro
      - /sys:/host/sys:ro
      - /:/rootfs:ro
    command:
      - '--path.procfs=/host/proc'
      - '--path.sysfs=/host/sys'
      - '--collector.filesystem.mount-points-exclude=^/(sys|proc|dev|host|etc)($$|/)'
      - '--path.rootfs=/rootfs'
    ports:
      - 9100:9100
    restart: always
EOF
docker compose up -d
```
