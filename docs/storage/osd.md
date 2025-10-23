# Object Storage 对象存储

OSD 全称 Object Storage Device，负责响应客户端请求，返回具体数据的进程，Ceph集群中一般通过专门的主机提供OSD买这个主机上的多个磁盘都可添加为OSD设备

## 命令查看
### 1.查看所有OSD的ID值
```shell
ceph osd ls
0
1
2
3
4
5
```
### 2.查看OSD概述信息
```shell
ceph osd dump
epoch 34
fsid d901ea94-de1d-4814-9f97-6f7ebd4329dd
created 2025-10-21 14:36:36.240960
modified 2025-10-21 15:00:36.907145
flags sortbitwise,recovery_deletes,purged_snapdirs,pglog_hardlimit
crush_version 13
full_ratio 0.95
backfillfull_ratio 0.9
nearfull_ratio 0.85
require_min_compat_client jewel
min_compat_client jewel
require_osd_release nautilus
pool 1 '.rgw.root' replicated size 3 min_size 2 crush_rule 0 object_hash rjenkins pg_num 32 pgp_num 32 autoscale_mode warn last_change 28 flags hashpspool stripe_width 0 application rgw
pool 2 'default.rgw.control' replicated size 3 min_size 2 crush_rule 0 object_hash rjenkins pg_num 32 pgp_num 32 autoscale_mode warn last_change 30 flags hashpspool stripe_width 0 application rgw
pool 3 'default.rgw.meta' replicated size 3 min_size 2 crush_rule 0 object_hash rjenkins pg_num 32 pgp_num 32 autoscale_mode warn last_change 32 flags hashpspool stripe_width 0 application rgw
pool 4 'default.rgw.log' replicated size 3 min_size 2 crush_rule 0 object_hash rjenkins pg_num 32 pgp_num 32 autoscale_mode warn last_change 34 flags hashpspool stripe_width 0 application rgw
max_osd 6
osd.0 up   in  weight 1 up_from 5 up_thru 32 down_at 0 last_clean_interval [0,0) [v2:192.168.1.101:6802/64857,v1:192.168.1.101:6803/64857] [v2:192.168.122.101:6800/64857,v1:192.168.122.101:6801/64857] exists,up d04abe1d-abb7-4ef9-8235-ffbfea2529cf
osd.1 up   in  weight 1 up_from 9 up_thru 32 down_at 0 last_clean_interval [0,0) [v2:192.168.1.101:6806/65311,v1:192.168.1.101:6807/65311] [v2:192.168.122.101:6804/65311,v1:192.168.122.101:6805/65311] exists,up c487e57b-68f3-4598-a1dd-2cd1ebb59d90
osd.2 up   in  weight 1 up_from 13 up_thru 32 down_at 0 last_clean_interval [0,0) [v2:192.168.1.102:6800/64246,v1:192.168.1.102:6801/64246] [v2:192.168.122.102:6800/64246,v1:192.168.122.102:6801/64246] exists,up 3134cec2-6f22-472e-8787-e18d7d77e641
osd.3 up   in  weight 1 up_from 17 up_thru 32 down_at 0 last_clean_interval [0,0) [v2:192.168.1.102:6804/64698,v1:192.168.1.102:6805/64698] [v2:192.168.122.102:6804/64698,v1:192.168.122.102:6805/64698] exists,up 6145a6c0-9916-4dfd-a04c-93e7cc460da4
osd.4 up   in  weight 1 up_from 21 up_thru 32 down_at 0 last_clean_interval [0,0) [v2:192.168.1.103:6800/64113,v1:192.168.1.103:6801/64113] [v2:192.168.122.103:6800/64113,v1:192.168.122.103:6801/64113] exists,up 1490030e-420b-493e-b817-515ef0aec597
osd.5 up   in  weight 1 up_from 25 up_thru 32 down_at 0 last_clean_interval [0,0) [v2:192.168.1.103:6804/64566,v1:192.168.1.103:6805/64566] [v2:192.168.122.103:6804/64566,v1:192.168.122.103:6805/64566] exists,up a3d688ed-4432-4d0e-b12d-d75f82f70b52
```

