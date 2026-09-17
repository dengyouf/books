## MySQL服务安装

!!! info "在 Rocky Linux 10上安装 MySQL Server 8.4.11"
    
    - OS: Rocky Linux release 10.2 (Red Quartz)
    - MySQL: 8.4.11


=== "Yum"
    
    ??? example "使用Yum源安装"

        ```shell
        wget https://dev.mysql.com/get/mysql84-community-release-el10-3.noarch.rpm
        sudo dnf install mysql84-community-release-el10-3.noarch.rpm
        # 禁用 9.7 相关的源
        sudo dnf config-manager --disable mysql-9.7-lts-community mysql-tools-9.7-lts-community
        # 启用 8.4 相关的源
        sudo dnf config-manager --enable mysql-8.4-lts-community mysql-tools-8.4-lts-community
        # 
        sudo dnf install -y mysql-community-server --setopt=install_weak_deps=False
        
        # 启动服务
        sudo systemctl  start  mysqld
        sudo grep 'temporary password' /var/log/mysqld.log
        2026-09-16T10:14:47.625949Z 6 [Note] [MY-010454] [Server] A temporary password is generated for root@localhost: y*f,?=MA7nTi
        # 修改密码
        mysql -uroot -p"y*f,?=MA7nTi"
        mysql: [Warning] Using a password on the command line interface can be insecure.
        Welcome to the MySQL monitor.  Commands end with ; or \g.
        Your MySQL connection id is 12
        Server version: 8.4.11
        
        Copyright (c) 2000, 2026, Oracle and/or its affiliates.
        
        Oracle is a registered trademark of Oracle Corporation and/or its
        affiliates. Other names may be trademarks of their respective
        owners.
        
        Type 'help;' or '\h' for help. Type '\c' to clear the current input statement.
        
        mysql> ALTER USER 'root'@'localhost' IDENTIFIED BY 'Rocky@2026#MySQL';
        
        # 临时降低密码策略（仅测试环境）
        -- 查看当前策略
        SHOW VARIABLES LIKE 'validate_password%';
        -- 将策略降为 LOW（只检查长度），长度设为 6
        SET GLOBAL validate_password.policy = LOW;
        SET GLOBAL validate_password.length = 6;
        -- 现在可以设置简单密码了
        ALTER USER 'root'@'localhost' IDENTIFIED BY 'rootPwd';
        ```

