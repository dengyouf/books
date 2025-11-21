# 使用Ceph-Deploy部署Ceph分布式存储系统

## ceph集群规划
使用deph-deploy快速部署ceph集群，操作系统为CentOS Linux release 7.5.1804 (Core)，用到的各相关程序版本如下:

- ceph-deploy: 2.0.1
- ceph: 14.2.22(nautilus)
- 公共网络: 192.168.1.0/24
- 集群网络: 192.168.122.0/24

| 主机名         | IP                               | 机器配置             | 角色              | 备注                                           |
|-------------|----------------------------------|------------------|-----------------|----------------------------------------------|
| ceph-admin  | 192.168.1.100<br>192.168.122.100 | 2c4g/60G         | admin管理节点       ||
| ceph-node01 | 192.168.1.101<br>192.168.122.101 | 2c4g/60G/30G/50G | mon、mgr、osd、mds | 其中vdb,vdc预留给osd使用                            |
| ceph-node02 | 192.168.1.102<br>192.168.122.102 | 2c4g/60G/30G/50G | mon、mgr、osd、mds | 其中vdb,vdc预留给osd使用                            |
| ceph-node03 | 192.168.1.103<br>192.168.122.103 | 2c4g/60G/30G/50G | mon、rgw、osd     | 其中vdb,vdc预留给osd使用                            |

- ceph-mgr(Manager)管理器: 集群性能指标手机，管理插件，负载均衡，提供API服务
- ceph-mon(Monitor)监控器: 集群状态管理，使用 Paxos 算法保证元数据一致性，身份验证，仲裁管理，生产环境最少3个节点
- ceph-osd(Object Storage Daemon)对象存储守护进程: 一块磁盘就是一个OSD，提供数据存储，数据复制，心跳检测，数据再平衡
- ceph-mds(Metadata Server)元数据服务: 元数据管理(维护文件和目录的层次结构、管理文件权限、大小、时间戳等 inode 信息、维护完整的文件系统命名空间)，客户端协调(将文件路径转换为对象存储位置、处理文件锁和目录锁，确保多个客户端之间的缓存一致性)
- ceph-rgw(RADOS Gateway)对象存储网关: 供了与 Amazon S3 和 Swift 兼容的 RESTful API 接口，将 Ceph 存储集群暴露为对象存储服务
- PG(Placement Groups): 一个PG包含多个OSD，可实现更好的分配数据和数据定位，，写数据时，先写入主OSD，在冗余到副本OSD节点

## 系统环境准备

### 1.主机名解析

```shell
cat >> /etc/hosts << 'EOF'
192.168.1.100 ceph-admin
192.168.1.101 ceph-node01
192.168.1.102 ceph-node02
192.168.1.103 ceph-node03
EOF
```

### 2.关闭防火墙和Selinux
```shell
for i in stop disable;do systemctl $i firewalld; done
sed -i 's/enforcing/disabled/' /etc/selinux/config && setenforce 0
```

### 3.关闭NetworkManager
```shell
systemctl disable NetworkManager && systemctl stop NetworkManager
```
### 4.内核参数优化
```shell
echo "ulimit -SHn 102400" >> /etc/rc.local
cat >> /etc/security/limits.conf << EOF
* soft nofile 65535
* hard nofile 65535
EOF
cat >> /etc/sysctl.conf << EOF
kernel.pid_max = 4194303
EOF
echo "vm.swappiness = 0" >> /etc/sysctl.conf
sysctl -p
```
### 5.创建普通用户
ceph-deploy 必须以普通用户登录到Ceph集群的各目标节点，且此用户需要拥有无密码使用sudo命令的权限，以便在安装软件及生成配置文件的过程中无需中断配置过程
```shell
useradd  cephadm
echo "cephadm" | passwd --stdin cephadm
echo "cephadm ALL = (root) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/cephadm
chmod 0440 /etc/sudoers.d/cephadm
```

