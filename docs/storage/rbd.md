# RADOS Block Device块设备

RBD（RADOS Block Device） 是 Ceph 提供的 块存储接口，它基于 Ceph 的分布式对象存储层（RADOS）实现。
简单说，它可以把 Ceph 的对象存储池抽象成「块设备」给主机使用，就像一块虚拟磁盘一样。

常用于：

- 虚拟机磁盘（比如：OpenStack、KVM）
- 容器存储（Kubernetes 的 RBD/Ceph CSI）
- 数据库存储卷

## RBD操作逻辑

rbd接口在ceph环境创建后，就在服务端自动提供了，客户端基于librdb库，可讲rados存储集群用作块设备，具体使用逻辑如下：

- 1.创建专用rbd存储池
- 2.对存储池启用rdb功能
- 3.对存储池执行环境初始化
- 4.基于存储池创建磁盘镜像

```shell
# 创建专用rbd存储池
~]$ ceph osd pool create rbdpool 8 8
# 对存储池启用rdb功能
~]$ ceph osd pool application enable rbdpool rbd
enabled application 'rbd' on pool 'rbdpool'
# 对存储池执行环境初始化
~]$ rbd pool init -p rbdpool
# 基于存储池创建磁盘镜
~]$ rbd create node-img1 --size 1G --pool rbdpool
[cephadm@ceph-admin ~]$ rbd pool stats rbdpool
Total Images: 1
Total Snapshots: 0
Provisioned Size: 1 GiB
# 查看镜像信息
~]$ rbd info --image node-img1 --pool rbdpool
rbd image 'node-img1':
	size 1 GiB in 256 objects
	order 22 (4 MiB objects)
	snapshot_count: 0
	id: 3b4e90cea1f4
	block_name_prefix: rbd_data.3b4e90cea1f4
	format: 2
	features: layering, exclusive-lock, object-map, fast-diff, deep-flatten
	op_features:
	flags:
	create_timestamp: Tue Oct 21 18:59:13 2025
	access_timestamp: Tue Oct 21 18:59:13 2025
	modify_timestamp: Tue Oct 21 18:59:13 2025
```

| 镜像属性           | 说明      |
|----------------|------------------------------------------|
| layering       | 分层克隆机制      |
| exclusive-lock | 排他锁，仅能一个客户端访问当前image  |
| striping       | 是否支持数据对象间的数据条带化     |
| object-map     | 对象位图，用户加速导入导出已经容量统计等操作，依赖排他锁  |           |
| fast-diff      | 快照定制机制，快速比对数据差异，便于快照管理，依赖对象位图 |           |
| deep-flatten   | 数据处理机制，解除父子image以及快照的依赖关系                |
| journaling     | 磁盘日志机制，将image的所有修改进行日志化，便于异地备份，依赖排他所     |
| data-pool      | 是否支持将image的数据对象存储于纠删码池，主要用于将元数据和数据放置于不同的存储池 |

```shell
# 删除镜像属性
~]$ rbd feature disable rbdpool/node-img1 object-map fast-diff deep-flatten
~]$ rbd info --image node-img1 --pool rbdpool
rbd image 'node-img1':
	size 1 GiB in 256 objects
	order 22 (4 MiB objects)
	snapshot_count: 0
	id: 3b4e90cea1f4
	block_name_prefix: rbd_data.3b4e90cea1f4
	format: 2
	features: layering, exclusive-lock
	op_features:
	flags:
	create_timestamp: Tue Oct 21 18:59:13 2025
	access_timestamp: Tue Oct 21 18:59:13 2025
	modify_timestamp: Tue Oct 21 18:59:13 2025
~]$ rbd feature enable rbdpool/node-img1 object-map fast-diff
~]$ rbd info --image node-img1 --pool rbdpool
rbd image 'node-img1':
	size 1 GiB in 256 objects
	order 22 (4 MiB objects)
	snapshot_count: 0
	id: 3b4e90cea1f4
	block_name_prefix: rbd_data.3b4e90cea1f4
	format: 2
	features: layering, exclusive-lock, object-map, fast-diff
	op_features:
	flags: object map invalid, fast diff invalid
	create_timestamp: Tue Oct 21 18:59:13 2025
	access_timestamp: Tue Oct 21 18:59:13 2025
	modify_timestamp: Tue Oct 21 18:59:13 2025
```

