#!/bin/bash

# WORM智能挖矿系统 - 主控制脚本
# 一键部署和管理所有WORM挖矿功能

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

# 系统配置
GITHUB_REPO="https://raw.githubusercontent.com/Zzzzzarvis/worm-mining-scripts/main"
WORK_DIR="$HOME/worm-mining"
LOG_DIR="$WORK_DIR/logs"
CONFIG_DIR="$WORK_DIR/config"

# 脚本文件列表
declare -A SCRIPTS=(
    ["install"]="install.sh"
    ["burn"]="burn_eth.sh"
    ["mine"]="smart_mining.sh"
    ["claim"]="auto_claim.sh"
    ["master"]="worm_master.sh"
)

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

# 显示Banner
show_banner() {
    clear
    echo -e "${CYAN}"
    echo "================================================"
    echo "🐉 WORM智能挖矿系统 - 主控制面板"
    echo "================================================"
    echo -e "${NC}"
    echo "🚀 一键部署 | 🧠 智能策略 | 🤖 全自动化"
    echo ""
    echo -e "${YELLOW}作者: 区块链编程专家${NC}"
    echo -e "${YELLOW}版本: v1.0${NC}"
    echo ""
}

# 检查系统环境
check_environment() {
    log_step "检查系统环境..."
    
    # 检查操作系统
    if ! grep -q "Ubuntu" /etc/os-release 2>/dev/null; then
        log_warn "未检测到Ubuntu系统，脚本可能无法正常工作"
    fi
    
    # 检查架构
    if [ "$(uname -m)" != "x86_64" ]; then
        log_error "仅支持x86_64架构"
        return 1
    fi
    
    # 检查网络连接
    if ! curl -s --connect-timeout 5 google.com >/dev/null; then
        log_warn "网络连接可能存在问题"
    fi
    
    log_info "环境检查完成"
}

