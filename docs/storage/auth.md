# 认证管理

ceph 作为一个分布式存储系统，支持对象存储、快设备和文件系统，为了在网络传输中繁殖数据被篡改，做到较高程度的安全性，加入CephX加密认证协议。目的是为了在客户端和管理端之前实现身份识别，数据加密、验证等。ceph集群默认开启了cephX协议

```shell
ceph-cluster]$ cat ceph.conf
[global]
...
auth_cluster_required = cephx
auth_service_required = cephx
auth_client_required = cephx
```

## 认证和授权

ceph系统中，所有的元数据都保存在mon节点的ceph-mon进程中，mon保存了系统中重要的认证相关元数据，下面是每个用户key以及权限，格式如下：
```shell
~]$ ceph auth ls
client.admin
	key: AQD0KfdoGLBlDhAARnjOcCCD2+J+ZHhJU8F1Aw==
	caps: [mds] allow *
	caps: [mgr] allow *
	caps: [mon] allow *
	caps: [osd] allow *
```
对于ceph认证和授权来说，主要涉及三个内容，ceph用户，资源权限，用户授权
- ceph用户必须拥有执行权限才能执行ceph的管理命令
- ceph用户需要拥有存储池的访问权限才能到ceph中读写数据

**1.用户** ceph创建出来的用户

**2.授权** 将某些资源的使用权利叫个特定的用户`allow`

**3.权限**
- r
- w
- x
- class-read
- class-write
- profile osd

## 用户管理

### 1.列出用户
```shell
~]$ ceph auth list
```
### 2.检索用户
```shell
~]$ ceph auth get client.admin
[client.admin]
	key = AQD0KfdoGLBlDhAARnjOcC4X2+J+ZHhJU8F1Aw==
	caps mds = "allow *"
	caps mgr = "allow *"
	caps mon = "allow *"
	caps osd = "allow *"
exported keyring for client.admin
~]$ ceph auth export client.admin
[client.admin]
	key = AQD0KfdoGLBlDhAARnjOcC4X2+J+ZHhJU8F1Aw==
	caps mds = "allow *"
	caps mgr = "allow *"
	caps mon = "allow *"
	caps osd = "allow *"
export auth(key=AQD0KfdoGLBlDhAARnjOcC4X2+J+ZHhJU8F1Aw==)
```
### 3.列出用户私钥
```shell
~]$ ceph auth print-key client.admin
AQD0KfdoGLBlDhAARnjOcC4X2+J+ZHhJU8F1Aw==
```
### 4.添加用户
```shell
# ceph auth add: 创建用户、生成密钥并添加指定caps
~]$ ceph auth add client.testuser mon 'allow r' osd 'allow rw pool=rbdpool'
added key for client.testuser
~]$ ceph auth get client.testuser
[client.testuser]
	key = AQA2XPdodzX7DRAAkXjpN2u/pUlLqrGMIG2r7w==
	caps mon = "allow r"
	caps osd = "allow rw pool=rbdpool"
exported keyring for client.testuser
#ceph auth get-or-create: 创建用户并返回密钥文件格式的密钥信息，用户存在时返回密钥信息
~]$ ceph auth get-or-create  client.testuser mon 'allow rw' osd 'allow rw pool=rbdpool'
[client.testuser]
	key = AQA2XPdodzX7DRAAkXjpN2u/pUlLqrGMIG2r7w==
#ceph auth get-or-create-key: 创建用户并返回密钥信息，用户存在时返回密钥信息
~]$ ceph auth get-or-create-key  client.testuser mon 'allow rw' osd 'allow rw pool=rbdpool'
AQA2XPdodzX7DRAAkXjpN2u/pUlLqrGMIG2r7w==
```
### 5.导入/导出用户
```shell
# 导出
~]$ ceph auth export client.testuser > testuser.file
# 导入
~]$ ceph auth import -i testuser.file
imported keyring
```
### 6.更新用户
```shell
# 替换用户权限,不是追加，是整体替换
~]$ ceph auth caps client.testuser mon 'allow rw' osd 'allow rw pool=rbdpool'
updated caps for client.testuser
```
### 7.删除用户
```shell
~]$ ceph auth del client.testuser
```

## Keyring

密钥环文件是存储机密、密码、密钥、证书并使他们可应用应用程序的组件的集合。密钥环文件存储一个或多个Ceph身份验证密钥以及可能的相关功能规范

访问Ceph集群时，客户端默认会于本地查看密钥环，只有认证成功的对象才可以正常使用，默认的密钥环有下面四个：

- `/etc/ceph/cluster-name.user-name.keyring`: 单用户
- `/etc/ceph/cluster.keyring`：多用户
- `/etc/ceph/keyring`
- `/etc/ceph/keyring.bin`
```shell
~]$ ls /etc/ceph/ -l
总用量 12
-rw-r-----+ 1 root root 151 10月 21 14:45 ceph.client.admin.keyring
-rw-r--r--  1 root root 323 10月 21 14:45 ceph.conf
-rw-r--r--  1 root root  92 6月  30 2021 rbdmap
-rw-------  1 root root   0 10月 21 14:45 tmpklVbo9
```
### keyring管理
#### 添加keyring

- 方式1:先创建用户，在导出keyring文件
```shell
# ceph auth add
~]$ ceph  auth get-or-create client.kube mon 'allow r' osd 'allow * pool=kube'
[client.kube]
	key = AQDGYfdoWGEBFxAAZCGy/1RktgAWmuyYKTkhow==
# ceph auth get -o
~]$ ceph auth get client.kube -o ceph.client.kube.keyring
exported keyring for client.kube
~]$ cat ceph.client.kube.keyring
[client.kube]
	key = AQDGYfdoWGEBFxAAZCGy/1RktgAWmuyYKTkhow==
	caps mon = "allow r"
	caps osd = "allow * pool=kube"
```
- 方式2:创建keyring，然后导入集群
```shell
#ceph-authtool
~]$ ceph-authtool --create-keyring ceph.cluster.keyring
#ceph auth add -i 合并多用用户密钥环文件
~]$ ceph-authtool ceph.cluster.keyring --import-keyring ceph.client.kube.keyring
~]$ ceph-authtool ceph.cluster.keyring --import-keyring ceph-cluster/ceph.client.admin.keyring
~]$ cat ceph.cluster.keyring
[client.admin]
	key = AQD0KfdoGLBlDhAARnjOcC4X2+J+ZHhJU8F1Aw==
	caps mds = "allow *"
	caps mgr = "allow *"
	caps mon = "allow *"
	caps osd = "allow *"
[client.kube]
	key = AQDGYfdoWGEBFxAAZCGy/1RktgAWmuyYKTkhow==
	caps mon = "allow r"
	caps osd = "allow * pool=kube"
```
