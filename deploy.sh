#!/bin/bash

# WORM智能挖矿系统 - 一键部署脚本
# 自动下载并启动完整的挖矿系统

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
GITHUB_RAW_URL="https://raw.githubusercontent.com/Zzzzzarvis/worm-mining-scripts/main"
WORK_DIR="$HOME/worm-mining"

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

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

# 显示欢迎信息
show_welcome() {
    clear
    echo -e "${CYAN}"
    echo "================================================"
    echo "🐉 WORM智能挖矿系统 - 一键部署"
    echo "================================================"
    echo -e "${NC}"
    echo ""
    echo -e "${BOLD}🚀 特性:${NC}"
    echo "  • 🧠 智能挖矿策略"
    echo "  • 🤖 全自动化操作"  
    echo "  • 🎁 自动领取奖励"
    echo "  • 📊 实时监控面板"
    echo ""
    echo -e "${BOLD}💻 系统要求:${NC}"
    echo "  • Ubuntu 18.04+"
    echo "  • x86_64架构"
    echo "  • 16GB+ RAM"
    echo "  • 足够的Sepolia ETH"
    echo ""
}

# 检查系统要求
check_requirements() {
    log_step "检查系统要求..."
    
    # 检查操作系统
    if ! grep -q "Ubuntu" /etc/os-release 2>/dev/null; then
        log_error "仅支持Ubuntu系统"
        exit 1
    fi
    
    # 检查架构
    if [ "$(uname -m)" != "x86_64" ]; then
        log_error "仅支持x86_64架构"
        exit 1
    fi
    
    # 检查内存
    total_mem=$(free -g | awk '/^Mem:/{print $2}')
    if [ "$total_mem" -lt 15 ]; then
        log_warn "内存不足16GB，可能影响性能"
    fi
    
    # 检查网络
    if ! curl -s --connect-timeout 5 google.com >/dev/null; then
        log_error "网络连接失败"
        exit 1
    fi
    
    log_info "系统检查通过 ✓"
}

# 创建工作目录
setup_directories() {
    log_step "设置工作目录..."
    
    mkdir -p "$WORK_DIR"/{scripts,config,logs,backup}
    cd "$WORK_DIR"
    
    log_info "工作目录创建完成: $WORK_DIR"
}

# 下载脚本文件
download_scripts() {
    log_step "下载挖矿脚本..."
    
    local scripts=(
        "install.sh"
        "burn_eth.sh"
        "smart_mining.sh"
        "sniper_strategy.sh"
        "advanced_sniper.sh"
        "auto_claim.sh"
        "worm_master.sh"
    )
    
    local scripts_dir="$WORK_DIR/scripts"
    
    for script in "${scripts[@]}"; do
        local url="$GITHUB_RAW_URL/$script"
        
        log_info "下载: $script"
        
        # 尝试下载脚本
        if curl -fsSL "$url" -o "$scripts_dir/$script"; then
            chmod +x "$scripts_dir/$script"
            log_info "✓ $script 下载完成"
        else
            log_error "✗ $script 下载失败"
            
            # 如果GitHub下载失败，使用本地备用脚本
            log_warn "尝试使用备用下载方式..."
            create_fallback_script "$script" "$scripts_dir"
        fi
    done
}

# 创建备用脚本（如果GitHub下载失败）
create_fallback_script() {
    local script_name="$1"
    local target_dir="$2"
    
    case "$script_name" in
        "worm_master.sh")
            log_info "创建主控制脚本..."
            cat > "$target_dir/worm_master.sh" << 'EOF'
#!/bin/bash
echo "WORM智能挖矿系统主控制面板"
echo "GitHub脚本下载失败，请手动下载完整版本"
echo "访问: https://github.com/YOUR_USERNAME/worm-mining-scripts"
EOF
            chmod +x "$target_dir/worm_master.sh"
            ;;
    esac
}

# 安装系统依赖
install_dependencies() {
    log_step "安装系统依赖..."
    
    # 运行安装脚本
    if [ -f "$WORK_DIR/scripts/install.sh" ]; then
        bash "$WORK_DIR/scripts/install.sh"
    else
        log_warn "安装脚本不存在，手动安装依赖..."
        
        # 基础依赖安装
        sudo apt update -y
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
            screen
        
        # 安装Rust
        if ! command -v rustc &> /dev/null; then
            curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
            source ~/.cargo/env
        fi
        
        # 安装worm-miner
        if ! command -v worm-miner &> /dev/null; then
            mkdir -p ~/temp-worm
            cd ~/temp-worm
            git clone https://github.com/worm-privacy/miner
            cd miner
            make download_params
            source ~/.cargo/env
            cargo install --path .
            cd "$WORK_DIR"
            rm -rf ~/temp-worm
        fi
    fi
    
    log_success "依赖安装完成"
}

