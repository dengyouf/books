#!/bin/bash

# Zabbix Kubernetes 监控连接测试脚本

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 配置变量
K8S_NAMESPACE="kube-system"
SA_NAME="zabbix-monitoring-sa"
ZABBIX_CONFIG_DIR="/etc/zabbix"
TOKEN_FILE="${ZABBIX_CONFIG_DIR}/k8s-token"
CA_FILE="${ZABBIX_CONFIG_DIR}/k8s-ca.crt"

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
        print_error "$1 未安装"
        return 1
    fi
    return 0
}

# 测试 Kubernetes API Server 连接
test_k8s_api() {
    print_section "测试 Kubernetes API Server 连接"
    
    # 获取 API Server 地址
    API_SERVER=$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}' 2>/dev/null)
    
    if [ -z "$API_SERVER" ]; then
        print_warn "无法从 kubeconfig 获取 API Server 地址"
        API_SERVER="https://kubernetes.default.svc:443"
        print_info "使用默认地址: $API_SERVER"
    else
        print_info "API Server 地址: $API_SERVER"
    fi
    
    # 检查 Token 文件
    if [ ! -f "$TOKEN_FILE" ]; then
        print_error "Token 文件不存在: $TOKEN_FILE"
        return 1
    fi
    
    TOKEN=$(cat $TOKEN_FILE)
    if [ -z "$TOKEN" ]; then
        print_error "Token 文件为空"
        return 1
    fi
    
    print_info "Token 文件存在且有效"
    
    # 测试 API 连接
    print_info "测试 API Server 连接..."
    
    if [ -f "$CA_FILE" ]; then
        RESPONSE=$(curl -s -k --connect-timeout 5 \
            --cacert "$CA_FILE" \
            -H "Authorization: Bearer $TOKEN" \
            "${API_SERVER}/version" 2>&1)
    else
        RESPONSE=$(curl -s -k --connect-timeout 5 \
            -H "Authorization: Bearer $TOKEN" \
            "${API_SERVER}/version" 2>&1)
    fi
    
    if echo "$RESPONSE" | grep -q "gitVersion"; then
        print_info "✓ API Server 连接成功"
        echo "$RESPONSE" | python3 -m json.tool 2>/dev/null || echo "$RESPONSE"
        return 0
    else
        print_error "✗ API Server 连接失败"
        echo "$RESPONSE"
        return 1
    fi
}

# 测试 ServiceAccount 权限
test_sa_permissions() {
    print_section "测试 ServiceAccount 权限"
    
    # 测试节点权限
    print_info "测试节点访问权限..."
    if kubectl auth can-i get nodes --as=system:serviceaccount:${K8S_NAMESPACE}:${SA_NAME} &>/dev/null; then
        print_info "✓ 节点访问权限正常"
    else
        print_error "✗ 节点访问权限不足"
    fi
    
    # 测试 Pod 权限
    print_info "测试 Pod 访问权限..."
    if kubectl auth can-i get pods --as=system:serviceaccount:${K8S_NAMESPACE}:${SA_NAME} &>/dev/null; then
        print_info "✓ Pod 访问权限正常"
    else
        print_error "✗ Pod 访问权限不足"
    fi
    
    # 测试 Deployment 权限
    print_info "测试 Deployment 访问权限..."
    if kubectl auth can-i get deployments --as=system:serviceaccount:${K8S_NAMESPACE}:${SA_NAME} &>/dev/null; then
        print_info "✓ Deployment 访问权限正常"
    else
        print_error "✗ Deployment 访问权限不足"
    fi
    
    # 实际测试获取资源
    print_info "测试获取节点列表..."
    NODE_COUNT=$(kubectl get nodes --no-headers 2>/dev/null | wc -l)
    if [ "$NODE_COUNT" -gt 0 ]; then
        print_info "✓ 成功获取节点列表，共 $NODE_COUNT 个节点"
    else
        print_error "✗ 无法获取节点列表"
    fi
    
    print_info "测试获取 Pod 列表..."
    POD_COUNT=$(kubectl get pods --all-namespaces --no-headers 2>/dev/null | wc -l)
    if [ "$POD_COUNT" -gt 0 ]; then
        print_info "✓ 成功获取 Pod 列表，共 $POD_COUNT 个 Pod"
    else
        print_error "✗ 无法获取 Pod 列表"
    fi
}

