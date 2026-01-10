# Service Token 接入 Kibana 与 HTTPS 通信

## 获取Token

```shell
~]# curl -ks -u elastic:My_Sup3r_Str0ng_Pass!   -X POST https://192.168.2.67:9200/_security/service/elastic/kibana/credential/token|jq
{
  "created": true,
  "token": {
    "name": "token_A00rkpsBCYirY-BfERj0",
    "value": "AAEAAWVsYXN0aWMva2liYW5hL3Rva2VuX0EwMHJrcHNCQ1lpclktQmZFUmowOkhpNERpN1FrUjlxNThSczZoR0V6NEE"
  }
}
~]#  curl -k   -H "Authorization: Bearer AAEAAWVsYXN0aWMva2liYW5hL3Rva2VuX0EwMHJrcHNCQ1lpclktQmZFUmowOkhpNERpN1FrUjlxNThSczZoR0V6NEE" https://192.168.2.67:9200/_cat/nodes
192.168.2.67 13 95 1 0.22 0.07 0.02 cdfhilmrstw * es-node-1
192.168.2.69 44 95 1 0.03 0.02 0.00 cdfhilmrstw - es-node-3
192.168.2.68 10 95 1 0.04 0.03 0.00 cdfhilmrstw - es-node-2
```

## 提供配置文件

```shell
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

## 提供Compose文件

```shell
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
```

## 启动服务

```shell
kibana]# docker compose up -d
```
