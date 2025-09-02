#!/bin/bash

# WORM挖矿系统 - 高级自定义狙击策略
# 支持用户自定义投入倍数规则，实现精准化收益优化

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

# 全局变量
PRIVATE_KEY=""
BASE_AMOUNT=0
STRATEGY_RULES=()
CURRENT_EPOCH=0
EPOCH_START_TIME=0
MONITORING_ACTIVE=false

# 狙击配置
declare -A SNIPER_CONFIG=(
    ["NETWORK"]="sepolia"
    ["EPOCH_DURATION"]="1800"          # 30分钟
    ["MONITOR_INTERVAL"]="20"          # 监控间隔20秒
    ["SNIPE_WINDOW"]="180"             # 狙击窗口：最后3分钟
    ["EXECUTION_BUFFER"]="60"          # 执行缓冲：最后1分钟
    ["MAX_SINGLE_INVESTMENT"]="10.0"   # 单次最大投入限制
    ["MIN_BETH_RESERVE"]="0.1"         # 最小储备
)

# 日志函数
log_sniper() {
    echo -e "${PURPLE}[$(date '+%H:%M:%S')] [SNIPER]${NC} $1"
}

log_monitor() {
    echo -e "${CYAN}[$(date '+%H:%M:%S')] [MONITOR]${NC} $1"
}