# 测试 Zabbix Agent 2
test_zabbix_agent2() {
    print_section "测试 Zabbix Agent 2"
    
    # 检查服务状态
    if systemctl is-active --quiet zabbix-agent2 2>/dev/null; then
        print_info "✓ Zabbix Agent 2 服务运行中"
    else
        print_error "✗ Zabbix Agent 2 服务未运行"
        return 1
    fi
    
    # 检查配置文件
    if [ -f "/etc/zabbix/zabbix_agent2.conf" ]; then
        print_info "✓ 配置文件存在"
        
        # 检查 Kubernetes 配置
        if grep -q "Kubernetes.API.Server" /etc/zabbix/zabbix_agent2.conf; then
            print_info "✓ Kubernetes 配置已设置"
        else
            print_warn "✗ Kubernetes 配置未设置"
        fi
    else
        print_error "✗ 配置文件不存在"
    fi
    
    # 测试 Agent 2 连接（如果 zabbix_agent2 命令可用）
    if command -v zabbix_agent2 &> /dev/null; then
        print_info "测试 Agent 2 本地连接..."
        if timeout 5 zabbix_agent2 -t agent.ping &>/dev/null; then
            print_info "✓ Agent 2 本地连接正常"
        else
            print_warn "✗ Agent 2 本地连接测试失败"
        fi
    fi
    
    # 检查日志
    print_info "检查最近的日志..."
    if [ -f "/var/log/zabbix/zabbix_agent2.log" ]; then
        ERROR_COUNT=$(tail -n 50 /var/log/zabbix/zabbix_agent2.log | grep -i error | wc -l)
        if [ "$ERROR_COUNT" -gt 0 ]; then
            print_warn "发现 $ERROR_COUNT 个错误日志，请检查: tail -n 50 /var/log/zabbix/zabbix_agent2.log"
        else
            print_info "✓ 最近日志无错误"
        fi
    fi
}

# 显示配置信息
show_config() {
    print_section "当前配置信息"
    
    print_info "ServiceAccount: ${SA_NAME}"
    print_info "命名空间: ${K8S_NAMESPACE}"
    print_info "Token 文件: ${TOKEN_FILE}"
    
    if [ -f "$TOKEN_FILE" ]; then
        TOKEN_LENGTH=$(cat "$TOKEN_FILE" | wc -c)
        print_info "Token 长度: ${TOKEN_LENGTH} 字符"
    fi
    
    if [ -f "$CA_FILE" ]; then
        print_info "CA 证书文件: ${CA_FILE}"
    else
        print_warn "CA 证书文件不存在"
    fi
    
    # 显示 API Server 配置
    if [ -f "/etc/zabbix/zabbix_agent2.conf" ]; then
        API_SERVER=$(grep "^Kubernetes.API.Server=" /etc/zabbix/zabbix_agent2.conf | cut -d'=' -f2)
        if [ -n "$API_SERVER" ]; then
            print_info "API Server: ${API_SERVER}"
        fi
    fi
}

# 主函数
main() {
    echo -e "${BLUE}"
    echo "=========================================="
    echo "  Zabbix Kubernetes 监控连接测试"
    echo "=========================================="
    echo -e "${NC}"
    
    # 检查命令
    check_command kubectl || exit 1
    check_command curl || exit 1
    
    # 显示配置
    show_config
    
    # 测试 Kubernetes API
    test_k8s_api
    
    # 测试权限
    test_sa_permissions
    
    # 测试 Zabbix Agent 2
    test_zabbix_agent2
    
    print_section "测试完成"
    print_info "如果所有测试通过，可以在 Zabbix Web 界面中配置监控"
}

# 运行主函数
main