## 镜像使用

- 初始化存储池后，创建image
- 最好禁用 object-map fast-diff deep-flatten 等属性
- 需要直接于monitor角色进行通信，如果启用认证，还需要指定用户名和keyring
- 使用rdb的map名利、进行磁盘文件的映射

### 1.准备rbd镜像卷

```shell
# 准备块存储
~]$ ceph osd pool create kube 16 16
pool 'kube' created
~]$ ceph osd pool application enable  kube rbd
~]$ rbd pool init -p kube
~]$ rbd create vol-01 --size 1G --pool kube
~]$ rbd feature disable kube/vol-01 object-map fast-diff deep-flatten
~]$ rbd feature disable kube/vol-01 object-map fast-diff deep-flatten
[cephadm@ceph-admin ~]$ rbd info kube/vol-01
rbd image 'vol-01':
	size 1 GiB in 256 objects
	order 22 (4 MiB objects)
	snapshot_count: 0
	id: 150def6887b3
	block_name_prefix: rbd_data.150def6887b3
	format: 2
	features: layering, exclusive-lock
	op_features:
	flags:
	create_timestamp: Tue Oct 21 19:58:31 2025
	access_timestamp: Tue Oct 21 19:58:31 2025
	modify_timestamp: Tue Oct 21 19:58:31 2025
 Warnick <patience@newdream.net>
author:         Yehuda Sadeh <yehuda@hq.newdream.net>
author:         Sage We# 客户端主机安装ceph-common
```
### 2.客户端主机安装ceph
```shell
~]# yum install https://mirrors.aliyun.com/ceph/rpm-nautilus/el7/noarch/ceph-release-1-1.el7.noarch.rpm
~]# yum install -y ceph-common
~]# modinfo ceph
filename:       /lib/modules/3.10.0-862.el7.x86_64/kernel/fs/ceph/ceph.ko.xz
license:        GPL
description:    Ceph filesystem for Linux
author:         Patienceil <sage@newdream.net>
alias:          fs-ceph
retpoline:      Y
rhelversion:    7.5
srcversion:     FD277B552FF7AC92D1E3117
depends:        libceph
intree:         Y
vermagic:       3.10.0-862.el7.x86_64 SMP mod_unload modversions
signer:         CentOS Linux kernel signing key
sig_key:        3A:F3:CE:8A:74:69:6E:F1:BD:0F:37:E5:52:62:7B:71:09:E3:2B:96
sig_hashalgo:   sha256
```
### 3.提供认证信息给客户端
```shell
# 确认用户权限
~]$ ceph auth get client.kube|tee  ceph.client.kube.keyring
exported keyring for client.kube
[client.kube]
	key = AQDGYfdoWGEBFxAAZCGy/1RktgAWmuyYKTkhow==
	caps mon = "allow r"
	caps osd = "allow * pool=kube"
# scp 认证文件到客户机
~]$ scp ceph.client.kube.keyring ceph-cluster/ceph.conf root@192.168.1.109:/etc/ceph/
# 客户端验证通过
~]# ceph -s --user kube
  cluster:
    id:     d901ea94-de1d-4814-9f97-6f7ebd4329dd
    health: HEALTH_OK

  services:
    mon: 3 daemons, quorum ceph-node01,ceph-node02,ceph-node03 (age 5h)
    mgr: ceph-node01(active, since 5h), standbys: ceph-node02
    mds:  2 up:standby
    osd: 6 osds: 6 up (since 3h), 6 in (since 3h)
    rgw: 1 daemon active (ceph-node03)

  task status:

  data:
    pools:   5 pools, 144 pgs
    objects: 191 objects, 1.2 KiB
    usage:   6.1 GiB used, 234 GiB / 240 GiB avail
    pgs:     144 active+clean
```
### 4.挂载使用
```shell
# 映射远程ceph磁盘到本地
~]# rbd --user kube map kube/vol-01
~]# lsblk
NAME            MAJ:MIN RM   SIZE RO TYPE MOUNTPOINT
sr0              11:0    1  1024M  0 rom
vda             252:0    0   200G  0 disk
├─vda1          252:1    0     1G  0 part /boot
└─vda2          252:2    0   199G  0 part
  ├─centos-root 253:0    0 195.1G  0 lvm  /
  └─centos-swap 253:1    0   3.9G  0 lvm  [SWAP]
rbd0            251:0    0     1G  0 disk
~]# rbd showmapped
id pool namespace image  snap device
0  kube           vol-01 -    /dev/rbd0
# 格式化，挂载使用
~]# mkfs.ext4 /dev/rbd0
~]# mount /dev/rbd0 /mnt
~]# touch /mnt/rbddata.txt
```
### 5.卸载盘
```shell
~]# umount /dev/rbd0
~]# rbd --user kube unmap kube/vol-01
~]# rbd showmapped
```

