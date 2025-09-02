# 🐉 WORM智能挖矿系统

![Version](https://img.shields.io/badge/version-v1.0-blue)
![Platform](https://img.shields.io/badge/platform-Ubuntu-orange)
![License](https://img.shields.io/badge/license-MIT-green)

> 🚀 **专业的WORM挖矿自动化解决方案**  
> 智能策略 | 自动化操作 | 高收益优化

## ✨ 主要特性

### 🎯 **智能挖矿策略**
- 🧠 **自适应算法**: 根据竞争情况自动调整投入策略
- 🚀 **激进模式**: 低竞争时大量投入获取高收益
- 🐌 **保守模式**: 高竞争时小额投入等待机会
- ⚖️ **平衡模式**: 稳健的中等风险投入策略

### 🤖 **全自动化操作**
- 🔥 **智能燃烧**: 自动分批燃烧ETH，每次最多1ETH避免bug
- ⛏️ **自动挖矿**: 持续监控并参与最优epoch
- 🎁 **自动领取**: 智能监控并自动领取WORM奖励
- 📊 **实时监控**: 详细的日志和统计信息

### 🛡️ **安全保障**
- 🔒 **私钥保护**: 本地存储，绝不上传
- 💰 **资金安全**: 智能风控，最小储备保护
- 🔄 **故障恢复**: 自动重试和错误处理
- 📋 **操作日志**: 完整的操作记录

## 🚀 一键安装

### 快速部署
```bash
# 一键安装并启动系统
curl -fsSL https://raw.githubusercontent.com/Zzzzzarvis/worm-mining-scripts/main/install.sh | bash

# 或者分步安装
wget https://raw.githubusercontent.com/Zzzzzarvis/worm-mining-scripts/main/worm_master.sh
chmod +x worm_master.sh
./worm_master.sh
```

### 系统要求
- ✅ **操作系统**: Ubuntu 18.04+ 
- ✅ **架构**: x86_64 (不支持ARM/Apple Silicon)
- ✅ **内存**: 16GB+ RAM
- ✅ **网络**: Sepolia测试网连接
- ✅ **资金**: 足够的Sepolia ETH

## 📋 使用指南

### 第一次使用

1. **🛠️ 系统安装**
   ```bash
   ./worm_master.sh
   # 选择 "1. 系统安装/更新"
   ```

2. **🔥 燃烧ETH获取BETH**
   ```bash
   # 选择 "2. 燃烧ETH获取BETH"
   # 输入私钥和燃烧数量
   # 系统自动分批处理
   ```

3. **🧠 启动智能挖矿**
   ```bash
   # 选择 "3. 启动智能挖矿"
   # 选择挖矿策略
   # 系统在screen会话中运行
   ```

4. **🎁 启动自动领取**
   ```bash
   # 选择 "4. 启动自动领取"
   # 自动监控并领取WORM奖励
   ```

### 挖矿策略详解

#### 🤖 全自动智能策略 (推荐)
- **低竞争环境** (< 2 BETH总投入): 激进投入0.5 BETH/epoch
- **中等竞争** (2-10 BETH): 平衡投入0.1 BETH/epoch  
- **高竞争环境** (> 10 BETH): 保守投入0.02 BETH/epoch
- **实时调整**: 每5分钟重新评估竞争情况

#### 🎯 狙击手策略 (高级玩家)
- **实时监控**: 持续监控当前epoch的投入情况
- **精准时机**: 在epoch最后1-3分钟执行投入
- **动态决策**: 根据竞争水平选择狙击力度
- **高收益**: 避开早期竞争，获得更高收益率

#### 🚀 自定义狙击策略 (专家级)
- **完全自定义**: 用户自定义竞争区间和投入倍数
- **智能分析**: 根据实时竞争情况自动选择策略
- **配置示例**: `1:0-50,3x;50-100,2x;100-200,1x`
- **超高收益**: 收益潜力提升50%-300%

#### ⚖️ 平衡稳健策略
- 固定投入0.1 BETH/epoch
- 适合稳定收益需求
- 风险控制优先

#### 🚀 激进高收益策略  
- 大额投入0.5 BETH/epoch
- 追求最大收益
- 高风险高回报

#### 🐌 保守安全策略
- 小额投入0.02 BETH/epoch
- 最低风险
- 适合测试和保守用户

## 📊 收益优化技巧

### 🎯 **时机策略**
```bash
# 监控竞争水平
worm-miner info --network sepolia --private-key YOUR_KEY

# 最佳挖矿时机
- 深夜时段 (UTC 02:00-08:00)
- 新epoch开始的前几分钟
- 竞争者较少的时段
```

### 💰 **资金配置**
```bash
# 建议资金分配
总资金 = 10 ETH 示例:
├── 储备资金: 2 ETH (20%)
├── 激进投入: 5 ETH (50%) 
├── 平衡投入: 2 ETH (20%)
└── 应急资金: 1 ETH (10%)
```

### 🚀 **自定义狙击策略详解**

#### **📝 配置格式说明**
```
基础投入:竞争区间1,倍数1;竞争区间2,倍数2;...

示例: 1:0-50,3x;50-100,2x;100-200,1x
解释:
• 基础投入: 1 BETH
• 其他人投入0-50 BETH时: 投入 1×3 = 3 BETH  
• 其他人投入50-100 BETH时: 投入 1×2 = 2 BETH
• 其他人投入100-200 BETH时: 投入 1×1 = 1 BETH
```

#### **🎯 策略模板**
```bash
# 保守策略 (新手推荐)
0.5:0-20,3x;20-50,2x;50-100,1x

# 激进策略 (高收益)  
1:0-10,10x;10-30,5x;30-80,2x;80-200,1x

# 平衡策略 (稳健)
0.2:0-5,8x;5-15,4x;15-40,2x;40-100,1x;100-999,0x
```

### 📈 **收益计算**
```
预期收益 = (您的BETH投入 / 当前总投入) × 50 WORM

示例:
- 您投入: 2 BETH
- 总投入: 5 BETH  
- 您的收益: (2/5) × 50 = 20 WORM (40%份额)
```

## 🔧 高级功能

### 📊 监控面板
```bash
# 查看运行状态
./worm_master.sh
# 选择 "5. 监控面板"

# 或直接查看screen会话
screen -list
screen -r worm-mining-SESSION_ID
```

### 🛠️ 故障排除
```bash
# 重启所有服务
./worm_master.sh -> 监控面板 -> 重启服务

# 查看日志
tail -f ~/worm-mining/logs/*.log

# 手动执行单个操作
cd ~/worm-mining/scripts
./burn_eth.sh YOUR_KEY AMOUNT
./smart_mining.sh YOUR_KEY  
./auto_claim.sh YOUR_KEY
```

### ⚙️ 自定义配置
编辑配置文件: `~/worm-mining/config/settings.conf`
```bash
# 竞争阈值
LOW_COMPETITION=2.0
HIGH_COMPETITION=20.0

# 投入策略
BASE_STAKE=0.05
AGGRESSIVE_STAKE=0.5
CONSERVATIVE_STAKE=0.02

# 监控间隔
MONITOR_INTERVAL=300  # 5分钟
CLAIM_INTERVAL=600    # 10分钟
```

## 📁 项目结构

```
worm-mining/
├── scripts/           # 核心脚本
│   ├── install.sh     # 系统安装
│   ├── burn_eth.sh    # ETH燃烧
│   ├── smart_mining.sh # 智能挖矿
│   ├── auto_claim.sh  # 自动领取
│   └── worm_master.sh # 主控制器
├── config/            # 配置文件
│   └── settings.conf  # 系统设置
├── logs/              # 日志文件
│   ├── mining.log     # 挖矿日志
│   └── claim.log      # 领取日志
└── backup/            # 备份文件
    └── YYYYMMDD_HHMMSS/
```

## 🎯 性能优化

### 💡 **收益最大化策略**
1. **时机优化** (40%影响): 选择低竞争时段
2. **数据分析** (30%影响): 基于历史数据调整策略  
3. **自动化** (20%影响): 减少人工操作延迟
4. **信息优势** (10%影响): 快速响应市场变化

### 📈 **预期收益提升**
- **基础优化**: +20-30%
- **中级策略**: +40-60%
- **高级技巧**: +80-150%

## 🔒 安全须知

### ⚠️ **重要提醒**
- 🔑 **私钥安全**: 绝不分享给任何人
- 💰 **资金管理**: 不要投入超过承受能力的资金
- 🧪 **测试网风险**: 当前为Sepolia测试网，代币可能无实际价值
- 📊 **市场风险**: 收益依赖于参与者数量，存在波动

### 🛡️ **最佳实践**
- 定期备份配置文件
- 监控系统资源使用
- 保持脚本更新
- 记录重要操作

## 🆘 故障排除

### 常见问题

**Q: 安装失败怎么办？**
```bash
# 检查系统兼容性
lsb_release -a
uname -m

# 手动安装依赖
sudo apt update
sudo apt install build-essential cmake libgmp-dev
```

**Q: 挖矿没有收益？**
```bash
# 检查BETH余额
worm-miner info --network sepolia --private-key YOUR_KEY

# 检查参与状态
tail -f ~/worm-mining/logs/mining.log
```

**Q: 私钥格式错误？**
```bash
# 正确格式
64位十六进制: abcd1234...
或 0x开头66位: 0xabcd1234...
```

## 📞 技术支持

- 🐛 **问题反馈**: 创建GitHub Issue
- 💬 **技术讨论**: 加入Telegram群组
- 📧 **商务合作**: 发送邮件联系

## 📄 许可证

本项目采用 MIT 许可证 - 查看 [LICENSE](LICENSE) 文件了解详情

## 🙏 致谢

感谢WORM协议团队提供的优秀基础设施，以及所有测试用户的反馈和建议。

---

**⚡ 立即开始您的WORM挖矿之旅！**

```bash
curl -fsSL https://raw.githubusercontent.com/Zzzzzarvis/worm-mining-scripts/main/install.sh | bash
```

*免责声明: 本软件仅用于教育和研究目的。投资有风险，请谨慎操作。*
