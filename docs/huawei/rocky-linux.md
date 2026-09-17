# Rocky Linux
 
??? note "[华为云镜像源](https://mirrors.huaweicloud.com/rockylinux/)"
    
    **1. 备份原有配置**
    
    ```shell
    sudo mkdir -p /etc/yum.repos.d/backup
    sudo mv /etc/yum.repos.d/rocky*.repo /etc/yum.repos.d/backup/
    ```
    
    **2. 创建华为云 repo 文件**
    
    ```shell
    cat > /etc/yum.repos.d/huawei-rocky.repo << 'EOF'
    [baseos]
    name=Rocky Linux $releasever BaseOS - Huawei Cloud
    baseurl=https://mirrors.huaweicloud.com/rockylinux/$releasever/BaseOS/$basearch/os/
    gpgcheck=1
    gpgkey=https://mirrors.huaweicloud.com/rockylinux/RPM-GPG-KEY-Rocky-$releasever
    enabled=1
    
    [appstream]
    name=Rocky Linux $releasever AppStream - Huawei Cloud
    baseurl=https://mirrors.huaweicloud.com/rockylinux/$releasever/AppStream/$basearch/os/
    gpgcheck=1
    gpgkey=https://mirrors.huaweicloud.com/rockylinux/RPM-GPG-KEY-Rocky-$releasever
    enabled=1
    
    [extras]
    name=Rocky Linux $releasever Extras - Huawei Cloud
    baseurl=https://mirrors.huaweicloud.com/rockylinux/$releasever/extras/$basearch/os/
    gpgcheck=1
    gpgkey=https://mirrors.huaweicloud.com/rockylinux/RPM-GPG-KEY-Rocky-$releasever
    enabled=1
    EOF
    ```
    
    **3. 刷新缓存并生效**
    
    ```shell
    sudo dnf clean all
    sudo dnf makecache
    ```
    
    **4. 安装epel源**
    
    ```shell
    sudo dnf install -y epel-release
    ```

    ???+ tip annotate "小技巧"
    
        如果你是在华为云 ECS 内网环境，可以把 baseurl 中的 mirrors.huaweicloud.com 替换为内网域名 mirrors.myhuaweicloud.com，速度更快且不消耗公网流量

??? note "[Docker-CE](https://mirrors.huaweicloud.com/mirrorDetail/5ea14d84b58d16ef329c5c13?mirrorName=docker-ce&catalog=docker)"
    
    ```shell
    # 配置代理
    export https_proxy=http://172.16.143.1:7897 http_proxy=http://172.16.143.1:7897 all_proxy=socks5://172.16.143.1:7897
    sudo mkdir -p /etc/systemd/system/docker.service.d
    sudo touch /etc/systemd/system/docker.service.d/proxy.conf
    cat  > /etc/systemd/system/docker.service.d/proxy.conf << EOF
    [Service]
    Environment="HTTP_PROXY=$https_proxy/"
    Environment="HTTPS_PROXY=$https_proxy/"
    Environment="NO_PROXY=localhost,127.0.0.1,.devops.io"
    EOF
    sudo systemctl daemon-reload && sudo systemctl enable docker --now
    ```