# 创建启动脚本
create_launcher() {
    log_step "创建启动脚本..."
    
    cat > "$WORK_DIR/start.sh" << 'EOF'
#!/bin/bash

# WORM挖矿系统启动脚本

WORK_DIR="$HOME/worm-mining"

echo "🐉 启动WORM智能挖矿系统..."

if [ -f "$WORK_DIR/scripts/worm_master.sh" ]; then
    cd "$WORK_DIR"
    exec bash scripts/worm_master.sh "$@"
else
    echo "错误: 主控制脚本不存在"
    echo "请重新运行部署脚本"
    exit 1
fi
EOF
    
    chmod +x "$WORK_DIR/start.sh"
    
    # 创建全局符号链接
    sudo ln -sf "$WORK_DIR/start.sh" /usr/local/bin/worm-mining 2>/dev/null || true
    
    log_info "启动脚本创建完成"
}

# 创建配置文件
create_config() {
    log_step "创建配置文件..."
    
    cat > "$WORK_DIR/config/settings.conf" << 'EOF'
# WORM智能挖矿系统配置文件

# 网络设置
NETWORK=sepolia

# 竞争阈值设置
LOW_COMPETITION=2.0
MEDIUM_COMPETITION=10.0
HIGH_COMPETITION=20.0

# 投入策略设置
BASE_STAKE=0.05
AGGRESSIVE_STAKE=0.5
CONSERVATIVE_STAKE=0.02
MAX_STAKE_PER_EPOCH=1.0

# 风控设置
MIN_BETH_RESERVE=0.1
MAX_EPOCHS_AHEAD=5

# 监控设置
MONITOR_INTERVAL=300
CLAIM_INTERVAL=600
RETRY_ATTEMPTS=3
RETRY_DELAY=30

# 自动化设置
AUTO_CLAIM_ENABLED=true
AUTO_MINING_ENABLED=true

# 日志设置
LOG_LEVEL=INFO
LOG_ROTATION=daily
LOG_RETENTION=7
EOF
    
    log_info "配置文件创建完成"
}

# 设置服务
setup_service() {
    log_step "设置系统服务..."
    
    # 创建systemd服务文件（可选）
    cat > "$WORK_DIR/worm-mining.service" << EOF
[Unit]
Description=WORM智能挖矿系统
After=network.target

[Service]
Type=simple
User=$USER
WorkingDirectory=$WORK_DIR
ExecStart=$WORK_DIR/start.sh
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
    
    log_info "服务配置创建完成"
    log_info "如需自启动，请运行: sudo systemctl enable $WORK_DIR/worm-mining.service"
}

# 显示完成信息
show_completion() {
    echo ""
    echo "================================================"
    log_success "🎉 WORM智能挖矿系统部署完成！"
    echo "================================================"
    echo ""
    echo -e "${BOLD}🚀 快速开始:${NC}"
    echo ""
    echo "1. 启动系统:"
    echo -e "   ${CYAN}cd $WORK_DIR && ./start.sh${NC}"
    echo -e "   ${CYAN}或直接运行: worm-mining${NC}"
    echo ""
    echo "2. 首次使用流程:"
    echo "   • 选择 '系统安装/更新' (如果依赖安装失败)"
    echo "   • 选择 '燃烧ETH获取BETH'"  
    echo "   • 选择 '启动智能挖矿'"
    echo "   • 选择 '启动自动领取'"
    echo ""
    echo -e "${BOLD}📁 项目目录:${NC}"
    echo "   工作目录: $WORK_DIR"
    echo "   脚本目录: $WORK_DIR/scripts"
    echo "   配置文件: $WORK_DIR/config"
    echo "   日志目录: $WORK_DIR/logs"
    echo ""
    echo -e "${BOLD}🔧 常用命令:${NC}"
    echo "   启动系统: worm-mining"
    echo "   查看会话: screen -list"
    echo "   连接会话: screen -r <会话名>"
    echo "   查看日志: tail -f $WORK_DIR/logs/*.log"
    echo ""
    echo -e "${BOLD}⚠️ 重要提醒:${NC}"
    echo "   • 准备足够的Sepolia ETH"
    echo "   • 保护好您的私钥安全"
    echo "   • 建议在screen会话中运行"
    echo ""
}

# 主安装流程
main() {
    show_welcome
    
    echo -e "${YELLOW}即将开始自动化部署，预计需要5-15分钟${NC}"
    echo ""
    read -p "按回车键开始部署，或按Ctrl+C取消..."
    
    # 执行部署步骤
    check_requirements
    setup_directories
    download_scripts
    install_dependencies
    create_launcher
    create_config
    setup_service
    
    # 显示完成信息
    show_completion
    
    # 询问是否立即启动
    echo ""
    read -p "是否立即启动WORM智能挖矿系统？(y/N): " start_now
    if [ "$start_now" = "y" ] || [ "$start_now" = "Y" ]; then
        echo ""
        log_info "正在启动系统..."
        exec "$WORK_DIR/start.sh"
    else
        echo ""
        log_info "部署完成，使用 'worm-mining' 命令启动系统"
    fi
}

# 错误处理
trap 'echo ""; log_error "部署过程中出现错误，请检查日志"; exit 1' ERR

# 执行主函数
main "$@"
