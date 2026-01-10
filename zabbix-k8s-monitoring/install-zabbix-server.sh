#!/bin/bash

# Zabbix Server 6.0 安装脚本（Ubuntu ARM 架构）
# 使用 Docker Compose 部署

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 配置变量
ZABBIX_DIR="/opt/zabbix"
ZABBIX_DATA_DIR="${ZABBIX_DIR}/data"
ZABBIX_CONFIG_DIR="/etc/zabbix"
COMPOSE_FILE="docker-compose-zabbix.yml"
ENV_FILE=".env"

# 打印带颜色的消息
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_section() {
    echo -e "\n${BLUE}=== $1 ===${NC}"
}

# 检查命令是否存在
check_command() {
    if ! command -v $1 &> /dev/null; then
        print_error "$1 未安装，请先安装 $1"
        return 1
    fi
    return 0
}

# 检查是否为 root 用户
check_root() {
    if [ "$EUID" -ne 0 ]; then 
        print_error "请使用 root 用户或 sudo 运行此脚本"
        exit 1
    fi
}

# 检查系统架构
check_architecture() {
    print_info "检查系统架构..."
    ARCH=$(uname -m)
    print_info "系统架构: $ARCH"
    
    if [[ "$ARCH" != "aarch64" && "$ARCH" != "arm64" ]]; then
        print_warn "检测到非 ARM 架构，但脚本将继续执行"
    else
        print_info "✓ ARM 架构检测通过"
    fi
}

# 安装 Docker
install_docker() {
    print_section "安装 Docker"
    
    if command -v docker &> /dev/null; then
        print_info "Docker 已安装: $(docker --version)"
        return 0
    fi
    
    print_info "开始安装 Docker..."
    
    # 更新包索引
    apt-get update
    
    # 安装依赖
    apt-get install -y \
        ca-certificates \
        curl \
        gnupg \
        lsb-release
    
    # 添加 Docker 官方 GPG 密钥
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg
    
    # 设置 Docker 仓库
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
      $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # 安装 Docker Engine
    apt-get update
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    
    # 启动 Docker 服务
    systemctl start docker
    systemctl enable docker
    
    print_info "✓ Docker 安装完成"
}

# 安装 Docker Compose
install_docker_compose() {
    print_section "安装 Docker Compose"
    
    if command -v docker compose &> /dev/null; then
        print_info "Docker Compose 已安装: $(docker compose version)"
        return 0
    fi
    
    # Docker Compose 通常随 Docker 一起安装
    # 如果没有，尝试安装旧版本
    if ! command -v docker-compose &> /dev/null; then
        print_info "安装 docker-compose..."
        apt-get install -y docker-compose
    fi
    
    print_info "✓ Docker Compose 安装完成"
}

# 创建目录结构
create_directories() {
    print_section "创建目录结构"
    
    mkdir -p ${ZABBIX_DIR}
    mkdir -p ${ZABBIX_DATA_DIR}
    mkdir -p ${ZABBIX_CONFIG_DIR}
    mkdir -p ${ZABBIX_CONFIG_DIR}/scripts
    
    print_info "✓ 目录创建完成"
}

# 配置环境变量
configure_env() {
    print_section "配置环境变量"
    
    if [ ! -f "${ZABBIX_DIR}/${ENV_FILE}" ]; then
        if [ -f ".env.example" ]; then
            cp .env.example ${ZABBIX_DIR}/${ENV_FILE}
            print_info "已从 .env.example 创建 ${ENV_FILE} 文件"
        else
            # 生成随机密码
            DB_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)
            DB_ROOT_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)
            
            cat > ${ZABBIX_DIR}/${ENV_FILE} <<EOF
# Zabbix Docker Compose 环境变量配置
# 自动生成的密码，请妥善保管

DB_PASSWORD=${DB_PASSWORD}
DB_ROOT_PASSWORD=${DB_ROOT_PASSWORD}
PHP_TZ=Asia/Shanghai
EOF
            print_info "已创建 ${ENV_FILE} 文件（包含自动生成的密码）"
            print_warn "数据库密码已保存到: ${ZABBIX_DIR}/${ENV_FILE}"
            print_warn "请妥善保管此文件！"
        fi
    else
        print_info "${ENV_FILE} 文件已存在，跳过创建"
    fi
}