# 创建工作目录
create_directories() {
    log_step "创建工作目录..."
    
    mkdir -p "$WORK_DIR"/{scripts,logs,config,backup}
    
    # 设置日志轮转
    cat > "$LOG_DIR/logrotate.conf" << 'EOF'
/home/*/worm-mining/logs/*.log {
    daily
    rotate 7
    compress
    missingok
    notifempty
    create 644 $USER $USER
}
EOF
    
    log_info "工作目录创建完成"
}

# 下载脚本
download_scripts() {
    log_step "下载挖矿脚本..."
    
    local scripts_dir="$WORK_DIR/scripts"
    
    # 如果GitHub仓库还未创建，使用本地文件
    local script_files=(
        "install.sh"
        "burn_eth.sh" 
        "smart_mining.sh"
        "auto_claim.sh"
        "worm_master.sh"
    )
    
    # 这里暂时跳过下载，因为脚本还在本地
    log_warn "注意: 脚本下载功能需要在GitHub仓库创建后启用"
    log_info "当前使用本地脚本文件"
    
    # 复制本地脚本到工作目录
    for script in "${script_files[@]}"; do
        if [ -f "/Users/z/Desktop/worm/$script" ]; then
            cp "/Users/z/Desktop/worm/$script" "$scripts_dir/"
            chmod +x "$scripts_dir/$script"
            log_info "✓ 复制脚本: $script"
        fi
    done
}

# 系统安装
install_system() {
    echo ""
    echo "================================================"
    echo "🛠️ 系统安装"
    echo "================================================"
    
    log_info "开始安装WORM挖矿系统..."
    
    # 检查是否已安装
    if command -v worm-miner &> /dev/null; then
        log_warn "检测到worm-miner已安装"
        read -p "是否重新安装？(y/N): " reinstall
        if [ "$reinstall" != "y" ] && [ "$reinstall" != "Y" ]; then
            log_info "跳过安装步骤"
            return 0
        fi
    fi
    
    # 运行安装脚本
    if [ -f "$WORK_DIR/scripts/install.sh" ]; then
        bash "$WORK_DIR/scripts/install.sh"
    else
        log_error "安装脚本不存在"
        return 1
    fi
    
    log_success "系统安装完成"
}

# ETH燃烧功能
burn_eth_interface() {
    echo ""
    echo "================================================"
    echo "🔥 ETH燃烧功能"
    echo "================================================"
    
    # 获取用户输入
    echo "请输入您的私钥："
    read -s -p "私钥: " private_key
    echo ""
    
    echo "请输入要燃烧的ETH总数量："
    echo "注意: 系统将自动分批燃烧，每次最多1ETH"
    read -p "燃烧数量: " burn_amount
    
    # 验证输入
    if [[ ! $burn_amount =~ ^[0-9]+\.?[0-9]*$ ]] || (( $(echo "$burn_amount <= 0" | bc -l) )); then
        log_error "请输入有效的燃烧数量"
        return 1
    fi
    
    # 执行燃烧
    if [ -f "$WORK_DIR/scripts/burn_eth.sh" ]; then
        bash "$WORK_DIR/scripts/burn_eth.sh" "$private_key" "$burn_amount"
    else
        log_error "燃烧脚本不存在"
        return 1
    fi
}

# 挖矿策略选择
mining_strategy_interface() {
    echo ""
    echo "================================================"
    echo "🧠 智能挖矿策略"
    echo "================================================"
    
    echo "可选挖矿策略："
    echo "1. 🤖 全自动智能策略 (推荐)"
    echo "2. ⚖️ 平衡稳健策略"
    echo "3. 🚀 激进高收益策略"
    echo "4. 🐌 保守安全策略"
    echo ""
    
    read -p "请选择策略 (1-4): " strategy_choice
    
    case $strategy_choice in
        1)
            log_info "选择: 全自动智能策略"
            strategy_mode="intelligent"
            ;;
        2)
            log_info "选择: 平衡稳健策略"
            strategy_mode="balanced"
            ;;
        3)
            log_info "选择: 激进高收益策略"
            strategy_mode="aggressive"
            ;;
        4)
            log_info "选择: 保守安全策略"
            strategy_mode="conservative"
            ;;
        *)
            log_warn "无效选择，使用默认智能策略"
            strategy_mode="intelligent"
            ;;
    esac
    
    # 获取私钥
    echo ""
    echo "请输入您的私钥："
    read -s -p "私钥: " private_key
    echo ""
    
    # 启动挖矿
    start_mining "$private_key" "$strategy_mode"
}

# 启动挖矿
start_mining() {
    local private_key="$1"
    local strategy="$2"
    
    log_step "启动智能挖矿系统..."
    
    # 创建screen会话
    local session_name="worm-mining-$(date +%s)"
    
    if [ -f "$WORK_DIR/scripts/smart_mining.sh" ]; then
        # 在screen会话中启动挖矿
        screen -dmS "$session_name" bash "$WORK_DIR/scripts/smart_mining.sh" "$private_key"
        
        log_success "挖矿系统已在screen会话中启动: $session_name"
        log_info "查看挖矿状态: screen -r $session_name"
        log_info "退出screen: Ctrl+A, D"
        
        # 保存会话信息
        echo "$session_name" > "$CONFIG_DIR/mining_session.txt"
        
    else
        log_error "挖矿脚本不存在"
        return 1
    fi
}

# 启动狙击策略
start_sniper_strategy() {
    echo ""
    echo "================================================"
    echo "🎯 狙击手策略系统"
    echo "================================================"
    echo ""
    echo -e "${RED}${BOLD}⚠️ 高级策略警告:${NC}"
    echo "• 狙击策略属于高风险高收益策略"
    echo "• 需要精确的时机把握和网络条件"
    echo "• 建议先小额测试，熟悉机制后再使用"
    echo "• 可能与其他狙击手产生竞争"
    echo ""
    
    read -p "确认启动狙击策略？(y/N): " confirm_sniper
    if [ "$confirm_sniper" != "y" ] && [ "$confirm_sniper" != "Y" ]; then
        log_info "用户取消狙击策略"
        return 0
    fi
    
    # 获取私钥
    echo ""
    echo "请输入您的私钥："
    read -s -p "私钥: " private_key
    echo ""
    
    # 创建screen会话
    local session_name="worm-sniper-$(date +%s)"
    
    if [ -f "$WORK_DIR/scripts/sniper_strategy.sh" ]; then
        screen -dmS "$session_name" bash "$WORK_DIR/scripts/sniper_strategy.sh" "$private_key"
        
        log_success "🎯 狙击手系统已在screen会话中启动: $session_name"
        log_info "查看狙击状态: screen -r $session_name"
        log_warn "注意: 狙击系统将持续监控并在最后时刻执行"
        
        # 保存会话信息
        echo "$session_name" > "$CONFIG_DIR/sniper_session.txt"
        
    else
        log_error "狙击策略脚本不存在"
        return 1
    fi
}

# 启动高级自定义狙击策略
start_advanced_sniper() {
    echo ""
    echo "================================================"
    echo "🚀 高级自定义狙击策略系统"
    echo "================================================"
    echo ""
    echo -e "${RED}${BOLD}🎯 专家级策略警告:${NC}"
    echo "• 这是最高级的狙击策略，支持完全自定义规则"
    echo "• 可以根据竞争情况设置不同的投入倍数"
    echo "• 需要深度理解WORM挖矿机制"
    echo "• 建议有经验的用户使用"
    echo "• 收益潜力: 50%-300% 提升"
    echo ""
    echo -e "${YELLOW}💡 功能特点:${NC}"
    echo "• 📊 实时监控未确认区块投入情况"
    echo "• 🎯 根据竞争水平自动调整投入倍数"  
    echo "• ⏰ 在最后1-3分钟精准执行投入"
    echo "• 🧠 完全自定义策略规则"
    echo ""
    
    read -p "确认启动高级自定义狙击策略？(y/N): " confirm_advanced
    if [ "$confirm_advanced" != "y" ] && [ "$confirm_advanced" != "Y" ]; then
        log_info "用户取消高级狙击策略"
        return 0
    fi
    
    # 创建screen会话运行高级狙击脚本
    local session_name="worm-advanced-sniper-$(date +%s)"
    
    if [ -f "$WORK_DIR/scripts/advanced_sniper.sh" ]; then
        screen -dmS "$session_name" bash "$WORK_DIR/scripts/advanced_sniper.sh"
        
        log_success "🚀 高级狙击系统已在screen会话中启动: $session_name"
        log_info "查看狙击状态: screen -r $session_name"
        log_warn "注意: 系统会引导您配置自定义策略规则"
        
        # 保存会话信息
        echo "$session_name" > "$CONFIG_DIR/advanced_sniper_session.txt"
        
    else
        log_error "高级狙击策略脚本不存在"
        return 1
    fi
}

# 启动自动领取
start_auto_claim() {
    echo ""
    echo "================================================"
    echo "🎁 自动领取奖励"
    echo "================================================"
    
    # 获取私钥
    echo "请输入您的私钥："
    read -s -p "私钥: " private_key
    echo ""
    
    # 创建screen会话
    local session_name="worm-claim-$(date +%s)"
    
    if [ -f "$WORK_DIR/scripts/auto_claim.sh" ]; then
        screen -dmS "$session_name" bash "$WORK_DIR/scripts/auto_claim.sh" "$private_key"
        
        log_success "自动领取已在screen会话中启动: $session_name"
        log_info "查看领取状态: screen -r $session_name"
        
        # 保存会话信息
        echo "$session_name" > "$CONFIG_DIR/claim_session.txt"
        
    else
        log_error "自动领取脚本不存在"
        return 1
    fi
}

# 监控面板
monitoring_dashboard() {
    echo ""
    echo "================================================"
    echo "📊 监控面板"
    echo "================================================"
    
    # 显示当前运行的会话
    echo "🔄 当前运行的服务:"
    
    if [ -f "$CONFIG_DIR/mining_session.txt" ]; then
        local mining_session=$(cat "$CONFIG_DIR/mining_session.txt")
        if screen -list | grep -q "$mining_session"; then
            echo "  ✅ 挖矿服务: $mining_session (运行中)"
        else
            echo "  ❌ 挖矿服务: 未运行"
        fi
    else
        echo "  ❌ 挖矿服务: 未启动"
    fi
    
    if [ -f "$CONFIG_DIR/claim_session.txt" ]; then
        local claim_session=$(cat "$CONFIG_DIR/claim_session.txt")
        if screen -list | grep -q "$claim_session"; then
            echo "  ✅ 自动领取: $claim_session (运行中)"
        else
            echo "  ❌ 自动领取: 未运行"
        fi
    else
        echo "  ❌ 自动领取: 未启动"
    fi
    
    if [ -f "$CONFIG_DIR/sniper_session.txt" ]; then
        local sniper_session=$(cat "$CONFIG_DIR/sniper_session.txt")
        if screen -list | grep -q "$sniper_session"; then
            echo "  🎯 狙击系统: $sniper_session (监控中)"
        else
            echo "  ❌ 狙击系统: 未运行"
        fi
    else
        echo "  ❌ 狙击系统: 未启动"
    fi
    
    if [ -f "$CONFIG_DIR/advanced_sniper_session.txt" ]; then
        local advanced_sniper_session=$(cat "$CONFIG_DIR/advanced_sniper_session.txt")
        if screen -list | grep -q "$advanced_sniper_session"; then
            echo "  🚀 高级狙击: $advanced_sniper_session (自定义策略运行中)"
        else
            echo "  ❌ 高级狙击: 未运行"
        fi
    else
        echo "  ❌ 高级狙击: 未启动"
    fi
    
    echo ""
    echo "📋 管理操作:"
    echo "1. 查看挖矿日志"
    echo "2. 查看领取日志"
    echo "3. 查看狙击日志"
    echo "4. 查看高级狙击日志"
    echo "5. 停止所有服务"
    echo "6. 重启服务"
    echo "7. 返回主菜单"
    echo ""
    
    read -p "请选择操作 (1-7): " monitor_choice
    
    case $monitor_choice in
        1)
            if [ -f "$CONFIG_DIR/mining_session.txt" ]; then
                local session=$(cat "$CONFIG_DIR/mining_session.txt")
                log_info "连接到挖矿会话: $session"
                screen -r "$session"
            else
                log_warn "挖矿服务未启动"
            fi
            ;;
        2)
            if [ -f "$CONFIG_DIR/claim_session.txt" ]; then
                local session=$(cat "$CONFIG_DIR/claim_session.txt")
                log_info "连接到领取会话: $session"
                screen -r "$session"
            else
                log_warn "自动领取服务未启动"
            fi
            ;;
        3)
            if [ -f "$CONFIG_DIR/sniper_session.txt" ]; then
                local session=$(cat "$CONFIG_DIR/sniper_session.txt")
                log_info "连接到狙击会话: $session"
                screen -r "$session"
            else
                log_warn "狙击系统未启动"
            fi
            ;;
        4)
            if [ -f "$CONFIG_DIR/advanced_sniper_session.txt" ]; then
                local session=$(cat "$CONFIG_DIR/advanced_sniper_session.txt")
                log_info "连接到高级狙击会话: $session"
                screen -r "$session"
            else
                log_warn "高级狙击系统未启动"
            fi
            ;;
        5)
            stop_all_services
            ;;
        6)
            restart_services
            ;;
        7)
            return 0
            ;;
        *)
            log_warn "无效选择"
            ;;
    esac
}

# 停止所有服务
stop_all_services() {
    log_step "停止所有服务..."
    
    # 停止挖矿服务
    if [ -f "$CONFIG_DIR/mining_session.txt" ]; then
        local mining_session=$(cat "$CONFIG_DIR/mining_session.txt")
        screen -S "$mining_session" -X quit 2>/dev/null || true
        rm -f "$CONFIG_DIR/mining_session.txt"
        log_info "✓ 挖矿服务已停止"
    fi
    
    # 停止自动领取服务
    if [ -f "$CONFIG_DIR/claim_session.txt" ]; then
        local claim_session=$(cat "$CONFIG_DIR/claim_session.txt")
        screen -S "$claim_session" -X quit 2>/dev/null || true
        rm -f "$CONFIG_DIR/claim_session.txt"
        log_info "✓ 自动领取服务已停止"
    fi
    
    # 停止狙击系统
    if [ -f "$CONFIG_DIR/sniper_session.txt" ]; then
        local sniper_session=$(cat "$CONFIG_DIR/sniper_session.txt")
        screen -S "$sniper_session" -X quit 2>/dev/null || true
        rm -f "$CONFIG_DIR/sniper_session.txt"
        log_info "✓ 狙击系统已停止"
    fi
    
    # 停止高级狙击系统
    if [ -f "$CONFIG_DIR/advanced_sniper_session.txt" ]; then
        local advanced_sniper_session=$(cat "$CONFIG_DIR/advanced_sniper_session.txt")
        screen -S "$advanced_sniper_session" -X quit 2>/dev/null || true
        rm -f "$CONFIG_DIR/advanced_sniper_session.txt"
        log_info "✓ 高级狙击系统已停止"
    fi
    
    log_success "所有服务已停止"
}

# 重启服务
restart_services() {
    log_step "重启服务..."
    
    stop_all_services
    sleep 2
    
    echo "请输入私钥以重启服务："
    read -s -p "私钥: " private_key
    echo ""
    
    # 重启挖矿
    start_mining "$private_key" "intelligent"
    
    # 重启自动领取
    local claim_session="worm-claim-$(date +%s)"
    screen -dmS "$claim_session" bash "$WORK_DIR/scripts/auto_claim.sh" "$private_key"
    echo "$claim_session" > "$CONFIG_DIR/claim_session.txt"
    
    log_success "服务重启完成"
}

# 显示主菜单
show_main_menu() {
    echo ""
    echo "================================================"
    echo "📋 主功能菜单"
    echo "================================================"
    echo ""
    echo "1. 🛠️  系统安装/更新"
    echo "2. 🔥  燃烧ETH获取BETH"
    echo "3. 🧠  启动智能挖矿"
    echo "4. 🎯  启动狙击策略 (高级)"
    echo "5. 🚀  启动自定义狙击 (专家级)"
    echo "6. 🎁  启动自动领取"
    echo "7. 📊  监控面板"
    echo "8. ⚙️   系统设置"
    echo "9. 📖  帮助文档"
    echo "10. 🚪  退出程序"
    echo ""
    echo -e "${YELLOW}提示: 建议先安装系统，然后燃烧ETH，最后启动挖矿${NC}"
    echo ""
}

# 系统设置
system_settings() {
    echo ""
    echo "================================================"
    echo "⚙️ 系统设置"
    echo "================================================"
    echo ""
    echo "1. 查看系统状态"
    echo "2. 备份配置文件"
    echo "3. 清理日志文件"
    echo "4. 更新脚本"
    echo "5. 返回主菜单"
    echo ""
    
    read -p "请选择操作 (1-5): " settings_choice
    
    case $settings_choice in
        1)
            show_system_status
            ;;
        2)
            backup_configs
            ;;
        3)
            clean_logs
            ;;
        4)
            update_scripts
            ;;
        5)
            return 0
            ;;
        *)
            log_warn "无效选择"
            ;;
    esac
}

# 显示系统状态
show_system_status() {
    echo ""
    echo "================================================"
    echo "💻 系统状态"
    echo "================================================"
    
    echo "🖥️ 系统信息:"
    echo "  操作系统: $(lsb_release -d 2>/dev/null | cut -f2 || echo 'Unknown')"
    echo "  架构: $(uname -m)"
    echo "  内存: $(free -h | awk '/^Mem:/{print $2}')"
    echo "  磁盘: $(df -h / | awk 'NR==2{print $4 " 可用 / " $2 " 总计"}')"
    
    echo ""
    echo "📦 软件版本:"
    if command -v worm-miner &> /dev/null; then
        echo "  ✅ worm-miner: 已安装"
    else
        echo "  ❌ worm-miner: 未安装"
    fi
    
    if command -v rustc &> /dev/null; then
        echo "  ✅ Rust: $(rustc --version | awk '{print $2}')"
    else
        echo "  ❌ Rust: 未安装"
    fi
    
    echo ""
    echo "📁 工作目录:"
    echo "  路径: $WORK_DIR"
    echo "  大小: $(du -sh "$WORK_DIR" 2>/dev/null | awk '{print $1}' || echo 'Unknown')"
    
    echo ""
    read -p "按回车键继续..."
}

# 帮助文档
show_help() {
    echo ""
    echo "================================================"
    echo "📖 WORM挖矿系统帮助文档"
    echo "================================================"
    echo ""
    echo "🚀 快速开始:"
    echo "1. 选择 '系统安装/更新' 安装必要组件"
    echo "2. 准备足够的Sepolia ETH"
    echo "3. 选择 '燃烧ETH获取BETH' 转换资产"
    echo "4. 选择 '启动智能挖矿' 开始挖矿"
    echo "5. 选择 '启动自动领取' 自动收取奖励"
    echo ""
    echo "💡 挖矿策略说明:"
    echo "• 智能策略: 根据竞争情况自动调整投入"
    echo "• 狙击策略: 实时监控，最后时刻精准投入 (高级)"
    echo "• 平衡策略: 稳健的投入策略"
    echo "• 激进策略: 高风险高收益"
    echo "• 保守策略: 低风险稳定收益"
    echo ""
    echo "⚠️ 重要提醒:"
    echo "• 私钥安全非常重要，不要泄露给他人"
    echo "• 建议在screen会话中运行长期任务"
    echo "• 定期检查系统状态和收益情况"
    echo "• 保持足够的ETH余额支付gas费用"
    echo ""
    echo "🔗 相关命令:"
    echo "• 查看screen会话: screen -list"
    echo "• 连接到会话: screen -r <会话名>"
    echo "• 退出screen: Ctrl+A, D"
    echo "• 停止会话: screen -S <会话名> -X quit"
    echo ""
    read -p "按回车键继续..."
}

# 备份配置
backup_configs() {
    log_step "备份配置文件..."
    
    local backup_dir="$WORK_DIR/backup/$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$backup_dir"
    
    cp -r "$CONFIG_DIR"/* "$backup_dir/" 2>/dev/null || true
    
    log_success "配置文件已备份到: $backup_dir"
}

# 清理日志
clean_logs() {
    log_step "清理日志文件..."
    
    find "$LOG_DIR" -name "*.log" -mtime +7 -delete 2>/dev/null || true
    
    log_success "日志清理完成"
}

# 更新脚本
update_scripts() {
    log_step "更新脚本文件..."
    
    # 这里可以添加从GitHub下载最新脚本的逻辑
    log_warn "脚本更新功能需要在GitHub仓库创建后实现"
}

# 主程序循环
main_loop() {
    while true; do
        show_banner
        show_main_menu
        
        read -p "请选择功能 (1-10): " choice
        
        case $choice in
            1)
                install_system
                ;;
            2)
                burn_eth_interface
                ;;
            3)
                mining_strategy_interface
                ;;
            4)
                start_sniper_strategy
                ;;
            5)
                start_advanced_sniper
                ;;
            6)
                start_auto_claim
                ;;
            7)
                monitoring_dashboard
                ;;
            8)
                system_settings
                ;;
            9)
                show_help
                ;;
            10)
                log_info "感谢使用WORM智能挖矿系统！"
                exit 0
                ;;
            *)
                log_warn "无效选择，请重试"
                sleep 2
                ;;
        esac
        
        echo ""
        read -p "按回车键继续..."
    done
}

# 初始化
initialize() {
    # 检查环境
    check_environment
    
    # 创建目录
    create_directories
    
    # 下载脚本
    download_scripts
}

# 主函数
main() {
    # 检查是否在VPS上运行
    if [ -n "$SSH_CONNECTION" ]; then
        log_info "检测到VPS环境"
    fi
    
    # 初始化系统
    initialize
    
    # 进入主循环
    main_loop
}

# 信号处理
trap 'echo ""; log_info "程序被中断，正在安全退出..."; exit 0' SIGINT SIGTERM

# 执行主函数
main "$@"
