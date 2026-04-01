# 2.3 环境变量

> Claude Code 环境变量完整参考

---

## API 相关

### `ANTHROPIC_API_KEY`

Anthropic API 密钥。

```bash
# 必需
export ANTHROPIC_API_KEY=sk-ant-xxxxx

# 验证
echo $ANTHROPIC_API_KEY
```

### `ANTHROPIC_BASE_URL`

API 端点 URL（用于代理或自定义端点）。

```bash
# 默认值
export ANTHROPIC_BASE_URL=https://api.anthropic.com

# 使用代理
export ANTHROPIC_BASE_URL=http://localhost:8080
```

### `ANTHROPIC_MODEL`

指定默认模型。

```bash
# 使用 Sonnet
export ANTHROPIC_MODEL=claude-sonnet-4-20250514

# 使用 Opus
export ANTHROPIC_MODEL=claude-opus-4-20250514

# 使用 Haiku
export ANTHROPIC_MODEL=claude-haiku-4-20250507
```

---

## 权限相关

### `CLAUDE_PERMISSION_MODE`

默认权限模式。

```bash
# 可选值: acceptEdits, bypassPermissions, default, dontAsk, plan
export CLAUDE_PERMISSION_MODE=default
```

| 值 | 说明 |
|----|------|
| `default` | 每次询问 |
| `acceptEdits` | 自动接受编辑 |
| `bypassPermissions` | 绕过所有检查 |
| `dontAsk` | 不询问，直接拒绝 |
| `plan` | 仅在计划模式 |

---

## 会话相关

### `CLAUDE_SESSION_DIR`

会话存储目录。

```bash
# 默认值
export CLAUDE_SESSION_DIR=~/.claude/sessions

# 自定义位置
export CLAUDE_SESSION_DIR=/mnt/sessions
```

### `CLAUDE_SESSION_TIMEOUT`

会话超时时间（秒）。

```bash
export CLAUDE_SESSION_TIMEOUT=3600
```

---

## 配置相关

### `CLAUDE_CONFIG_DIR`

配置目录位置。

```bash
# 默认值
export CLAUDE_CONFIG_DIR=~/.claude

# 项目配置优先
export CLAUDE_CONFIG_DIR=.claude
```

### `CLAUDE_SETTINGS_FILE`

指定设置文件路径。

```bash
export CLAUDE_SETTINGS_FILE=~/.claude/custom-settings.json
```

---

## MCP 相关

### `MCP_SERVERS`

逗号分隔的 MCP 服务器列表。

```bash
export MCP_SERVERS=github,filesystem,slack
```

### `MCP_SERVER_TIMEOUT`

MCP 服务器超时时间（毫秒）。

```bash
export MCP_SERVER_TIMEOUT=30000
```

---

## 调试相关

### `CLAUDE_DEBUG`

启用调试模式。

```bash
# 启用所有调试
export CLAUDE_DEBUG=1

# 启用特定调试
export CLAUDE_DEBUG=hooks,tools,agent

# 禁用
unset CLAUDE_DEBUG
```

### `CLAUDE_LOG_LEVEL`

日志级别。

```bash
export CLAUDE_LOG_LEVEL=debug
export CLAUDE_LOG_LEVEL=info
export CLAUDE_LOG_LEVEL=warn
export CLAUDE_LOG_LEVEL=error
```

### `CLAUDE_LOG_FILE`

日志输出文件。

```bash
export CLAUDE_LOG_FILE=/tmp/claude-debug.log
```

---

## 代理相关

### `HTTP_PROXY` / `HTTPS_PROXY`

HTTP/HTTPS 代理。

```bash
export HTTP_PROXY=http://proxy.example.com:8080
export HTTPS_PROXY=http://proxy.example.com:8080
```

### `NO_PROXY`

跳过代理的地址。

```bash
export NO_PROXY=localhost,127.0.0.1,.local
```

---

## 工具相关

### `CLAUDE_TOOL_TIMEOUT`

工具默认超时（毫秒）。

```bash
export CLAUDE_TOOL_TIMEOUT=60000
```

### `CLAUDE_BROWSER_TOOL`

浏览器工具实现。

```bash
export CLAUDE_BROWSER_TOOL=playwright
export CLAUDE_BROWSER_TOOL=selenium
export CLAUDE_BROWSER_TOOL=none
```

---

## 用户界面

### `CLAUDE_THEME`

UI 主题。

```bash
export CLAUDE_THEME=dark
export CLAUDE_THEME=light
export CLAUDE_THEME=auto
```

### `CLAUDE_COLOR_OUTPUT`

启用彩色输出。

```bash
export CLAUDE_COLOR_OUTPUT=1
```

---

## Hooks 相关

### `CLAUDE_HOOKS_DIR`

Hooks 脚本目录。

```bash
export CLAUDE_HOOKS_DIR=~/.claude/hooks
```

### `CLAUDE_HOOK_TIMEOUT`

Hook 执行超时（毫秒）。

```bash
export CLAUDE_HOOK_TIMEOUT=30000
```

---

## 实验性功能

### `CLAUDE_FEATURE_FLAGS`

启用实验性功能。

```bash
export CLAUDE_FEATURE_FLAGS=multi-agent,advanced-compact
```

---

## 完整环境变量配置示例

```bash
# ~/.zshrc 或 ~/.bashrc

# API 配置
export ANTHROPIC_API_KEY=sk-ant-xxxxx
export ANTHROPIC_BASE_URL=https://api.anthropic.com

# 权限配置
export CLAUDE_PERMISSION_MODE=ask

# 调试配置
export CLAUDE_DEBUG=0
export CLAUDE_LOG_LEVEL=info

# 会话配置
export CLAUDE_SESSION_DIR=~/.claude/sessions

# 代理配置（如果需要）
export HTTP_PROXY=http://localhost:8080
export HTTPS_PROXY=http://localhost:8080

# MCP 配置
export MCP_SERVER_TIMEOUT=30000
```

---

## 跨平台配置

### macOS (~/.zshrc)

```bash
echo 'export ANTHROPIC_API_KEY=sk-ant-xxxxx' >> ~/.zshrc
source ~/.zshrc
```

### Linux (~/.bashrc)

```bash
echo 'export ANTHROPIC_API_KEY=sk-ant-xxxxx' >> ~/.bashrc
source ~/.bashrc
```

### Windows (PowerShell)

```powershell
[Environment]::SetEnvironmentVariable(
    "ANTHROPIC_API_KEY",
    "sk-ant-xxxxx",
    "User"
)
```

---

## 安全注意事项

### 敏感信息保护

```bash
# 不要在脚本中硬编码
# 错误 ❌
export ANTHROPIC_API_KEY=sk-ant-xxxxx

# 正确 ✅
# 使用 1Password 或类似工具
op run -- echo $ANTHROPIC_API_KEY
```

### 环境文件

```bash
# 创建 .env 文件
cat > ~/.claude/.env << 'EOF'
ANTHROPIC_API_KEY=sk-ant-xxxxx
CLAUDE_PERMISSION_MODE=ask
EOF

# 加载
set -a
source ~/.claude/.env
set +a
```

---

## 故障排除

### 变量不生效

```bash
# 检查变量是否存在
echo $CLAUDE_PERMISSION_MODE

# 检查配置文件
cat ~/.zshrc | grep CLAUDE

# 重新加载
source ~/.zshrc
```

### 权限问题

```bash
# 确保文件权限正确
chmod 600 ~/.claude/.env
```