## 容量管理

```shell
~]$ rbd info kube/vol-01
rbd image 'vol-01':
	size 1 GiB in 256 objects
	order 22 (4 MiB objects)
	snapshot_count: 0
	id: 150def6887b3
	block_name_prefix: rbd_data.150def6887b3
	format: 2
	features: layering, exclusive-lock
	op_features:
	flags:
	create_timestamp: Tue Oct 21 19:58:31 2025
	access_timestamp: Tue Oct 21 19:58:31 2025
	modify_timestamp: Tue Oct 21 19:58:31 2025
```
### 1.调整image大小

```shell
 ~]$ rbd resize kube/vol-01 --size 5G
Resizing image: 100% complete...done.
[cephadm@ceph-admin ~]$ rbd info kube/vol-01
rbd image 'vol-01':
	size 5 GiB in 1280 objects
	order 22 (4 MiB objects)
	snapshot_count: 0
	id: 150def6887b3
	block_name_prefix: rbd_data.150def6887b3
	format: 2
	features: layering, exclusive-lock
	op_features:
	flags:
	create_timestamp: Tue Oct 21 19:58:31 2025
	access_timestamp: Tue Oct 21 19:58:31 2025
	modify_timestamp: Tue Oct 21 19:58:31 2025
```
```shell
~]$ rbd resize kube/vol-01 --size 3G --allow-shrink
Resizing image: 100% complete...done.
[cephadm@ceph-admin ~]$ rbd info kube/vol-01
rbd image 'vol-01':
	size 3 GiB in 768 objects
	order 22 (4 MiB objects)
	snapshot_count: 0
	id: 150def6887b3
	block_name_prefix: rbd_data.150def6887b3
	format: 2
	features: layering, exclusive-lock
	op_features:
	flags:
	create_timestamp: Tue Oct 21 19:58:31 2025
	access_timestamp: Tue Oct 21 19:58:31 2025
	modify_timestamp: Tue Oct 21 19:58:31 2025
```
### 2.扩容后挂载
```shell
rbd --user kube map kube/vol-01
mount /dev/rbd0 /mnt
resize2fs /dev/rbd0
```
### 3.删除镜像

```shell
~]$ rbd --pool kube ls  -l
NAME   SIZE  PARENT FMT PROT LOCK
vol-01 3 GiB          2
# 垃圾桶功能，可恢复
~]$ rbd remove kube/vol-01
~]$ rbd trash move kube/vol-01
~]$ rbd --pool kube ls  -l
~]$ rbd trash ls -p kube
150def6887b3 vol-01
# 恢复
~]$ rbd trash restore --pool kube --image vol-01 --image-id 150def6887b3
[cephadm@ceph-admin ~]$ rbd --pool kube ls  -l
NAME   SIZE  PARENT FMT PROT LOCK
vol-01 3 GiB          2
```
```shell
# 彻底删除
~]$ rbd remove kube/vol-01
```

## 快照管理

RBD支持快照技术，借助快照可以保留image的状态历史。Ceph还支持快照分层机制，从而实现快速克隆VM映像。

### 1.创建快照
创建快照之前，应停止image上的IO操作，且image上存在文件系统是，还要确保其处于一致状态
```shell
rbd snap create [--pool <pool>] --image <image> --snap <snap>
rbd snap create [<pool-name>/]<image-name>@<snapshot-name>
```

### 2.列出快照

```shell
rbd snap ls [--pool <pool>] --image <image> ...
```