### 3.osd相信状态信息
```shell
 ceph osd status
+----+-------------+-------+-------+--------+---------+--------+---------+-----------+
| id |     host    |  used | avail | wr ops | wr data | rd ops | rd data |   state   |
+----+-------------+-------+-------+--------+---------+--------+---------+-----------+
| 0  | ceph-node01 | 1028M | 28.9G |    0   |     0   |    0   |     0   | exists,up |
| 1  | ceph-node01 | 1028M | 48.9G |    0   |     0   |    0   |     0   | exists,up |
| 2  | ceph-node02 | 1028M | 28.9G |    0   |     0   |    0   |     0   | exists,up |
| 3  | ceph-node02 | 1028M | 48.9G |    0   |     0   |    0   |     0   | exists,up |
| 4  | ceph-node03 | 1028M | 28.9G |    0   |     0   |    0   |     0   | exists,up |
| 5  | ceph-node03 | 1028M | 48.9G |    0   |     0   |    0   |     0   | exists,up |
+----+-------------+-------+-------+--------+---------+--------+---------+-----------+
ceph osd stat
6 osds: 6 up (since 19m), 6 in (since 19m); epoch: e34
```

### 4.查看osd在主机的分布信息
```shell
ceph osd tree
ID CLASS WEIGHT  TYPE NAME            STATUS REWEIGHT PRI-AFF
-1       0.23428 root default
-3       0.07809     host ceph-node01
 0   hdd 0.02930         osd.0            up  1.00000 1.00000
 1   hdd 0.04880         osd.1            up  1.00000 1.00000
-5       0.07809     host ceph-node02
 2   hdd 0.02930         osd.2            up  1.00000 1.00000
 3   hdd 0.04880         osd.3            up  1.00000 1.00000
-7       0.07809     host ceph-node03
 4   hdd 0.02930         osd.4            up  1.00000 1.00000
 5   hdd 0.04880         osd.5            up  1.00000 1.00000
```
### 5.osd延迟统计信息
```shell
ceph osd perf
osd commit_latency(ms) apply_latency(ms)
  5                  0                 0
  4                  0                 0
  0                  0                 0
  1                  0                 0
  2                  0                 0
  3                  0                 0
```
### 5.osd磁盘使用率信息
```shell
ceph osd df
ID CLASS WEIGHT  REWEIGHT SIZE    RAW USE DATA    OMAP META  AVAIL   %USE VAR  PGS STATUS
 0   hdd 0.02930  1.00000  30 GiB 1.0 GiB 4.4 MiB  0 B 1 GiB  29 GiB 3.35 1.33  51     up
 1   hdd 0.04880  1.00000  50 GiB 1.0 GiB 4.6 MiB  0 B 1 GiB  49 GiB 2.01 0.80  77     up
 2   hdd 0.02930  1.00000  30 GiB 1.0 GiB 4.4 MiB  0 B 1 GiB  29 GiB 3.35 1.33  47     up
 3   hdd 0.04880  1.00000  50 GiB 1.0 GiB 4.6 MiB  0 B 1 GiB  49 GiB 2.01 0.80  81     up
 4   hdd 0.02930  1.00000  30 GiB 1.0 GiB 4.6 MiB  0 B 1 GiB  29 GiB 3.35 1.33  49     up
 5   hdd 0.04880  1.00000  50 GiB 1.0 GiB 4.4 MiB  0 B 1 GiB  49 GiB 2.01 0.80  79     up
                    TOTAL 240 GiB 6.0 GiB  27 MiB  0 B 6 GiB 234 GiB 2.51
MIN/MAX VAR: 0.80/1.33  STDDEV: 0.69
```
## 暂停和开启

