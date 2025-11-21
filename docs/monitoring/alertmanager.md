# Alertmanager

## 二进制安装

```shell
# wget https://github.com/prometheus/alertmanager/releases/download/v0.25.1/alertmanager-0.25.1.linux-amd64.tar.gz
wget https://ghfast.top/https://github.com/prometheus/alertmanager/releases/download/v0.25.1/alertmanager-0.25.1.linux-amd64.tar.gz
tar -xf alertmanager-0.25.1.linux-amd64.tar.gz  -C /usr/local/
chown prometheus.prometheus -R /usr/local/alertmanager-0.25.1.linux-amd64/
cat > /etc/systemd/system/alertmanager.service<< 'EOF'
[Unit]
Description=alertmanager
Documentation=https://prometheus.io/docs/introduction/overview/
After=network.target

[Service]
Type=simple
User=prometheus
ExecStart=/usr/local/alertmanager-0.25.1.linux-amd64/alertmanager \
            --config.file="/usr/local/alertmanager-0.25.1.linux-amd64/alertmanager.yml" \
            --storage.path="/usr/local/alertmanager-0.25.1.linux-amd64/data/" \
            --data.retention=120h \
            --log.level=info
ExecReload=/bin/kill -HUP $MAINPID
TimeoutStopSec=20s
Restart=always

[Install]
WantedBy=multi-user.target
EOF
systemctl  daemon-reload && systemctl  enable alertmanager --now
```
