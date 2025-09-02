#!/bin/bash

# WORM挖矿系统 - 自动领取奖励脚本
# 智能监控并自动领取可用的WORM奖励

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

log_claim() {
    echo -e "${CYAN}[$(date '+%H:%M:%S')] [CLAIM]${NC} $1"
}

log_reward() {
    echo -e "${PURPLE}[$(date '+%H:%M:%S')] [REWARD]${NC} $1"
}

# 配置参数
declare -A CLAIM_CONFIG=(
    ["NETWORK"]="sepolia"
    ["CHECK_INTERVAL"]="600"           # 检查间隔10分钟
    ["MIN_CLAIM_AMOUNT"]="0.001"       # 最小领取数量阈值
    ["MAX_EPOCHS_PER_CLAIM"]="20"      # 单次最多领取的epoch数
    ["RETRY_ATTEMPTS"]="3"             # 失败重试次数
    ["RETRY_DELAY"]="30"               # 重试间隔
    ["AUTO_CLAIM_ENABLED"]="true"      # 是否启用自动领取
)

# 全局变量
PRIVATE_KEY=""
TOTAL_CLAIMED=0
CLAIM_COUNT=0
LAST_CLAIM_TIME=0

# 解析账户信息获取可领取数量
parse_claimable_amount() {
    local info_output="$1"
    
    # 提取可领取WORM数量
    local claimable=$(echo "$info_output" | grep "Claimable WORM" | awk '{print $4}')
    
    if [[ $claimable =~ ^[0-9]+\.?[0-9]*$ ]]; then
        echo "$claimable"
    else
        echo "0"
    fi
}

# 解析epoch信息
parse_epoch_info() {
    local info_output="$1"
    local current_epoch
    local completed_epochs=()
    
    # 获取当前epoch
    current_epoch=$(echo "$info_output" | grep "Current epoch:" | awk '{print $3}')
    
    # 查找已完成且有奖励的epoch
    local epoch_lines=$(echo "$info_output" | grep "Epoch #" | grep -v "0.000000000000000000 WORM")
    
    while IFS= read -r line; do
        if [[ $line == *"Epoch #"* ]] && [[ $line != *"0.000000000000000000 WORM"* ]]; then
            local epoch_num=$(echo "$line" | sed 's/Epoch #\([0-9]*\).*/\1/')
            local expected_worm=$(echo "$line" | sed 's/.*(\(Expecting\|Earned\) \([0-9.]*\) WORM).*/\2/')
            
            if [[ $epoch_num =~ ^[0-9]+$ ]] && [[ $expected_worm =~ ^[0-9]+\.?[0-9]*$ ]] && (( $(echo "$expected_worm > 0" | bc -l) )); then
                completed_epochs+=("$epoch_num:$expected_worm")
            fi
        fi
    done <<< "$epoch_lines"
    
    echo "$current_epoch ${completed_epochs[*]}"
}

# 检查是否有可领取奖励
check_claimable_rewards() {
    local private_key="$1"
    
    log_claim "🔍 检查可领取奖励..."
    
    # 获取账户信息
    local info_output
    info_output=$(worm-miner info --network "${CLAIM_CONFIG[NETWORK]}" --private-key "$private_key" 2>/dev/null)
    
    if [ $? -ne 0 ]; then
        log_error "获取账户信息失败"
        return 1
    fi
    
    # 解析可领取数量
    local claimable_amount
    claimable_amount=$(parse_claimable_amount "$info_output")
    
    # 解析epoch信息
    local epoch_info
    epoch_info=$(parse_epoch_info "$info_output")
    read -r current_epoch completed_epochs_str <<< "$epoch_info"
    
    # 转换为数组
    local completed_epochs=()
    if [ -n "$completed_epochs_str" ]; then
        IFS=' ' read -ra completed_epochs <<< "$completed_epochs_str"
    fi
    
    # 显示检查结果
    log_claim "当前Epoch: $current_epoch"
    log_claim "可领取WORM: $claimable_amount"
    log_claim "待领取Epoch数: ${#completed_epochs[@]}"
    
    # 检查是否达到领取阈值
    if (( $(echo "$claimable_amount >= ${CLAIM_CONFIG[MIN_CLAIM_AMOUNT]}" | bc -l) )); then
        echo "claimable $claimable_amount ${#completed_epochs[@]} ${completed_epochs[*]}"
        return 0
    else
        echo "not_claimable $claimable_amount ${#completed_epochs[@]}"
        return 0
    fi
}

