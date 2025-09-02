#!/bin/bash

# WORM挖矿系统 - 狙击手策略脚本
# 实时监控epoch投入情况，在最后时刻精准投入获取高收益

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

# 狙击策略配置
declare -A SNIPER_CONFIG=(
    ["NETWORK"]="sepolia"
    ["EPOCH_DURATION"]="1800"          # 30分钟 = 1800秒
    ["MONITOR_START"]="300"            # 开始监控时间：epoch开始后5分钟
    ["SNIPE_WINDOW"]="180"             # 狙击窗口：最后3分钟
    ["EXECUTION_BUFFER"]="60"          # 执行缓冲：最后1分钟执行
    
    # 狙击阈值
    ["LOW_COMPETITION_THRESHOLD"]="1.0"     # 低竞争：< 1 BETH
    ["MEDIUM_COMPETITION_THRESHOLD"]="5.0"  # 中等竞争：1-5 BETH
    ["HIGH_COMPETITION_THRESHOLD"]="15.0"   # 高竞争：> 15 BETH
    
    # 狙击投入量
    ["SNIPE_AGGRESSIVE"]="2.0"         # 激进狙击：2 BETH
    ["SNIPE_BALANCED"]="0.5"           # 平衡狙击：0.5 BETH
    ["SNIPE_CONSERVATIVE"]="0.1"       # 保守狙击：0.1 BETH
    
    # 风控设置
    ["MAX_SNIPE_AMOUNT"]="3.0"         # 单次最大狙击量
    ["MIN_BETH_RESERVE"]="0.5"         # 最小储备
    ["SNIPE_SUCCESS_RATE_TARGET"]="70" # 目标成功率 70%
)

# 全局变量
PRIVATE_KEY=""
CURRENT_EPOCH=0
EPOCH_START_TIME=0
TOTAL_INVESTED=0
MY_INVESTED=0
COMPETITORS_COUNT=0
SNIPE_DECISION=""

# 日志函数
log_sniper() {
    echo -e "${PURPLE}[$(date '+%H:%M:%S')] [SNIPER]${NC} $1"
}

log_monitor() {
    echo -e "${CYAN}[$(date '+%H:%M:%S')] [MONITOR]${NC} $1"
}

log_execute() {
    echo -e "${RED}[$(date '+%H:%M:%S')] [EXECUTE]${NC} $1"
}

log_info() {
    echo -e "${GREEN}[$(date '+%H:%M:%S')] [INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[$(date '+%H:%M:%S')] [WARN]${NC} $1"
}

# 获取详细的epoch信息
get_detailed_epoch_info() {
    local private_key="$1"
    
    local info_output
    info_output=$(worm-miner info --network "${SNIPER_CONFIG[NETWORK]}" --private-key "$private_key" 2>/dev/null)
    
    if [ $? -ne 0 ]; then
        echo "error"
        return 1
    fi
    
    # 解析当前epoch
    CURRENT_EPOCH=$(echo "$info_output" | grep "Current epoch:" | awk '{print $3}')
    
    # 解析当前epoch的投入情况
    local current_epoch_line=$(echo "$info_output" | grep "Epoch #$CURRENT_EPOCH =>")
    
    if [ -n "$current_epoch_line" ]; then
        # 格式: Epoch #X => your_amount / total_amount (Expecting Y WORM)
        MY_INVESTED=$(echo "$current_epoch_line" | sed 's/.*=> \([0-9.]*\) \/.*/\1/')
        TOTAL_INVESTED=$(echo "$current_epoch_line" | sed 's/.*\/ \([0-9.]*\).*/\1/')
    else
        MY_INVESTED="0"
        TOTAL_INVESTED="0"
    fi
    
    # 计算其他参与者投入
    local others_invested=$(echo "$TOTAL_INVESTED - $MY_INVESTED" | bc -l)
    
    echo "$info_output"
    return 0
}

