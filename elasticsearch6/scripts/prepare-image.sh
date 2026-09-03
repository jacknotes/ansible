#!/bin/bash

# ELK Docker Image Preparation Script
# 用于在有网络限制的环境中准备Docker镜像

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

ELK_IMAGE="sebp/elk:651"
IMAGE_FILE="elk-image-651.tar.gz"

# 检查Docker是否安装
check_docker() {
    if ! command -v docker &> /dev/null; then
        print_error "Docker未安装，请先安装Docker"
        exit 1
    fi
}

# 从网络拉取镜像并保存
pull_and_save() {
    print_info "尝试拉取镜像: $ELK_IMAGE"
    
    if docker pull $ELK_IMAGE; then
        print_success "镜像拉取成功"
        print_info "保存镜像到文件: $IMAGE_FILE"
        docker save $ELK_IMAGE | gzip > $IMAGE_FILE
        print_success "镜像已保存到: $IMAGE_FILE"
        print_info "文件大小: $(du -h $IMAGE_FILE | cut -f1)"
    else
        print_error "镜像拉取失败"
        print_warning "请尝试以下方案："
        echo "  1. 配置Docker镜像加速器后重试"
        echo "  2. 在有网络的环境中拉取并保存镜像，然后复制到目标服务器"
        echo "  3. 使用阿里云私有镜像仓库"
        exit 1
    fi
}

# 从文件加载镜像
load_image() {
    if [[ ! -f "$IMAGE_FILE" ]]; then
        print_error "镜像文件不存在: $IMAGE_FILE"
        print_info "请先运行: $0 save"
        exit 1
    fi
    
    print_info "加载镜像文件: $IMAGE_FILE"
    docker load < $IMAGE_FILE
    print_success "镜像加载完成"
    
    # 验证镜像
    if docker images | grep -q "sebp/elk"; then
        print_success "镜像验证成功"
        docker images | grep "sebp/elk"
    else
        print_error "镜像验证失败"
        exit 1
    fi
}

# 配置镜像加速器
configure_mirror() {
    print_info "配置Docker镜像加速器..."
    
    mkdir -p /etc/docker
    
    cat > /etc/docker/daemon.json <<EOF
{
    "storage-driver": "overlay2",
    "log-driver": "json-file",
    "log-opts": {
        "max-size": "100m",
        "max-file": "3"
    },
    "registry-mirrors": [
        "https://registry.cn-hangzhou.aliyuncs.com",
        "https://docker.mirrors.ustc.edu.cn",
        "https://hub-mirror.c.163.com"
    ]
}
EOF
    
    print_success "镜像加速器配置完成"
    print_info "重启Docker服务..."
    systemctl daemon-reload
    systemctl restart docker
    print_success "Docker服务重启完成"
}

# 使用阿里云私有镜像仓库
push_to_aliyun() {
    local aliyun_registry="registry.cn-hangzhou.aliyuncs.com"
    local namespace="${1:-your_namespace}"
    
    print_info "推送到阿里云私有镜像仓库..."
    print_warning "请确保已登录阿里云容器镜像服务: docker login $aliyun_registry"
    
    local target_image="$aliyun_registry/$namespace/elk:651"
    
    docker tag $ELK_IMAGE $target_image
    docker push $target_image
    
    print_success "镜像已推送到: $target_image"
    print_info "在目标服务器拉取: docker pull $target_image"
}

# 显示帮助
show_help() {
    echo "ELK Docker Image Preparation Script"
    echo ""
    echo "Usage: $0 [command]"
    echo ""
    echo "Commands:"
    echo "  pull      - 拉取镜像并保存到本地文件"
    echo "  load      - 从本地文件加载镜像"
    echo "  mirror    - 配置Docker镜像加速器"
    echo "  push      - 推送到阿里云私有镜像仓库"
    echo "  help      - 显示此帮助信息"
    echo ""
    echo "典型工作流程："
    echo "  1. 在有网络的环境: $0 pull"
    echo "  2. 复制 $IMAGE_FILE 到目标服务器"
    echo "  3. 在目标服务器: $0 load"
}

# 主函数
main() {
    local command=${1:-"help"}
    
    check_docker
    
    case $command in
        "pull")
            pull_and_save
            ;;
        "load")
            load_image
            ;;
        "mirror")
            configure_mirror
            ;;
        "push")
            push_to_aliyun $2
            ;;
        "help"|*)
            show_help
            ;;
    esac
}

main "$@"