暂停接受数据：`ceph osd pause`
开始接收数据：`ceph osd unpause`

```shell
ceph osd pause
pauserd,pausewr is set
ceph -s
  cluster:
    id:     d901ea94-de1d-4814-9f97-6f7ebd4329dd
    health: HEALTH_WARN
            pauserd,pausewr flag(s) set

  services:
    mon: 3 daemons, quorum ceph-node01,ceph-node02,ceph-node03 (age 45m)
    mgr: ceph-node01(active, since 38m), standbys: ceph-node02
    mds:  2 up:standby
    osd: 6 osds: 6 up (since 25m), 6 in (since 25m)
         flags pauserd,pausewr
    rgw: 1 daemon active (ceph-node03)

  task status:

  data:
    pools:   4 pools, 128 pgs
    objects: 187 objects, 1.2 KiB
    usage:   6.0 GiB used, 234 GiB / 240 GiB avail
    pgs:     128 active+clean

ceph osd unpause
pauserd,pausewr is unset
ceph -s
  cluster:
    id:     d901ea94-de1d-4814-9f97-6f7ebd4329dd
    health: HEALTH_OK

  services:
    mon: 3 daemons, quorum ceph-node01,ceph-node02,ceph-node03 (age 45m)
    mgr: ceph-node01(active, since 38m), standbys: ceph-node02
    mds:  2 up:standby
    osd: 6 osds: 6 up (since 26m), 6 in (since 26m)
    rgw: 1 daemon active (ceph-node03)

  task status:

  data:
    pools:   4 pools, 128 pgs
    objects: 187 objects, 1.2 KiB
    usage:   6.0 GiB used, 234 GiB / 240 GiB avail
    pgs:     128 active+clean
```

## 数据操作比重

命令格式：`ceph osd crush reweight osd.ID 权重`，调整权重为0，则表示CRUSH 算法不会再选择这个 OSD 存储新数据。

```shell
# 查看默认权重
ceph osd crush tree
ID CLASS WEIGHT  TYPE NAME
-1       0.23428 root default
-3       0.07809     host ceph-node01
 0   hdd 0.02930         osd.0
 1   hdd 0.04880         osd.1
-5       0.07809     host ceph-node02
 2   hdd 0.02930         osd.2
 3   hdd 0.04880         osd.3
-7       0.07809     host ceph-node03
 4   hdd 0.02930         osd.4
 5   hdd 0.04880         osd.5
 # 调整权重为0，则表示CRUSH 算法不会再选择这个 OSD 存储新数据
ceph osd crush reweight osd.4 0
reweighted item id 4 name 'osd.4' to 0 in crush map
[cephadm@ceph-admin ceph-cluster]$ ceph osd crush tree
ID CLASS WEIGHT  TYPE NAME
-1       0.20499 root default
-3       0.07809     host ceph-node01
 0   hdd 0.02930         osd.0
 1   hdd 0.04880         osd.1
-5       0.07809     host ceph-node02
 2   hdd 0.02930         osd.2
 3   hdd 0.04880         osd.3
-7       0.04880     host ceph-node03
 4   hdd       0         osd.4
 5   hdd 0.04880         osd.5
```

## OSD上下线

osd有专门的管理服务控制，一旦发现被下线，会尝试启动它
- 上线：`ceph osd down ID`
- 下线：`ceph osd up ID`