=== "Generic Binaries"

    ??? example "通用二进制安装"
    
        ```shell
        # 安装依赖包
        sudo dnf install libaio ncurses-compat-libs
        # 准备用户
        sudo groupadd -r  -g 27 mysql
        sudo useradd -r -m -g 27 -u 27 -d /data/mysql mysql
        # 准备程序文件
        sudo wget https://dev.mysql.com/get/Downloads/MySQL-8.4/mysql-8.4.11-linux-glibc2.28-x86_64.tar.xz
        sudo tar -xf mysql-8.4.11-linux-glibc2.28-x86_64.tar.xz  -C /usr/local/
        sudo ln -sv /usr/local/mysql-8.4.11-linux-glibc2.28-x86_64/ /usr/local/mysql
        sudo  chown -R mysql:mysql /usr/local/mysql*
        # 准备环境变量
        sudo echo "PATH=/usr/local/mysql/bin:$PATH" > /etc/profile.d/mysql.sh
        sudo source /etc/profile.d/mysql.sh
        # 准备配置文件
        cat  > /etc/my.cnf << EOF
        [client]
        socket = /data/mysql/run/mysql.sock
        loose-default-character-set = utf8mb4
        [mysqld_safe]
        user = mysql
        nice = 0
        [mysqld]
        ########## 基础与路径 ##########
        user = mysql
        datadir = /data/mysql/data
        socket = /data/mysql/run/mysql.sock
        log-error = /data/mysql/logs/mysqld.log
        pid-file = /data/mysql/run/mysqld.pid
        tmpdir = /data/mysql/tmp
        ########## 字符集与排序规则 ##########
        character_set_server = utf8mb4
        collation_server = utf8mb4_0900_ai_ci
        explicit_defaults_for_timestamp = ON
        ########## 时区与端口 ##########
        default-time-zone = '+8:00'
        port = 3306
        bind-address = 0.0.0.0
        ########## 连接与线程 ##########
        max_connections = 500
        max_connect_errors = 1000000
        thread_cache_size = 64
        open_files_limit = 65535
        back_log = 1024
        interactive_timeout = 600
        wait_timeout = 600
        lock_wait_timeout = 300
        ########## InnoDB 内存与缓冲池 ##########
        innodb_buffer_pool_size = 10G
        innodb_buffer_pool_instances = 8
        innodb_redo_log_capacity = 2G
        ########## InnoDB 磁盘 I/O ##########
        innodb_io_capacity = 2000
        innodb_io_capacity_max = 4000
        innodb_flush_method = O_DIRECT
        innodb_flush_log_at_trx_commit = 1
        innodb_thread_concurrency = 0
        innodb_file_per_table = ON
        innodb_temp_data_file_path = ibtmp1:12M:autoextend:max:5G
        ########## 会话级缓冲区 ##########
        sort_buffer_size = 4M
        join_buffer_size = 4M
        read_buffer_size = 2M
        read_rnd_buffer_size = 4M
        tmp_table_size = 64M
        max_heap_table_size = 64M
        ########## 表缓存 ##########
        table_open_cache = 4000
        table_definition_cache = 2000
        table_open_cache_instances = 16
        ########## 事务隔离与 SQL 模式 ##########
        transaction_isolation = READ-COMMITTED
        sql_mode = STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION
        ########## 日志与诊断 ##########
        log_error_verbosity = 3
        innodb_print_ddl_logs = ON
        performance_schema = ON
        ########## 慢查询日志 ##########
        slow_query_log = ON
        slow_query_log_file = /data/mysql/logs/mysql-slow.log
        long_query_time = 1
        log_queries_not_using_indexes = ON
        ########## 安全相关 ##########
        local_infile = OFF
        skip_name_resolve = ON
        secure_file_priv = /data/mysql/mysql-files
        # mysqlx = 0
        ########## Binlog 配置（新增） ##########
        log-bin = /data/mysql/logs/mysql-bin
        server-id = 3306
        binlog_format = ROW
        binlog_row_image = FULL
        binlog_expire_logs_seconds = 604800
        max_binlog_size = 500M
        sync_binlog = 1
        EOF
        sudo chmod 644 /etc/my.cnf
        # 创建目录并授权
        sudo mkdir -p /data/mysql/{data,logs,run,mysql-files,tmp}
        sudo chown -R mysql:mysql /data/mysql
        sudo chmod 750 /data/mysql /data/mysql/{data,logs,run,mysql-files,tmp}
        # 初始化数据库文件和初始密码
        mysqld --initialize --user=mysql --datadir=/data/mysql/data/
        grep 'temporary password' /data/mysql/logs/mysqld.log
        2026-09-16T11:35:44.808333Z 6 [Note] [MY-010454] [Server] A temporary password is generated for root@localhost: Jq<ip-wCt9a.
        # 提供启动文件
        cat > /etc/systemd/system/mysqld.service << EOF
        [Unit]
        Description=MySQL 8.4 database server (custom data paths)
        Documentation=man:mysqld(8)
        Documentation=http://dev.mysql.com/doc/refman/en/using-systemd.html
        After=network.target
        After=syslog.target
        [Install]
        WantedBy=multi-user.target
        [Service]
        User=mysql
        Group=mysql
        # 指定使用自定义的配置文件
        ExecStart=/usr/local/mysql/bin/mysqld --defaults-file=/etc/my.cnf --user=mysql
        PIDFile=/data/mysql/run/mysqld.pid
        # 服务启动类型，对于 MySQL 8.4 官方推荐使用 notify
        Type=notify
        # 如果启动失败或异常退出，自动重启
        Restart=on-failure
        RestartPreventExitStatus=1
        # 文件描述符限制，与你的 my.cnf 中 open_files_limit 保持一致
        LimitNOFILE=65535
        # 给足启动和关闭的时间
        TimeoutSec=300
        # 避免临时文件放在 /tmp
        PrivateTmp=true
        [Install]
        WantedBy=multi-user.target
        EOF
        # 启动服务
        systemctl  daemon-reload
        systemctl  start mysqld
        # 修改密码
        mysql -uroot -p'Jq<ip-wCt9a.'
        ALTER USER 'root'@'localhost' IDENTIFIED BY 'Rocky@2026#MySQL';
        -- 查看当前策略（临时降低密码策略）（仅测试环境）
        SHOW VARIABLES LIKE 'validate_password%';
        -- 将策略降为 LOW（只检查长度），长度设为 6
        SET GLOBAL validate_password.policy = LOW;
        SET GLOBAL validate_password.length = 6;
        -- 现在可以设置简单密码了
        ALTER USER 'root'@'localhost' IDENTIFIED BY 'rootPwd';
        ```

