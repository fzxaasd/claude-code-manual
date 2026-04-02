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

# 添加服务器 (stdio)
claude mcp add <name> <command> [args...]

# 添加服务器 (HTTP/SSE/WS)
claude mcp add <name> <url>

# 添加服务器 (OAuth/XAA)
claude mcp add <name> <url> --xaa --client-id <id> --client-secret <secret>

# 从 Claude Desktop 导入
claude mcp add-from-claude-desktop [--scope <scope>]

# JSON 添加
claude mcp add-json

# 获取服务器详情
claude mcp get <name>

# 重置项目选择
claude mcp reset-project-choices

# 移除服务器
claude mcp remove <name> [--scope <scope>]

# XAA IdP 管理
claude mcp xaa setup --issuer <url> --client-id <id> [--client-secret] [--callback-port <port>]
claude mcp xaa login
claude mcp xaa show
claude mcp xaa clear

# 启动 Claude Code 作为 MCP 服务器
claude mcp serve [--debug] [--verbose]
```

**注意**:
- `claude mcp add` 的 `<command>` 是**位置参数**，不是 `--command` 选项
- `--client-id`, `--client-secret`, `--callback-port`, `--xaa` 仅对 HTTP/SSE 传输有效，stdio 会忽略
- `--issuer` 和 `--client-id` 是 `mcp xaa setup` 的**必选参数**
- XAA 由 `CLAUDE_CODE_ENABLE_XAA=1` 环境变量启用，非企业独占

**mcp xaa 子命令说明**:
- `xaa setup`: 配置 XAA (SEP-990) IdP 连接，一次配置供所有 XAA 服务器使用
  - `--issuer` (必填): IdP issuer URL
  - `--client-id` (必填): OAuth client ID
  - `--client-secret` (可选): OAuth 客户端密钥，不提供时从环境变量读取
  - `--callback-port` (可选): 固定回调端口
- `xaa login`: 登录 IdP 获取令牌
  - `--force`: 忽略缓存的 id_token 并重新登录
  - `--id-token <jwt>`: 直接写入预获取的 id_token，跳过 OIDC 浏览器登录
- `xaa show`: 显示当前 IdP 配置
- `xaa clear`: 清除 IdP 配置和令牌

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

# 市场管理
claude plugin marketplace add <source> [--sparse <paths...>] [--scope <scope>]
claude plugin marketplace list [--json]
claude plugin marketplace remove <name>
claude plugin marketplace remove <name>  # 别名: rm
claude plugin marketplace update [name]

# 安装插件
claude plugin install <plugin>
claude plugin install <plugin> --scope <scope>

# 卸载插件
claude plugin uninstall <plugin>
claude plugin uninstall <plugin> --scope <scope> [--keep-data]

# 更新插件
claude plugin update <plugin>
claude plugin update <plugin> --scope <scope>

# 启用/禁用插件
claude plugin enable <plugin>
claude plugin disable <plugin>
claude plugin disable --all
```

**marketplace 子命令说明**:
- `marketplace add <source>`: 从 URL、路径或 GitHub 仓库添奸市场。`--sparse` 用于 monorepo 限制目录，`--scope` 指定作用域 (user/project/local)
- `marketplace list`: 列出所有已配置的市场
- `marketplace remove <name>`: 移除配置的市场
- `marketplace update [name]`: 更新市场，不指定名称则更新所有

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
# 创建任务
claude task create <subject> [--description <text>] [--list <id>]

# 列出任务
claude task list [--list <id>] [--pending] [--json]

# 获取任务详情
claude task get <id> [--list <id>]

# 更新任务
claude task update <id> [--status <status>] [--subject <text>] [--description <text>] [--owner <agentId>] [--clear-owner]

# 显示任务目录
claude task dir [--list <id>]
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
# 显示有效配置
claude auto-mode config

# 显示默认规则 (JSON 格式)
claude auto-mode defaults

# AI 反馈你的自定义规则
claude auto-mode critique [--model <model>]
```

---

## 未文档化的子命令选项

> 以下选项存在于源码中但未在官方文档中记录

### `claude server` - 直接连接选项

| 选项 | 类型 | 说明 |
|------|------|------|
| `--port <number>` | string | HTTP 端口，默认 '0' |
| `--host <string>` | string | 绑定地址，默认 '0.0.0.0' |
| `--auth-token <token>` | string | Bearer 令牌用于认证 |
| `--unix <path>` | string | 监听 Unix 域套接字 |
| `--workspace <dir>` | string | 不指定 cwd 的会话的默认工作目录 |
| `--idle-timeout <ms>` | string | 分离会话的空闲超时(毫秒)，默认 '600000' |
| `--max-sessions <n>` | string | 最大并发会话数，默认 '32' |

### `claude ssh` - SSH 远程选项

| 选项 | 类型 | 说明 |
|------|------|------|
| `--permission-mode <mode>` | string | 远程会话的权限模式 |
| `--dangerously-skip-permissions` | boolean | 跳过所有远程权限提示 (危险) |
| `--local` | boolean | e2e 测试模式 - 本地生成子 CLI (跳过 ssh/deploy) |

### `claude rollback` - 回滚选项

| 选项 | 类型 | 说明 |
|------|------|------|
| `-l, --list` | boolean | 列出最近的发布版本及时间 |
| `--dry-run` | boolean | 显示将要安装的内容而不安装 |
| `--safe` | boolean | 回滚到服务器固定的安全版本 |

### `claude completion` - 补全选项

| 选项 | 类型 | 说明 |
|------|------|------|
| `--output <file>` | string | 直接写入文件而非 stdout |

### `claude mcp` - MCP 选项

| 命令 | 选项 | 类型 | 说明 |
|------|------|------|------|
| `mcp serve` | `--verbose` | boolean | 覆盖配置中的 verbose 模式设置 |
| `mcp add` | `--xaa` | boolean | 为此服务器启用 XAA (SEP-990)，需要先运行 `claude mcp xaa setup` |
| `mcp xaa login` | `--force` | boolean | 忽略缓存的 id_token 并重新登录 |
| `mcp xaa login` | `--id-token <jwt>` | string | 直接写入预获取的 id_token，跳过 OIDC 浏览器登录 |

### Cowork 选项 (隐藏)

所有 plugin 和 marketplace 子命令支持 `--cowork` 参数，使用 `cowork_plugins` 目录：

| 命令 | 说明 |
|------|------|
| `plugin validate --cowork` | 使用 cowork_plugins 目录验证 |
| `plugin list --cowork` | 使用 cowork_plugins 目录列出 |
| `plugin install --cowork` | 使用 cowork_plugins 目录安装 |
| `plugin uninstall --cowork` | 使用 cowork_plugins 目录卸载 |
| `plugin enable --cowork` | 使用 cowork_plugins 目录启用 |
| `plugin disable --cowork` | 使用 cowork_plugins 目录禁用 |
| `plugin update --cowork` | 使用 cowork_plugins 目录更新 |
| `marketplace add --cowork` | 使用 cowork_plugins 目录添加 |
| `marketplace list --cowork` | 使用 cowork_plugins 目录列出 |
| `marketplace remove --cowork` | 使用 cowork_plugins 目录移除 |
| `marketplace update --cowork` | 使用 cowork_plugins 目录更新 |

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