log_strategy() {
    echo -e "${YELLOW}[$(date '+%H:%M:%S')] [STRATEGY]${NC} $1"
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

log_error() {
    echo -e "${RED}[$(date '+%H:%M:%S')] [ERROR]${NC} $1"
}

# 显示功能说明
show_feature_explanation() {
    clear
    echo -e "${BOLD}${CYAN}"
    echo "================================================"
    echo "🎯 高级自定义狙击策略系统"
    echo "================================================"
    echo -e "${NC}"
    echo ""
    echo -e "${BOLD}🚀 功能说明:${NC}"
    echo ""
    echo "📊 ${BOLD}智能监控${NC}: 实时监控当前epoch中其他参与者的BETH投入总量"
    echo "⏰ ${BOLD}精准时机${NC}: 在epoch最后1-3分钟执行投入，避开早期竞争"
    echo "🎯 ${BOLD}自定义策略${NC}: 根据竞争水平自动调整投入倍数"
    echo "💰 ${BOLD}收益最大化${NC}: 通过避开高竞争时段获得更高收益率"
    echo ""
    echo -e "${BOLD}💡 策略优势:${NC}"
    echo ""
    echo "• 🔍 ${YELLOW}信息优势${NC}: 提前掌握竞争情况"
    echo "• ⚡ ${YELLOW}时机优势${NC}: 最后时刻精准投入"
    echo "• 🧠 ${YELLOW}策略优势${NC}: 根据实际情况动态调整"
    echo "• 💎 ${YELLOW}收益优势${NC}: 预期收益提升50%-300%"
    echo ""
    echo -e "${BOLD}⚠️ 风险提醒:${NC}"
    echo ""
    echo "• 网络延迟可能导致投入失败"
    echo "• 其他玩家也可能使用类似策略"
    echo "• 建议先小额测试验证效果"
    echo ""
    read -p "按回车键继续设置策略..."
}

# 显示策略配置格式说明
show_strategy_format() {
    echo ""
    echo "================================================"
    echo "📋 策略配置格式说明"
    echo "================================================"
    echo ""
    echo -e "${BOLD}📝 配置格式:${NC}"
    echo "基础投入:竞争范围1,倍数1;竞争范围2,倍数2;..."
    echo ""
    echo -e "${BOLD}🔧 参数说明:${NC}"
    echo "• ${CYAN}基础投入${NC}: 您的基础BETH投入量（如：0.1, 1, 2等）"
    echo "• ${CYAN}竞争范围${NC}: 其他人总投入的BETH范围（如：0-50, 50-100等）"
    echo "• ${CYAN}倍数${NC}: 在该竞争范围内的投入倍数（如：2x, 3x, 5x等）"
    echo ""
    echo -e "${BOLD}📊 配置示例:${NC}"
    echo ""
    echo -e "${GREEN}示例1 (保守策略):${NC}"
    echo "输入: ${YELLOW}0.5:0-20,3x;20-50,2x;50-100,1x${NC}"
    echo "解释:"
    echo "  • 基础投入: 0.5 BETH"
    echo "  • 其他人投入0-20 BETH时: 投入 0.5×3 = 1.5 BETH"
    echo "  • 其他人投入20-50 BETH时: 投入 0.5×2 = 1.0 BETH"
    echo "  • 其他人投入50-100 BETH时: 投入 0.5×1 = 0.5 BETH"
    echo ""
    echo -e "${GREEN}示例2 (激进策略):${NC}"
    echo "输入: ${YELLOW}1:0-10,10x;10-30,5x;30-80,2x;80-200,1x${NC}"
    echo "解释:"
    echo "  • 基础投入: 1 BETH"
    echo "  • 其他人投入0-10 BETH时: 投入 1×10 = 10 BETH (超级狙击!)"
    echo "  • 其他人投入10-30 BETH时: 投入 1×5 = 5 BETH"
    echo "  • 其他人投入30-80 BETH时: 投入 1×2 = 2 BETH"
    echo "  • 其他人投入80-200 BETH时: 投入 1×1 = 1 BETH"
    echo ""
    echo -e "${GREEN}示例3 (平衡策略):${NC}"
    echo "输入: ${YELLOW}0.2:0-5,8x;5-15,4x;15-40,2x;40-100,1x;100-999,0x${NC}"
    echo "解释:"
    echo "  • 基础投入: 0.2 BETH"
    echo "  • 其他人投入0-5 BETH时: 投入 0.2×8 = 1.6 BETH"
    echo "  • 其他人投入5-15 BETH时: 投入 0.2×4 = 0.8 BETH"
    echo "  • 其他人投入15-40 BETH时: 投入 0.2×2 = 0.4 BETH"
    echo "  • 其他人投入40-100 BETH时: 投入 0.2×1 = 0.2 BETH"
    echo "  • 其他人投入>100 BETH时: 投入 0.2×0 = 0 BETH (放弃)"
    echo ""
    echo -e "${BOLD}💰 收益预估:${NC}"
    echo "假设某epoch其他人总投入5 BETH，您用示例2策略投入5 BETH:"
    echo "• 您的份额: 5/(5+5) = 50%"
    echo "• 您的收益: 50% × 50 WORM = 25 WORM"
    echo "• 投资回报率: 25 WORM / 5 BETH = 5倍回报!"
    echo ""
    echo -e "${BOLD}🎯 策略建议:${NC}"
    echo "• 新手推荐: 保守策略，先熟悉机制"
    echo "• 有经验者: 激进策略，追求高收益"
    echo "• 大资金量: 平衡策略，稳定盈利"
    echo ""
}

# 解析策略配置
parse_strategy_config() {
    local config="$1"
    
    # 分离基础投入和规则
    IFS=':' read -r base_part rules_part <<< "$config"
    
    # 验证基础投入
    if ! [[ $base_part =~ ^[0-9]+\.?[0-9]*$ ]]; then
        log_error "基础投入格式错误: $base_part"
        return 1
    fi
    
    BASE_AMOUNT="$base_part"
    
    # 清空现有规则
    STRATEGY_RULES=()
    
    # 解析规则
    IFS=';' read -ra rules <<< "$rules_part"
    
    for rule in "${rules[@]}"; do
        # 分离范围和倍数
        IFS=',' read -r range_part multiplier_part <<< "$rule"
        
        # 解析范围
        IFS='-' read -r min_val max_val <<< "$range_part"
        
        # 解析倍数（移除x后缀）
        multiplier=$(echo "$multiplier_part" | sed 's/x$//')
        
        # 验证格式
        if ! [[ $min_val =~ ^[0-9]+\.?[0-9]*$ ]] || ! [[ $max_val =~ ^[0-9]+\.?[0-9]*$ ]] || ! [[ $multiplier =~ ^[0-9]+\.?[0-9]*$ ]]; then
            log_error "规则格式错误: $rule"
            return 1
        fi
        
        # 添加到规则数组
        STRATEGY_RULES+=("$min_val:$max_val:$multiplier")
    done
    
    log_info "策略配置解析成功"
    log_info "基础投入: $BASE_AMOUNT BETH"
    log_info "规则数量: ${#STRATEGY_RULES[@]}"
    
    return 0
}

# 显示解析后的策略
show_parsed_strategy() {
    echo ""
    echo "================================================"
    echo "✅ 您的策略配置"
    echo "================================================"
    echo ""
    echo "💰 ${BOLD}基础投入:${NC} $BASE_AMOUNT BETH"
    echo ""
    echo "📊 ${BOLD}投入规则:${NC}"
    
    local rule_index=1
    for rule in "${STRATEGY_RULES[@]}"; do
        IFS=':' read -r min_val max_val multiplier <<< "$rule"
        local actual_amount=$(echo "$BASE_AMOUNT * $multiplier" | bc -l)
        
        printf "   %d. 竞争范围 %s-%s BETH → 投入倍数 %sx → 实际投入 %s BETH\n" \
               "$rule_index" "$min_val" "$max_val" "$multiplier" "$actual_amount"
        
        ((rule_index++))
    done
    
    echo ""
    echo "🎯 ${BOLD}策略分析:${NC}"
    
    # 分析策略特点
    local total_rules=${#STRATEGY_RULES[@]}
    local max_multiplier=0
    local min_multiplier=999
    
    for rule in "${STRATEGY_RULES[@]}"; do
        IFS=':' read -r min_val max_val multiplier <<< "$rule"
        if (( $(echo "$multiplier > $max_multiplier" | bc -l) )); then
            max_multiplier=$multiplier
        fi
        if (( $(echo "$multiplier < $min_multiplier" | bc -l) )); then
            min_multiplier=$multiplier
        fi
    done
    
    local max_investment=$(echo "$BASE_AMOUNT * $max_multiplier" | bc -l)
    local min_investment=$(echo "$BASE_AMOUNT * $min_multiplier" | bc -l)
    
    echo "   • 最大单次投入: $max_investment BETH (${max_multiplier}x倍数)"
    echo "   • 最小单次投入: $min_investment BETH (${min_multiplier}x倍数)"
    echo "   • 规则覆盖数: $total_rules 个竞争区间"
    
    # 策略类型判断
    if (( $(echo "$max_multiplier >= 5" | bc -l) )); then
        echo "   • 策略类型: 🚀 激进型 (高风险高收益)"
    elif (( $(echo "$max_multiplier >= 3" | bc -l) )); then
        echo "   • 策略类型: ⚖️ 平衡型 (中等风险收益)"
    else
        echo "   • 策略类型: 🐌 保守型 (低风险稳定)"
    fi
    
    echo ""
}

# 根据竞争情况计算投入金额
calculate_investment_amount() {
    local others_invested="$1"
    
    for rule in "${STRATEGY_RULES[@]}"; do
        IFS=':' read -r min_val max_val multiplier <<< "$rule"
        
        # 检查是否在范围内
        if (( $(echo "$others_invested >= $min_val && $others_invested <= $max_val" | bc -l) )); then
            local investment=$(echo "$BASE_AMOUNT * $multiplier" | bc -l)
            echo "$investment:$multiplier"
            return 0
        fi
    done
    
    # 没有匹配的规则，返回0
    echo "0:0"
    return 0
}

# 获取详细epoch信息
get_detailed_epoch_info() {
    local private_key="$1"
    
    local info_output
    info_output=$(worm-miner info --network "${SNIPER_CONFIG[NETWORK]}" --private-key "$private_key" 2>/dev/null)
    
    if [ $? -ne 0 ]; then
        return 1
    fi
    
    # 解析当前epoch
    CURRENT_EPOCH=$(echo "$info_output" | grep "Current epoch:" | awk '{print $3}')
    
    # 解析当前epoch的投入情况
    local current_epoch_line=$(echo "$info_output" | grep "Epoch #$CURRENT_EPOCH =>")
    
    local my_invested="0"
    local total_invested="0"
    
    if [ -n "$current_epoch_line" ]; then
        my_invested=$(echo "$current_epoch_line" | sed 's/.*=> \([0-9.]*\) \/.*/\1/')
        total_invested=$(echo "$current_epoch_line" | sed 's/.*\/ \([0-9.]*\).*/\1/')
    fi
    
    # 计算其他人投入
    local others_invested=$(echo "$total_invested - $my_invested" | bc -l)
    
    echo "$my_invested:$total_invested:$others_invested"
    return 0
}

# 实时监控和狙击主循环
monitor_and_snipe() {
    log_sniper "🎯 开始实时监控和狙击..."
    
    MONITORING_ACTIVE=true
    
    while $MONITORING_ACTIVE; do
        # 获取epoch信息
        local epoch_info
        if epoch_info=$(get_detailed_epoch_info "$PRIVATE_KEY"); then
            IFS=':' read -r my_invested total_invested others_invested <<< "$epoch_info"
            
            # 获取当前时间信息
            local current_time=$(date +%s)
            
            # 如果是新的epoch，重新设置开始时间
            if [ "$EPOCH_START_TIME" -eq 0 ]; then
                EPOCH_START_TIME=$current_time
            fi
            
            local epoch_elapsed=$((current_time - EPOCH_START_TIME))
            local epoch_remaining=$((${SNIPER_CONFIG[EPOCH_DURATION]} - epoch_elapsed))
            
            # 检查epoch是否结束
            if [ $epoch_remaining -le 0 ]; then
                log_monitor "Epoch #$CURRENT_EPOCH 已结束，等待下一个epoch..."
                wait_for_next_epoch
                continue
            fi
            
            # 显示实时监控信息
            echo "----------------------------------------"
            log_monitor "📊 实时监控数据:"
            log_monitor "  当前Epoch: #$CURRENT_EPOCH"
            log_monitor "  剩余时间: ${epoch_remaining}秒 ($(echo "$epoch_remaining / 60" | bc)分钟)"
            log_monitor "  我的投入: $my_invested BETH"
            log_monitor "  其他投入: $others_invested BETH"
            log_monitor "  总投入: $total_invested BETH"
            
            # 计算基于策略的建议投入
            local investment_info
            investment_info=$(calculate_investment_amount "$others_invested")
            IFS=':' read -r suggested_amount multiplier <<< "$investment_info"
            
            log_strategy "🎯 策略分析:"
            log_strategy "  其他人投入: $others_invested BETH"
            log_strategy "  匹配倍数: ${multiplier}x"
            log_strategy "  建议投入: $suggested_amount BETH"
            
            # 计算潜在收益
            if (( $(echo "$suggested_amount > 0 && $total_invested > 0" | bc -l) )); then
                local new_total=$(echo "$total_invested + $suggested_amount" | bc -l)
                local my_new_total=$(echo "$my_invested + $suggested_amount" | bc -l)
                local my_share=$(echo "scale=2; $my_new_total / $new_total * 100" | bc -l)
                local potential_worm=$(echo "$my_new_total / $new_total * 50" | bc -l)
                local roi=$(echo "scale=2; $potential_worm / $my_new_total * 100" | bc -l)
                
                log_strategy "  预期份额: ${my_share}%"
                log_strategy "  预期收益: $potential_worm WORM"
                log_strategy "  投资回报率: ${roi}%"
            fi
            
            # 判断是否执行狙击
            if [ $epoch_remaining -le "${SNIPER_CONFIG[SNIPE_WINDOW]}" ] && [ $epoch_remaining -gt "${SNIPER_CONFIG[EXECUTION_BUFFER]}" ]; then
                log_sniper "⏰ 进入狙击窗口 (剩余${epoch_remaining}秒)"
                
                if (( $(echo "$suggested_amount > 0" | bc -l) )); then
                    log_sniper "🎯 准备执行狙击: $suggested_amount BETH"
                else
                    log_sniper "🚫 当前竞争过于激烈，策略建议跳过"
                fi
                
            elif [ $epoch_remaining -le "${SNIPER_CONFIG[EXECUTION_BUFFER]}" ]; then
                if (( $(echo "$suggested_amount > 0" | bc -l) )); then
                    log_execute "🚀 执行狙击攻击!"
                    execute_snipe "$suggested_amount" "$multiplier"
                    
                    # 执行后等待下一个epoch
                    wait_for_next_epoch
                    continue
                else
                    log_sniper "🚫 策略决定跳过本轮"
                    wait_for_next_epoch
                    continue
                fi
            fi
            
        else
            log_warn "获取epoch信息失败，重试中..."
        fi
        
        # 监控间隔
        sleep "${SNIPER_CONFIG[MONITOR_INTERVAL]}"
    done
}

# 执行狙击
execute_snipe() {
    local amount="$1"
    local multiplier="$2"
    
    log_execute "💰 狙击金额: $amount BETH"
    log_execute "📊 投入倍数: ${multiplier}x"
    log_execute "⚡ 执行狙击..."
    
    # 安全检查
    if (( $(echo "$amount > ${SNIPER_CONFIG[MAX_SINGLE_INVESTMENT]}" | bc -l) )); then
        log_warn "投入金额超过安全限制，调整为最大值: ${SNIPER_CONFIG[MAX_SINGLE_INVESTMENT]} BETH"
        amount="${SNIPER_CONFIG[MAX_SINGLE_INVESTMENT]}"
    fi
    
    # 执行参与命令
    if worm-miner participate \
        --amount-per-epoch "$amount" \
        --num-epochs 1 \
        --private-key "$PRIVATE_KEY" \
        --network "${SNIPER_CONFIG[NETWORK]}"; then
        
        log_execute "✅ 狙击成功!"
        log_execute "🎉 已投入 $amount BETH 到 Epoch #$CURRENT_EPOCH"
        
        # 验证结果
        sleep 10
        local final_info
        if final_info=$(get_detailed_epoch_info "$PRIVATE_KEY"); then
            IFS=':' read -r my_final total_final others_final <<< "$final_info"
            local final_share=$(echo "scale=2; $my_final / $total_final * 100" | bc -l)
            local expected_worm=$(echo "$my_final / $total_final * 50" | bc -l)
            
            log_execute "🏆 最终结果:"
            log_execute "   我的投入: $my_final BETH"
            log_execute "   总投入: $total_final BETH"
            log_execute "   我的份额: ${final_share}%"
            log_execute "   预期收益: $expected_worm WORM"
        fi
        
    else
        log_execute "❌ 狙击失败!"
        log_execute "可能原因: 网络延迟、gas不足、或epoch已结束"
    fi
}

# 等待下一个epoch
wait_for_next_epoch() {
    log_info "⏳ 等待下一个epoch开始..."
    
    local last_epoch=$CURRENT_EPOCH
    
    while true; do
        local epoch_info
        if epoch_info=$(get_detailed_epoch_info "$PRIVATE_KEY"); then
            IFS=':' read -r my_invested total_invested others_invested <<< "$epoch_info"
            
            if [ "$CURRENT_EPOCH" != "$last_epoch" ]; then
                log_info "🎉 新的epoch开始: #$CURRENT_EPOCH"
                EPOCH_START_TIME=$(date +%s)
                break
            fi
        fi
        sleep 60
    done
}

# 获取用户策略配置
get_user_strategy() {
    show_feature_explanation
    show_strategy_format
    
    echo ""
    echo "================================================"
    echo "⚙️ 请输入您的策略配置"
    echo "================================================"
    echo ""
    echo -e "${BOLD}💡 友情提示:${NC}"
    echo "• 如果您是新手，建议先使用保守策略测试"
    echo "• 可以从小金额开始，熟悉后再加大投入"
    echo "• 策略配置会影响您的投资风险和收益"
    echo ""
    
    while true; do
        echo -e "${YELLOW}请输入策略配置:${NC}"
        echo "(格式: 基础投入:范围1,倍数1;范围2,倍数2;...)"
        read -p "配置: " strategy_input
        
        if [ -z "$strategy_input" ]; then
            log_warn "配置不能为空，请重新输入"
            continue
        fi
        
        # 解析策略配置
        if parse_strategy_config "$strategy_input"; then
            show_parsed_strategy
            
            echo ""
            read -p "确认使用此策略配置？(y/N): " confirm
            if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
                break
            else
                echo "请重新配置..."
                continue
            fi
        else
            log_error "配置格式错误，请检查并重新输入"
            echo ""
            echo "正确格式示例: 1:0-50,3x;50-100,2x;100-200,1x"
            echo ""
            continue
        fi
    done
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
    echo -e "${BOLD}${PURPLE}"
    echo "================================================"
    echo "🎯 WORM高级自定义狙击策略系统"
    echo "================================================"
    echo -e "${NC}"
    echo ""
    echo "🚀 欢迎使用最强大的WORM挖矿策略工具！"
    echo ""
    
    # 获取策略配置
    get_user_strategy
    
    # 获取私钥
    echo ""
    echo "================================================"
    echo "🔐 安全验证"
    echo "================================================"
    echo ""
    echo "请输入您的私钥："
    read -s -p "私钥: " PRIVATE_KEY
    echo ""
    
    if ! validate_private_key "$PRIVATE_KEY"; then
        log_error "私钥格式不正确"
        exit 1
    fi
    
    # 最终确认
    echo ""
    echo "================================================"
    echo "🚦 启动确认"
    echo "================================================"
    echo ""
    echo -e "${BOLD}即将启动的配置:${NC}"
    echo "• 基础投入: $BASE_AMOUNT BETH"
    echo "• 策略规则: ${#STRATEGY_RULES[@]} 个"
    echo "• 网络: ${SNIPER_CONFIG[NETWORK]}"
    echo "• 狙击窗口: 最后 ${SNIPER_CONFIG[SNIPE_WINDOW]} 秒"
    echo ""
    echo -e "${YELLOW}⚠️ 重要提醒:${NC}"
    echo "• 狙击系统将持续监控并自动执行"
    echo "• 请确保有足够的BETH余额"
    echo "• 建议在screen会话中运行"
    echo "• 可以随时按Ctrl+C安全退出"
    echo ""
    
    read -p "确认启动高级狙击系统？(y/N): " final_confirm
    if [ "$final_confirm" != "y" ] && [ "$final_confirm" != "Y" ]; then
        log_info "用户取消操作"
        exit 0
    fi
    
    # 启动监控和狙击
    log_sniper "🎯 高级狙击系统启动成功！"
    log_sniper "📊 开始实时监控epoch投入情况..."
    
    # 等待下一个epoch开始
    wait_for_next_epoch
    
    # 开始主监控循环
    monitor_and_snipe
}

# 信号处理
trap 'echo ""; log_info "🛑 收到停止信号，安全退出狙击系统..."; MONITORING_ACTIVE=false; exit 0' SIGINT SIGTERM

# 检查依赖
if ! command -v worm-miner &> /dev/null; then
    log_error "worm-miner未安装，请先运行安装脚本"
    exit 1
fi

if ! command -v bc &> /dev/null; then
    log_error "bc计算器未安装，请运行: sudo apt install bc"
    exit 1
fi

# 执行主函数
main "$@"