# 实时监控当前epoch
monitor_current_epoch() {
    local private_key="$1"
    
    while true; do
        # 获取当前时间
        local current_time=$(date +%s)
        local epoch_elapsed=$((current_time - EPOCH_START_TIME))
        local epoch_remaining=$((${SNIPER_CONFIG[EPOCH_DURATION]} - epoch_elapsed))
        
        # 检查epoch是否结束
        if [ $epoch_remaining -le 0 ]; then
            log_monitor "Epoch已结束，等待下一个epoch..."
            wait_for_next_epoch
            continue
        fi
        
        # 获取实时投入情况
        log_monitor "监控进行中... (剩余: ${epoch_remaining}s)"
        
        local info_output
        if info_output=$(get_detailed_epoch_info "$private_key"); then
            
            # 计算其他参与者投入
            local others_invested=$(echo "$TOTAL_INVESTED - $MY_INVESTED" | bc -l)
            
            # 显示监控信息
            echo "----------------------------------------"
            log_monitor "📊 实时数据:"
            log_monitor "  当前Epoch: #$CURRENT_EPOCH"
            log_monitor "  剩余时间: ${epoch_remaining}秒 ($(echo "$epoch_remaining / 60" | bc)分钟)"
            log_monitor "  我的投入: $MY_INVESTED BETH"
            log_monitor "  其他投入: $others_invested BETH"
            log_monitor "  总投入: $TOTAL_INVESTED BETH"
            
            # 计算当前收益率
            if (( $(echo "$TOTAL_INVESTED > 0" | bc -l) )); then
                local my_share=$(echo "scale=2; $MY_INVESTED / $TOTAL_INVESTED * 100" | bc -l)
                local potential_worm=$(echo "$MY_INVESTED / $TOTAL_INVESTED * 50" | bc -l)
                log_monitor "  当前份额: ${my_share}%"
                log_monitor "  预期收益: $potential_worm WORM"
            fi
            
            # 判断是否进入狙击窗口
            if [ $epoch_remaining -le "${SNIPER_CONFIG[SNIPE_WINDOW]}" ]; then
                log_sniper "🎯 进入狙击窗口！分析狙击机会..."
                analyze_snipe_opportunity "$others_invested" "$epoch_remaining"
                
                # 如果决定狙击，执行狙击
                if [ "$SNIPE_DECISION" != "skip" ] && [ $epoch_remaining -le "${SNIPER_CONFIG[EXECUTION_BUFFER]}" ]; then
                    execute_snipe_attack "$private_key"
                    break
                fi
            fi
            
        else
            log_warn "获取epoch信息失败，重试中..."
        fi
        
        # 监控间隔
        sleep 30
    done
}

# 分析狙击机会
analyze_snipe_opportunity() {
    local others_invested="$1"
    local time_remaining="$2"
    
    log_sniper "🔍 狙击机会分析:"
    log_sniper "  其他投入: $others_invested BETH"
    log_sniper "  剩余时间: ${time_remaining}秒"
    
    # 根据竞争情况决定狙击策略
    if (( $(echo "$others_invested < ${SNIPER_CONFIG[LOW_COMPETITION_THRESHOLD]}" | bc -l) )); then
        SNIPE_DECISION="aggressive"
        local snipe_amount="${SNIPER_CONFIG[SNIPE_AGGRESSIVE]}"
        log_sniper "🚀 决策: 激进狙击 ($snipe_amount BETH)"
        log_sniper "📈 预期份额: ~$(echo "scale=1; $snipe_amount / ($others_invested + $snipe_amount) * 100" | bc -l)%"
        
    elif (( $(echo "$others_invested < ${SNIPER_CONFIG[MEDIUM_COMPETITION_THRESHOLD]}" | bc -l) )); then
        SNIPE_DECISION="balanced"
        local snipe_amount="${SNIPER_CONFIG[SNIPE_BALANCED]}"
        log_sniper "⚖️ 决策: 平衡狙击 ($snipe_amount BETH)"
        log_sniper "📈 预期份额: ~$(echo "scale=1; $snipe_amount / ($others_invested + $snipe_amount) * 100" | bc -l)%"
        
    elif (( $(echo "$others_invested < ${SNIPER_CONFIG[HIGH_COMPETITION_THRESHOLD]}" | bc -l) )); then
        SNIPE_DECISION="conservative"
        local snipe_amount="${SNIPER_CONFIG[SNIPE_CONSERVATIVE]}"
        log_sniper "🐌 决策: 保守狙击 ($snipe_amount BETH)"
        log_sniper "📈 预期份额: ~$(echo "scale=1; $snipe_amount / ($others_invested + $snipe_amount) * 100" | bc -l)%"
        
    else
        SNIPE_DECISION="skip"
        log_sniper "🚫 决策: 放弃狙击 (竞争过于激烈)"
        log_sniper "📊 当前竞争: $others_invested BETH (超过阈值 ${SNIPER_CONFIG[HIGH_COMPETITION_THRESHOLD]})"
    fi
}

