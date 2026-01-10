#!/bin/bash

# Zabbix Kubernetes 监控部署脚本
# 用于部署 Zabbix 6.0 监控 Kubernetes 1.31.6 的配置

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 配置变量
K8S_NAMESPACE="kube-system"
SA_NAME="zabbix-monitoring-sa"
ZABBIX_CONFIG_DIR="/etc/zabbix"
ZABBIX_SCRIPTS_DIR="/etc/zabbix/scripts"
ZABBIX_AGENT2_CONF="/etc/zabbix/zabbix_agent2.conf"

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

# 检查命令是否存在
check_command() {
    if ! command -v $1 &> /dev/null; then
        print_error "$1 未安装，请先安装 $1"
        exit 1
    fi
}

# 检查是否为 root 用户
check_root() {
    if [ "$EUID" -ne 0 ]; then 
        print_error "请使用 root 用户运行此脚本"
        exit 1
    fi
}

# 检查 Kubernetes 连接
check_k8s_connection() {
    print_info "检查 Kubernetes 连接..."
    if ! kubectl cluster-info &> /dev/null; then
        print_error "无法连接到 Kubernetes 集群，请检查 kubeconfig 配置"
        exit 1
    fi
    print_info "Kubernetes 连接正常"
}

# 部署 Kubernetes 资源
deploy_k8s_resources() {
    print_info "部署 Kubernetes 资源..."
    
    # 检查文件是否存在
    if [ ! -f "k8s-serviceaccount.yaml" ] || [ ! -f "k8s-clusterrole.yaml" ] || [ ! -f "k8s-clusterrolebinding.yaml" ]; then
        print_error "Kubernetes 配置文件不存在，请确保在正确的目录运行脚本"
        exit 1
    fi
    
    # 应用 ServiceAccount
    print_info "创建 ServiceAccount..."
    kubectl apply -f k8s-serviceaccount.yaml
    
    # 应用 ClusterRole
    print_info "创建 ClusterRole..."
    kubectl apply -f k8s-clusterrole.yaml
    
    # 应用 ClusterRoleBinding
    print_info "创建 ClusterRoleBinding..."
    kubectl apply -f k8s-clusterrolebinding.yaml
    
    # 等待 Secret 创建
    print_info "等待 Token Secret 创建..."
    sleep 5
    
    # 获取 Token
    print_info "获取 ServiceAccount Token..."
    TOKEN=$(kubectl get secret ${SA_NAME}-token -n ${K8S_NAMESPACE} -o jsonpath='{.data.token}' 2>/dev/null | base64 -d)
    
    if [ -z "$TOKEN" ]; then
        print_error "无法获取 Token，请检查 ServiceAccount 是否创建成功"
        exit 1
    fi
    
    # 保存 Token 到文件
    mkdir -p ${ZABBIX_CONFIG_DIR}
    echo "$TOKEN" > ${ZABBIX_CONFIG_DIR}/k8s-token
    chmod 600 ${ZABBIX_CONFIG_DIR}/k8s-token
    chown zabbix:zabbix ${ZABBIX_CONFIG_DIR}/k8s-token 2>/dev/null || true
    print_info "Token 已保存到 ${ZABBIX_CONFIG_DIR}/k8s-token"
    
    # 获取 CA 证书（如果需要）
    print_info "获取 Kubernetes CA 证书..."
    kubectl get secret ${SA_NAME}-token -n ${K8S_NAMESPACE} -o jsonpath='{.data.ca\.crt}' | base64 -d > ${ZABBIX_CONFIG_DIR}/k8s-ca.crt 2>/dev/null || true
    if [ -f ${ZABBIX_CONFIG_DIR}/k8s-ca.crt ]; then
        chmod 644 ${ZABBIX_CONFIG_DIR}/k8s-ca.crt
        chown zabbix:zabbix ${ZABBIX_CONFIG_DIR}/k8s-ca.crt 2>/dev/null || true
        print_info "CA 证书已保存到 ${ZABBIX_CONFIG_DIR}/k8s-ca.crt"
    fi
}