### 6.主机互信
```shell
cat > ssh_trust_setup.sh << 'EOF'
#!/bin/bash
#
set -e
HOSTS=(
192.168.1.100
192.168.1.101
192.168.1.102
192.168.1.103
)

USER=cephadm
PORT=22

if ! command -v sshpass >/dev/null 2>&1; then
  echo "[INFO] 未检测到 sshpass，正在安装..."
  if command -v apt >/dev/null 2>&1; then
    sudo apt update -y && apt install -y sshpass
  elif command -v yum >/dev/null 2>&1; then
    sudo yum install -y epel-release && sudo yum install -y sshpass
  else
    echo "[ERROR] 未找到 apt 或 yum，请手动安装 sshpass"
    exit 1
  fi
fi

if [ ! -f ~/.ssh/id_rsa ]; then
  echo "[INFO] 未检测到 SSH 密钥，正在生成..."
  ssh-keygen -t rsa -b 4096 -N "" -f ~/.ssh/id_rsa
fi

echo
read -s -p "请输入远程主机 (${USER}) 登录密码: " PASSWORD
echo
echo "[INFO] 开始配置互信..."

for host in "${HOSTS[@]}"; do
  echo "-----> 正在配置 $host"
  sshpass -p "$PASSWORD" ssh-copy-id -o StrictHostKeyChecking=no -p "$PORT" "${USER}@${host}" >/dev/null 2>&1 \
    && echo "[OK] $host 互信建立成功" \
    || echo "[FAIL] $host 互信失败"
done

echo
echo "[DONE] 所有主机 SSH 互信配置完成。"
echo "可测试：ssh ${USER}@${HOSTS[0]}"
EOF
```
### 7.配置[ceph源](https://mirrors.aliyun.com/ceph/rpm-nautilus/el7/noarch/ceph-release-1-1.el7.noarch.rpm)

```shell
sudo yum install https://mirrors.aliyun.com/ceph/rpm-nautilus/el7/noarch/ceph-release-1-1.el7.noarch.rpm
```

## 安装ceph-deploy

在管理节点安装ceph-deploy工具包

```shell
su - cephadm
sudo yum install ceph-deploy python-setuptools python2-subprocess32 -y
ceph-deploy --version
2.0.1
```

## 部署Ceph集群

### 1.集群初始化

在管理节点上以cephadm用户创建集群相关的配置文件目录
```shell
su - cephadm
mkdir ceph-cluster
cd ceph-cluster
ceph-deploy new --public-network 192.168.1.0/24 --cluster-network 192.168.122.0/24 ceph-node01 ceph-node02 ceph-node03 --no-ssh-copykey
 ll
总用量 16
-rw-rw-r-- 1 cephadm cephadm  323 10月 21 14:00 ceph.conf
-rw-rw-r-- 1 cephadm cephadm 7567 10月 21 14:00 ceph-deploy-ceph.log
-rw------- 1 cephadm cephadm   73 10月 21 14:00 ceph.mon.keyring
cat ceph.conf
[global]
fsid = d901ea94-de1d-4814-9f97-6f7ebd4329dd
public_network = 192.168.1.0/24
cluster_network = 192.168.122.0/24
mon_initial_members = ceph-node01, ceph-node02, ceph-node03
mon_host = 192.168.1.101,192.168.1.102,192.168.1.103
auth_cluster_required = cephx
auth_service_required = cephx
auth_client_required = cephx
```

### 2.在所有节点安装ceph软件
ceph-deploy命令能够以远程的方式连入Ceph集群各节点完成程序包安装等操作，命令格式如下：ceph-deploy install {ceph-node} [{ceph-node} ...]因此，若要将ceph-node01、ceph-node02和ceph-node03配置为Ceph集群节点，则执行如下命令即可：
```shell
ceph-deploy install --nogpgcheck ceph-node01 ceph-node02 ceph-node03
```
此处为了加速我们在集群各节点手动安装ceph程序包`yum install -y ceph ceph-radosgw`

等待各个集群节点程序包安装完成后，配置 ceph-node01， ceph-node02， ceph-node03 为 ceph 集群节点，此处为了不让 ceph-deploy 节点 再次重新安装 ceph 程序，我们需要添加参数 --no-adjust-repos
```shell
ceph-deploy install --nogpgcheck --no-adjust-repos ceph-node01 ceph-node02 ceph-node03
```

### 3.初始化Monitor节点
在节点上会启动一个 ceph-mon 进程，并且以 ceph 用户运行。在 /etc/ceph 目录会生成一些对应的配置文件，其中 ceph.conf 文件就是从前面 ceph-cluater 文件直接copy过去的，此文件也可以直接进行修改
```shell
ceph-deploy mon create-initial
for i in ceph-node01 ceph-node02 ceph-node03;do ssh $i "ps aux|grep ceph-mon"|grep -v grep ; done
ceph       63884  0.3  0.8 504340 34548 ?        Ssl  14:36   0:00 /usr/bin/ceph-mon -f --cluster ceph --id ceph-node01 --setuser ceph --setgroup ceph
ceph       63551  0.3  0.8 504340 33668 ?        Ssl  14:36   0:00 /usr/bin/ceph-mon -f --cluster ceph --id ceph-node02 --setuser ceph --setgroup ceph
ceph       63598  0.2  0.9 503316 35248 ?        Ssl  14:36   0:00 /usr/bin/ceph-mon -f --cluster ceph --id ceph-node03 --setuser ceph --setgroup ceph
```
### 4.分发配置文件到集群节点
```shell
ceph-deploy admin ceph-node01 ceph-node02 ceph-node03
```