# 执行狙击攻击
execute_snipe_attack() {
    local private_key="$1"
    
    if [ "$SNIPE_DECISION" = "skip" ]; then
        log_sniper "跳过本轮狙击"
        return 0
    fi
    
    # 确定狙击金额
    local snipe_amount
    case "$SNIPE_DECISION" in
        "aggressive")
            snipe_amount="${SNIPER_CONFIG[SNIPE_AGGRESSIVE]}"
            ;;
        "balanced")
            snipe_amount="${SNIPER_CONFIG[SNIPE_BALANCED]}"
            ;;
        "conservative")
            snipe_amount="${SNIPER_CONFIG[SNIPE_CONSERVATIVE]}"
            ;;
        *)
            log_warn "未知狙击决策: $SNIPE_DECISION"
            return 1
            ;;
    esac
    
    log_execute "🎯 执行狙击攻击！"
    log_execute "💰 狙击金额: $snipe_amount BETH"
    log_execute "🎪 狙击模式: $SNIPE_DECISION"
    
    # 执行参与命令
    if worm-miner participate \
        --amount-per-epoch "$snipe_amount" \
        --num-epochs 1 \
        --private-key "$private_key" \
        --network "${SNIPER_CONFIG[NETWORK]}"; then
        
        log_execute "✅ 狙击成功！"
        log_execute "🎉 已投入 $snipe_amount BETH 到当前epoch"
        
        # 重新获取信息验证
        sleep 10
        local final_info
        if final_info=$(get_detailed_epoch_info "$private_key"); then
            local final_share=$(echo "scale=2; $MY_INVESTED / $TOTAL_INVESTED * 100" | bc -l)
            log_execute "🏆 最终份额: ${final_share}%"
            log_execute "💎 预期收益: $(echo "$MY_INVESTED / $TOTAL_INVESTED * 50" | bc -l) WORM"
        fi
        
    else
        log_execute "❌ 狙击失败！"
        log_execute "可能原因: 网络延迟、gas不足、或epoch已结束"
    fi
}

# 等待下一个epoch
wait_for_next_epoch() {
    log_info "⏳ 等待下一个epoch开始..."
    
    local last_epoch=$CURRENT_EPOCH
    
    while true; do
        local info_output
        if info_output=$(get_detailed_epoch_info "$PRIVATE_KEY"); then
            if [ "$CURRENT_EPOCH" != "$last_epoch" ]; then
                log_info "🎉 新的epoch开始: #$CURRENT_EPOCH"
                EPOCH_START_TIME=$(date +%s)
                break
            fi
        fi
        sleep 60  # 每分钟检查一次
    done
}

# 显示狙击配置
show_sniper_config() {
    echo "================================================"
    echo "🎯 狙击手策略配置"
    echo "================================================"
    echo ""
    echo "⏰ 时间设置:"
    echo "  Epoch时长: ${SNIPER_CONFIG[EPOCH_DURATION]}秒 (30分钟)"
    echo "  狙击窗口: 最后${SNIPER_CONFIG[SNIPE_WINDOW]}秒 (3分钟)"
    echo "  执行时机: 最后${SNIPER_CONFIG[EXECUTION_BUFFER]}秒 (1分钟)"
    echo ""
    echo "🎯 竞争阈值:"
    echo "  低竞争: < ${SNIPER_CONFIG[LOW_COMPETITION_THRESHOLD]} BETH"
    echo "  中等竞争: < ${SNIPER_CONFIG[MEDIUM_COMPETITION_THRESHOLD]} BETH"
    echo "  高竞争: > ${SNIPER_CONFIG[HIGH_COMPETITION_THRESHOLD]} BETH"
    echo ""
    echo "💰 狙击投入:"
    echo "  激进模式: ${SNIPER_CONFIG[SNIPE_AGGRESSIVE]} BETH"
    echo "  平衡模式: ${SNIPER_CONFIG[SNIPE_BALANCED]} BETH"
    echo "  保守模式: ${SNIPER_CONFIG[SNIPE_CONSERVATIVE]} BETH"
    echo ""
    echo "🛡️ 风控设置:"
    echo "  最大投入: ${SNIPER_CONFIG[MAX_SNIPE_AMOUNT]} BETH"
    echo "  储备资金: ${SNIPER_CONFIG[MIN_BETH_RESERVE]} BETH"
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

# 主函数
main() {
    clear
    echo -e "${BOLD}${RED}"
    echo "================================================"
    echo "🎯 WORM狙击手策略系统"
    echo "================================================"
    echo -e "${NC}"
    echo "🚀 特性: 实时监控 | 精准狙击 | 高收益优化"
    echo ""
    
    # 显示配置
    show_sniper_config
    
    # 获取私钥
    echo "请输入您的私钥："
    read -s -p "私钥: " PRIVATE_KEY
    echo ""
    
    # 验证私钥
    if ! validate_private_key "$PRIVATE_KEY"; then
        log_error "私钥格式不正确"
        exit 1
    fi
    
    # 安全警告
    echo ""
    log_warn "⚠️ 狙击策略风险提醒:"
    log_warn "1. 网络延迟可能导致狙击失败"
    log_warn "2. 其他人也可能使用类似策略"
    log_warn "3. Gas费用波动可能影响交易确认"
    log_warn "4. 建议先小额测试策略效果"
    echo ""
    
    read -p "确认开始狙击监控？(y/N): " confirm
    if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
        log_info "用户取消操作"
        exit 0
    fi
    
    # 初始化并开始监控
    log_sniper "🎯 狙击手系统启动！"
    
    # 等待下一个epoch开始
    wait_for_next_epoch
    
    # 开始监控和狙击
    while true; do
        monitor_current_epoch "$PRIVATE_KEY"
        wait_for_next_epoch
    done
}

# 信号处理
trap 'echo ""; log_info "狙击手系统安全退出..."; exit 0' SIGINT SIGTERM

# 执行主函数
main "$@"
