# Ceph Cluster集群管理

## 集群状态
### 1.检查集群状态
```shell
~]$ ceph -s
  cluster:
    id:     d901ea94-de1d-4814-9f97-6f7ebd4329dd
    health: HEALTH_OK

  services:
    mon: 3 daemons, quorum ceph-node01,ceph-node02,ceph-node03 (age 20h)
    mgr: ceph-node01(active, since 20h), standbys: ceph-node02
    mds: cephfs:1 {0=ceph-node01=up:active} 1 up:standby
    osd: 6 osds: 6 up (since 19h), 6 in (since 19h)
    rgw: 1 daemon active (ceph-node03)

  task status:

  data:
    pools:   10 pools, 416 pgs
    objects: 336 objects, 168 MiB
    usage:   6.5 GiB used, 233 GiB / 240 GiB avail
    pgs:     416 active+clean
```
### 2.pg状态查看
```shell
~]$ ceph pg stat
416 pgs: 416 active+clean; 168 MiB data, 549 MiB used, 233 GiB / 240 GiB avail
```
### 3.存储空间

```shell
~]$ ceph df [detail]
RAW STORAGE:
    CLASS     SIZE        AVAIL       USED        RAW USED     %RAW USED
    hdd       240 GiB     233 GiB     549 MiB      6.5 GiB          2.72
    TOTAL     240 GiB     233 GiB     549 MiB      6.5 GiB          2.72

POOLS:
    POOL                          ID     PGS     STORED      OBJECTS     USED        %USED     MAX AVAIL
    .rgw.root                      1      32     1.2 KiB           4     768 KiB         0        73 GiB
    default.rgw.control            2      32         0 B           8         0 B         0        73 GiB
    default.rgw.meta               3      32     2.1 KiB          11     1.9 MiB         0        73 GiB
    default.rgw.log                4      32         0 B         207         0 B         0        73 GiB
    kube                           7      16     129 MiB          50     391 MiB      0.17        73 GiB
    kvmpool                        8      16      13 MiB          18      48 MiB      0.02        73 GiB
    default.rgw.buckets.index      9      32         0 B           4         0 B         0        73 GiB
    default.rgw.buckets.data      10      32     5.7 KiB          11     2.1 MiB         0        73 GiB
    cephfs-metadata               11      64      18 KiB          22     1.5 MiB         0        73 GiB
    cephfs-data                   12     128         4 B           1     192 KiB         0        73 GiB
```
### 4.OSD状态
```shell
~]$ ceph osd stat
6 osds: 6 up (since 19h), 6 in (since 19h); epoch: e134
~]$ ceph osd tree
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
### 5.MON状态
```shell
~]$ ceph mon stat
e2: 3 mons at {ceph-node01=[v2:192.168.1.101:3300/0,v1:192.168.1.101:6789/0],ceph-node02=[v2:192.168.1.102:3300/0,v1:192.168.1.102:6789/0],ceph-node03=[v2:192.168.1.103:3300/0,v1:192.168.1.103:6789/0]}, election epoch 8, leader 0 ceph-node01, quorum 0,1,2 ceph-node01,ceph-node02,ceph-node03
~]$ ceph mon dump
epoch 2
fsid d901ea94-de1d-4814-9f97-6f7ebd4329dd
last_changed 2025-10-21 14:36:37.597634
created 2025-10-21 14:36:14.439192
min_mon_release 14 (nautilus)
0: [v2:192.168.1.101:3300/0,v1:192.168.1.101:6789/0] mon.ceph-node01
1: [v2:192.168.1.102:3300/0,v1:192.168.1.102:6789/0] mon.ceph-node02
2: [v2:192.168.1.103:3300/0,v1:192.168.1.103:6789/0] mon.ceph-node03
dumped monmap epoch 2
# 选举状态
~]$ ceph quorum_status [-f json-pretty]
```

## 管理套接字

ceph的管理套接字，通常用于查询守护进程，资源对象文件保存在/var/lib/ceph目录，套接字默认保存在/var/run/ceph/目录，只能本地使用。

```shell
~]# ceph --admin-daemon /var/run/ceph/ceph-osd.0.asok status
{
    "cluster_fsid": "d901ea94-de1d-4814-9f97-6f7ebd4329dd",
    "osd_fsid": "d04abe1d-abb7-4ef9-8235-ffbfea2529cf",
    "whoami": 0,
    "state": "active",
    "oldest_map": 1,
    "newest_map": 134,
    "num_pgs": 161
}
~]# ceph --admin-daemon /var/run/ceph/ceph-mon.ceph-node01.asok config show
~]# ceph --admin-daemon /var/run/ceph/ceph-mon.ceph-node01.asok config get xio_mp_max_page
{
    "xio_mp_max_page": "4096"
}
```
## 配置文件
### 1.文件格式
```shell
~]# cat /etc/ceph/ceph.conf
[global]
fsid = d901ea94-de1d-4814-9f97-6f7ebd4329dd
public_network = 192.168.1.0/24
cluster_network = 192.168.122.0/24
mon_initial_members = ceph-node01, ceph-node02, ceph-node03
mon_host = 192.168.1.101,192.168.1.102,192.168.1.103
auth_cluster_required = cephx
auth_service_required = cephx
auth_client_required = cephx
[mon]
mon allow_pool_delete = true
[mon.mon01]
[osd]
...
[osd.1]
...
[mgr]
..
[client]
...
```
### 2.文件加载

全局配置文件

- /etc/ceph/ceph.conf
- export CEPH_CONF=xxx
- -c path/to/conf

局部配置文件

- ～/.ceph.config
- ./ceph/conf

### 3.实践
```shell
# 获取所有属性
~]# ceph daemon osd.0 config show
# 获取单个属性
~]# ceph daemon osd.0 config get target_max_misplaced_ratio
{
    "target_max_misplaced_ratio": "0.050000"
}
# 删除存储池
~]$ ceph osd pool rm mypool mypool --yes-i-really-really-mean-it
Error EPERM: pool deletion is disabled; you must first set the mon_allow_pool_delete config option to true before you can destroy a pool
~]$ ceph config set mon   mon_allow_pool_delete true
~]$ ceph osd pool rm mypool mypool --yes-i-really-really-mean-it
pool 'mypool' removed
~]$ ceph config set mon   mon_allow_pool_delete false
```

## 磁盘管理

[见OSD节点操作](http://127.0.0.1:8000/books/storage/osd/#osd_2)

## 性能调优

性能调优就是在现有主机资源前提下，发挥业务作答的处理能力。通过空间换实践，优化业务处理效益

- 改善业务逻辑处理速度
- 提升业务吞吐量
- 优化主机消耗量

| 通用措施 | 类型    | 说明                               |
|------|-------|----------------------------------|
| 基础设施 | 合适设备  | 多云环境、新旧服务器结合、合适网络                |
|      | 研发环境  | 应用架构、研发平台、代码规范                   |
| 应用软件 | 多级缓存  | 浏览器缓存、缓存服务器、服务器缓存，应用缓存、代码缓存、数据缓存 |
|      | 数据压缩  | 构建压缩、传输雅俗、缓存压缩、对象压缩，清理无效数据       |
|      | 数据预热  | 缓冲数据】预取数据、预制主机、数据同步              |
| 业务处理 | 削峰填谷  | 延时加载、的批发部、限流控制、异步处理、超时降级         |
|  | 任务批处理 | 数据打包传输、批量传输、延迟数据处理               |

### 1.常见策略

ceph集群各个服务守护进程在Linux主机运行，所以实弹优化操作系统能够对ceph性能产生积极的影响

- 选择合适的CPU和内存: 不同角色具有不同的CPU需求，内存需求
- 选择合适的磁盘容量：计算节点数量磁盘容量需求，选择合适的SAS，SATA，SSD实现分级存储
- 选择合适的网络：ceph集群对网络传输能力要求高，需要支持巨型桢，所以网络带宽尽量大最好
- 配置合适的文件系统
- 搭建内部时间服务器
- 合理采用多云架构：将合适的业务迁移到公有云环境

## 性能测试

### 基准测试

#### 1.磁盘测试

```shell
# 清理缓存
~]# echo 3 > /proc/sys/vm/drop_caches
# 写性能
~]# dd if=/dev/zero of=/var/lib/ceph/osd/ceph-0/write_test bs=1M count=1024
记录了1024+0 的读入
记录了1024+0 的写出
1073741824字节(1.1 GB)已复制，2.74816 秒，391 MB/秒
# 读性能
~]# dd if=/var/lib/ceph/osd/ceph-0/write_test of=/dev/null bs=1M count=1024
记录了1024+0 的读入
记录了1024+0 的写出
1073741824字节(1.1 GB)已复制，0.566816 秒，1.9 GB/秒
# 清理环境
~]# rm -rf /var/lib/ceph/osd/ceph-0/write_test
```

#### 2.网络测试

```shell
~]# yum install iperf -y
# 启动服务端
~]# iperf -s -p 6090
------------------------------------------------------------
Server listening on TCP port 6090
TCP window size: 85.3 KByte (default)
------------------------------------------------------------
# 客户端测试
~]# iperf -c ceph-node01 -p 6090
------------------------------------------------------------
Client connecting to ceph-node01, TCP port 6090
TCP window size:  493 KByte (default)
------------------------------------------------------------
[  3] local 192.168.1.102 port 49794 connected with 192.168.1.101 port 6090
[ ID] Interval       Transfer     Bandwidth
[  3]  0.0-10.0 sec  24.0 GBytes  20.7 Gbits/sec
```

### rados测试
#### 1.bench性能工具

```shell
~]# ceph osd pool create testpool 32 32
# 写测试
~]# rados bench -p testpool 10 write --no-cleanup
hints = 1
Maintaining 16 concurrent writes of 4194304 bytes to objects of size 4194304 for up to 10 seconds or 0 objects
Object prefix: benchmark_data_ceph-node02_75493
  sec Cur ops   started  finished  avg MB/s  cur MB/s last lat(s)  avg lat(s)
    0       0         0         0         0         0           -           0
    1      16        47        31   123.957       124    0.339039     0.26998
    2      16        48        32    63.979         4    0.926563    0.290498
    3      16        51        35   46.6536        12     2.37035    0.474669
    4      16        62        46   45.9874        44     2.54365    0.970419
    5      16        80        64   51.1822        72     1.86982     1.13235
    6      16        95        79   52.6495        60    0.829198     1.11541
    7      16       107        91   51.9836        48     1.70162     1.09511
    8      16       123       107   53.4834        64     1.65955     1.11566
    9      16       139       123   54.6504        64     1.26755     1.10312
   10      16       155       139   55.5842        64     1.03061     1.08782
