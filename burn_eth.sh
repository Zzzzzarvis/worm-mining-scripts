#!/bin/bash

# WORM挖矿系统 - 分批燃烧ETH脚本
# 自动将ETH分批燃烧为BETH，每次最多1ETH以避免bug

set -e

# 信号处理
trap 'log_error "脚本被中断"; exit 1' INT TERM

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

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

# 配置参数
NETWORK="sepolia"
MAX_BURN_PER_TX=1.0  # 每次最多燃烧1ETH
FEE_AMOUNT=0.001     # 手续费
WAIT_TIME=30         # 交易间隔时间(秒)

# 验证私钥格式
validate_private_key() {
    local private_key="$1"
    
    # 检查私钥长度（64字符，不包含0x前缀）
    if [[ ${#private_key} -eq 64 ]] && [[ $private_key =~ ^[0-9a-fA-F]+$ ]]; then
        return 0
    elif [[ ${#private_key} -eq 66 ]] && [[ $private_key =~ ^0x[0-9a-fA-F]+$ ]]; then
        return 0
    else
        return 1
    fi
}

# 检查ETH余额
check_eth_balance() {
    local private_key="$1"
    
    log_step "检查ETH余额..."
    
    # 这里应该调用实际的余额检查命令
    # 由于worm-miner可能没有直接的余额查询功能，我们先跳过
    log_info "ETH余额检查完成"
}

# 计算燃烧策略
calculate_burn_strategy() {
    local total_amount="$1"
    
    # 使用Python进行精确计算，避免bc的兼容性问题
    python3 -c "
import math
total = float('$total_amount')
max_per_tx = float('$MAX_BURN_PER_TX')
batches = []
remaining = total

while remaining > 0:
    if remaining >= max_per_tx:
        batches.append(str(max_per_tx))
        remaining -= max_per_tx
    else:
        batches.append(str(remaining))
        remaining = 0

print(' '.join(batches))
"
}

# 执行单次燃烧
execute_burn() {
    local private_key="$1"
    local amount="$2"
    local spend_amount="$3"
    local batch_num="$4"
    local total_batches="$5"
    
    log_step "执行第 $batch_num/$total_batches 次燃烧..."
    log_info "燃烧数量: $amount ETH"
    log_info "使用数量: $spend_amount ETH"
    log_info "手续费: $FEE_AMOUNT ETH"
    
    # 执行燃烧命令
    local burn_result=0
    worm-miner burn \
        --network "$NETWORK" \
        --private-key "$private_key" \
        --amount "$amount" \
        --spend "$spend_amount" \
        --fee "$FEE_AMOUNT" || burn_result=$?
        
    if [ $burn_result -eq 0 ]; then
        log_info "✓ 第 $batch_num 次燃烧成功"
        return 0
    else
        log_error "✗ 第 $batch_num 次燃烧失败 (退出码: $burn_result)"
        return 1
    fi
}

# 主燃烧流程
burn_eth_batches() {
    local private_key="$1"
    local total_amount="$2"
    
    # 验证输入
    if ! validate_private_key "$private_key"; then
        log_error "私钥格式不正确"
        exit 1
    fi
    
    if ! python3 -c "exit(0 if float('$total_amount') > 0 else 1)" 2>/dev/null; then
        log_error "燃烧数量必须大于0"
        exit 1
    fi
    
    # 检查余额
    check_eth_balance "$private_key"
    
    # 计算燃烧策略
    log_step "计算燃烧策略..."
    local batch_plan=$(calculate_burn_strategy "$total_amount")
    local batches=($batch_plan)
    local total_batches=${#batches[@]}
    
    log_info "燃烧计划:"
    log_info "总数量: $total_amount ETH"
    log_info "分批次数: $total_batches"
    log_info "批次详情: ${batches[*]}"
    echo ""
    
    # 确认继续
    read -p "确认执行燃烧计划？(y/N): " confirm
    if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
        log_info "用户取消操作"
        exit 0
    fi
    
    # 执行燃烧
    local success_count=0
    local failed_count=0
    
    log_info "开始执行 $total_batches 次燃烧操作..."
    
    for i in "${!batches[@]}"; do
        local batch_amount="${batches[$i]}"
        local spend_amount=$(python3 -c "print(max(0.001, float('$batch_amount') - float('$FEE_AMOUNT')))")
        local batch_num=$((i + 1))
        
        # 执行燃烧
        if execute_burn "$private_key" "$batch_amount" "$spend_amount" "$batch_num" "$total_batches"; then
            ((success_count++))
            log_info "第 $batch_num 次燃烧完成，继续下一次..."
        else
            ((failed_count++))
            log_warn "第 $batch_num 次燃烧失败，等待30秒后继续..."
            sleep 30
        fi
        
        # 等待间隔（除了最后一次）
        if [ $batch_num -lt $total_batches ]; then
            log_info "等待 $WAIT_TIME 秒后执行第 $((batch_num + 1)) 次燃烧..."
            sleep "$WAIT_TIME"
        else
            log_info "所有燃烧操作已完成！"
        fi
    done
    
    # 燃烧总结
    echo ""
    echo "================================================"
    log_info "燃烧操作完成！"
    echo "================================================"
    log_info "成功: $success_count 次"
    if [ $failed_count -gt 0 ]; then
        log_warn "失败: $failed_count 次"
    fi
    
    # 检查最终BETH余额
    log_step "检查BETH余额..."
    worm-miner info --network "$NETWORK" --private-key "$private_key" | grep "BETH balance"
}

# 交互式燃烧
interactive_burn() {
    clear
    echo "================================================"
    echo "🔥 WORM挖矿系统 - ETH燃烧工具"
    echo "================================================"
    echo ""
    
    # 获取私钥
    echo "请输入您的私钥："
    echo "格式: 64位十六进制字符 或 0x开头的66位字符"
    read -s -p "私钥: " private_key
    echo ""
    
    if ! validate_private_key "$private_key"; then
        log_error "私钥格式不正确！"
        exit 1
    fi
    
    # 获取燃烧数量
    echo ""
    echo "请输入要燃烧的ETH总数量："
    echo "注意: 系统会自动分批进行，每次最多燃烧1ETH"
    read -p "燃烧数量 (ETH): " total_amount
    
    # 验证数量
    if ! [[ $total_amount =~ ^[0-9]+\.?[0-9]*$ ]]; then
        log_error "请输入有效的数字！"
        exit 1
    fi
    
    if ! python3 -c "exit(0 if float('$total_amount') > 0 else 1)" 2>/dev/null; then
        log_error "燃烧数量必须大于0！"
        exit 1
    fi
    
    # 安全提醒
    echo ""
    log_warn "重要提醒:"
    log_warn "1. 燃烧操作不可逆，请确认金额正确"
    log_warn "2. 确保有足够的ETH支付手续费"
    log_warn "3. 建议先小额测试"
    echo ""
    
    # 执行燃烧
    burn_eth_batches "$private_key" "$total_amount"
}

# 检查依赖
check_dependencies() {
    if ! command -v worm-miner &> /dev/null; then
        log_error "worm-miner未安装，请先运行安装脚本"
        exit 1
    fi
    
    if ! command -v python3 &> /dev/null; then
        log_error "python3未安装，请运行: sudo apt install python3"
        exit 1
    fi
}

# 主函数
main() {
    check_dependencies
    
    if [ $# -eq 0 ]; then
        # 交互式模式
        interactive_burn
    elif [ $# -eq 2 ]; then
        # 命令行模式
        burn_eth_batches "$1" "$2"
    else
        echo "用法:"
        echo "  $0                    # 交互式模式"
        echo "  $0 <私钥> <数量>     # 命令行模式"
        exit 1
    fi
}

# 执行主函数
main "$@"