=== "Container"
    
    ??? example "容器安装"
    
        ```shell
        mkdir -pv  /data/apps/mysql && cd /data/apps/mysql
        mkdir -p ./mysql_data ./mysql_conf ./init
        chmod 777 ./mysql_data  # 首次启动必需，容器内 mysql 用户 UID 通常为 999
        cat > docker-compose.yml << EOF
        services:
          mysql:
            image: mysql:8.4.11
            container_name: mysql8.4
            restart: unless-stopped
            environment:
              MYSQL_ROOT_PASSWORD: "YourStrong@RootPwd123"
              MYSQL_DATABASE: "app_db"
              MYSQL_USER: "app_user"
              MYSQL_PASSWORD: "YourStrong@UserPwd123"
              TZ: "Asia/Shanghai"
            ports:
              - "3306:3306"
            volumes:
              - ./mysql_data:/var/lib/mysql
              - ./mysql_conf:/etc/mysql/conf.d
              - ./init:/docker-entrypoint-initdb.d
            command:
              - --character-set-server=utf8mb4
              - --collation-server=utf8mb4_unicode_ci
              - --lower_case_table_names=1
              - --max_connections=500
              - --innodb_buffer_pool_size=1G
            healthcheck:
              test: ["CMD-SHELL", "MYSQL_PWD=$$MYSQL_ROOT_PASSWORD mysqladmin ping -h 127.0.0.1"]
              interval: 10s
              timeout: 5s
              retries: 10
              start_period: 40s
        EOF
        docker compose up -d
        ```
## MySQL多实例安装

!!! info "使用二进制的方式，安装在一台服务器上安装多个MySQL多实例，能有效利用服务器资源。"

??? example "1. 准备实例目录"
    
    ```shell
    mkdir -pv  /data/apps/mysql/{3306,3307,3308}/{data,etc,bin,logs,run,mysql-files,tmp}
    tree /data/apps/mysql/
    /data/apps/mysql/
    ├── 3306
    │   ├── bin
    │   ├── data
    │   ├── etc
    │   ├── logs
    │   ├── mysql-files
    │   ├── run
    │   └── tmp
    ├── 3307
    │   ├── bin
    │   ├── data
    │   ├── etc
    │   ├── logs
    │   ├── mysql-files
    │   ├── run
    │   └── tmp
    └── 3308
        ├── bin
        ├── data
        ├── etc
        ├── logs
        ├── mysql-files
        ├── run
        └── tmp
    ```

