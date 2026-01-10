
#!/bin/bash

# 创建永不过期的 ServiceAccount Token 脚本
# 适用于 Kubernetes 1.24+ 版本

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 配置变量
SA_NAME="zabbix-monitoring-sa"
NAMESPACE="kube-system"
SECRET_NAME="${SA_NAME}-token"
ZABBIX_CONFIG_DIR="/etc/zabbix"

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
        exit 1
    fi
}

# 检查是否为 root 用户
check_root() {
    if [ "$EUID" -ne 0 ]; then
        print_error "请使用 root 用户或 sudo 运行此脚本"
        exit 1
    fi
}

# 方法 1: 使用 TokenRequest API 创建长期有效的 token（推荐）
create_token_request() {
    print_section "方法 1: 使用 TokenRequest API 创建长期有效的 Token"

    print_info "创建长期有效的 Token（有效期 10 年）..."

    # 获取 ServiceAccount UID
    SA_UID=$(kubectl get sa ${SA_NAME} -n ${NAMESPACE} -o jsonpath='{.metadata.uid}' 2>/dev/null)

    if [ -z "$SA_UID" ]; then
        print_error "ServiceAccount ${SA_NAME} 不存在，请先创建 ServiceAccount"
        return 1
    fi

    # 计算 10 年后的时间戳（秒）
    EXPIRY_SECONDS=$((10 * 365 * 24 * 60 * 60))

    # 创建 TokenRequest
    TOKEN_REQUEST=$(cat <<EOF | kubectl create -f - 2>&1
apiVersion: v1
kind: Secret
metadata:
  name: ${SECRET_NAME}-manual
  namespace: ${NAMESPACE}
  annotations:
    kubernetes.io/service-account.name: ${SA_NAME}
type: kubernetes.io/service-account-token
EOF
)

    # 等待 token 生成
    print_info "等待 Token 生成..."
    sleep 5

    # 获取 token
    TOKEN=$(kubectl get secret ${SECRET_NAME}-manual -n ${NAMESPACE} -o jsonpath='{.data.token}' 2>/dev/null | base64 -d)

    if [ -z "$TOKEN" ]; then
        print_warn "方法 1 失败，尝试方法 2..."
        return 1
    fi

    # 保存 token
    mkdir -p ${ZABBIX_CONFIG_DIR}
    echo "$TOKEN" > ${ZABBIX_CONFIG_DIR}/k8s-token
    chmod 600 ${ZABBIX_CONFIG_DIR}/k8s-token
    chown zabbix:zabbix ${ZABBIX_CONFIG_DIR}/k8s-token 2>/dev/null || true

    print_info "✓ Token 已创建并保存到 ${ZABBIX_CONFIG_DIR}/k8s-token"
    print_warn "注意: 此 Token 使用 TokenRequest API，可能有过期时间限制"
    return 0
}

# 方法 2: 创建手动管理的 Secret（永不过期，推荐）
create_manual_secret() {
    print_section "方法 2: 创建手动管理的 Secret（永不过期）"

    print_info "检查 ServiceAccount 是否存在..."

    # 检查 ServiceAccount 是否存在
    if ! kubectl get sa ${SA_NAME} -n ${NAMESPACE} &>/dev/null; then
        print_error "ServiceAccount ${SA_NAME} 不存在，请先创建 ServiceAccount"
        print_info "运行: kubectl apply -f k8s-serviceaccount.yaml"
        return 1
    fi

    # 获取 ServiceAccount UID
    SA_UID=$(kubectl get sa ${SA_NAME} -n ${NAMESPACE} -o jsonpath='{.metadata.uid}')
    print_info "ServiceAccount UID: ${SA_UID}"

    # 删除已存在的 Secret（如果存在）
    if kubectl get secret ${SECRET_NAME} -n ${NAMESPACE} &>/dev/null; then
        print_warn "Secret ${SECRET_NAME} 已存在，删除旧 Secret..."
        kubectl delete secret ${SECRET_NAME} -n ${NAMESPACE}
        sleep 2
    fi

    # 创建新的 Secret
    print_info "创建新的 Secret..."
    kubectl apply -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: ${SECRET_NAME}
  namespace: ${NAMESPACE}
  annotations:
    kubernetes.io/service-account.name: ${SA_NAME}
    kubernetes.io/service-account.uid: ${SA_UID}
type: kubernetes.io/service-account-token
EOF

    # 等待 Kubernetes 自动填充 token
    print_info "等待 Kubernetes 生成 Token（这可能需要几秒钟）..."

    for i in {1..30}; do
        TOKEN=$(kubectl get secret ${SECRET_NAME} -n ${NAMESPACE} -o jsonpath='{.data.token}' 2>/dev/null | base64 -d)
        if [ -n "$TOKEN" ] && [ "$TOKEN" != "null" ]; then
            print_info "✓ Token 已生成"
            break
        fi
        print_info "等待 Token 生成... ($i/30)"
        sleep 2
    done

    if [ -z "$TOKEN" ] || [ "$TOKEN" == "null" ]; then
        print_error "Token 生成失败，可能需要手动创建"
        print_info "请参考文档中的手动创建方法"
        return 1
    fi

    # 保存 token
    mkdir -p ${ZABBIX_CONFIG_DIR}
    echo "$TOKEN" > ${ZABBIX_CONFIG_DIR}/k8s-token
    chmod 600 ${ZABBIX_CONFIG_DIR}/k8s-token
    chown zabbix:zabbix ${ZABBIX_CONFIG_DIR}/k8s-token 2>/dev/null || true

    # 保存 CA 证书
    CA_CERT=$(kubectl get secret ${SECRET_NAME} -n ${NAMESPACE} -o jsonpath='{.data.ca\.crt}' 2>/dev/null | base64 -d)
    if [ -n "$CA_CERT" ]; then
        echo "$CA_CERT" > ${ZABBIX_CONFIG_DIR}/k8s-ca.crt
        chmod 644 ${ZABBIX_CONFIG_DIR}/k8s-ca.crt
        chown zabbix:zabbix ${ZABBIX_CONFIG_DIR}/k8s-ca.crt 2>/dev/null || true
        print_info "✓ CA 证书已保存到 ${ZABBIX_CONFIG_DIR}/k8s-ca.crt"
    fi

    print_info "✓ Token 已保存到 ${ZABBIX_CONFIG_DIR}/k8s-token"
    print_info "✓ 此 Token 是手动管理的 Secret，不会自动过期"

    return 0
}

