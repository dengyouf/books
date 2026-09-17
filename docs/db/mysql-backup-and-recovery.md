# 备份恢复

## 逻辑备份和恢复

!!! info "逻辑备份是 CREATE 和 INSERT 等SQL 语句"
    
    > mysqldump 的输出重定向到一个 .sql 文件

    - 简单、跨版本兼容性好、输出可读可编辑
    - 备份和恢复速度相对较慢，不适合超大规模数据
    
    | 参数| 作用 | 
    | --- | --- |
    | `--databases` |  备份指定的数据库, 备份文件里已包含 CREATE DATABASE 和 USE 语句，恢复时不需要提前建库，也不用指定数据库名|
    | `--all-databases` | 备份所有数据库，含 mysql 系统库，但通常不会备份 information_schema、performance_schema 和 sys 这几个库｜
    | `--ignore-table`|  排除掉不想导的库 |
    | `--single-transaction` | 对 InnoDB 表开启一致性快照，不锁表，不影响线上读写 |
    | `--no-data` | 只导出表结构，不导数据|
    | --quick | 逐行读取，避免大表把内存撑爆 |
    | `--routines` | 备份存储过程、函数 |
    |`--events` | 备份存事件调度器 |
    |`--triggers`|备份触发器|
    

??? example "备份单个数据库"

    ```shell
    # 恢复时，需要提前创建数据库
    mysqldump -uroot \
      -prootPwd \
      --single-transaction \
      --quick   \
      --routines   \
      --events   \
      --triggers  \
      --set-gtid-purged=OFF \
      hellodb  | gzip > backup_$(date +%F).sql.gz
    ```
 
??? example "备份多个数据库"

    ```shell
    # 用 --databases，文件里会包含 CREATE DATABASE
    mysqldump \
      -uroot \
      -prootPwd \
      --single-transaction \
      --quick   \
      --routines \
      --events  \
      --triggers \
      --databases hellodb  mysql | gzip > backup_$(date +%F).sql.gz
    ```

??? example "备份所有数据库"

    ```shell
    mysqldump \
      -uroot \
      -prootPwd \
      --single-transaction \
      --quick   \
      --routines \
      --events \
      --triggers \
      --all-databases | gzip > backup_$(date +%F).sql.gz
    ```

??? example "只备份某几张表"
    
    ```shell
    # 不含 create 语句
    mysqldump \
      -uroot \
      -prootPwd \
      --single-transaction \
      --quick \
      --routines \
      --events \
      --triggers  hellodb students teachers| gzip > backup_$(date +%F).sql.gz
    ```

??? example "恢复备份"

    ```shell
    # 如果备份含有 create dabase，则不需要指定数据库
    # 写法一：gunzip 解压后管道给 mysql
    gunzip < backup_2026-09-17.sql.gz | mysql -uroot -prootPwd 
    # 写法二：zcat 直接流式解压
    zcat backup_2026-09-17.sql.gz | mysql -uroot -prootPwd hellodb
    ```

## 物理备份和恢复

!!! info "物理备份是数据目录和文件的原始副本"
    
    > 生产中主要使用 Percona XtraBackup

    - 速度快、热备份，不阻塞写
    - 物理备份适合大型、繁忙、对恢复速度要求高的库

    !!! warning "Percona 官方明确要求 XtraBackup 必须与 MySQL 严格版本配对：PXB 8.4 对应 MySQL 8.4"


??? example "Percona XtraBackup from Percona yum repository"
    

    ```shell
    # percona-xtrabackup-24 对应的是 XtraBackup 2.4，它只支持 MySQL 5.6 和 5.7。
    # Percona 官方明确要求 XtraBackup 必须与 MySQL 严格版本配对：PXB 8.4 对应 MySQL 8.4。混用大版本会静默产生损坏的备份
    sudo yum install -y https://repo.percona.com/yum/percona-release-latest.noarch.rpm
    #sudo percona-release enable-only pxb-84-lts
    sudo percona-release setup -y pxb-84-lts
    sudo yum install -y percona-xtrabackup-84
    xtrabackup --version
    ```