```shell
# 见磁盘快速下线，然后查看状态
ceph osd down 0
marked down osd.0.
[cephadm@ceph-admin ceph-cluster]$ ceph osd tree
ID CLASS WEIGHT  TYPE NAME            STATUS REWEIGHT PRI-AFF
-1       0.23428 root default
-3       0.07809     host ceph-node01
 0   hdd 0.02930         osd.0          down  1.00000 1.00000
 1   hdd 0.04880         osd.1            up  1.00000 1.00000
-5       0.07809     host ceph-node02
 2   hdd 0.02930         osd.2            up  1.00000 1.00000
 3   hdd 0.04880         osd.3            up  1.00000 1.00000
-7       0.07809     host ceph-node03
 4   hdd 0.02930         osd.4            up  1.00000 1.00000
 5   hdd 0.04880         osd.5            up  1.00000 1.00000
#等待一分钟后插件状态，指定节点又自动上线了
 ceph osd tree
ID CLASS WEIGHT  TYPE NAME            STATUS REWEIGHT PRI-AFF
-1       0.23428 root default
-3       0.07809     host ceph-node01
 0   hdd 0.02930         osd.0            up  1.00000 1.00000
 1   hdd 0.04880         osd.1            up  1.00000 1.00000
-5       0.07809     host ceph-node02
 2   hdd 0.02930         osd.2            up  1.00000 1.00000
 3   hdd 0.04880         osd.3            up  1.00000 1.00000
-7       0.07809     host ceph-node03
 4   hdd 0.02930         osd.4            up  1.00000 1.00000
 5   hdd 0.04880         osd.5            up  1.00000 1.00000
```

## 驱逐加入OSD对象

驱逐或加入OSD对象，本质上是Ceph集群数据操作的权重值调整,一般更换磁盘的时候会使用到

- 驱逐：`ceph osd out osd编号`
- 加入：`ceph osd in osd编号`

## OSD节点操作

### 1.OSD删除步骤

OSD删除需要遵循一定的步骤，否则会存在数据丢失的情况：

1. 修改OSD的数据操作权重值，让数据不分布在这个节点上
2. 到指定节点，停止指定的osd进程
3. 将移除的osd节点状态标记为out
4. 从crush中移除OSD节点，该节点不再作为数据的载体
5. 删除OSD节点
6. 删除OSD节点的认证信息