??? example "2. 准备mysqld程序"

    ```shell
    for port in 3306 3307 3308; do
      cp -f /usr/sbin/mysqld /data/apps/mysql/$port/bin/
    done
    ```

??? example "3. 准备配置文件"
    
    ```shell
    cat  > /data/apps/mysql/3306/etc/my.cnf << EOF
    [client]
    socket = /data/apps/mysql/3306/run/mysql.sock
    default-character-set = utf8mb4
    [mysqld_safe]
    user = mysql
    nice = 0
    [mysqld]
    ########## 基础与路径 ##########
    user = mysql
    datadir = /data/apps/mysql/3306/data
    socket = /data/apps/mysql/3306/run/mysql.sock
    log-error = /data/apps/mysql/3306/logs/mysqld.log
    pid-file = /data/apps/mysql/3306/run/mysqld.pid
    tmpdir = /data/apps/mysql/3306/tmp
    ########## 字符集与排序规则 ##########
    character_set_server = utf8mb4
    collation_server = utf8mb4_0900_ai_ci
    explicit_defaults_for_timestamp = ON
    ########## 时区与端口 ##########
    default-time-zone = '+8:00'
    port = 3306
    bind-address = 0.0.0.0
    ########## 连接与线程 ##########
    max_connections = 500
    max_connect_errors = 1000000
    thread_cache_size = 64
    open_files_limit = 65535
    back_log = 1024
    interactive_timeout = 600
    wait_timeout = 600
    lock_wait_timeout = 300
    ########## InnoDB 内存与缓冲池 ##########
    innodb_buffer_pool_size = 10G
    innodb_buffer_pool_instances = 8
    innodb_redo_log_capacity = 2G
    ########## InnoDB 磁盘 I/O ##########
    innodb_io_capacity = 2000
    innodb_io_capacity_max = 4000
    innodb_flush_method = O_DIRECT
    innodb_flush_log_at_trx_commit = 1
    innodb_thread_concurrency = 0
    innodb_file_per_table = ON
    innodb_temp_data_file_path = ibtmp1:12M:autoextend:max:5G
    ########## 会话级缓冲区 ##########
    sort_buffer_size = 4M
    join_buffer_size = 4M
    read_buffer_size = 2M
    read_rnd_buffer_size = 4M
    tmp_table_size = 64M
    max_heap_table_size = 64M
    ########## 表缓存 ##########
    table_open_cache = 4000
    table_definition_cache = 2000
    table_open_cache_instances = 16
    ########## 事务隔离与 SQL 模式 ##########
    transaction_isolation = READ-COMMITTED
    sql_mode = STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION
    ########## 日志与诊断 ##########
    log_error_verbosity = 3
    innodb_print_ddl_logs = ON
    performance_schema = ON
    ########## 慢查询日志 ##########
    slow_query_log = ON
    slow_query_log_file = /data/apps/mysql/3306/logs/mysql-slow.log
    long_query_time = 1
    log_queries_not_using_indexes = ON
    ########## 安全相关 ##########
    local_infile = OFF
    skip_name_resolve = ON
    secure_file_priv = /data/apps/mysql/3306/mysql-files
    # mysqlx = 0
    ########## Binlog 配置（新增） ##########
    log-bin = /data/apps/mysql/3306/logs/mysql-bin
    server-id = 3306
    binlog_format = ROW
    binlog_row_image = FULL
    binlog_expire_logs_seconds = 604800
    max_binlog_size = 500M
    sync_binlog = 1
    EOF
    sed 's@3306@3307@g' /data/apps/mysql/3306/etc/my.cnf > /data/apps/mysql/3307/etc/my.cnf
    sed 's@3306@3308@g' /data/apps/mysql/3306/etc/my.cnf > /data/apps/mysql/3308/etc/my.cnf
    ```