# 执行奖励领取
execute_claim() {
    local private_key="$1"
    local epochs_count="$2"
    local estimated_amount="$3"
    
    if [ "$epochs_count" -eq 0 ]; then
        log_warn "没有可领取的epoch"
        return 0
    fi
    
    # 计算领取参数
    local from_epoch=0  # 从epoch 0开始
    local num_epochs="$epochs_count"
    
    # 限制单次领取的epoch数量
    if [ "$num_epochs" -gt "${CLAIM_CONFIG[MAX_EPOCHS_PER_CLAIM]}" ]; then
        num_epochs="${CLAIM_CONFIG[MAX_EPOCHS_PER_CLAIM]}"
    fi
    
    log_claim "🎁 执行奖励领取..."
    log_claim "起始Epoch: $from_epoch"
    log_claim "Epoch数量: $num_epochs"
    log_claim "预期奖励: $estimated_amount WORM"
    
    # 重试机制
    local attempt=1
    while [ $attempt -le "${CLAIM_CONFIG[RETRY_ATTEMPTS]}" ]; do
        log_claim "🔄 尝试领取 (第 $attempt 次)..."
        
        if worm-miner claim \
            --from-epoch "$from_epoch" \
            --num-epochs "$num_epochs" \
            --private-key "$private_key" \
            --network "${CLAIM_CONFIG[NETWORK]}"; then
            
            log_reward "✅ 奖励领取成功！"
            
            # 更新统计信息
            TOTAL_CLAIMED=$(echo "$TOTAL_CLAIMED + $estimated_amount" | bc -l)
            ((CLAIM_COUNT++))
            LAST_CLAIM_TIME=$(date +%s)
            
            # 显示领取统计
            log_reward "📊 领取统计:"
            log_reward "   本次领取: $estimated_amount WORM"
            log_reward "   累计领取: $TOTAL_CLAIMED WORM"
            log_reward "   领取次数: $CLAIM_COUNT 次"
            
            return 0
        else
            log_error "❌ 第 $attempt 次领取失败"
            
            if [ $attempt -lt "${CLAIM_CONFIG[RETRY_ATTEMPTS]}" ]; then
                log_warn "等待 ${CLAIM_CONFIG[RETRY_DELAY]} 秒后重试..."
                sleep "${CLAIM_CONFIG[RETRY_DELAY]}"
            fi
            
            ((attempt++))
        fi
    done
    
    log_error "❌ 所有重试均失败，跳过本次领取"
    return 1
}

# 自动领取主循环
auto_claim_loop() {
    log_info "🚀 启动自动领取系统..."
    log_info "检查间隔: ${CLAIM_CONFIG[CHECK_INTERVAL]}秒"
    log_info "最小领取阈值: ${CLAIM_CONFIG[MIN_CLAIM_AMOUNT]} WORM"
    
    local loop_count=0
    
    while true; do
        ((loop_count++))
        
        echo ""
        echo "========================================"
        log_info "🔄 自动领取检查 #$loop_count"
        echo "========================================"
        
        # 检查可领取奖励
        local claim_result
        if claim_result=$(check_claimable_rewards "$PRIVATE_KEY"); then
            read -r status amount epochs_count epochs_info <<< "$claim_result"
            
            if [ "$status" = "claimable" ]; then
                log_reward "🎉 发现可领取奖励！"
                
                if [ "${CLAIM_CONFIG[AUTO_CLAIM_ENABLED]}" = "true" ]; then
                    execute_claim "$PRIVATE_KEY" "$epochs_count" "$amount"
                else
                    log_info "自动领取已禁用，跳过领取"
                fi
            else
                log_info "💤 暂无可领取奖励"
                log_info "当前可领取: $amount WORM (低于阈值 ${CLAIM_CONFIG[MIN_CLAIM_AMOUNT]})"
            fi
        else
            log_error "检查奖励失败，等待下次检查..."
        fi
        
        # 显示下次检查时间
        local next_check=$(date -d "+${CLAIM_CONFIG[CHECK_INTERVAL]} seconds" '+%H:%M:%S')
        log_info "⏰ 下次检查时间: $next_check"
        
        # 等待下次检查
        sleep "${CLAIM_CONFIG[CHECK_INTERVAL]}"
    done
}

