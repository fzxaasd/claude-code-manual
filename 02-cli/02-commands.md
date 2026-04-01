# 2.2 CLI 子命令详解

> Claude Code 命令行子命令完整参考

---

## 会话管理

### `claude` - 主命令

启动交互式会话或执行单次命令。

```bash
# 交互式会话
claude

# 单次命令
claude "你的指令"

# 指定模型
claude --model opus "复杂任务"
claude --model sonnet "简单任务"
```

### `claude session` - 远程会话管理

显示远程会话 QR 码，用于通过手机/网页远程控制 Claude Code。

```bash
# 显示远程会话 QR 码和 URL
claude session
```

### `claude compact` - 压缩会话

```bash
# 手动压缩上下文
claude compact

# 查看压缩统计
# 显示: 压缩前 token 数, 压缩后 token 数, 节省比例
```

### `claude resume` - 恢复会话

```bash
# 恢复最近会话
claude --resume

# 恢复指定会话
claude --resume <session-id>

# 从用户消息恢复并重置文件状态
claude --resume --rewind-files <user-message-id>
```

---

## 配置命令

### `claude config` - 配置管理

```bash
# 打开交互式配置面板
claude config
claude settings
```

> **注意**: `config` 是 local-jsx 命令，打开交互式 UI。`show/get/set/reset` 等子命令不存在于 CLI 层。

### `claude init` - 项目初始化

```bash
# 在当前目录初始化
claude init

# 初始化并指定配置
claude init --project-name my-project --permission-mode acceptEdits

# 交互式初始化流程
claude init --interactive
```

**初始化创建的文件:**
```
.claude/
└── settings.json      # 项目设置 (permissions 在 settings.json 的 permissions 字段中)
```

**注意**: `--permission-mode` 参数值应为 `acceptEdits`/`dontAsk` 等，而非 `all`/`limiting`。

### `claude model` - 模型选择

启动交互式菜单界面，用于选择和管理模型。

---

## 权限管理

### `claude permissions` - 权限规则

启动交互式菜单界面，用于管理权限规则。

```bash
# 启动交互式权限管理菜单
claude permissions
```

### `claude privacy-settings` - 隐私设置

```bash
# 查看隐私设置
claude privacy-settings

# 配置数据收集偏好
```

---

## Hooks 管理

### `claude hooks` - Hooks 操作

启动交互式菜单界面，用于管理 Hooks。

```bash
# 启动交互式 Hooks 管理菜单
claude hooks
```

---

## 插件与技能管理

### `claude plugin` - 插件操作

```bash
# 列出已安装插件
claude plugin list

# 安装插件
claude plugin install <plugin>

# 卸载插件
claude plugin uninstall <plugin>

# 更新插件
claude plugin update <plugin>

# 启用/禁用插件
claude plugin enable <plugin>
claude plugin disable <plugin>
claude plugin disable --all
```

### `claude skills` - 技能管理

启动交互式菜单界面，用于管理技能。

```bash
# 启动交互式技能管理菜单
claude skills
```

---

## MCP 相关

### `claude mcp` - MCP 服务器管理

```bash
# 列出 MCP 服务器
claude mcp list

# 添加服务器
claude mcp add github --command "npx @modelcontextprotocol/server-github"

# 从 Claude Desktop 导入
claude mcp add-from-claude-desktop

# JSON 添加
claude mcp add-json <name> <json>

# 获取服务器详情
claude mcp get <name>

# 重置项目选择
claude mcp reset-project-choices

# 移除服务器
claude mcp remove <name>

# 启动 Claude Code 作为 MCP 服务器
claude mcp serve

# 注意: claude mcp status 和 claude mcp reconnect 不存在（reconnect 仅在交互模式下可用）
```

---

## Agent 相关

### `claude agents` - Agent 管理

```bash
# 列出可用 Agent
claude agents list

# Agent 由 --agent 参数在启动时指定
claude --agent reviewer "审查这段代码"
```

---

## 快速操作命令

### `claude btw` - 快速侧问

在当前会话中添加一个旁注，不会中断主流程。

```bash
claude btw "顺便检查一下测试覆盖率"
```

### `claude feedback` - 发送反馈