??? example "4. 初始化数据库文件"
    
    ```shell
    chown -R mysql:mysql  /data/apps/mysql/
    for port in 3306 3307 3308; do
      mysqld --defaults-file=/data/apps/mysql/$port/etc/my.cnf --initialize --user=mysql --datadir=/data/apps/mysql/$port/data
    done
    for port in 3306 3307 3308; do
      grep 'temporary password' /data/apps/mysql/$port/logs/mysqld.log
    done
    2026-09-16T12:46:09.501863Z 6 [Note] [MY-010454] [Server] A temporary password is generated for root@localhost: gGHussWhV3<q
    2026-09-16T12:46:12.918990Z 6 [Note] [MY-010454] [Server] A temporary password is generated for root@localhost: XEua*yuEk4==
    2026-09-16T12:46:16.429273Z 6 [Note] [MY-010454] [Server] A temporary password is generated for root@localhost: #jVtHLnhR92d
    ```

??? example "5. 提供启动文件"
    
    ```shell
    cat > /etc/systemd/system/mysqld3306.service << EOF
    [Unit]
    Description=MySQL 8.4 database server (custom data paths)
    Documentation=man:mysqld(8)
    Documentation=http://dev.mysql.com/doc/refman/en/using-systemd.html
    After=network.target
    After=syslog.target
    [Install]
    WantedBy=multi-user.target
    [Service]
    User=mysql
    Group=mysql
    # 指定使用自定义的配置文件
    ExecStart=/data/apps/mysql/3306/bin/mysqld --defaults-file=/data/apps/mysql/3306/etc/my.cnf --user=mysql
    PIDFile=/data/apps/mysql/3306/run/mysqld.pid
    # 服务启动类型，对于 MySQL 8.4 官方推荐使用 notify
    Type=notify
    # 如果启动失败或异常退出，自动重启
    Restart=on-failure
    RestartPreventExitStatus=1
    # 文件描述符限制，与你的 my.cnf 中 open_files_limit 保持一致
    LimitNOFILE=65535
    # 给足启动和关闭的时间
    TimeoutSec=300
    # 避免临时文件放在 /tmp
    PrivateTmp=true
    [Install]
    WantedBy=multi-user.target
    EOF
    
    sed "s@3306@3307@g" /etc/systemd/system/mysqld3306.service > /etc/systemd/system/mysqld3307.service
    sed "s@3306@3308@g" /etc/systemd/system/mysqld3306.service > /etc/systemd/system/mysqld3308.service
    systemctl  daemon-reload 
    systemctl enable mysqld3306 --now
    systemctl enable mysqld3307 --now
    systemctl enable mysqld3308 --now
    ```

## MySQL主从复制

!!! 主从复制原理
    
    > **主库把变更写进 binlog，从库拉过来重放一遍**

    ```shell
            主库 (Master)                        从库 (Slave/Replica)
        ┌─────────────────┐                  ┌─────────────────────┐
        │  客户端写入      │                  │                     │
        │      ↓          │                  │   SQL Thread        │
        │  Binlog (二进制日志) │ ──网络传输──→ │      ↑              │
        │      ↑          │                  │  Relay Log (中继日志) │
        │  dump thread    │                  │      ↑              │
        └─────────────────┘                  │  IO Thread          │
                                             └─────────────────────┘
    ```

    | 步骤| 作用|
    | --- | --- |
    | 第 1 步：主库产生 binlog | 客户端执行 UPDATE users SET name='Tom' WHERE id=1;，主库在事务提交前把变更写入 binlog（sync_binlog=1 时刷盘）|
    | 第 2 步：Dump 线程推送 | 主库的 dump 线程检测到 binlog 有新内容，把 event 推给从库的 IO 线程|
    | 第 3 步：IO 线程写入 relay log|从库 IO 线程收到 event 后，先写入本地的 relay log（中继日志），并更新 master.info（记录已拉取到主库的哪个 binlog 位置）|
    | 第 4 步：SQL 线程重放 |从库 SQL 线程读取 relay log，解析成具体的 SQL 或行变更，在从库执行，并更新 relay-log.info（记录已重放到哪个位置）|