Total time run:         10.5233
Total writes made:      156
Write size:             4194304
Object size:            4194304
Bandwidth (MB/sec):     59.2968
Stddev Bandwidth:       33.2238
Max bandwidth (MB/sec): 124
Min bandwidth (MB/sec): 4
Average IOPS:           14
Stddev IOPS:            8.30596
Max IOPS:               31
Min IOPS:               1
Average Latency(s):     1.07799
Stddev Latency(s):      0.676048
Max latency(s):         3.48482
Min latency(s):         0.0520137
# 读测试
~]# rados bench -p testpool 10 seq
hints = 1
  sec Cur ops   started  finished  avg MB/s  cur MB/s last lat(s)  avg lat(s)
    0       1         1         0         0         0           -           0
Total time run:       0.854894
Total reads made:     156
Read size:            4194304
Object size:          4194304
Bandwidth (MB/sec):   729.915
Average IOPS:         182
Stddev IOPS:          0
Max IOPS:             155
Min IOPS:             155
Average Latency(s):   0.0858158
Max latency(s):       0.295643
Min latency(s):       0.00947855
# 随机读
~]# rados bench -p testpool 10 rand
hints = 1
  sec Cur ops   started  finished  avg MB/s  cur MB/s last lat(s)  avg lat(s)
    0       0         0         0         0         0           -           0
    1      16       265       249   995.125       996    0.049809    0.060605
    2      16       557       541   1081.33      1168   0.0125041   0.0563806
    3      16       850       834   1111.23      1172   0.0137341   0.0559525
    4      16      1146      1130   1129.21      1184   0.0858852   0.0556404
    5      16      1449      1433   1145.54      1212     0.12376   0.0549243
    6      16      1756      1740   1159.14      1228   0.0154079   0.0539604
    7      15      2063      2048   1169.37      1232     0.10969   0.0539128
    8      16      2364      2348   1173.05      1200   0.0504233    0.053643
    9      16      2666      2650   1176.88      1208   0.0920287   0.0535442
   10      16      2966      2950   1179.06      1200   0.0244516   0.0534336
