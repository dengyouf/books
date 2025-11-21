# BlackBox Exporter

## 二进制安装

```shell
#wget https://github.com/prometheus/blackbox_exporter/releases/download/v0.26.0/blackbox_exporter-0.26.0.linux-amd64.tar.gz
wget https://ghfast.top/https://github.com/prometheus/blackbox_exporter/releases/download/v0.26.0/blackbox_exporter-0.26.0.linux-amd64.tar.gz
tar -xf blackbox_exporter-0.26.0.linux-amd64.tar.gz  -C /usr/local/
chown prometheus.prometheus -R /usr/local/blackbox_exporter-0.26.0.linux-amd64/
cat > /etc/systemd/system/blackbox_exporter.service << 'EOF'
[Unit]
Description=blackbox_exporter
Documentation=https://prometheus.io/docs/introduction/overview/
After=network.target

[Service]
Type=simple
User=prometheus
EnvironmentFile=-/etc/default/blackbox_exporter
ExecStart=/usr/local/blackbox_exporter-0.26.0.linux-amd64/blackbox_exporter \
  --web.listen-address=:9115 \
  --config.file=/usr/local/blackbox_exporter-0.26.0.linux-amd64/blackbox.yml
ExecReload=/bin/kill -HUP $MAINPID
TimeoutStopSec=20s
Restart=always

[Install]
WantedBy=multi-user.target
EOF

systemctl  daemon-reload && systemctl  start blackbox_exporter
```