# 复制配置文件
copy_config_files() {
    print_section "复制配置文件"
    
    # 复制 docker-compose 文件
    if [ -f "${COMPOSE_FILE}" ]; then
        cp ${COMPOSE_FILE} ${ZABBIX_DIR}/docker-compose.yml
        print_info "✓ docker-compose.yml 已复制"
    else
        print_error "${COMPOSE_FILE} 文件不存在"
        exit 1
    fi
    
    # 复制 Zabbix Agent 2 配置文件（如果存在）
    if [ -f "zabbix-agent2.conf" ]; then
        cp zabbix-agent2.conf ${ZABBIX_CONFIG_DIR}/zabbix_agent2.conf
        print_info "✓ zabbix-agent2.conf 已复制"
    fi
    
    print_info "✓ 配置文件复制完成"
}

# 初始化数据库
init_database() {
    print_section "初始化数据库"
    
    print_info "启动数据库容器..."
    cd ${ZABBIX_DIR}
    docker compose up -d zabbix-db
    
    print_info "等待数据库启动..."
    sleep 10
    
    # 检查数据库是否就绪
    for i in {1..30}; do
        if docker compose exec -T zabbix-db mysqladmin ping -h localhost --silent 2>/dev/null; then
            print_info "✓ 数据库已就绪"
            return 0
        fi
        print_info "等待数据库启动... ($i/30)"
        sleep 2
    done
    
    print_error "数据库启动超时"
    return 1
}

# 启动 Zabbix 服务
start_zabbix() {
    print_section "启动 Zabbix 服务"
    
    cd ${ZABBIX_DIR}
    
    print_info "启动所有服务..."
    docker compose up -d
    
    print_info "等待服务启动..."
    sleep 15
    
    # 检查服务状态
    print_info "检查服务状态..."
    docker compose ps
    
    print_info "✓ Zabbix 服务启动完成"
}

# 显示访问信息
show_access_info() {
    print_section "访问信息"
    
    # 获取服务器 IP
    SERVER_IP=$(hostname -I | awk '{print $1}')
    
    echo -e "${GREEN}"
    echo "=========================================="
    echo "  Zabbix Server 安装完成！"
    echo "=========================================="
    echo -e "${NC}"
    
    print_info "Zabbix Web 界面访问地址:"
    echo -e "  ${GREEN}http://${SERVER_IP}${NC}"
    echo -e "  或 ${GREEN}http://localhost${NC}"
    
    print_info "默认登录信息:"
    echo -e "  用户名: ${GREEN}Admin${NC}"
    echo -e "  密码: ${GREEN}zabbix${NC}"
    echo -e "  ${YELLOW}（首次登录后请立即修改密码！）${NC}"
    
    print_info "数据库信息:"
    echo -e "  主机: ${GREEN}localhost:3306${NC}"
    echo -e "  数据库: ${GREEN}zabbix${NC}"
    echo -e "  用户名: ${GREEN}zabbix${NC}"
    echo -e "  密码: 查看 ${ZABBIX_DIR}/${ENV_FILE} 文件中的 DB_PASSWORD"
    
    print_info "服务管理命令:"
    echo -e "  启动: ${GREEN}cd ${ZABBIX_DIR} && docker compose up -d${NC}"
    echo -e "  停止: ${GREEN}cd ${ZABBIX_DIR} && docker compose down${NC}"
    echo -e "  查看日志: ${GREEN}cd ${ZABBIX_DIR} && docker compose logs -f${NC}"
    echo -e "  查看状态: ${GREEN}cd ${ZABBIX_DIR} && docker compose ps${NC}"
    
    print_warn "重要提示:"
    echo -e "  1. 请立即修改默认密码"
    echo -e "  2. 请妥善保管 ${ZABBIX_DIR}/${ENV_FILE} 文件"
    echo -e "  3. 生产环境请修改数据库密码"
}

# 主函数
main() {
    echo -e "${BLUE}"
    echo "=========================================="
    echo "  Zabbix Server 6.0 安装脚本"
    echo "  Ubuntu ARM 架构"
    echo "=========================================="
    echo -e "${NC}"
    
    # 检查前置条件
    check_root
    check_architecture
    
    # 安装依赖
    install_docker
    install_docker_compose
    
    # 创建目录
    create_directories
    
    # 配置环境
    configure_env
    
    # 复制配置文件
    copy_config_files
    
    # 初始化数据库
    init_database
    
    # 启动服务
    start_zabbix
    
    # 显示访问信息
    show_access_info
    
    print_section "安装完成"
    print_info "下一步："
    print_info "1. 访问 Zabbix Web 界面并修改默认密码"
    print_info "2. 导入 Kubernetes 监控模板"
    print_info "3. 配置 Kubernetes 监控（运行 ./deploy.sh）"
}

# 运行主函数
main