### 4.创建Manager节点
对于Luminious+版本 或以后的版本，必须配置Manager节点，启动ceph-mgr进程，否则ceph是不健康的不完整的。Ceph Manager守护进程以“Active/Standby”模式运行，部署其它ceph-mgr守护程序可确保在Active节点或其上的 ceph-mgr守护进程故障时，其中的一个Standby实例可以在不中断服务的情况下接管其任务。 Mgr 是一个无状态的服务，所以我们可以随意添加其个数，通常而言，使用 2 个节点即可。
```shell
ceph-deploy  mgr create ceph-node01 ceph-node02
for i in ceph-node01 ceph-node02;do ssh $i "ps aux|grep ceph-mgr"|grep -v grep ; done
ceph       64369  5.8  3.1 1038164 123764 ?      Ssl  14:43   0:01 /usr/bin/ceph-mgr -f --cluster ceph --id ceph-node01 --setuser ceph --setgroup ceph
ceph       63799  5.3  3.0 740804 120220 ?       Ssl  14:43   0:01 /usr/bin/ceph-mgr -f --cluster ceph --id ceph-node02 --setuser ceph --setgroup ceph
```
### 5.配置管理节点也能查看集群
我们可以通过 `ceph -s` 命令验证， 如果没有 ceph 命令则需要安装 ceph-common ，为了能让 ceph-admin 也能执行ceph -s命令，我们需要安装 ceph-common 命令，并且通过 ceph-deploy admin推送配置文件给 ceph-admin,并设置cephadm 对 配置文件有可读权限


```shell
sudo yum install -y ceph-common
ceph-deploy admin ceph-admin
sudo setfacl -m u:cephadm:r /etc/ceph/ceph.client.admin.keyring
 ceph -s
  cluster:
    id:     d901ea94-de1d-4814-9f97-6f7ebd4329dd
    health: HEALTH_WARN
            OSD count 0 < osd_pool_default_size 3
            mons are allowing insecure global_id reclaim

  services:
    mon: 3 daemons, quorum ceph-node01,ceph-node02,ceph-node03 (age 9m)
    mgr: ceph-node01(active, since 2m), standbys: ceph-node02
    osd: 0 osds: 0 up, 0 in

  data:
    pools:   0 pools, 0 pgs
    objects: 0 objects, 0 B
    usage:   0 B used, 0 B / 0 B avail
    pgs:
# 可选操作，忽略告警
ceph health detail
HEALTH_WARN OSD count 0 < osd_pool_default_size 3; mons are allowing insecure global_id reclaim
TOO_FEW_OSDS OSD count 0 < osd_pool_default_size 3
AUTH_INSECURE_GLOBAL_ID_RECLAIM_ALLOWED mons are allowing insecure global_id reclaim
    mon.ceph-node01 has auth_allow_insecure_global_id_reclaim set to true
    mon.ceph-node02 has auth_allow_insecure_global_id_reclaim set to true
    mon.ceph-node03 has auth_allow_insecure_global_id_reclaim set to true
ceph config set mon auth_allow_insecure_global_id_reclaim false
```

### 6.添加OSD

在此 ceph 集群中，我们每台机器使用了三块硬盘 ，/dev/vda、/dev/vdb、/dev/vdc， 其中/dev/vda是系统盘，/dev/vdb、/dev/vdc,是我们接下要添加为 OSD 的磁盘
```shell
lsblk
NAME            MAJ:MIN RM   SIZE RO TYPE MOUNTPOINT
sr0              11:0    1  1024M  0 rom
vda             252:0    0    60G  0 disk
├─vda1          252:1    0     1G  0 part /boot
└─vda2          252:2    0    60G  0 part
  ├─centos-root 253:0    0  65.1G  0 lvm  /
  └─centos-swap 253:1    0   3.9G  0 lvm  [SWAP]
vdb             252:16   0    30G  0 disk
vdc             252:32   0    50G  0 disk
```
早期版本的ceph-deploy命令支持在将添加OSD的过程分为两个步骤：准备OSD和激活OSD，但新版本中，此种操作方式已经被废除。添加OSD的步骤只能由命令”ceph-deploy osd create {node} --data {data-disk}“一次完成，默认使用的存储引擎为bluestore