### 3.回滚快照
使用当前快照中的数据重写当前版本的image，回滚时间随着数据打大小增加而延长
```shell
rbd snap rollback [--pool <pool>] --image <image> --snap <snap> ...
```
### 4.限制快照数量
快照数量过多时，会导致镜像山惯有数据的第一次修改时的IO压力恶化
```shell
# 限制
rbd snap limit set [--pool <pool>] [--image <image>] --limit int
# 解除
rbd snap limit clear [--pool <pool>] [--image <image>]
```
### 5.删除快照
Ceph OSD会以一步方式删除数据，因此删除快照不会立即释放磁盘空间
```shell
rbd snap rm [--pool <pool>] --image <image> --snap <snap> ... [--force]
```
### 6.清理快照
删除一个镜像的所有快照，可以使用 purge
```shell
rbd snap purge  [--pool <pool>] --image <image>
```
### 7.快照实战

- 准备镜像

```shell
~]$ rbd create vol01 --size 2G --pool kube
~]$ rbd feature disable kube/vol01 object-map fast-diff deep-flatten
~]$  rbd info kube/vol01
rbd image 'vol01':
	size 2 GiB in 512 objects
	order 22 (4 MiB objects)
	snapshot_count: 0
	id: 15a059e5a259
	block_name_prefix: rbd_data.15a059e5a259
	format: 2
	features: layering, exclusive-lock
	op_features:
	flags:
	create_timestamp: Tue Oct 21 20:58:40 2025
	access_timestamp: Tue Oct 21 20:58:40 2025
	modify_timestamp: Tue Oct 21 20:58:40 2025
```

- 挂载产生数据

```shell
~]# rbd --user kube map kube/vol01
~]# mkfs.ext4 /dev/rbd0
~]# mount /dev/rbd0 /mnt
~]# cp /etc/fstab /mnt/
~]# echo "1111" > /mnt/test.txt
~]# ll /mnt/
total 24
-rw-r--r-- 1 root root   465 Oct 21 21:01 fstab
drwx------ 2 root root 16384 Oct 21 21:00 lost+found
-rw-r--r-- 1 root root     5 Oct 21 21:01 test.txt
```

- 创建快照1

```shell
~]$ rbd snap create kube/vol01@vol01-1
~]$ rbd snap ls kube/vol01
SNAPID NAME    SIZE  PROTECTED TIMESTAMP
     4 vol01-1 2 GiB           Tue Oct 21 21:03:54 2025
```

- 删除数据

```shell
~]# rm -rf /mnt/*
```

- 恢复数据

```shell
# 卸载盘
~]# umount /dev/rbd0
~]# rbd --user kube unmap kube/vol01
# 恢复快照
 ~]$ rbd snap rollback kube/vol01@vol01-1
# 挂载盘，检查数据是否恢复
~]# rbd --user kube map kube/vol01
/dev/rbd0
~]# mount /dev/rbd0 /mnt
~]# ls /mnt/
fstab  lost+found  test.txt
```

- 删除快照

```shell
~]$ rbd snap list --pool kube --image vol01
SNAPID NAME    SIZE  PROTECTED TIMESTAMP
     4 vol01-1 2 GiB           Tue Oct 21 21:03:54 2025
     5 vol01-2 2 GiB           Tue Oct 21 21:06:08 2025
~]$ rbd snap rm kube/vol01@vol01-2
```
- 快照数量限制

```shell
~]$ rbd snap limit set kube/vol01 --limit 5
~]$ rbd snap create kube/vol01@vol01-2
[cephadm@ceph-admin ~]$ rbd snap create kube/vol01@vol01-3
[cephadm@ceph-admin ~]$ rbd snap create kube/vol01@vol01-4
[cephadm@ceph-admin ~]$ rbd snap create kube/vol01@vol01-5
[cephadm@ceph-admin ~]$ rbd snap create kube/vol01@vol01-6
rbd: failed to create snapshot: (122) Disk quota exceeded
~]$ rbd snap limit clear kube/vol01
~]$ rbd snap create kube/vol01@vol01-6
```

- 清理所有快照

```shell
~]$ rbd snap purge kube/vol01
Removing all snapshots: 100% complete...done.
```

## 快照分层

ceph支持在一个块设备快照的基础上创建一个或者多个COW或COR类型的克隆，类似于Vmware虚拟机的快速克隆模式。基于一个base镜像(保护镜像)快速克隆出来新的镜像。这就是快照分层技术，支持跨存储池。

### 1.保护快照(protect)
```shell
rbd snap protect [--pool <pool>] --image <image> --snap <snap> --dest-pool <dest-pool> ...
```
### 2.克隆快照

