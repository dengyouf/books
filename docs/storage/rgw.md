# RADOS Gateway对象存储网关

RADOS Gateway（RGW） 是 Ceph 的一个 HTTP REST 网关服务， 它的作用是让外部应用通过 S3 / Swift 协议 访问 Ceph 后端的对象存储。同时RGW为了实现RESTful接口功能，默认使用Civetweb作为WebService，而Civetweb默认使用端口为7448提供服务，如果想修改端口，可以在ceph配置文件中实现。

## 修改默认端口

http://192.168.1.103:7480/

```shell
~]#vim /etc/ceph/ceph.conf
[client.rgw.ceph-node03]
rgw_frontends = "civetweb port=8080"
]# systemctl  restart ceph-radosgw@rgw.ceph-node03.service
~]# ss -tnlp|grep 8080
LISTEN     0      128          *:8080                     *:*                   users:(("radosgw",pid=66470,fd=48)
```
## ssl通信

```shell
~]# mkdir /etc/ceph/ssl && cd /etc/ceph/ssl
ssl]# openssl genrsa -out civetweb.key 2480
ssl]# openssl req -new -x509 -key civetweb.key -out civetweb.crt -days 3650 -subj "/CN=ceph-node03.devops.io"
ssl]# cat civetweb.key  civetweb.crt > civetweb.pem
```
```shell
~]#vim /etc/ceph/ceph.conf
[client.rgw.ceph-node03]
rgw_frontends = "civetweb port=8080+8443s ssl_certificate=/etc/ceph/ssl/civetweb.pem num_threads=2000"
~]# systemctl  restart ceph-radosgw@rgw.ceph-node03.service
~]# ss -tnlp|grep radosgw
LISTEN     0      128          *:8080                     *:*                   users:(("radosgw",pid=67094,fd=47))
LISTEN     0      128          *:8443                     *:*                   users:(("radosgw",pid=67094,fd=48))
```

## 泛域名实践
radosgw 的S3 API 接口功能强依赖DNS的泛域名解析服务。它碧玺能正常解析任何`<bucket-name>/<radosgw-host>`格式的名称至radosgw主机，此外，我们还需要配置每个radosgw守护进程的`rgw_dns_name`为其DNS名称
### 1. dns环境配置