```shell
ceph-deploy --overwrite-conf osd create ceph-node01 --data /dev/vdb
ceph-deploy --overwrite-conf osd create ceph-node01 --data /dev/vdc
ceph-deploy --overwrite-conf osd create ceph-node02 --data /dev/vdb
ceph-deploy --overwrite-conf osd create ceph-node02 --data /dev/vdc
ceph-deploy --overwrite-conf osd create ceph-node03 --data /dev/vdb
ceph-deploy --overwrite-conf osd create ceph-node03 --data /dev/vdc
for i in ceph-node01 ceph-node02 ceph-node03;do ssh $i "ps aux|grep ceph-osd"|grep -v grep ; done
ceph       64857  0.4  0.9 874180 36668 ?        Ssl  14:54   0:00 /usr/bin/ceph-osd -f --cluster ceph --id 0 --setuser ceph --setgroup ceph
ceph       65311  0.4  1.0 874184 42636 ?        Ssl  14:54   0:00 /usr/bin/ceph-osd -f --cluster ceph --id 1 --setuser ceph --setgroup ceph
ceph       64246  0.5  0.9 874184 38040 ?        Ssl  14:55   0:00 /usr/bin/ceph-osd -f --cluster ceph --id 2 --setuser ceph --setgroup ceph
ceph       64698  0.5  1.0 874180 40384 ?        Ssl  14:55   0:00 /usr/bin/ceph-osd -f --cluster ceph --id 3 --setuser ceph --setgroup ceph
ceph       64113  0.6  0.9 874180 38532 ?        Ssl  14:55   0:00 /usr/bin/ceph-osd -f --cluster ceph --id 4 --setuser ceph --setgroup ceph
ceph       64566  0.7  1.0 874184 39960 ?        Ssl  14:56   0:00 /usr/bin/ceph-osd -f --cluster ceph --id 5 --setuser ceph --setgroup ceph
```
```shell
 ceph -s
  cluster:
    id:     d901ea94-de1d-4814-9f97-6f7ebd4329dd
    health: HEALTH_WARN
            mons are allowing insecure global_id reclaim

  services:
    mon: 3 daemons, quorum ceph-node01,ceph-node02,ceph-node03 (age 19m)
    mgr: ceph-node01(active, since 12m), standbys: ceph-node02
    osd: 6 osds: 6 up (since 7s), 6 in (since 7s)

  task status:

  data:
    pools:   0 pools, 0 pgs
    objects: 0 objects, 0 B
    usage:   6.0 GiB used, 234 GiB / 240 GiB avail
    pgs:
```
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
### 7.部署rgw用来提供对象存储

```shell
ceph-deploy rgw create ceph-node03
```
### 8.部署 MDS 用来提供 CephFS

```shell
ceph-deploy mds create ceph-node01 ceph-node02
```

### 8.部署完成

```shell
ceph -s
  cluster:
    id:     d901ea94-de1d-4814-9f97-6f7ebd4329dd
    health: HEALTH_WARN
            mons are allowing insecure global_id reclaim

  services:
    mon: 3 daemons, quorum ceph-node01,ceph-node02,ceph-node03 (age 26m)
    mgr: ceph-node01(active, since 19m), standbys: ceph-node02
    mds:  2 up:standby
    osd: 6 osds: 6 up (since 7m), 6 in (since 7m)
    rgw: 1 daemon active (ceph-node03)

  task status:

  data:
    pools:   4 pools, 128 pgs
    objects: 187 objects, 1.2 KiB
    usage:   6.0 GiB used, 234 GiB / 240 GiB avail
    pgs:     128 active+clean
 ceph health detail
HEALTH_WARN mons are allowing insecure global_id reclaim
AUTH_INSECURE_GLOBAL_ID_RECLAIM_ALLOWED mons are allowing insecure global_id reclaim
    mon.ceph-node01 has auth_allow_insecure_global_id_reclaim set to true
    mon.ceph-node02 has auth_allow_insecure_global_id_reclaim set to true
    mon.ceph-node03 has auth_allow_insecure_global_id_reclaim set to true
ceph config set mon auth_allow_insecure_global_id_reclaim false
ceph -s
  cluster:
    id:     d901ea94-de1d-4814-9f97-6f7ebd4329dd
    health: HEALTH_OK

  services:
    mon: 3 daemons, quorum ceph-node01,ceph-node02,ceph-node03 (age 28m)
    mgr: ceph-node01(active, since 21m), standbys: ceph-node02
    mds:  2 up:standby
    osd: 6 osds: 6 up (since 8m), 6 in (since 8m)
    rgw: 1 daemon active (ceph-node03)

  task status:

  data:
    pools:   4 pools, 128 pgs
    objects: 187 objects, 1.2 KiB
    usage:   6.0 GiB used, 234 GiB / 240 GiB avail
    pgs:     128 active+clean
```
