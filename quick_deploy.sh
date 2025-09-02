#!/bin/bash

# WORM智能挖矿系统 - 真正的一键部署脚本
# 完全自动化，无需用户交互

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# 配置参数
WORK_DIR="$HOME/worm-mining"

# 日志函数
log_info() {
    echo -e "${GREEN}[$(date '+%H:%M:%S')] [INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[$(date '+%H:%M:%S')] [WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[$(date '+%H:%M:%S')] [ERROR]${NC} $1"
}

log_step() {
    echo -e "${BLUE}[$(date '+%H:%M:%S')] [STEP]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[$(date '+%H:%M:%S')] [SUCCESS]${NC} $1"
}

# 显示欢迎信息
show_banner() {
    clear
    echo -e "${CYAN}${BOLD}"
    echo "================================================"
    echo "🐉 WORM智能挖矿系统 - 真正一键部署"
    echo "================================================"
    echo -e "${NC}"
    echo "🚀 完全自动化安装，无需用户交互"
    echo "⏱️ 预计安装时间: 10-20分钟"
    echo ""
}

# 检查系统
check_system() {
    log_step "检查系统环境..."
    
    # 检查Ubuntu
    if ! grep -q "Ubuntu" /etc/os-release 2>/dev/null; then
        log_warn "未检测到Ubuntu系统，继续尝试安装..."
    fi
    
    # 检查架构
    if [ "$(uname -m)" != "x86_64" ]; then
        log_error "仅支持x86_64架构"
        exit 1
    fi
    
    log_info "系统检查通过"
}

# 更新系统和安装依赖
install_system_dependencies() {
    log_step "更新系统并安装依赖包..."
    
    # 设置非交互模式
    export DEBIAN_FRONTEND=noninteractive
    
    # 更新包列表
    log_info "更新软件包列表..."
    sudo apt update -y >/dev/null 2>&1
    
    # 安装基础依赖
    log_info "安装系统依赖..."
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
        bc \
        jq \
        screen \
        htop >/dev/null 2>&1
    
    log_success "系统依赖安装完成"
}

# 安装Rust
install_rust() {
    log_step "安装Rust工具链..."
    
    if command -v rustc &> /dev/null; then
        log_info "Rust已安装，跳过安装步骤"
        return
    fi
    
    # 自动安装Rust
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y >/dev/null 2>&1
    
    # 加载Rust环境
    source ~/.cargo/env
    
    # 验证安装
    if command -v rustc &> /dev/null; then
        log_success "Rust安装成功: $(rustc --version)"
    else
        log_error "Rust安装失败"
        exit 1
    fi
}

# 创建工作目录
setup_workspace() {
    log_step "创建工作目录..."
    
    mkdir -p "$WORK_DIR"/{scripts,config,logs,backup}
    cd "$WORK_DIR"
    
    log_info "工作目录创建: $WORK_DIR"
}

# 下载所有脚本
download_all_scripts() {
    log_step "下载挖矿脚本..."
    
    local scripts=(
        "worm_master.sh"
        "burn_eth.sh"
        "smart_mining.sh"
        "sniper_strategy.sh"
        "advanced_sniper.sh"
        "auto_claim.sh"
    )
    
    cd "$WORK_DIR/scripts"
    
    for script in "${scripts[@]}"; do
        log_info "下载: $script"
        if curl -fsSL "https://raw.githubusercontent.com/Zzzzzarvis/worm-mining-scripts/main/$script" -o "$script"; then
            chmod +x "$script"
            log_info "✓ $script 下载完成"
        else
            log_error "✗ $script 下载失败"
            exit 1
        fi
    done
    
    log_success "所有脚本下载完成"
}