```shell
~]# yum install bind bind-chroot bind-utils bind-libs -y
~]# vim /etc/named.conf
options {
        listen-on port 53 { any; };
        allow-query     { any; };
        ...
        /*
        dnssec-enable yes;
        dnssec-validation yes;
        */
};
...
// 定制域名的zone配置
zone "devops.io" IN {
    type master;
    file "/var/named/devops.io.zone";
    allow-update { none; };
};


cat  > /var/named/devops.io.zone << 'EOF'
$TTL 1H
@       IN  SOA  ns1.devops.io. admin.devops.io. (
                2025102101 ; 序列号
                1H         ; 刷新
                10M        ; 重试
                1W         ; 过期
                1H )       ; 最小TTL

; DNS服务器自身
        IN  NS   ns1.devops.io.
ns1     IN  A    192.168.1.100

; 主域名（devops.io）
@                      IN  A    192.168.1.100     ; 可选，也可以是网站IP

; ceph-node03 主机
node3           IN  A    192.168.1.103

; 泛域名 *.ceph-node03.devops.io
*.node3           IN  A    192.168.1.103
EOF
systemctl start named
dig -t A devops.io @192.168.1.100
dig -t A node3 .devops.io @192.168.1.100
dig -t A img.node3 .devops.io @192.168.1.100
dig -t A file.node3.devops.io @192.168.1.100
```
### 2.创建专属的用户名
```shell
~]# radosgw-admin user create --uid='s3user' --display-name 'S3 Testing User'
{
    "user_id": "s3user",
    "display_name": "S3 Testing User",
    "email": "",
    "suspended": 0,
    "max_buckets": 1000,
    "subusers": [],
    "keys": [
        {
            "user": "s3user",
            "access_key": "0WGYN1LLSQ5QLU7KA581",
            "secret_key": "vQQGkynYDEu4Nc4LQGN6SWBMo2cvBuTH6brH7Jpc"
        }
    ],
    "swift_keys": [],
    "caps": [],
    "op_mask": "read, write, delete",
    "default_placement": "",
    "default_storage_class": "",
    "placement_tags": [],
    "bucket_quota": {
        "enabled": false,
        "check_on_raw": false,
        "max_size": -1,
        "max_size_kb": 0,
        "max_objects": -1
    },
    "user_quota": {
        "enabled": false,
        "check_on_raw": false,
        "max_size": -1,
        "max_size_kb": 0,
        "max_objects": -1
    },
    "temp_url_keys": [],
    "type": "rgw",
    "mfa_ids": []
}
```
### 3.安装专属的客户端命令
```shell
~]# yum install s3cmd
```
### 4.配置专属的认证配置文件
```shell
~]#  s3cmd --configure

Enter new values or accept defaults in brackets with Enter.
Refer to user manual for detailed description of all options.

Access key and Secret key are your identifiers for Amazon S3. Leave them empty for using the env variables.
Access Key: 0WGYN1LLSQ5QLU7KA581
Secret Key: vQQGkynYDEu4Nc4LQGN6SWBMo2cvBuTH6brH7Jpc
Default Region [US]:

Use "s3.amazonaws.com" for S3 Endpoint and not modify it to the target Amazon S3.
S3 Endpoint [s3.amazonaws.com]: node3.devops.io:8080

Use "%(bucket)s.s3.amazonaws.com" to the target Amazon S3. "%(bucket)s" and "%(location)s" vars can be used
if the target S3 system supports dns based buckets.
DNS-style bucket+hostname:port template for accessing a bucket [%(bucket)s.s3.amazonaws.com]: %(bucket)s.node3.devops.io:8080

Encryption password is used to protect your files from reading
by unauthorized persons while in transfer to S3
Encryption password:
Path to GPG program [/bin/gpg]:

When using secure HTTPS protocol all communication with Amazon S3
servers is protected from 3rd party eavesdropping. This method is
slower than plain HTTP, and can only be proxied with Python 2.7 or newer
Use HTTPS protocol [Yes]: No

On some networks all internet access must go through a HTTP proxy.
Try setting it here if you can't connect to S3 directly
HTTP Proxy server name:

New settings:
  Access Key: 0WGYN1LLSQ5QLU7KA581
  Secret Key: vQQGkynYDEu4Nc4LQGN6SWBMo2cvBuTH6brH7Jpc
  Default Region: US
  S3 Endpoint: node3.devops.io:8080
  DNS-style bucket+hostname:port template for accessing a bucket: %(bucket)s.node3.devops.io:8080
  Encryption password:
  Path to GPG program: /bin/gpg
  Use HTTPS protocol: False
  HTTP Proxy server name:
  HTTP Proxy server port: 0

Test access with supplied credentials? [Y/n] y
Please wait, attempting to list all buckets...
Success. Your access key and secret key worked fine :-)

Now verifying that encryption works...
Not configured. Never mind.

Save settings? [y/N] y
Configuration saved to '/root/.s3cfg'
```
### 5.综合测试s3的资源对象管理