```shell
rbd clone [<pool-name>/]<image-name>@<snapshot-name> [<pool-name>/<image-name>]
```
### 3.列出快照的子项
```shell
rbd children  [--pool <pool>] --image <image> --snap <snap>
```
### 4.展平克隆
```shell
rbd flatten [--pool <pool>] --image <image> --snap <snap>
```

### 5.分层实践

- 已有rbd卷

```shell
~]$ rbd ls  --pool kube -l
NAME  SIZE  PARENT FMT PROT LOCK
vol01 2 GiB          2
~]# df -h
Filesystem               Size  Used Avail Use% Mounted on
/dev/mapper/centos-root  196G  1.4G  194G   1% /
devtmpfs                 1.9G     0  1.9G   0% /dev
tmpfs                    1.9G     0  1.9G   0% /dev/shm
tmpfs                    1.9G   17M  1.9G   1% /run
tmpfs                    1.9G     0  1.9G   0% /sys/fs/cgroup
/dev/vda1               1014M  142M  873M  14% /boot
tmpfs                    379M     0  379M   0% /run/user/0
/dev/rbd0                2.0G  6.1M  1.8G   1% /mnt
~]# ls /mnt/
fstab  lost+found  test.txt
```
- 定制基础快照

```shell
~]$ rbd snap create kube/vol01@basetp01
~]$ rbd snap ls kube/vol01
SNAPID NAME     SIZE  PROTECTED TIMESTAMP
    20 basetp01 2 GiB           Tue Oct 21 21:40:35 2025
```
- 保护快照

```shell
~]$ rbd snap protect kube/vol01@basetp01
~]$ rbd snap ls kube/vol01
SNAPID NAME     SIZE  PROTECTED TIMESTAMP
    20 basetp01 2 GiB yes       Tue Oct 21 21:40:35 2025
```

- 基于基础快照克隆子快照

```shell
~]$ rbd clone kube/vol01@basetp01 kube/image01
~]$ rbd clone kube/vol01@basetp01 kube/image02
~]$ rbd ls --pool kube -l
NAME           SIZE  PARENT              FMT PROT LOCK
image01        2 GiB kube/vol01@basetp01   2
image02        2 GiB kube/vol01@basetp01   2
vol01          2 GiB                       2
vol01@basetp01 2 GiB                       2 yes
```
- 查看子快照

```shell
~]$ rbd children kube/vol01@basetp01
kube/image01
kube/image02
```
- 挂载子快照

```shell
~]# rbd --user kube --pool kube ls
image01
image02
vol01
~]# rbd --user kube map kube/image01
/dev/rbd1
~]# rbd --user kube map kube/image02
/dev/rbd2
~]# mkdir /data/image01 -pv
~]# mkdir /data/image02 -pv
~]# mount /dev/rdb1 /data/image01
~]# echo "rbd1 image01" >> /data/image01/image.txt
~]# ll /data/image01/
total 28
-rw-r--r-- 1 root root   465 Oct 21 21:01 fstab
-rw-r--r-- 1 root root    13 Oct 21 21:50 image.txt
drwx------ 2 root root 16384 Oct 21 21:00 lost+found
-rw-r--r-- 1 root root     5 Oct 21 21:01 test.txt
~]# mount /dev/rdb2 /data/image02
~]# echo "rbd1 image02" >> /data/image02/image02.txt
~]# ll /data/image02
total 28
-rw-r--r-- 1 root root   465 Oct 21 21:01 fstab
-rw-r--r-- 1 root root    13 Oct 21 21:51 image02.txt
drwx------ 2 root root 16384 Oct 21 21:00 lost+found
-rw-r--r-- 1 root root     5 Oct 21 21:01 test.txt
```

- 展平子快照

克隆的镜像会保留对父镜像的引用，展平则会完成复制父快照的的数据，从而成为一个独立的不对父镜像有依赖的镜像。
```
~]$ rbd flatten kube/image01
Image flatten: 100% complete...done.
~]$ rbd flatten kube/image02
Image flatten: 100% complete...done.
```
- 此时删除基础快照对image01/image02无任何影响
```shell
~]$ rbd snap unprotect kube/vol01@basetp01
~]$ rbd snap rm kube/vol01@basetp01
Removing snap: 100% complete...done.
~]$ rbd ls --pool kube  -l
NAME    SIZE  PARENT FMT PROT LOCK
image01 2 GiB          2
image02 2 GiB          2
vol01   2 GiB          2
```