??? example "完全备份&恢复"

    !!! info "备份"
        
        ```shell
        # 备份
        mkdir -pv  /data/backup
        xtrabackup --backup --target-dir=/data/backup/full --user=root --password=rootPwd
        ...
        26-09-17T23:35:57.549616+08:00 0 [Note] [MY-011825] [Xtrabackup] MySQL binlog position: filename 'binlog.000003', position '158'
        2026-09-17T23:35:57.549666+08:00 0 [Note] [MY-011825] [Xtrabackup] Writing /data/backup/full/backup-my.cnf
        2026-09-17T23:35:57.549769+08:00 0 [Note] [MY-011825] [Xtrabackup] Done: Writing file /data/backup/full/backup-my.cnf
        2026-09-17T23:35:57.550536+08:00 0 [Note] [MY-011825] [Xtrabackup] Writing /data/backup/full/xtrabackup_info
        2026-09-17T23:35:57.550815+08:00 0 [Note] [MY-011825] [Xtrabackup] Done: Writing file /data/backup/full/xtrabackup_info
        2026-09-17T23:35:57.551300+08:00 0 [Note] [MY-011825] [Xtrabackup] Backup size: 74.43 MiB (78050341 bytes)
        2026-09-17T23:35:58.551730+08:00 0 [Note] [MY-011825] [Xtrabackup] Transaction log of lsn (19516730) to (19516730) was copied.
        2026-09-17T23:35:58.759349+08:00 0 [Note] [MY-011825] [Xtrabackup] completed OK!
        ```
    !!! info "恢复"

    ```shell
    # 确保要恢复的数据库为启动，且数据目录为空
    systemctl  stop mysqld
    rm -rf /var/lib/mysql/*
    # copy 备份文件到本机
    rsync -avP root@172.16.143.131:/data/backup/full /data/backup
    # 使用--prepare 对备份过来的数据进行整理
    xtrabackup --prepare --target-dir=/data/backup/full
    ...
    2026-09-17T23:38:36.462501+08:00 0 [Note] [MY-011825] [Xtrabackup] Time taken to build dictionary: 0.0152444 seconds
    2026-09-17T23:38:37.467534+08:00 0 [Note] [MY-011825] [Xtrabackup] starting shutdown with innodb_fast_shutdown = 1
    2026-09-17T23:38:37.467953+08:00 0 [Note] [MY-012330] [InnoDB] FTS optimize thread exiting.
    2026-09-17T23:38:38.463906+08:00 0 [Note] [MY-013072] [InnoDB] Starting shutdown...
    2026-09-17T23:38:38.565846+08:00 0 [Note] [MY-013084] [InnoDB] Log background threads are being closed...
    2026-09-17T23:38:38.578524+08:00 0 [Note] [MY-012980] [InnoDB] Shutdown completed; log sequence number 19516950
    2026-09-17T23:38:38.580878+08:00 0 [Note] [MY-015019] [Server] MySQL Server: Plugins Shutdown - start.
    2026-09-17T23:38:38.580928+08:00 0 [Note] [MY-015020] [Server] MySQL Server: Plugins Shutdown - end.
    2026-09-17T23:38:38.581371+08:00 0 [Note] [MY-011825] [Xtrabackup] completed OK!
    #  恢复备份到数据目录
    xtrabackup --copy-back --target-dir=/data/backup/full --datadir=/var/lib/mysql
    ...
    2026-09-17T23:38:38.565846+08:00 0 [Note] [MY-013084] [InnoDB] Log background threads are being closed...
    2026-09-17T23:38:38.578524+08:00 0 [Note] [MY-012980] [InnoDB] Shutdown completed; log sequence number 19516950
    2026-09-17T23:38:38.580878+08:00 0 [Note] [MY-015019] [Server] MySQL Server: Plugins Shutdown - start.
    2026-09-17T23:38:38.580928+08:00 0 [Note] [MY-015020] [Server] MySQL Server: Plugins Shutdown - end.
    2026-09-17T23:38:38.581371+08:00 0 [Note] [MY-011825] [Xtrabackup] completed OK!
    # 修复权限（关键，否则 MySQL 无法启动）
    chown -R mysql:mysql /var/lib/mysql
    # 启动 MySQL
    systemctl start mysqld
    ```

??? example "完全备份+增量备份&恢复"
    
    !!! info "备份"
    
        ```shell
        # 创建完全备份（基准）
        xtrabackup --backup --target-dir=/data/backup/full
        # 第一次增量：基于 full
        xtrabackup --backup \
          --target-dir=/data/backup/inc1 \
          --incremental-basedir=/data/backup/full
        # 第二次增量：基于 inc1
        xtrabackup --backup \
          --target-dir=/data/backup/inc2 \
          --incremental-basedir=/data/backup/inc1
        # 第三次增量：基于 inc2
        xtrabackup --backup \
          --target-dir=/data/backup/inc3 \
          --incremental-basedir=/data/backup/inc2
        ```
   
    !!! info "恢复"
   
        ```shell
        # # 整理全量（只前滚，不回滚）
        xtrabackup --prepare --apply-log-only --target-dir=/data/backup/full
        # 合并 inc1（--apply-log-only : 它阻止的是未提交事务的回滚（rollback））
        xtrabackup --prepare --apply-log-only \
          --target-dir=/data/backup/full \
          --incremental-dir=/data/backup/inc1
        # 合并 inc2（--apply-log-only : 阻止的是未提交事务的回滚（rollback））
        xtrabackup --prepare --apply-log-only \
          --target-dir=/data/backup/full \
          --incremental-dir=/data/backup/inc2
          
        #合并 inc3（最后一次，去掉 apply-log-only，执行完整恢复）
        xtrabackup --prepare \
          --target-dir=/data/backup/full \
          --incremental-dir=/data/backup/inc3
          
        # 恢复备份
        systemctl stop mysqld
        rm -rf /var/lib/mysql/*   # 危险操作，确认路径
        xtrabackup --copy-back --target-dir=/data/backup/full
        chown -R mysql:mysql /var/lib/mysql
        systemctl start mysqld
        ```