# 手动领取模式
manual_claim() {
    local private_key="$1"
    
    echo "================================================"
    echo "🎁 手动领取奖励"
    echo "================================================"
    
    # 检查可领取奖励
    local claim_result
    if claim_result=$(check_claimable_rewards "$private_key"); then
        read -r status amount epochs_count epochs_info <<< "$claim_result"
        
        if [ "$status" = "claimable" ]; then
            echo ""
            log_reward "发现可领取奖励: $amount WORM"
            log_reward "待领取Epoch数: $epochs_count"
            echo ""
            
            read -p "确认领取奖励？(y/N): " confirm
            if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
                execute_claim "$private_key" "$epochs_count" "$amount"
            else
                log_info "用户取消领取"
            fi
        else
            log_info "暂无可领取奖励"
            log_info "当前可领取: $amount WORM"
        fi
    else
        log_error "检查奖励失败"
        exit 1
    fi
}

# 显示领取统计
show_claim_stats() {
    echo "================================================"
    echo "📊 领取统计信息"
    echo "================================================"
    echo ""
    echo "💰 累计领取: $TOTAL_CLAIMED WORM"
    echo "🔄 领取次数: $CLAIM_COUNT 次"
    
    if [ $LAST_CLAIM_TIME -gt 0 ]; then
        local last_claim_date=$(date -d "@$LAST_CLAIM_TIME" '+%Y-%m-%d %H:%M:%S')
        echo "🕐 最后领取: $last_claim_date"
    else
        echo "🕐 最后领取: 从未领取"
    fi
    
    if [ $CLAIM_COUNT -gt 0 ]; then
        local avg_claim=$(echo "$TOTAL_CLAIMED / $CLAIM_COUNT" | bc -l)
        printf "📈 平均每次: %.6f WORM\n" "$avg_claim"
    fi
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

# 显示配置信息
show_config() {
    echo "================================================"
    echo "⚙️ 自动领取配置"
    echo "================================================"
    echo ""
    echo "🔍 检查间隔: ${CLAIM_CONFIG[CHECK_INTERVAL]}秒 ($(echo "${CLAIM_CONFIG[CHECK_INTERVAL]} / 60" | bc)分钟)"
    echo "💰 最小阈值: ${CLAIM_CONFIG[MIN_CLAIM_AMOUNT]} WORM"
    echo "📦 最大批次: ${CLAIM_CONFIG[MAX_EPOCHS_PER_CLAIM]} epochs"
    echo "🔄 重试次数: ${CLAIM_CONFIG[RETRY_ATTEMPTS]} 次"
    echo "⏱️ 重试间隔: ${CLAIM_CONFIG[RETRY_DELAY]} 秒"
    echo "🤖 自动领取: ${CLAIM_CONFIG[AUTO_CLAIM_ENABLED]}"
    echo ""
}

# 主函数
main() {
    clear
    echo "================================================"
    echo "🎁 WORM自动领取奖励系统"
    echo "================================================"
    echo ""
    
    # 检查依赖
    check_dependencies
    
    # 显示配置
    show_config
    
    # 解析命令行参数
    local mode="auto"
    if [ "$1" = "manual" ]; then
        mode="manual"
        shift
    elif [ "$1" = "check" ]; then
        mode="check"
        shift
    fi
    
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
    
    # 根据模式执行操作
    case "$mode" in
        "manual")
            manual_claim "$PRIVATE_KEY"
            ;;
        "check")
            check_claimable_rewards "$PRIVATE_KEY"
            ;;
        "auto")
            echo ""
            log_warn "自动领取系统将持续运行，建议在screen会话中执行"
            read -p "确认启动自动领取？(y/N): " confirm
            if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
                auto_claim_loop
            else
                log_info "用户取消操作"
                exit 0
            fi
            ;;
        *)
            log_error "未知模式: $mode"
            exit 1
            ;;
    esac
}

# 信号处理
trap 'echo ""; log_info "收到终止信号，正在安全退出..."; show_claim_stats; exit 0' SIGINT SIGTERM

# 执行主函数
main "$@"