### 2. 实践：删除osd.5
```shell
ceph osd tree
ID CLASS WEIGHT  TYPE NAME            STATUS REWEIGHT PRI-AFF
-1       0.23428 root default
-3       0.07809     host ceph-node01
 0   hdd 0.02930         osd.0            up  1.00000 1.00000
 1   hdd 0.04880         osd.1            up  1.00000 1.00000
-5       0.07809     host ceph-node02
 2   hdd 0.02930         osd.2            up  1.00000 1.00000
 3   hdd 0.04880         osd.3            up  1.00000 1.00000
-7       0.07809     host ceph-node03
 4   hdd 0.02930         osd.4            up  1.00000 1.00000
 5   hdd 0.04880         osd.5            up  1.00000 1.00000
```
```shell
# 修改OSD的数据操作权重值为0，让数据不分布在这个节点上
ceph osd crush reweight osd.5 0
reweighted item id 5 name 'osd.5' to 0 in crush map
[cephadm@ceph-admin ceph-cluster]$ ceph osd tree
ID CLASS WEIGHT  TYPE NAME            STATUS REWEIGHT PRI-AFF
-1       0.18549 root default
-3       0.07809     host ceph-node01
 0   hdd 0.02930         osd.0            up  1.00000 1.00000
 1   hdd 0.04880         osd.1            up  1.00000 1.00000
-5       0.07809     host ceph-node02
 2   hdd 0.02930         osd.2            up  1.00000 1.00000
 3   hdd 0.04880         osd.3            up  1.00000 1.00000
-7       0.02930     host ceph-node03
 4   hdd 0.02930         osd.4            up  1.00000 1.00000
 5   hdd       0         osd.5            up  1.00000 1.00000
 # ssh ceph-node03停止进程
ssh cephadm@ceph-node03 "sudo systemctl stop ceph-osd@5"
ceph osd tree
ID CLASS WEIGHT  TYPE NAME            STATUS REWEIGHT PRI-AFF
-1       0.18549 root default
-3       0.07809     host ceph-node01
 0   hdd 0.02930         osd.0            up  1.00000 1.00000
 1   hdd 0.04880         osd.1            up  1.00000 1.00000
-5       0.07809     host ceph-node02
 2   hdd 0.02930         osd.2            up  1.00000 1.00000
 3   hdd 0.04880         osd.3            up  1.00000 1.00000
-7       0.02930     host ceph-node03
 4   hdd 0.02930         osd.4            up  1.00000 1.00000
 5   hdd       0         osd.5          down  1.00000 1.00000
#  将移除的osd节点状态标记为out
ceph osd out 5
marked out osd.5.
ceph osd tree
ID CLASS WEIGHT  TYPE NAME            STATUS REWEIGHT PRI-AFF
-1       0.18549 root default
-3       0.07809     host ceph-node01
 0   hdd 0.02930         osd.0            up  1.00000 1.00000
 1   hdd 0.04880         osd.1            up  1.00000 1.00000
-5       0.07809     host ceph-node02
 2   hdd 0.02930         osd.2            up  1.00000 1.00000
 3   hdd 0.04880         osd.3            up  1.00000 1.00000
-7       0.02930     host ceph-node03
 4   hdd 0.02930         osd.4            up  1.00000 1.00000
 5   hdd       0         osd.5          down        0 1.00000
# 从crush中移除OSD节点，该节点不再作为数据的载体
ceph osd crush rm osd.5
ceph osd crush tree
ID CLASS WEIGHT  TYPE NAME
-1       0.18549 root default
-3       0.07809     host ceph-node01
 0   hdd 0.02930         osd.0
 1   hdd 0.04880         osd.1
-5       0.07809     host ceph-node02
 2   hdd 0.02930         osd.2
 3   hdd 0.04880         osd.3
-7       0.02930     host ceph-node03
 4   hdd 0.02930         osd.4
# 5. 删除OSD节点
ceph osd rm 5
removed osd.5
[cephadm@ceph-admin ceph-cluster]$ ceph osd tree
ID CLASS WEIGHT  TYPE NAME            STATUS REWEIGHT PRI-AFF
-1       0.18549 root default
-3       0.07809     host ceph-node01
 0   hdd 0.02930         osd.0            up  1.00000 1.00000
 1   hdd 0.04880         osd.1            up  1.00000 1.00000
-5       0.07809     host ceph-node02
 2   hdd 0.02930         osd.2            up  1.00000 1.00000
 3   hdd 0.04880         osd.3            up  1.00000 1.00000
-7       0.02930     host ceph-node03
 4   hdd 0.02930         osd.4            up  1.00000 1.00000
# 删除OSD节点的认证信息
ceph auth rm osd.5
```
### 3.OSD添加步骤

将OSD添加集群步骤如下：

1. 确定OSD节点没有被占用
2. 格式化磁盘
3. ceph擦除磁盘上的数据
4. 添加OSD到集群
### 4.实践:添加OSD
将 ceph-node3上的/dev/vdc磁盘添加成OSD

- 清除之前的osd映射关系

