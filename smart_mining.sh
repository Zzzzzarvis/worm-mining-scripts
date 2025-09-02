#!/bin/bash

# WORM智能挖矿策略脚本
# 根据竞争情况自动调整投入策略：少人时梭哈，多人时稳健

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

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

log_strategy() {
    echo -e "${PURPLE}[$(date '+%H:%M:%S')] [STRATEGY]${NC} $1"
}

log_mining() {
    echo -e "${CYAN}[$(date '+%H:%M:%S')] [MINING]${NC} $1"
}

# 挖矿策略配置
declare -A MINING_CONFIG=(
    # 基础配置
    ["NETWORK"]="sepolia"
    ["MONITOR_INTERVAL"]="300"     # 监控间隔5分钟
    ["EPOCH_DURATION"]="1800"      # 每个epoch 30分钟
    
    # 竞争阈值配置
    ["LOW_COMPETITION"]="2.0"      # 低竞争阈值: 总质押 < 2 BETH
    ["MEDIUM_COMPETITION"]="10.0"  # 中等竞争阈值: 2-10 BETH
    ["HIGH_COMPETITION"]="20.0"    # 高竞争阈值: > 20 BETH
    
    # 投入策略配置
    ["BASE_STAKE"]="0.05"          # 基础投入量
    ["AGGRESSIVE_STAKE"]="0.5"     # 激进投入量（梭哈模式）
    ["CONSERVATIVE_STAKE"]="0.02"  # 保守投入量
    ["MAX_STAKE_PER_EPOCH"]="1.0"  # 单个epoch最大投入
    
    # 风控配置
    ["MIN_BETH_RESERVE"]="0.1"     # 最小BETH储备
    ["MAX_EPOCHS_AHEAD"]="5"       # 最多提前参与的epoch数
    ["RISK_LEVEL"]="medium"        # 风险级别: low/medium/high
)

# 全局变量
PRIVATE_KEY=""
CURRENT_STRATEGY=""
TOTAL_BETH_BALANCE=0
AVAILABLE_BETH=0
CURRENT_EPOCH=0

# 获取账户信息
get_account_info() {
    local info_output
    info_output=$(worm-miner info --network "${MINING_CONFIG[NETWORK]}" --private-key "$PRIVATE_KEY" 2>/dev/null)
    
    if [ $? -ne 0 ]; then
        log_error "获取账户信息失败"
        return 1
    fi
    
    # 解析当前epoch
    CURRENT_EPOCH=$(echo "$info_output" | grep "Current epoch:" | awk '{print $3}')
    
    # 解析BETH余额
    TOTAL_BETH_BALANCE=$(echo "$info_output" | grep "BETH balance:" | awk '{print $3}')
    
    # 计算可用BETH（保留储备金）
    AVAILABLE_BETH=$(echo "$TOTAL_BETH_BALANCE - ${MINING_CONFIG[MIN_BETH_RESERVE]}" | bc -l)
    
    # 确保可用BETH不为负数
    if (( $(echo "$AVAILABLE_BETH < 0" | bc -l) )); then
        AVAILABLE_BETH=0
    fi
    
    echo "$info_output"
}

# 分析竞争情况
analyze_competition() {
    local info_output="$1"
    local total_committed=0
    local participant_count=0
    
    # 解析最近几个epoch的竞争情况
    local recent_epochs=$(echo "$info_output" | grep "Epoch #" | head -3)
    
    if [ -z "$recent_epochs" ]; then
        echo "unknown 0 0"
        return
    fi
    
    # 计算平均竞争水平
    while IFS= read -r line; do
        if [[ $line == *"Epoch #"* ]]; then
            # 提取总投入量（格式：Epoch #X => your_amount / total_amount）
            local total=$(echo "$line" | sed 's/.*\/ \([0-9.]*\).*/\1/')
            if [[ $total =~ ^[0-9]+\.?[0-9]*$ ]]; then
                total_committed=$(echo "$total_committed + $total" | bc -l)
                ((participant_count++))
            fi
        fi
    done <<< "$recent_epochs"
    
    if [ $participant_count -eq 0 ]; then
        echo "unknown 0 0"
        return
    fi
    
    # 计算平均竞争水平
    local avg_competition=$(echo "$total_committed / $participant_count" | bc -l)
    
    # 判断竞争级别
    local competition_level
    if (( $(echo "$avg_competition < ${MINING_CONFIG[LOW_COMPETITION]}" | bc -l) )); then
        competition_level="low"
    elif (( $(echo "$avg_competition < ${MINING_CONFIG[MEDIUM_COMPETITION]}" | bc -l) )); then
        competition_level="medium"
    else
        competition_level="high"
    fi
    
    echo "$competition_level $avg_competition $participant_count"
}