!!! example "配置过程"
    
    ??? info "主库开启二进制日志"
    
        ```shell
        [mysqld]
        # 主库的唯一标识，整数即可，集群内不能重复
        server-id = 131
        # 开启二进制日志，指定日志文件前缀（关键）
        log-bin = mysql-bin
        # 二进制日志格式，强烈建议使用 ROW 保证主从一致性
        binlog_format = ROW
        ```
        !!! warning "必须重启 MySQL 服务使配置生效"
    ??? info "主库创建一个仅具备 REPLICATION SLAVE 权限的账号"

        ```shell
        CREATE USER 'repl'@'%' IDENTIFIED BY 'rootPwd@123';
        GRANT REPLICATION SLAVE ON *.* TO 'repl'@'%';
        FLUSH PRIVILEGES;
        ```
    ??? info "获取主库二进制日志坐标"

        ??? warning "业务允许短暂只读，执行 FLUSH TABLES WITH READ LOCK 后再记录坐标"
    
            ```shell 
            FLUSH TABLES WITH READ LOCK;  -- 短暂锁定，确保坐标一致
            SHOW BINARY LOG STATUS;
            +---------------+----------+--------------+------------------+-------------------+
            | File          | Position | Binlog_Do_DB | Binlog_Ignore_DB | Executed_Gtid_Set |
            +---------------+----------+--------------+------------------+-------------------+
            | binlog.000003 |      858 |              |                  |                   |
            +---------------+----------+--------------+------------------+-------------------+
            1 row in set (0.00 sec)
            UNLOCK TABLES
            ```
        ??? warning "对一个正在运行的服务器搭建主从复制的标准做法"
            
            ```shell
            # 使用mysqldump进行备份,然后恢复到从库，在根据坐标进行主从配置
            mysqldump --source-data=2 --single-transaction \
              --routines --triggers --events \
              -u root -p \
              --all-databases > /tmp/full_backup.sql
            # 将备份恢复到从库
            mysql -uroot -prootPwd < full_backup.sql
            # 获取主库二进制日志坐标
            grep -o "SOURCE_LOG_FILE='[^']*'.*SOURCE_LOG_POS=[0-9]*" /tmp/full_backup.sql
            SOURCE_LOG_FILE='binlog.000003', SOURCE_LOG_POS=858
            ```

    ??? info "从库启动复制"
        
        ```shell
        select @@server_id;
        +-------------+
        | @@server_id |
        +-------------+
        |         133 |
        +-------------+
        # 告诉从库「主库是谁、用什么账号连、从哪个位点开始同步、要不要加密」
        CHANGE REPLICATION SOURCE TO
          SOURCE_HOST='172.16.143.131',
          SOURCE_USER='repl',
          SOURCE_PASSWORD='rootPwd@123',
          SOURCE_LOG_FILE='mysql-bin.000003',
          SOURCE_LOG_POS=858,
          SOURCE_SSL=1;
        # 启动从库的两个复制线程。
        START REPLICA;
        # 查看从库当前的复制状态
        SHOW REPLICA STATUS\G
    
        ```
        | 参数 | 说明 |
        | --- | --- |
        |SOURCE_HOST|主库的 IP 地址
        |SOURCE_USER|复制专用账号（之前 GRANT REPLICATION SLAVE 建的那个）
        |SOURCE_PASSWORD|该账号的密码
        |SOURCE_LOG_FILE|从主库的哪个 binlog 文件开始读
        |SOURCE_LOG_POS|从这个文件的哪个字节位置开始读
        |SOURCE_SSL=1|使用 TLS 加密连接，解决 caching_sha2_password 的认证要求
        
        !!! warning "只要 Replica_IO_Running 和 Replica_SQL_Running 都是 Yes，且两个 Errno 都是 0，就说明主从复制正常"