Total time run:       10.0675
Total reads made:     2966
Read size:            4194304
Object size:          4194304
Bandwidth (MB/sec):   1178.44
Average IOPS:         294
Stddev IOPS:          17.0163
Max IOPS:             308
Min IOPS:             249
Average Latency(s):   0.053714
Max latency(s):       0.244274
Min latency(s):       0.00392119
# 清理数据
~]# rados -p testpool cleanup
Removed 156 objects
```

## 吞吐量测试

```shell
~]# rados -p testpool load-gen --number-objects 50 --min-object-size 4M --max-object-size 4M --max-ops 16 --min-op-len 4M --max-op=len 4M --percent 5 --target-throughput 4M --run-length 10
run length 10 seconds
preparing 200 objects
load-gen will run 10 seconds
    1: throughput=0MB/sec pending data=0
READ : oid=obj-Udh-Weeu_MUOLwS off=0 len=4194304
READ : oid=obj-w3kIYN5wOlX9pg2 off=0 len=4194304
op 0 completed, throughput=3.92MB/sec
op 1 completed, throughput=7.79MB/sec
    2: throughput=3.95MB/sec pending data=0
READ : oid=obj-qe8nOCcIUI7EeNe off=0 len=4194304
op 2 completed, throughput=5.86MB/sec
    3: throughput=3.94MB/sec pending data=0