# 安装worm-miner
install_worm_miner() {
    log_step "安装worm-miner..."
    
    cd ~
    
    # 克隆项目
    if [ -d "miner" ]; then
        log_info "更新现有项目..."
        cd miner
        git pull >/dev/null 2>&1
    else
        log_info "克隆worm-miner项目..."
        git clone https://github.com/worm-privacy/miner >/dev/null 2>&1
        cd miner
    fi
    
    # 下载参数文件
    log_info "下载参数文件..."
    make download_params >/dev/null 2>&1
    
    # 确保Rust环境加载
    source ~/.cargo/env
    
    # 编译安装
    log_info "编译安装worm-miner..."
    cargo install --path . >/dev/null 2>&1
    
    # 验证安装
    if command -v worm-miner &> /dev/null; then
        log_success "worm-miner安装成功"
    else
        log_error "worm-miner安装失败"
        exit 1
    fi
}

# 创建启动脚本
create_startup_scripts() {
    log_step "创建启动脚本..."
    
    # 创建主启动脚本
    cat > "$WORK_DIR/start.sh" << 'EOF'
#!/bin/bash
cd ~/worm-mining
exec bash scripts/worm_master.sh "$@"
EOF
    chmod +x "$WORK_DIR/start.sh"
    
    # 创建全局命令
    sudo ln -sf "$WORK_DIR/start.sh" /usr/local/bin/worm-mining 2>/dev/null || true
    
    log_info "启动脚本创建完成"
}

# 创建配置文件
create_configs() {
    log_step "创建配置文件..."
    
    cat > "$WORK_DIR/config/settings.conf" << 'EOF'
# WORM智能挖矿系统配置文件
NETWORK=sepolia
LOW_COMPETITION=2.0
MEDIUM_COMPETITION=10.0
HIGH_COMPETITION=20.0
BASE_STAKE=0.05
AGGRESSIVE_STAKE=0.5
CONSERVATIVE_STAKE=0.02
MAX_STAKE_PER_EPOCH=1.0
MIN_BETH_RESERVE=0.1
MONITOR_INTERVAL=300
CLAIM_INTERVAL=600
AUTO_CLAIM_ENABLED=true
AUTO_MINING_ENABLED=true
EOF
    
    log_info "配置文件创建完成"
}

# 显示完成信息
show_completion() {
    echo ""
    echo "================================================"
    log_success "🎉 WORM智能挖矿系统安装完成！"
    echo "================================================"
    echo ""
    echo -e "${BOLD}🚀 快速开始:${NC}"
    echo ""
    echo "1. 启动挖矿系统:"
    echo -e "   ${CYAN}worm-mining${NC}"
    echo ""
    echo "2. 或者手动启动:"
    echo -e "   ${CYAN}cd ~/worm-mining && ./start.sh${NC}"
    echo ""
    echo -e "${BOLD}📋 操作流程:${NC}"
    echo "1. 选择 '🔥 燃烧ETH获取BETH' - 输入私钥和数量"
    echo "2. 选择 '🚀 启动自定义狙击' - 配置策略 (如: 1:50-100,3x;100-150,2x)"
    echo "3. 选择 '🎁 启动自动领取' - 自动收取奖励"
    echo ""
    echo -e "${BOLD}💡 重要提示:${NC}"
    echo "• 准备好您的私钥"
    echo "• 确保有足够的Sepolia ETH"
    echo "• 建议在screen会话中运行长期任务"
    echo ""
    echo -e "${YELLOW}现在可以运行 'worm-mining' 开始挖矿了！${NC}"
    echo ""
}

# 主安装流程
main() {
    show_banner
    
    log_info "🚀 开始自动化安装..."
    
    # 执行所有安装步骤
    check_system
    install_system_dependencies
    install_rust
    setup_workspace
    download_all_scripts
    install_worm_miner
    create_startup_scripts
    create_configs
    
    # 显示完成信息
    show_completion
    
    # 自动启动系统
    echo "正在启动WORM挖矿系统..."
    sleep 2
    exec "$WORK_DIR/start.sh"
}

# 错误处理
trap 'echo ""; log_error "安装过程中出现错误"; exit 1' ERR

# 执行主函数
main "$@"
