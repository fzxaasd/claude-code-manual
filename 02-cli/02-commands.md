# 2.2 CLI 子命令详解

> Claude Code 命令行子命令完整参考。**注意**: Claude Code 有两类命令：
> 1. **CLI 子命令** - 在终端直接执行，如 `claude mcp list`
> 2. **REPL 斜杠命令** - 在 Claude Code 会话中输入，如输入 `/mcp`

---

## 实际存在的 CLI 子命令

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
```

### `claude auth` - 认证管理

```bash
# 启动登录流程
claude auth login

# 带选项登录
claude auth login --console
claude auth login --claudeai
claude auth login --email user@example.com
claude auth login --sso

# 查看认证状态
claude auth status

# 登出
claude auth logout
```

### `claude plugin` / `claude plugins` - 插件管理

```bash
# 列出已安装插件
claude plugin list
claude plugins list

# 验证插件
claude plugin validate <path>

# 查看市场
claude plugin marketplace

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

### `claude agents` - Agent 管理

```bash
# 列出可用 Agent
claude agents list
```

### `claude doctor` - 健康检查

```bash
# 运行诊断
claude doctor
```

### `claude update` / `claude upgrade` - 更新检查

```bash
# 检查更新
claude update

# 升级
claude upgrade
```

### `claude install` - 安装

```bash
# 安装 Claude Code
claude install
```

### `claude setup-token` - Token 设置

```bash
# 设置 API token
claude setup-token
```

---

## ANT-ONLY CLI 命令

以下命令仅在 ANT (Anthropic Team) 环境中可用：

### `claude up` - 环境初始化

```bash
# 初始化环境
claude up
```

### `claude rollback` - 回滚

```bash
# 回滚版本
claude rollback [target]
```

### `claude log` - 日志管理

```bash
# 查看日志
claude log
```

### `claude error` - 错误日志

```bash
# 查看错误日志
claude error
```

### `claude task` - 任务管理

```bash
# 任务管理
claude task
```

### `claude completion` - Shell 补全

```bash
# 生成补全脚本
claude completion bash
claude completion zsh
claude completion fish
```

---

## Feature-Gated CLI 命令

以下命令需要特定功能开关才能使用：

### `claude server` - 直接连接 (DIRECT_CONNECT)

```bash
# 直接连接
claude server
```

### `claude ssh` - SSH 远程 (SSH_REMOTE)

```bash
# SSH 远程连接
claude ssh <host> [dir]
```

### `claude open` - 打开 Claude.ai 会话 (DIRECT_CONNECT)

```bash
# 打开 Claude.ai 会话
claude open <cc-url>
```

### `claude remote-control` / `claude rc` - 远程控制 (BRIDGE_MODE)

```bash
# 远程控制
claude remote-control [name]
claude rc [name]
```

### `claude assistant` - 助手模式 (KAIROS)

```bash
# 启动助手
claude assistant [sessionId]
```

### `claude auto-mode` - 自动模式配置 (TRANSCRIPT_CLASSIFIER)

```bash
# 配置自动模式
claude auto-mode config
```

---

## 重要说明

### CLI vs REPL 命令区别

以下命令**不是 CLI 子命令**，而是 **REPL 斜杠命令** (在 Claude Code 会话中输入 `/命令`):

| 误列为 CLI 命令 | 正确类型 | 实际用法 |
|----------------|----------|----------|
| `claude session` | REPL 命令 | `/session` |
| `claude compact` | REPL 命令 | `/compact` |
| `claude config` | REPL 命令 | `/config` |
| `claude init` | REPL 命令 | `/init` |
| `claude model` | REPL 命令 | `/model` |
| `claude permissions` | REPL 命令 | `/permissions` |
| `claude hooks` | REPL 命令 | `/hooks` |
| `claude skills` | REPL 命令 | `/skills` |
| `claude btw` | REPL 命令 | `/btw` |
| `claude feedback` | REPL 命令 | `/feedback` |
| `claude cost` | REPL 命令 | `/cost` |
| `claude stats` | REPL 命令 | `/stats` |
| `claude effort` | REPL 命令 | `/effort` |
| `claude insights` | REPL 命令 | `/insights` |
| `claude diff` | REPL 命令 | `/diff` |
| `claude commit` | REPL 命令 | `/commit` |
| `claude branch` | REPL 命令 | `/branch` |
| `claude context` | REPL 命令 | `/context` |
| `claude files` | REPL 命令 | `/files` |
| `claude think-back` | REPL 命令 | `/think-back` |
| `claude rewind` | REPL 命令 | `/rewind` |
| `claude export` | REPL 命令 | `/export` |
| `claude theme` | REPL 命令 | `/theme` |
| `claude color` | REPL 命令 | `/color` |
| `claude vim` | REPL 命令 | `/vim` |
| `claude statusline` | REPL 命令 | `/statusline` |
| `claude ide` | REPL 命令 | `/ide` |
| `claude keybindings` | REPL 命令 | `/keybindings` |
| `claude plan` | REPL 命令 | `/plan` |
| `claude memory` | REPL 命令 | `/memory` |
| `claude exit` | REPL 命令 | `/exit` |

### 不存在的命令

以下命令**不存在**于 Claude Code:

- `claude privacy-settings`
- `claude sandbox-toggle`
- `claude rate-limit-options`
- `claude review`
- `claude security-review`
- `claude release-notes`
- `claude desktop`
- `claude clear`
- `claude copy`
- `claude stickers`
- `claude help`
- `claude usage`
- `claude extra-usage`
- `claude rewind-files`