# 计算最优投入策略
calculate_optimal_stake() {
    local competition_level="$1"
    local avg_competition="$2"
    local participant_count="$3"
    
    local stake_amount
    local epochs_to_participate
    local strategy_description
    
    case "$competition_level" in
        "low")
            # 低竞争：激进策略，大量投入
            stake_amount=$(echo "${MINING_CONFIG[AGGRESSIVE_STAKE]}" | bc -l)
            epochs_to_participate=3
            strategy_description="🚀 激进模式：低竞争环境，大量投入获取高收益"
            CURRENT_STRATEGY="aggressive"
            ;;
        "medium")
            # 中等竞争：平衡策略
            stake_amount=$(echo "${MINING_CONFIG[BASE_STAKE]} * 2" | bc -l)
            epochs_to_participate=4
            strategy_description="⚖️ 平衡模式：中等竞争，稳健投入"
            CURRENT_STRATEGY="balanced"
            ;;
        "high")
            # 高竞争：保守策略，小额投入等待机会
            stake_amount=$(echo "${MINING_CONFIG[CONSERVATIVE_STAKE]}" | bc -l)
            epochs_to_participate=2
            strategy_description="🐌 保守模式：高竞争环境，小额投入等待机会"
            CURRENT_STRATEGY="conservative"
            ;;
        *)
            # 未知情况：使用基础策略
            stake_amount=$(echo "${MINING_CONFIG[BASE_STAKE]}" | bc -l)
            epochs_to_participate=2
            strategy_description="❓ 基础模式：竞争情况未知，使用基础策略"
            CURRENT_STRATEGY="basic"
            ;;
    esac
    
    # 风险控制：确保不超过可用BETH
    local max_total_stake=$(echo "$stake_amount * $epochs_to_participate" | bc -l)
    if (( $(echo "$max_total_stake > $AVAILABLE_BETH" | bc -l) )); then
        if (( $(echo "$AVAILABLE_BETH > 0" | bc -l) )); then
            stake_amount=$(echo "$AVAILABLE_BETH / $epochs_to_participate" | bc -l)
            log_warn "调整投入量以适应可用BETH余额"
        else
            stake_amount=0
            epochs_to_participate=0
            strategy_description="❌ 无可用BETH，暂停挖矿"
        fi
    fi
    
    # 确保不超过单epoch最大投入
    if (( $(echo "$stake_amount > ${MINING_CONFIG[MAX_STAKE_PER_EPOCH]}" | bc -l) )); then
        stake_amount="${MINING_CONFIG[MAX_STAKE_PER_EPOCH]}"
    fi
    
    echo "$stake_amount $epochs_to_participate $strategy_description"
}

# 执行挖矿参与
execute_mining() {
    local stake_amount="$1"
    local epochs_to_participate="$2"
    
    if (( $(echo "$stake_amount <= 0" | bc -l) )) || [ "$epochs_to_participate" -eq 0 ]; then
        log_warn "跳过挖矿：投入量为0或epoch数为0"
        return 0
    fi
    
    log_mining "执行挖矿参与..."
    log_mining "每epoch投入: $stake_amount BETH"
    log_mining "参与epoch数: $epochs_to_participate"
    log_mining "总投入: $(echo "$stake_amount * $epochs_to_participate" | bc -l) BETH"
    
    if worm-miner participate \
        --amount-per-epoch "$stake_amount" \
        --num-epochs "$epochs_to_participate" \
        --private-key "$PRIVATE_KEY" \
        --network "${MINING_CONFIG[NETWORK]}"; then
        
        log_info "✓ 挖矿参与成功"
        return 0
    else
        log_error "✗ 挖矿参与失败"
        return 1
    fi
}