```shell
# ceph 数据被使用中
dmsetup status
ceph--333eccf3--9518--4e6e--bdc6--7e1c07c0dabe-osd--block--a3d688ed--4432--4d0e--b12d--d75f82f70b52: 0 104849408 linear
ceph--cb582b60--72ad--46f5--ba21--ac756204dac0-osd--block--1490030e--420b--493e--b817--515ef0aec597: 0 62906368 linear
centos-swap: 0 8126464 linear
centos-root: 0 409190400 linear
# 查看osd的id值
cat /var/lib/ceph/osd/ceph-5/fsid
a3d688ed-4432-4d0e-b12d-d75f82f70b52
lsblk
NAME                                                                                                  MAJ:MIN RM   SIZE RO TYPE MOUNTPOINT
sr0                                                                                                    11:0    1  1024M  0 rom
vda                                                                                                   252:0    0   200G  0 disk
├─vda1                                                                                                252:1    0     1G  0 part /boot
└─vda2                                                                                                252:2    0   199G  0 part
  ├─centos-root                                                                                       253:0    0 195.1G  0 lvm  /
  └─centos-swap                                                                                       253:1    0   3.9G  0 lvm  [SWAP]
vdb                                                                                                   252:16   0    30G  0 disk
└─ceph--cb582b60--72ad--46f5--ba21--ac756204dac0-osd--block--1490030e--420b--493e--b817--515ef0aec597 253:2    0    30G  0 lvm
vdc                                                                                                   252:32   0    50G  0 disk
└─ceph--333eccf3--9518--4e6e--bdc6--7e1c07c0dabe-osd--block--a3d688ed--4432--4d0e--b12d--d75f82f70b52 253:3    0    50G  0 lvm

# 删除 Ceph OSD 对应的 LVM 设备映射（device mapper），确定OSD节点没有被占用
~]# dmsetup remove ceph--333eccf3--9518--4e6e--bdc6--7e1c07c0dabe-osd--block--a3d688ed--4432--4d0e--b12d--d75f82f70b52
[root@ceph-node03 ~]# lsblk
NAME                                                                                                  MAJ:MIN RM   SIZE RO TYPE MOUNTPOINT
sr0                                                                                                    11:0    1  1024M  0 rom
vda                                                                                                   252:0    0   200G  0 disk
├─vda1                                                                                                252:1    0     1G  0 part /boot
└─vda2                                                                                                252:2    0   199G  0 part
  ├─centos-root                                                                                       253:0    0 195.1G  0 lvm  /
  └─centos-swap                                                                                       253:1    0   3.9G  0 lvm  [SWAP]
vdb                                                                                                   252:16   0    30G  0 disk
└─ceph--cb582b60--72ad--46f5--ba21--ac756204dac0-osd--block--1490030e--420b--493e--b817--515ef0aec597 253:2    0    30G  0 lvm
vdc                                                                                                   252:32   0    50G  0 disk
```
- 清理逻辑卷信息

```shell
# 停止osd进程，如果进程还在的话
systemctl stop ceph-osd@<osd-id>.service
lvs
  LV                                             VG                                        Attr       LSize    Pool Origin Data%  Meta%  Move Log Cpy%Sync Convert
  root                                           centos                                    -wi-ao---- <195.12g
  swap                                           centos                                    -wi-ao----   <3.88g
  osd-block-a3d688ed-4432-4d0e-b12d-d75f82f70b52 ceph-333eccf3-9518-4e6e-bdc6-7e1c07c0dabe -wi-------  <50.00g
  osd-block-1490030e-420b-493e-b817-515ef0aec597 ceph-cb582b60-72ad-46f5-ba21-ac756204dac0 -wi-ao----  <30.00g
pvs
  PV         VG                                        Fmt  Attr PSize    PFree
  /dev/vda2  centos                                    lvm2 a--  <199.00g 4.00m
  /dev/vdb   ceph-cb582b60-72ad-46f5-ba21-ac756204dac0 lvm2 a--   <30.00g    0
  /dev/vdc   ceph-333eccf3-9518-4e6e-bdc6-7e1c07c0dabe lvm2 a--   <50.00g    0
dmsetup ls | grep ceph
ceph--cb582b60--72ad--46f5--ba21--ac756204dac0-osd--block--1490030e--420b--493e--b817--515ef0aec597	(253:2)
# 删除旧 VG（彻底释放磁盘）
vgremove ceph-333eccf3-9518-4e6e-bdc6-7e1c07c0dabe
Do you really want to remove volume group "ceph-333eccf3-9518-4e6e-bdc6-7e1c07c0dabe" containing 1 logical volumes? [y/n]: y
  Logical volume "osd-block-a3d688ed-4432-4d0e-b12d-d75f82f70b52" successfully removed
  Volume group "ceph-333eccf3-9518-4e6e-bdc6-7e1c07c0dabe" successfully removed
# 删除 PV 标识
pvremove /dev/vdc
  Labels on physical volume "/dev/vdc" successfully wiped.
# 确认磁盘干净
ipefs -a /dev/vdc
```
- 擦除磁盘数据