```bash
# 发送反馈
claude feedback "功能建议：添加代码格式化功能"
```

### `claude cost` - 显示会话费用

```bash
# 查看当前会话费用统计
claude cost
```

### `claude stats` - 统计数据

```bash
# 显示会话统计信息
claude stats
```

### `claude effort` - 努力级别

```bash
# 设置努力级别
claude effort high
```

### `claude insights` - 会话分析报告

```bash
# 生成会话分析报告
claude insights
```

---

## Git 集成

### `claude diff` - Git Diff

```bash
# 查看未提交的更改
claude diff

# 比较特定提交
claude diff <commit-sha>

# 比较分支
claude diff main...feature-branch
```

### `claude commit` - Git 提交

```bash
# 创建提交
claude commit

# 带提交消息
claude commit -m "fix: 修复登录问题"

# 提交并推送
claude commit --push
```

### `claude branch` - Git 分支

```bash
# 列出分支
claude branch list

# 创建分支
claude branch create feature-x

# 切换分支
claude branch checkout <branch-name>
```

---

## 上下文管理

### `claude context` - 上下文管理

启动交互式菜单界面，用于管理上下文。

```bash
# 启动交互式上下文管理菜单
claude context
```

### `claude files` - 追踪文件列表

```bash
# 列出追踪的文件
claude files

# 添加文件到追踪
claude files add <path>

# 移除追踪
claude files remove <path>
```

### `claude think-back` - 回溯思考

```bash
# 查看之前的思考过程
claude think-back

# 回溯到特定点
claude think-back <message-id>
```

### `claude rewind` - 回退会话

```bash
# 回退到之前的状态
claude rewind <message-id>
```

---

### `claude export` - 导出功能

```bash
# 导出会话数据
claude export

# 导出到指定路径
claude export --output <path>
```

---

## UI 定制

### `claude theme` - 终端主题

启动交互式菜单界面，用于选择和管理终端主题。

```bash
# 启动交互式主题选择菜单
claude theme
```

### `claude color` - Agent 颜色

```bash
# 设置 Agent 显示颜色
claude color green
```

### `claude vim` - Vim 模式

```bash
# 启用/禁用 Vim 输入模式
claude vim

# 切换模式
claude vim on
claude vim off
```

### `claude statusline` - 状态栏

```bash
# 启用/禁用状态栏
claude statusline

# 显示状态栏
claude statusline on
```

### `claude ide` - IDE 相关设置

启动交互式菜单界面，用于配置 IDE 相关选项。

```bash
# 启动 IDE 设置菜单
claude ide
```

### `claude keybindings` - 快捷键

启动交互式菜单界面，用于管理快捷键绑定。

```bash
# 启动交互式快捷键管理菜单
claude keybindings
```

---

## 认证命令

### `claude auth login` - 登录认证

```bash
# 启动登录流程
claude auth login

# 带选项登录
claude auth login --sso
claude auth login --console
claude auth login --claudeai
claude auth login --email user@example.com
```

### `claude auth logout` - 登出认证

```bash
# 登出当前账号
claude auth logout
```

### `claude auth status` - 查看认证状态

```bash
claude auth status
```

---

## 辅助命令

### `claude doctor` - 健康检查

```bash
# 运行诊断
claude doctor

# 检查项:
# ✓ Claude API 连接
# ✓ 配置文件
# ✓ 权限设置
# ✓ Hook 配置
# ✓ MCP 服务器
```

### `claude desktop` - 桌面通知

```bash
# 发送桌面通知
claude desktop "构建完成"

# 通知优先级
claude desktop --urgent "错误：构建失败"
```

### `claude release-notes` - 发行说明

```bash
# 查看最新发行说明
claude release-notes

# 查看特定版本
claude release-notes --version 2.0.0
```

### `claude sandbox-toggle` - 沙箱切换

```bash
# 启用/禁用沙箱模式
claude sandbox-toggle
```

### `claude rate-limit-options` - 速率限制配置

```bash
# 查看速率限制选项
claude rate-limit-options

# 配置限制
claude rate-limit-options set <option> <value>
```

---

## 高级命令

### `claude review` - 代码审查