# 智能挖矿主循环
smart_mining_loop() {
    log_info "启动智能挖矿系统..."
    log_info "监控间隔: ${MINING_CONFIG[MONITOR_INTERVAL]}秒"
    
    local loop_count=0
    
    while true; do
        ((loop_count++))
        
        echo ""
        echo "========================================"
        log_info "🔄 智能挖矿循环 #$loop_count"
        echo "========================================"
        
        # 获取账户信息
        log_info "📊 获取账户信息..."
        local info_output
        if ! info_output=$(get_account_info); then
            log_error "获取账户信息失败，等待下次检查..."
            sleep "${MINING_CONFIG[MONITOR_INTERVAL]}"
            continue
        fi
        
        # 显示基本信息
        log_info "当前Epoch: $CURRENT_EPOCH"
        log_info "BETH总余额: $TOTAL_BETH_BALANCE"
        log_info "可用BETH: $AVAILABLE_BETH"
        
        # 分析竞争情况
        log_info "🔍 分析竞争情况..."
        local competition_info
        competition_info=$(analyze_competition "$info_output")
        read -r competition_level avg_competition participant_count <<< "$competition_info"
        
        log_info "竞争级别: $competition_level"
        log_info "平均投入: $avg_competition BETH"
        log_info "参与者数: $participant_count"
        
        # 计算最优策略
        log_strategy "💡 计算最优投入策略..."
        local strategy_info
        strategy_info=$(calculate_optimal_stake "$competition_level" "$avg_competition" "$participant_count")
        read -r stake_amount epochs_to_participate strategy_description <<< "$strategy_info"
        
        log_strategy "$strategy_description"
        
        # 执行挖矿
        if [ "$CURRENT_STRATEGY" != "none" ]; then
            execute_mining "$stake_amount" "$epochs_to_participate"
        fi
        
        # 显示下次检查时间
        local next_check=$(date -d "+${MINING_CONFIG[MONITOR_INTERVAL]} seconds" '+%H:%M:%S')
        log_info "⏰ 下次检查时间: $next_check"
        
        # 等待下次检查
        sleep "${MINING_CONFIG[MONITOR_INTERVAL]}"
    done
}

# 显示挖矿策略配置
show_strategy_config() {
    echo "================================================"
    echo "🧠 智能挖矿策略配置"
    echo "================================================"
    echo ""
    echo "📊 竞争分析阈值:"
    echo "  低竞争: < ${MINING_CONFIG[LOW_COMPETITION]} BETH"
    echo "  中等竞争: ${MINING_CONFIG[LOW_COMPETITION]} - ${MINING_CONFIG[MEDIUM_COMPETITION]} BETH"
    echo "  高竞争: > ${MINING_CONFIG[MEDIUM_COMPETITION]} BETH"
    echo ""
    echo "💰 投入策略:"
    echo "  激进模式: ${MINING_CONFIG[AGGRESSIVE_STAKE]} BETH/epoch (低竞争时)"
    echo "  平衡模式: $(echo "${MINING_CONFIG[BASE_STAKE]} * 2" | bc -l) BETH/epoch (中等竞争时)"
    echo "  保守模式: ${MINING_CONFIG[CONSERVATIVE_STAKE]} BETH/epoch (高竞争时)"
    echo ""
    echo "🛡️ 风控设置:"
    echo "  最小储备: ${MINING_CONFIG[MIN_BETH_RESERVE]} BETH"
    echo "  单epoch上限: ${MINING_CONFIG[MAX_STAKE_PER_EPOCH]} BETH"
    echo "  监控间隔: ${MINING_CONFIG[MONITOR_INTERVAL]}秒"
    echo ""
}

# 验证私钥
validate_private_key() {
    local private_key="$1"
    
    if [[ ${#private_key} -eq 64 ]] && [[ $private_key =~ ^[0-9a-fA-F]+$ ]]; then
        return 0
    elif [[ ${#private_key} -eq 66 ]] && [[ $private_key =~ ^0x[0-9a-fA-F]+$ ]]; then
        return 0
    else
        return 1
    fi
}

# 检查依赖
check_dependencies() {
    local missing_deps=()
    
    if ! command -v worm-miner &> /dev/null; then
        missing_deps+=("worm-miner")
    fi
    
    if ! command -v bc &> /dev/null; then
        missing_deps+=("bc")
    fi
    
    if [ ${#missing_deps[@]} -gt 0 ]; then
        log_error "缺少依赖: ${missing_deps[*]}"
        log_error "请先运行安装脚本"
        exit 1
    fi
}

# 主函数
main() {
    clear
    echo "================================================"
    echo "🧠 WORM智能挖矿系统"
    echo "================================================"
    echo ""
    
    # 检查依赖
    check_dependencies
    
    # 显示策略配置
    show_strategy_config
    
    # 获取私钥
    if [ -z "$1" ]; then
        echo "请输入您的私钥："
        read -s -p "私钥: " PRIVATE_KEY
        echo ""
    else
        PRIVATE_KEY="$1"
    fi
    
    # 验证私钥
    if ! validate_private_key "$PRIVATE_KEY"; then
        log_error "私钥格式不正确"
        exit 1
    fi
    
    # 确认开始
    echo ""
    log_warn "智能挖矿系统将持续运行，建议在screen会话中执行"
    read -p "确认开始智能挖矿？(y/N): " confirm
    if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
        log_info "用户取消操作"
        exit 0
    fi
    
    # 启动智能挖矿
    smart_mining_loop
}

# 信号处理
trap 'log_info "收到终止信号，正在安全退出..."; exit 0' SIGINT SIGTERM

# 执行主函数
main "$@"