# 配置 Zabbix Agent 2
configure_zabbix_agent2() {
    print_info "配置 Zabbix Agent 2..."
    
    # 检查 Zabbix Agent 2 是否安装
    if [ ! -f "$ZABBIX_AGENT2_CONF" ]; then
        print_warn "Zabbix Agent 2 配置文件不存在，将创建新配置"
        mkdir -p $(dirname $ZABBIX_AGENT2_CONF)
    fi
    
    # 备份现有配置
    if [ -f "$ZABBIX_AGENT2_CONF" ]; then
        print_info "备份现有配置文件..."
        cp $ZABBIX_AGENT2_CONF ${ZABBIX_AGENT2_CONF}.backup.$(date +%Y%m%d_%H%M%S)
    fi
    
    # 获取 API Server 地址
    API_SERVER=$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')
    if [ -z "$API_SERVER" ]; then
        API_SERVER="https://kubernetes.default.svc:443"
        print_warn "无法自动获取 API Server 地址，使用默认值: $API_SERVER"
    else
        print_info "检测到 API Server 地址: $API_SERVER"
    fi
    
    # 复制配置文件
    if [ -f "zabbix-agent2.conf" ]; then
        cp zabbix-agent2.conf $ZABBIX_AGENT2_CONF
        
        # 更新 API Server 地址
        sed -i "s|Kubernetes.API.Server=.*|Kubernetes.API.Server=${API_SERVER}|g" $ZABBIX_AGENT2_CONF
        
        # 更新 Token 文件路径
        sed -i "s|Kubernetes.API.TokenFile=.*|Kubernetes.API.TokenFile=${ZABBIX_CONFIG_DIR}/k8s-token|g" $ZABBIX_AGENT2_CONF
        
        # 更新 CA 证书路径（如果存在）
        if [ -f ${ZABBIX_CONFIG_DIR}/k8s-ca.crt ]; then
            sed -i "s|# Kubernetes.API.CAFile=|Kubernetes.API.CAFile=|g" $ZABBIX_AGENT2_CONF
            sed -i "s|Kubernetes.API.CAFile=.*|Kubernetes.API.CAFile=${ZABBIX_CONFIG_DIR}/k8s-ca.crt|g" $ZABBIX_AGENT2_CONF
        fi
        
        print_info "Zabbix Agent 2 配置已更新"
    else
        print_warn "zabbix-agent2.conf 文件不存在，请手动配置"
    fi
    
    # 创建脚本目录
    mkdir -p ${ZABBIX_SCRIPTS_DIR}
    chown zabbix:zabbix ${ZABBIX_SCRIPTS_DIR} 2>/dev/null || true
    
    # 复制监控脚本（如果存在）
    if [ -d "scripts" ]; then
        cp -r scripts/* ${ZABBIX_SCRIPTS_DIR}/
        chmod +x ${ZABBIX_SCRIPTS_DIR}/*.sh
        chown -R zabbix:zabbix ${ZABBIX_SCRIPTS_DIR} 2>/dev/null || true
        print_info "监控脚本已复制到 ${ZABBIX_SCRIPTS_DIR}"
    fi
}

# 重启 Zabbix Agent 2
restart_zabbix_agent2() {
    print_info "重启 Zabbix Agent 2..."
    
    if systemctl is-active --quiet zabbix-agent2; then
        systemctl restart zabbix-agent2
        print_info "Zabbix Agent 2 已重启"
    else
        print_warn "Zabbix Agent 2 服务未运行，请手动启动: systemctl start zabbix-agent2"
    fi
    
    # 检查服务状态
    sleep 2
    if systemctl is-active --quiet zabbix-agent2; then
        print_info "Zabbix Agent 2 运行正常"
    else
        print_error "Zabbix Agent 2 启动失败，请检查日志: journalctl -u zabbix-agent2"
    fi
}

# 验证配置
verify_config() {
    print_info "验证配置..."
    
    # 检查 Token 文件
    if [ -f ${ZABBIX_CONFIG_DIR}/k8s-token ]; then
        print_info "✓ Token 文件存在"
    else
        print_error "✗ Token 文件不存在"
    fi
    
    # 检查配置文件
    if [ -f $ZABBIX_AGENT2_CONF ]; then
        print_info "✓ Zabbix Agent 2 配置文件存在"
    else
        print_error "✗ Zabbix Agent 2 配置文件不存在"
    fi
    
    # 检查服务状态
    if systemctl is-active --quiet zabbix-agent2; then
        print_info "✓ Zabbix Agent 2 服务运行中"
    else
        print_warn "✗ Zabbix Agent 2 服务未运行"
    fi
}

# 主函数
main() {
    print_info "开始部署 Zabbix Kubernetes 监控..."
    
    # 检查前置条件
    check_root
    check_command kubectl
    check_command base64
    
    # 检查 Kubernetes 连接
    check_k8s_connection
    
    # 部署 Kubernetes 资源
    deploy_k8s_resources
    
    # 配置 Zabbix Agent 2
    configure_zabbix_agent2
    
    # 重启服务
    restart_zabbix_agent2
    
    # 验证配置
    verify_config
    
    print_info "部署完成！"
    print_info "下一步："
    print_info "1. 在 Zabbix Web 界面导入监控模板 (k8s-monitoring-template.xml)"
    print_info "2. 创建主机并关联模板"
    print_info "3. 配置主机宏（如需要）"
    print_info "4. 运行测试脚本验证连接: ./test-connection.sh"
}

# 运行主函数
main