```bash
# 审查变更
claude review

# 审查特定文件
claude review src/auth/login.ts

# 仅检查类型
claude review --type-check

# 输出格式
claude review --format markdown > review.md
```

### `claude security-review` - 安全审查

```bash
# 安全审查
claude security-review

# 审查特定文件
claude security-review src/auth/
```

### `claude compact` - 上下文压缩

```bash
# 压缩上下文
claude compact
```

### `claude memory` - 记忆管理

```bash
# 列出记忆
claude memory list

# 搜索记忆
claude memory search <query>

# 删除记忆
claude memory delete <id>
```

---

## 开发工具

### `claude mcp` - MCP 服务器

```bash
# 列出服务器
claude mcp list

# 添加服务器 (name 是位置参数)
claude mcp add <name> --command <command>

# 启动 Claude Code 作为 MCP 服务器
claude mcp serve [--debug] [--verbose]
```

### `claude exit` - 退出会话

```bash
# 退出当前会话
claude exit
```

### `claude clear` - 清除屏幕

```bash
# 清除终端屏幕
claude clear
```

### `claude copy` - 复制输出

```bash
# 复制最后一条消息
claude copy

# 复制指定消息
claude copy <message-id>
```

### `claude stickers` - 贴纸

```bash
# 发送贴纸
claude stickers <sticker-name>
```

### `claude help` - 帮助信息

```bash
# 通用帮助
claude --help

# 子命令帮助
claude session --help
claude config --help
```

---

## 速率限制与配额

### `claude usage` - 使用量查询

```bash
# 查看当前使用量
claude usage

# 查看详细报告
claude usage --detailed
```

### `claude extra-usage` - 额外配额

```bash
# 查看额外配额
claude extra-usage
```

### `claude plan` - 计划模式

```bash
# 启用计划模式
claude plan

# 计划模式不执行操作，仅生成计划
```

---

## Feature-Gated 命令

以下命令需要特定功能开关启用：

### `claude web-setup` (CCR_REMOTE_SETUP)

远程设置向导。

```bash
claude web-setup
```

### `claude fork` (FORK_SUBAGENT)

分支子会话。

```bash
claude fork
```

### `claude voice` (VOICE_MODE)

语音模式。

```bash
claude voice
```

### `claude proactive` (PROACTIVE | KAIROS)

主动模式。

```bash
claude proactive
```

### `claude assistant` (KAIROS)

助手模式。

```bash
claude assistant
```

### `claude bridge` (BRIDGE_MODE)

桥接模式。

```bash
claude bridge
```

### `claude ultraplan` (ULTRAPLAN)

高级计划模式。

```bash
claude ultraplan
```

### `claude subscribe-pr` (KAIROS_GITHUB_WEBHOOKS)

订阅 PR 通知。

```bash
claude subscribe-pr <pr-url>
```

### `claude force-snip` (HISTORY_SNIP)

强制截断历史。

```bash
claude force-snip
```

### `claude buddy` (BUDDY)

Buddy 模式。

```bash
claude buddy
```

### `claude torch` (TORCH)

Torch 模式。

```bash
claude torch
```

### `claude peers` (UDS_INBOX)

对等连接模式。

```bash
claude peers
```

### `claude server` (DIRECT_CONNECT)

启动 Claude Code 会话服务器。

```bash
claude server
```

### `claude ssh` (SSH_REMOTE)

通过 SSH 连接到远程会话。

```bash
claude ssh <host> [dir]
```

---

## 版本信息

### `claude version` - 版本信息

```bash
claude --version
# claude 2.1.81
```

---

## 命令行组合

### 常用组合

```bash
# 开发工作流
claude init && claude "安装依赖并启动开发服务器"

# 代码审查流程
claude review --format json | jq '.issues[]'

# 批量文件处理
claude "处理 src/components 下的所有文件"
```

### 管道集成

```bash
# 从文件读取指令
cat task.txt | claude

# 保存输出
claude "生成报告" > report.md

# 过滤输出
claude "列出所有 TODO" | grep -E "TODO|FIXME"
```

---

## 退出码

| 退出码 | 含义 |
|--------|------|
| 0 | 成功 |
| 1 | 错误 |
| 2 | 权限被拒绝 |
| 130 | 用户中断 (Ctrl+C) |