#### 5.1.上传文件
```
# 需要配置/etc/resolve.conf 使用自建的dns
~]# nslookup file.node3.devops.io
Server:		192.168.1.100
Address:	192.168.1.100#53

Name:	file.ceph-node03.devops.io
Address: 192.168.1.103
```
```shell
~]# ceph config set client.rgw.ceph-node03 rgw_dns_name node3.devops.io
~]# s3cmd mb s3://images
Bucket 's3://images/' created
~]# s3cmd mb s3://images1
Bucket 's3://images1/' created
[root@ceph-node03 ~]# s3cmd mb s3://images2
Bucket 's3://images2/' created
```
```shell
# 上传，上传目录请添加参数 --recursive
~]# s3cmd put /etc/fstab s3://images1/linux/myfs
upload: '/etc/fstab' -> 's3://images1/linux/myfs'  [1 of 1]
 465 of 465   100% in    0s    24.11 KB/s  done
# 列出
[root@ceph-node03 ~]# s3cmd ls  s3://images1/
                          DIR  s3://images1/linux/
[root@ceph-node03 ~]# s3cmd ls  s3://images1/linux
                          DIR  s3://images1/linux/
[root@ceph-node03 ~]# s3cmd ls  s3://images1/linux/myfs
2025-10-21 17:21          465  s3://images1/linux/myfs
```
#### 5.2.下载文件
```
~]# s3cmd get  s3://images1/linux/myfs /tmp/myfs
download: 's3://images1/linux/myfs' -> '/tmp/myfs'  [1 of 1]
 465 of 465   100% in    0s    10.69 KB/s  done
[root@ceph-node03 ~]# ls /tmp/myfs
/tmp/myfs
```
#### 5.3.访问文件
```shell
~]# s3cmd ls s3://images
~]# s3cmd  put /etc/fstab s3://images/linux/fstab.txt
upload: '/etc/fstab' -> 's3://images/linux/fstab.txt'  [1 of 1]
 465 of 465   100% in    0s    18.92 KB/s  done
~]# s3cmd  ls s3://images/linux/
2025-10-22 01:31          465  s3://images/linux/fstab.txt
~]# s3cmd  ls s3://images/linux
                          DIR  s3://images/linux/
# 授权 https://docs.ceph.com/en/quincy/radosgw/bucketpolicy/
 ~]# cat > policy.json << 'EOF'
{
	"Statement": [{
			"Effect": "Allow",
			"Principal": "*",
			"Action": ["s3:GetObject"],
			"Resource": "*"
	}]
}
EOF
~]# s3cmd setpolicy policy.json s3://images --acl-public
s3://images/: Policy updated
# 定制cors的策略文件
cat > rules.xml << 'EOF'
<CORSConfiguration>
  <CORSRule>
    <AllowedOrigin>*</AllowedOrigin>
    <AllowedMethod>GET</AllowedMethod>
    <AllowedMethod>PUT</AllowedMethod>
    <AllowedMethod>POST</AllowedMethod>
    <AllowedMethod>DELETE</AllowedMethod>
    <AllowedHeader>*</AllowedHeader>
    <ExposeHeader>ETag</ExposeHeader>
    <MaxAgeSeconds>3000</MaxAgeSeconds>
  </CORSRule>
</CORSConfiguration>
EOF
~]# s3cmd setcors rules.xml s3://images
[root@ceph-node03 ~]# s3cmd info s3://images
s3://images/ (bucket):
   Location:  default
   Payer:     BucketOwner
   Expiration Rule: none
   Policy:    {
	"Statement": [{
			"Effect": "Allow",
			"Principal": "*",
			"Action": ["s3:GetObject"],
			"Resource": "*"
	}]
}

   CORS:      <CORSConfiguration xmlns="http://s3.amazonaws.com/doc/2006-03-01/"><CORSRule><AllowedMethod>GET</AllowedMethod><AllowedMethod>PUT</AllowedMethod><AllowedMethod>DELETE</AllowedMethod><AllowedMethod>POST</AllowedMethod><AllowedOrigin>*</AllowedOrigin><AllowedHeader>*</AllowedHeader><MaxAgeSeconds>3000</MaxAgeSeconds><ExposeHeader>ETag</ExposeHeader></CORSRule></CORSConfiguration>
   ACL:       S3 Testing User: FULL_CONTROL
#
curl https://images.node3.devops.io:8080/linux/fstab.txt

#
# /etc/fstab
# Created by anaconda on Sun Oct 19 10:05:37 2025
#
# Accessible filesystems, by reference, are maintained under '/dev/disk'
# See man pages fstab(5), findfs(8), mount(8) and/or blkid(8) for more info
#
/dev/mapper/centos-root /                       xfs     defaults        0 0
UUID=21bb7911-72e6-4467-ac66-09f75857bc92 /boot                   xfs     defaults        0 0
/dev/mapper/centos-swap swap                    swap    defaults        0 0
```
## 进阶