# 方法 3: 使用 kubectl create token（Kubernetes 1.24+）
create_kubectl_token() {
    print_section "方法 3: 使用 kubectl create token（长期有效）"

    print_info "使用 kubectl create token 创建长期有效的 Token..."

    # 检查 kubectl 版本（需要 1.24+）
    KUBECTL_VERSION=$(kubectl version --client -o json 2>/dev/null | grep -oP '"gitVersion": "\K[^"]+' | cut -d'.' -f2)
    if [ -z "$KUBECTL_VERSION" ] || [ "$KUBECTL_VERSION" -lt 24 ]; then
        print_warn "kubectl 版本可能不支持 create token 命令，跳过此方法"
        return 1
    fi

    # 创建 token（有效期 10 年 = 315360000 秒）
    EXPIRY_SECONDS=315360000

    print_info "创建 Token（有效期约 10 年）..."
    TOKEN=$(kubectl create token ${SA_NAME} -n ${NAMESPACE} --duration=${EXPIRY_SECONDS}s 2>/dev/null)

    if [ -z "$TOKEN" ]; then
        print_warn "方法 3 失败，尝试其他方法..."
        return 1
    fi

    # 保存 token
    mkdir -p ${ZABBIX_CONFIG_DIR}
    echo "$TOKEN" > ${ZABBIX_CONFIG_DIR}/k8s-token
    chmod 600 ${ZABBIX_CONFIG_DIR}/k8s-token
    chown zabbix:zabbix ${ZABBIX_CONFIG_DIR}/k8s-token 2>/dev/null || true

    print_info "✓ Token 已创建并保存到 ${ZABBIX_CONFIG_DIR}/k8s-token"
    print_warn "注意: 此 Token 有效期约 10 年，到期后需要重新创建"

    return 0
}

# 验证 token
verify_token() {
    print_section "验证 Token"

    if [ ! -f "${ZABBIX_CONFIG_DIR}/k8s-token" ]; then
        print_error "Token 文件不存在"
        return 1
    fi

    TOKEN=$(cat ${ZABBIX_CONFIG_DIR}/k8s-token)

    if [ -z "$TOKEN" ]; then
        print_error "Token 文件为空"
        return 1
    fi

    # 获取 API Server 地址
    API_SERVER=$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}' 2>/dev/null)
    if [ -z "$API_SERVER" ]; then
        API_SERVER="https://kubernetes.default.svc:443"
    fi

    print_info "测试 Token 有效性..."

    # 测试 token
    RESPONSE=$(curl -s -k --connect-timeout 5 \
        -H "Authorization: Bearer $TOKEN" \
        "${API_SERVER}/api/v1/namespaces/${NAMESPACE}" 2>&1)

    if echo "$RESPONSE" | grep -q "kind.*Namespace"; then
        print_info "✓ Token 验证成功"
        return 0
    else
        print_error "✗ Token 验证失败"
        echo "$RESPONSE" | head -n 5
        return 1
    fi
}

# 主函数
main() {
    echo -e "${BLUE}"
    echo "=========================================="
    echo "  创建永不过期的 ServiceAccount Token"
    echo "=========================================="
    echo -e "${NC}"

    # 检查前置条件
    check_root
    check_command kubectl

    # 尝试不同的方法
    print_info "尝试创建永不过期的 Token..."

    # 优先使用方法 2（手动管理的 Secret，真正永不过期）
    if create_manual_secret; then
        verify_token
        print_section "完成"
        print_info "✓ Token 创建成功！"
        print_info "此 Token 使用手动管理的 Secret，不会自动过期"
        return 0
    fi

    # 如果方法 2 失败，尝试方法 3
    if create_kubectl_token; then
        verify_token
        print_section "完成"
        print_info "✓ Token 创建成功！"
        print_warn "此 Token 有效期约 10 年，到期后需要重新运行此脚本"
        return 0
    fi

    # 如果都失败，提供手动创建指南
    print_error "自动创建失败，请参考以下手动创建方法："
    echo ""
    echo "手动创建方法："
    echo "1. 确保 ServiceAccount 已创建："
    echo "   kubectl apply -f k8s-serviceaccount.yaml"
    echo ""
    echo "2. 获取 ServiceAccount UID："
    echo "   SA_UID=\$(kubectl get sa ${SA_NAME} -n ${NAMESPACE} -o jsonpath='{.metadata.uid}')"
    echo ""
    echo "3. 创建 Secret："
    echo "   kubectl apply -f k8s-serviceaccount.yaml"
    echo ""
    echo "4. 等待并获取 Token："
    echo "   kubectl get secret ${SECRET_NAME} -n ${NAMESPACE} -o jsonpath='{.data.token}' | base64 -d"

    exit 1
}

# 运行主函数
main