## kvm集成ceph

前提
- 安装kvm环境

- 安装ceph环境

### 1.准备kvm专属pool

```shell
~]$ ceph osd pool create kvmpool 16 16
pool 'kvmpool' created
~]$ ceph osd pool application enable  kvmpool rbd
~]$ rbd pool init -p kvmpool
```

### 2.专属认证权限设定

```shell
~]$ ceph auth get-or-create client.kvmuser mon 'allow r' osd 'allow class-read object_prefix rbd_chidren, allow rwx pool=kvmpool'
[client.kvmuser]
	key = AQAOl/doomzVKBAAdrBMHIXbar8r4jxHyHDiTg==
~]$ ceph auth get client.kvmuser -o ceph.client.kvmuser.keyring
exported keyring for client.kvmuser
~]$ cat ceph.client.kvmuser.keyring
[client.kvmuser]
	key = AQAOl/doomzVKBAAdrBMHIXbar8r4jxHyHDiTg==
	caps mon = "allow r"
	caps osd = "allow class-read object_prefix rbd_chidren, allow rwx pool=kvmpool"
```
### 3.传递认证信息到kvm主机

```shell
~]$ scp ceph.client.kvmuser.keyring ceph-cluster/{ceph.conf,ceph.client.admin.keyring} root@192.168.1.109:/etc/ceph
# kvm主机执行
~]# ceph --user kvmuser -s
  cluster:
    id:     d901ea94-de1d-4814-9f97-6f7ebd4329dd
    health: HEALTH_OK

  services:
    mon: 3 daemons, quorum ceph-node01,ceph-node02,ceph-node03 (age 7h)
    mgr: ceph-node01(active, since 7h), standbys: ceph-node02
    mds:  2 up:standby
    osd: 6 osds: 6 up (since 6h), 6 in (since 6h)
    rgw: 1 daemon active (ceph-node03)

  task status:

  data:
    pools:   6 pools, 160 pgs
    objects: 238 objects, 135 MiB
    usage:   6.5 GiB used, 234 GiB / 240 GiB avail
    pgs:     160 active+clean
```

### 4.kvm集成ceph

- 创建认证文件

```shell
~]# cat > ceph-client-kvmuser-secret.xml << 'EOF'
<secret ephemeral='no' private='no'>
    <usage type='ceph'>
        <name>client.kvmuser secret</name>
    </usage>
</secret>
EOF
~]# virsh secret-define --file ceph-client-kvmuser-secret.xml
Secret 1258b7ac-0b45-487b-8b1f-7cb3a66ab127 created
#
~]# virsh secret-set-value --secret 1258b7ac-0b45-487b-8b1f-7cb3a66ab127 --base64 $(ceph auth get-key client.kvmuser)
~]# virsh secret-list
 UUID                                  Usage
--------------------------------------------------------------------------------
 1258b7ac-0b45-487b-8b1f-7cb3a66ab127  ceph client.kvmuser secret
```

- 创建镜像

```shell
~]# qemu-img create -f rbd rbd:kvmpool/cirrors-image 2G
Formatting 'rbd:kvmpool/cirrors-image', fmt=rbd size=2147483648 cluster_size=0
~]# rbd --user kvmuser --pool kvmpool ls -l
NAME          SIZE  PARENT FMT PROT LOCK
cirrors-image 2 GiB          2
```

- 导入镜像

```shell
~# wget https://ghfast.top/https://github.com/cirros-dev/cirros/releases/download/0.4.0/cirros-0.4.0-x86_64-disk.img
~]# qemu-img info cirros-0.4.0-x86_64-disk.img
image: cirros-0.4.0-x86_64-disk.img
file format: qcow2
virtual size: 44M (46137344 bytes)
disk size: 12M
cluster_size: 65536
Format specific information:
    compat: 1.1
    lazy refcounts: false
~]# qemu-img  convert -f qcow2 -O raw cirros-0.4.0-x86_64-disk.img rbd:kvmpool/cirrors-0.4.0
~]# rbd --user kvmuser --pool kvmpool ls -l
NAME          SIZE   PARENT FMT PROT LOCK
cirrors-0.4.0 44 MiB          2
cirrors-image  2 GiB          2
```

待补充
