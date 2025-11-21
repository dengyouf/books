# CephFS文件系统

文件系统主要用于多客户端操作同一个文件，

## 初始化 CephFS 文件系统
```shell
# 创建元数据池（Metadata Pool）
~]$ ceph osd pool create cephfs-metadata 64 64
pool 'cephfs-metadata' created
# 创建数据池（Data Pool）
~]$ ceph osd pool create cephfs-data  128 128
pool 'cephfs-data' created
# 创建文件系统
~]$ ceph fs new cephfs cephfs-metadata cephfs-data
# 查看文件系统状态
~]$ ceph fs status
cephfs - 0 clients
======
+------+--------+-------------+---------------+-------+-------+
| Rank | State  |     MDS     |    Activity   |  dns  |  inos |
+------+--------+-------------+---------------+-------+-------+
|  0   | active | ceph-node01 | Reqs:    0 /s |   10  |   13  |
+------+--------+-------------+---------------+-------+-------+
+-----------------+----------+-------+-------+
|       Pool      |   type   |  used | avail |
+-----------------+----------+-------+-------+
| cephfs-metadata | metadata | 1536k | 73.0G |
|   cephfs-data   |   data   |    0  | 73.0G |
+-----------------+----------+-------+-------+
+-------------+
| Standby MDS |
+-------------+
| ceph-node02 |
+-------------+
MDS version: ceph version 14.2.22 (ca74598065096e6fcbd8433c8779a2be0c889351) nautilus (stable)
```

## 挂载Cephfs系统
### 2.Ceph 原生客户端
#### 2.1.准备认证文件
```shell
~]$ ceph auth get-or-create client.fsclient mon 'allow r' mds 'allow rw' osd 'allow rwx pool=cephfs-data' -o ceph.client.fsclient.keyring
~]$ ceph auth get-key client.fsclient -o fsclient.key
#复制到客户机上
~]$ scp ceph.client.fsclient.keyring fsclient.key root@192.168.1.109:/etc/ceph
```
#### 2.2 挂载cephFS
```shell
 ~]# mount -t ceph ceph-node01:6789,ceph-node02:6789,ceph-node03:6789:/ /mnt -o name=fsclient,secretfile=/etc/ceph/fsclient.key
[root@ceph-client01 ~]# df -h
Filesystem                                                  Size  Used Avail Use% Mounted on
...
192.168.1.101:6789,192.168.1.102:6789,192.168.1.103:6789:/   74G     0   74G   0% /mnt
~]# cd /mnt/
mnt]# touch 1111
~]# umount /mnt
~]# mkdir /cephdata
~]# mount -t ceph ceph-node01:6789,ceph-node02:6789,ceph-node03:6789:/ /cephdata/ -o name=fsclient,secretfile=/etc/ceph/fsclient.key
~]# ls /cephdata/
```
```shell
vim /etc/fstab
ceph-node01,ceph-node02,ceph-node03:/  /cephdata  ceph  name=fsclient,secretfile=/etc/ceph/fsclient.key,_netdev,noatime  0  0
```
### 3.FUSE实践

对于某些操作系统，本身没有支持ceph内核模块，此时如果还需要使用cephfs，可以通过fuse方式来实现。FUSE全称FileSystem in Usespace。用于飞特权用户能够无需操作内核而创建文件系统

#### 3.1。安装ceh-fuse软件包

```shell
~]# yum install ceph-fuse ceph-common
```
#### 3.2.获取授权文件
```shell
~]$ ceph auth get-or-create client.fsclient mon 'allow r' mds 'allow rw' osd 'allow rwx pool=cephfs-data' -o ceph.client.fsclient.keyring
~]$ ceph auth get-key client.fsclient -o fsclient.key
#复制到客户机上
~]$ scp ceph.client.fsclient.keyring fsclient.key root@192.168.1.109:/etc/ceph
```

#### 3.3.挂载cephfs

```shell
~]# ceph-fuse -n client.fsclient -m ceph-node01:6789,ceph-node02:6789,ceph-node03:6789 /mnt
ceph-fuse[15672]: starting ceph client2025-10-22 11:23:26.513 7f96ae88ff80 -1 init, newargv = 0x557c4b0e6a70 newargc=9

ceph-fuse[15672]: starting fuse
~]# df -h
Filesystem               Size  Used Avail Use% Mounted on
...
ceph-fuse                 74G     0   74G   0% /mnt
```




