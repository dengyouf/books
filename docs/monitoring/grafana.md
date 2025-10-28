# Grafana

## 二进制安装

```shell
sudo apt-get install -y adduser libfontconfig1 musl
wget https://dl.grafana.com/grafana/release/12.1.1/grafana_12.1.1_16903967602_linux_amd64.deb
sudo dpkg -i grafana_12.1.1_16903967602_linux_amd64.deb
```

## 访问UI

访问地址为：http://192.168.1.254:3000/login，默认账号/密码为admin/admin。

- Node Exporter Dashboard 20240520 通用JOB分组版:[16098](https://grafana.com/grafana/dashboards/16098-node-exporter-dashboard-20240520-job/)