### 1.rgw存储池
默认情况下 RGW安装完成后，会默认生成以下存储池
```shell
~]$ ceph osd  pool ls
# 自动生成的存储池
.rgw.root                         # 包含zone。zonegroup，realm等信息
default.rgw.control               # pool 中对象的控制信息
default.rgw.meta                 # 元数据信息
default.rgw.log                  # 日志处理信息
default.rgw.buckets.index        # 存储桶和对象的映射关系
default.rgw.buckets.data         # 对象数据信息
```
### 2.元数据

```shell
~]$ radosgw-admin metadata list
[
    "bucket",
    "bucket.instance",
    "otp",
    "user"
]
~]$ radosgw-admin metadata list user
[
    "s3user"
]
~]$ radosgw-admin metadata get user:s3user
{
    "key": "user:s3user",
    "ver": {
        "tag": "_OP5oLiEF_ZURFa71qgl9xJ5",
        "ver": 1
    },
    "mtime": "2025-10-21 16:50:44.004910Z",
    "data": {
        "user_id": "s3user",
        "display_name": "S3 Testing User",
        "email": "",
        "suspended": 0,
        "max_buckets": 1000,
        "subusers": [],
        "keys": [
            {
                "user": "s3user",
                "access_key": "0WGYN1LLSQ5QLU7KA581",
                "secret_key": "vQQGkynYDEu4Nc4LQGN6SWBMo2cvBuTH6brH7Jpc"
            }
        ],
        "swift_keys": [],
        "caps": [],
        "op_mask": "read, write, delete",
        "default_placement": "",
        "default_storage_class": "",
        "placement_tags": [],
        "bucket_quota": {
            "enabled": false,
            "check_on_raw": false,
            "max_size": -1,
            "max_size_kb": 0,
            "max_objects": -1
        },
        "user_quota": {
            "enabled": false,
            "check_on_raw": false,
            "max_size": -1,
            "max_size_kb": 0,
            "max_objects": -1
        },
        "temp_url_keys": [],
        "type": "rgw",
        "mfa_ids": [],
        "attrs": []
    }
}
~]$ radosgw-admin metadata list bucket
[
    "images",
    "images1",
    "images2",
    "imagess"
]
```
```shell
~]$ rados -p default.rgw.meta -N users.uid ls
s3user
s3user.buckets
~]$ rados -p default.rgw.meta -N users.uid listomapkeys  s3user.buckets
images
images1
images2
imagess
~]$ rados -p default.rgw.meta -N users.uid getomapval  s3user.buckets   images image_bucket
Writing to image_bucket
~]$ ceph-dencoder import image_bucket type cls_user_bucket_entry decode dump_json
{
    "bucket": {
        "name": "images",
        "marker": "341ed5a0-d53a-46ef-b9d0-eeb64b8bf21b.5970.1",
        "bucket_id": "341ed5a0-d53a-46ef-b9d0-eeb64b8bf21b.5970.1"
    },
    "size": 465,
    "size_rounded": 4096,
    "creation_time": "2025-10-21 17:14:36.068004Z",
    "count": 1,
    "user_stats_sync": "true"
}
~]$ rados -p default.rgw.buckets.index ls
.dir.341ed5a0-d53a-46ef-b9d0-eeb64b8bf21b.5970.4
.dir.341ed5a0-d53a-46ef-b9d0-eeb64b8bf21b.5970.1
.dir.341ed5a0-d53a-46ef-b9d0-eeb64b8bf21b.5970.3
.dir.341ed5a0-d53a-46ef-b9d0-eeb64b8bf21b.5970.5
[cephadm@ceph-admin ~]$ rados -p default.rgw.buckets.index listomapkeys .dir.341ed5a0-d53a-46ef-b9d0-eeb64b8bf21b.5970.4
[cephadm@ceph-admin ~]$ rados -p default.rgw.buckets.index listomapkeys .dir.341ed5a0-d53a-46ef-b9d0-eeb64b8bf21b.5970.5
[cephadm@ceph-admin ~]$ rados -p default.rgw.buckets.index listomapkeys .dir.341ed5a0-d53a-46ef-b9d0-eeb64b8bf21b.5970.1
linux/fstab.txt
~]$ rados -p default.rgw.buckets.index getomapval .dir.341ed5a0-d53a-46ef-b9d0-eeb64b8bf21b.5970.1 linux/fstab.txt object_key
~]$ ceph-dencoder type rgw_bucket_dir_entry import object_key decode dump_json
{
    "name": "linux/fstab.txt",
    "instance": "",
    "ver": {
        "pool": 10,
        "epoch": 4
    },
    "locator": "",
    "exists": "true",
    "meta": {
        "category": 1,
        "size": 465,
        "mtime": "2025-10-22 01:31:57.034413Z",
        "etag": "6e2d4f8e7d8bd64d7de48e79b941c2f3",
        "storage_class": "STANDARD",
        "owner": "s3user",
        "owner_display_name": "S3 Testing User",
        "content_type": "text/plain",
        "accounted_size": 465,
        "user_data": "",
        "appendable": "false"
    },
    "tag": "341ed5a0-d53a-46ef-b9d0-eeb64b8bf21b.16028.73",
    "flags": 0,
    "pending_map": [],
    "versioned_epoch": 0
}
```
```shell
~]$ rados -p default.rgw.buckets.data ls
341ed5a0-d53a-46ef-b9d0-eeb64b8bf21b.5970.3_root/.cshrc
341ed5a0-d53a-46ef-b9d0-eeb64b8bf21b.5970.3_root/.tcshrc
341ed5a0-d53a-46ef-b9d0-eeb64b8bf21b.5970.3_root/.rnd
341ed5a0-d53a-46ef-b9d0-eeb64b8bf21b.5970.3_root/.bash_history
341ed5a0-d53a-46ef-b9d0-eeb64b8bf21b.5970.3_root/.bash_profile
341ed5a0-d53a-46ef-b9d0-eeb64b8bf21b.5970.3_linux/myfs
341ed5a0-d53a-46ef-b9d0-eeb64b8bf21b.5970.3_root/.viminfo
341ed5a0-d53a-46ef-b9d0-eeb64b8bf21b.5970.3_root/.s3cfg
341ed5a0-d53a-46ef-b9d0-eeb64b8bf21b.5970.1_linux/fstab.txt
341ed5a0-d53a-46ef-b9d0-eeb64b8bf21b.5970.3_root/.bash_logout
341ed5a0-d53a-46ef-b9d0-eeb64b8bf21b.5970.3_root/.bashrc
~]$ rados -p default.rgw.buckets.data listxattr 341ed5a0-d53a-46ef-b9d0-eeb64b8bf21b.5970.1_linux/fstab.txt
user.rgw.acl
user.rgw.content_type
user.rgw.etag
user.rgw.idtag
user.rgw.manifest
user.rgw.pg_ver
user.rgw.source_zone
user.rgw.storage_class
user.rgw.tail_tag
user.rgw.x-amz-content-sha256
user.rgw.x-amz-date
user.rgw.x-amz-meta-s3cmd-attrs
~]$ rados -p default.rgw.buckets.data getxattr 341ed5a0-d53a-46ef-b9d0-eeb64b8bf21b.5970.1_linux/fstab.txt  user.rgw.manifest > fstab.txt
~]$ ceph-dencoder type RGWObjManifest import fstab.txt decode dump_json
```


