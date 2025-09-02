#!/bin/bash

# WORM智能挖矿系统 - 一键安装脚本
# 作者: 区块链编程专家
# 支持系统: Ubuntu 18.04+

set -e  # 遇到错误立即退出

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

# 检查系统
check_system() {
    log_step "检查系统兼容性..."
    
    # 检查Ubuntu版本
    if ! grep -q "Ubuntu" /etc/os-release; then
        log_error "此脚本仅支持Ubuntu系统"
        exit 1
    fi
    
    # 检查架构
    if [ "$(uname -m)" != "x86_64" ]; then
        log_error "仅支持x86_64架构，ARM/Apple Silicon不支持"
        exit 1
    fi
    
    # 检查内存
    total_mem=$(free -g | awk '/^Mem:/{print $2}')
    if [ "$total_mem" -lt 15 ]; then
        log_warn "内存不足16GB，可能影响性能"
        read -p "是否继续安装？(y/N): " confirm
        if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
            exit 1
        fi
    fi
    
    log_info "系统检查通过 ✓"
}

# 更新系统
update_system() {
    log_step "更新系统包..."
    sudo apt update -y
    sudo apt upgrade -y
    log_info "系统更新完成 ✓"
}

# 安装依赖
install_dependencies() {
    log_step "安装系统依赖..."
    
    # 安装基础依赖
    sudo apt install -y \
        build-essential \
        cmake \
        libgmp-dev \
        libsodium-dev \
        nasm \
        curl \
        m4 \
        git \
        wget \
        unzip \
        nlohmann-json3-dev \
        bc \
        jq \
        screen \
        htop
    
    log_info "系统依赖安装完成 ✓"
}

# 安装Rust
install_rust() {
    log_step "安装Rust工具链..."
    
    if command -v rustc &> /dev/null; then
        log_info "Rust已安装，跳过安装步骤"
        return
    fi
    
    # 下载并安装Rust
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    
    # 添加到PATH
    source ~/.cargo/env
    
    # 验证安装
    if command -v rustc &> /dev/null; then
        log_info "Rust安装成功 ✓ 版本: $(rustc --version)"
    else
        log_error "Rust安装失败"
        exit 1
    fi
}

# 克隆WORM项目
clone_worm_project() {
    log_step "克隆WORM挖矿项目..."
    
    # 创建工作目录
    mkdir -p ~/worm-mining
    cd ~/worm-mining
    
    # 克隆项目
    if [ -d "miner" ]; then
        log_info "项目已存在，更新代码..."
        cd miner
        git pull
        cd ..
    else
        git clone https://github.com/worm-privacy/miner
    fi
    
    cd miner
    log_info "项目克隆完成 ✓"
}

# 下载参数文件
download_parameters() {
    log_step "下载零知识证明参数文件..."
    
    make download_params
    
    log_info "参数文件下载完成 ✓"
}

# 编译安装worm-miner
install_worm_miner() {
    log_step "编译安装worm-miner..."
    
    # 添加Rust环境变量
    source ~/.cargo/env
    
    # 安装worm-miner
    cargo install --path .
    
    # 验证安装
    if command -v worm-miner &> /dev/null; then
        log_info "worm-miner安装成功 ✓"
        worm-miner --help | head -5
    else
        log_error "worm-miner安装失败"
        exit 1
    fi
}

# 创建工作目录
setup_workspace() {
    log_step "设置工作环境..."
    
    cd ~
    mkdir -p ~/worm-mining/{scripts,logs,config}
    
    # 创建配置文件
    cat > ~/worm-mining/config/settings.conf << 'EOF'
# WORM挖矿配置文件
NETWORK=sepolia
MIN_COMPETITION_THRESHOLD=2.0
MAX_COMPETITION_THRESHOLD=20.0
BASE_STAKE_AMOUNT=0.05
MAX_STAKE_AMOUNT=0.5
CLAIM_INTERVAL=3600
MONITOR_INTERVAL=300
EOF
    
    log_info "工作环境设置完成 ✓"
}

# 主安装流程
main() {
    clear
    echo "================================================"
    echo "🐉 WORM智能挖矿系统 - 一键安装脚本"
    echo "================================================"
    echo ""
    
    log_info "开始安装，预计需要10-20分钟..."
    echo ""
    
    # 执行安装步骤
    check_system
    update_system
    install_dependencies
    install_rust
    clone_worm_project
    download_parameters
    install_worm_miner
    setup_workspace
    
    echo ""
    echo "================================================"
    log_info "🎉 WORM挖矿系统安装完成！"
    echo "================================================"
    echo ""
    echo "下一步："
    echo "1. 下载智能挖矿脚本：wget -O ~/worm-mining/mine.sh [GitHub脚本URL]"
    echo "2. 运行挖矿脚本：bash ~/worm-mining/mine.sh"
    echo ""
    echo "注意事项："
    echo "- 确保拥有足够的Sepolia ETH"
    echo "- 准备好您的私钥"
    echo "- 建议在screen会话中运行长期挖矿"
    echo ""
}

# 执行主函数
main "$@"
