#!/bin/bash

echo "=== 燃烧脚本诊断工具 ==="
echo ""

echo "1. 检查脚本版本..."
if [ -f "$HOME/worm-mining/scripts/burn_eth.sh" ]; then
    echo "脚本存在: $HOME/worm-mining/scripts/burn_eth.sh"
    echo "文件大小: $(wc -c < $HOME/worm-mining/scripts/burn_eth.sh) 字节"
    echo "修改时间: $(stat -c %y $HOME/worm-mining/scripts/burn_eth.sh 2>/dev/null || stat -f %Sm $HOME/worm-mining/scripts/burn_eth.sh)"
    
    echo ""
    echo "2. 检查关键标识..."
    if grep -q "=== 第.*次燃烧 ===" "$HOME/worm-mining/scripts/burn_eth.sh"; then
        echo "✓ 包含新版本标识"
    else
        echo "✗ 缺少新版本标识"
    fi
    
    if grep -q "set -e" "$HOME/worm-mining/scripts/burn_eth.sh"; then
        echo "✗ 仍包含 set -e (旧版本)"
    else
        echo "✓ 已移除 set -e"
    fi
    
    echo ""
    echo "3. 脚本前10行："
    head -10 "$HOME/worm-mining/scripts/burn_eth.sh"
    
    echo ""
    echo "4. execute_burn函数片段："
    grep -A5 -B5 "Successfully burnt" "$HOME/worm-mining/scripts/burn_eth.sh" || echo "未找到相关代码"
    
else
    echo "✗ 脚本不存在"
fi

echo ""
echo "5. 手动下载最新版本..."
cd "$HOME/worm-mining/scripts"
wget -O burn_eth.sh.new "https://raw.githubusercontent.com/Zzzzzarvis/worm-mining-scripts/main/burn_eth.sh"
echo "新版本大小: $(wc -c < burn_eth.sh.new) 字节"

echo ""
echo "6. 对比差异..."
if [ -f "burn_eth.sh" ]; then
    diff_output=$(diff burn_eth.sh burn_eth.sh.new || true)
    if [ -n "$diff_output" ]; then
        echo "发现差异:"
        echo "$diff_output" | head -20
    else
        echo "文件相同"
    fi
else
    echo "原文件不存在"
fi

echo ""
echo "7. 替换为最新版本..."
mv burn_eth.sh.new burn_eth.sh
chmod +x burn_eth.sh
echo "✓ 已更新到最新版本"