WRITE : oid=obj-eh7WVeyYyCNSwT7 off=0 len=4194304
op 3 completed, throughput=5.13MB/sec
    4: throughput=3.88MB/sec pending data=0
READ : oid=obj-QCAn1qwZznVQ9un off=0 len=4194304
op 4 completed, throughput=4.82MB/sec
    5: throughput=3.88MB/sec pending data=0
READ : oid=obj-1DbQRDFIgSNsPrf off=0 len=4194304
op 5 completed, throughput=4.63MB/sec
    6: throughput=3.88MB/sec pending data=0
READ : oid=obj-Ramd9ZG0VCgviYr off=0 len=4194304
op 6 completed, throughput=4.52MB/sec
    7: throughput=3.89MB/sec pending data=0
WRITE : oid=obj-tMeI0yyhPOqrMgo off=0 len=4194304
op 7 completed, throughput=4.41MB/sec
    8: throughput=3.88MB/sec pending data=0
READ : oid=obj-i3suoA1HJ_h-pYv off=0 len=4194304
op 8 completed, throughput=4.35MB/sec
    9: throughput=3.88MB/sec pending data=0
WRITE : oid=obj-cIXMhiIlVBIY5Oh off=0 len=4194304
op 9 completed, throughput=4.28MB/sec
waiting for all operations to complete
cleaning up objects
```

