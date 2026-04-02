# 2.3 环境变量

> Claude Code 环境变量完整参考（基于源码验证）

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

### `ANTHROPIC_AUTH_TOKEN`

认证令牌（用于内部通信）。

```bash
export ANTHROPIC_AUTH_TOKEN=<token>
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

## 配置相关

### `CLAUDE_CONFIG_DIR`

配置目录位置。

```bash
# 默认值
export CLAUDE_CONFIG_DIR=~/.claude

# 项目配置优先
export CLAUDE_CONFIG_DIR=.claude
```

### `CLAUDE_CODE_SIMPLE`

简化模式（禁用高级功能）。

```bash
export CLAUDE_CODE_SIMPLE=1
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

## 功能开关

### `CLAUDE_CODE_ENABLE_TASKS`

启用 Tasks V2 系统。

```bash
export CLAUDE_CODE_ENABLE_TASKS=true
```

### `CLAUDE_CODE_PROACTIVE`

启用主动模式。

```bash
export CLAUDE_CODE_PROACTIVE=1
```

### `CLAUDE_CODE_BRIEF`

启用简短模式。

```bash
export CLAUDE_CODE_BRIEF=1
```

### `CLAUDE_CODE_DISABLE_TERMINAL_TITLE`

禁用终端标题更新。

```bash
export CLAUDE_CODE_DISABLE_TERMINAL_TITLE=1
```

---

## Plan Mode 相关

### `CLAUDE_CODE_PLAN_V2_AGENT_COUNT`

Plan Mode V2 Agent 数量。

```bash
export CLAUDE_CODE_PLAN_V2_AGENT_COUNT=3
```

### `CLAUDE_CODE_PLAN_V2_EXPLORE_AGENT_COUNT`

Plan Mode V2 探索 Agent 数量。

```bash
export CLAUDE_CODE_PLAN_V2_EXPLORE_AGENT_COUNT=5
```

### `CLAUDE_CODE_PLAN_MODE_INTERVIEW_PHASE`

启用 Plan Mode 面试阶段。

```bash
export CLAUDE_CODE_PLAN_MODE_INTERVIEW_PHASE=1
```

### `CLAUDE_CODE_ENABLE_XAA`

启用 XAA (Cross-App Access / SEP-990) 功能，用于 MCP 服务器的企业托管授权。

```bash
export CLAUDE_CODE_ENABLE_XAA=1
```

### `CLAUDE_CODE_CCR_MIRROR`

启用 CCR (Claude Code Remote) 镜像模式。

```bash
export CLAUDE_CODE_CCR_MIRROR=1
```

### `CLAUDE_CODE_REMOTE`

远程会话模式。

```bash
export CLAUDE_CODE_REMOTE=1
```

### `CLAUDE_CODE_REMOTE_MEMORY_DIR`

远程会话的内存目录覆盖。

```bash
export CLAUDE_CODE_REMOTE_MEMORY_DIR=/path/to/memory
```

### `CLAUDE_CODE_DISABLE_AUTO_MEMORY`

禁用自动内存功能。

```bash
# 禁用
export CLAUDE_CODE_DISABLE_AUTO_MEMORY=1

# 强制启用 (覆盖默认启用)
export CLAUDE_CODE_DISABLE_AUTO_MEMORY=0
```

### `CLAUDE_CODE_DISABLE_BACKGROUND_TASKS`

禁用后台任务。

```bash
export CLAUDE_CODE_DISABLE_BACKGROUND_TASKS=1
```

### `CLAUDE_CODE_DISABLE_THINKING`

禁用思考 (thinking) 功能。

```bash
export CLAUDE_CODE_DISABLE_THINKING=1
```

---

## CLI 功能标志

### `CLAUDE_CODE_CLI`

启用 CLI 模式。

```bash
export CLAUDE_CODE_CLI=1
```

---

## 已验证不存在的环境变量

以下环境变量**不存在**于 Claude Code 源码中：

| 变量名 | 说明 |
|--------|------|
| `CLAUDE_SESSION_DIR` | ❌ 不存在 |
| `CLAUDE_SESSION_TIMEOUT` | ❌ 不存在 |
| `CLAUDE_SETTINGS_FILE` | ❌ 不存在 |
| `CLAUDE_DEBUG` | ✅ 存在，用于调试模式下显示警告上下文 |
| `CLAUDE_LOG_LEVEL` | ❌ 不存在 |
| `CLAUDE_LOG_FILE` | ❌ 不存在 |
| `CLAUDE_TOOL_TIMEOUT` | ❌ 不存在 |
| `CLAUDE_BROWSER_TOOL` | ❌ 不存在 |
| `CLAUDE_THEME` | ❌ 不存在 |
| `CLAUDE_COLOR_OUTPUT` | ❌ 不存在 |
| `CLAUDE_HOOKS_DIR` | ❌ 不存在 |
| `CLAUDE_HOOK_TIMEOUT` | ❌ 不存在 |
| `CLAUDE_FEATURE_FLAGS` | ❌ 不存在 |
| `MCP_SERVERS` | ❌ 不存在 |
| `MCP_SERVER_TIMEOUT` | ❌ 不存在 |
| `CLAUDE_PERMISSION_MODE` | ❌ 不存在，应使用 `--permission-mode` CLI 参数 |

---

## 权限配置

**注意**: `CLAUDE_PERMISSION_MODE` 环境变量**不存在**。权限模式通过以下方式设置：

```bash
# CLI 参数
claude --permission-mode acceptEdits
claude --permission-mode dontAsk
```

| 值 | 说明 |
|----|------|
| `default` | 每次询问 |
| `acceptEdits` | 自动接受编辑 |
| `bypassPermissions` | 绕过所有检查 |
| `dontAsk` | 不询问，直接拒绝 |
| `plan` | 仅在计划模式 |

**settings.json 配置**:
```json
{
  "permissions": {
    "defaultMode": "dontAsk"
  }
}
```

---

## 完整环境变量配置示例

```bash
# ~/.zshrc 或 ~/.bashrc

# API 配置 (必需)
export ANTHROPIC_API_KEY=sk-ant-xxxxx
export ANTHROPIC_BASE_URL=https://api.anthropic.com

# 代理配置（如果需要）
export HTTP_PROXY=http://localhost:8080
export HTTPS_PROXY=http://localhost:8080

# 配置目录
export CLAUDE_CONFIG_DIR=~/.claude
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
ANTHROPIC_BASE_URL=https://api.anthropic.com
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
echo $ANTHROPIC_API_KEY

# 检查配置文件
cat ~/.zshrc | grep ANTHROPIC

# 重新加载
source ~/.zshrc
```

### 权限问题

```bash
# 确保文件权限正确
chmod 600 ~/.claude/.env
```