```shell
ceph-deploy disk zap ceph-node03 /dev/vdc
```
- 添加为osd

```shell
ceph-deploy osd create ceph-node03 --data /dev/vdc
ceph osd tree
ID CLASS WEIGHT  TYPE NAME            STATUS REWEIGHT PRI-AFF
-1       0.23428 root default
-3       0.07809     host ceph-node01
 0   hdd 0.02930         osd.0            up  1.00000 1.00000
 1   hdd 0.04880         osd.1            up  1.00000 1.00000
-5       0.07809     host ceph-node02
 2   hdd 0.02930         osd.2            up  1.00000 1.00000
 3   hdd 0.04880         osd.3            up  1.00000 1.00000
-7       0.07809     host ceph-node03
 4   hdd 0.02930         osd.4            up  1.00000 1.00000
 5   hdd 0.04880         osd.5            up  1.00000 1.00000
```

## OSD数据实践

### 1.相关术语

|对象|说明|用途|
|---|---|---|
|Pool|Pool 是 Ceph 的逻辑存储单元|用户在 Pool 中创建对象（object）,每个 Pool 可以设置不同的副本数、副本类型、归置策略|
|PG（Placement Group，放置组）|Ceph 数据放置和复制的最小单位|Pool 里的对象太多（可能上百万），不可能逐个做副本放置；把对象分到一组一组里，这些组叫 PG,PG 才是与具体 OSD 绑定的单位。|
|PGP（Placement Group for Placement）|用于 CRUSH 算法的 PG 数量。|为了平滑扩容或迁移，Ceph 允许 PG 数量（PG_num）和 PGP 数量（PGP_num）不同。|

### 2.创建存储池

```shell
ceph osd pool create <poolname> <pg-num> [pgp-num] [replicated] [crush-rule-name] [expected-num-object]
```
- `poolname`: 存储池名称，在rados集群具有唯一性
- `pg-num`:房前存储池中pg数量
- `pgp-num`:用于归置的pg数量，应等于pg-num
- `replicated`：存储类型。副本池需要更多原始空间
- `crush-rule-name`：存储池需要的CRUSH规则集名称，引用的名称必须事先存在
```shell
 ceph osd pool create mypool 16 16
```
### 3.查看存储池

```shell
~]$ ceph osd pool ls
.rgw.root
default.rgw.control
default.rgw.meta
default.rgw.log
mypool
~]$ rados lspools
.rgw.root
default.rgw.control
default.rgw.meta
default.rgw.log
mypool
```

### 4.提交数据

```shell
~]$ rados put myfstab /etc/fstab --pool mypool
~]$ rados ls --pool mypool
myfstab
~]$ ceph osd map --pool mypool myfstab
osdmap e72 pool 'mypool' (5) object 'myfstab' -> pg 5.1baefa14 (5.4) -> up ([4,1,3], p4) acting ([4,1,3], p4)
```

### 5.删除数据

```shell
~]$ rados rm myfstab --pool mypool
```

### 6.删除存储池

```shell
~]$ ceph osd pool rm mypool mypool --yes-i-really-really-mean-it
Error EPERM: pool deletion is disabled; you must first set the mon_allow_pool_delete config option to true before you can destroy a pool
~]$ ceph config set mon   mon_allow_pool_delete true
~]$ ceph osd pool rm mypool mypool --yes-i-really-really-mean-it
pool 'mypool' removed
~]$ ceph config set mon   mon_allow_pool_delete false
```
