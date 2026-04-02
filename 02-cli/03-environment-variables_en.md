# 2.3 Environment Variables

> Complete reference for Claude Code environment variables (verified against source code)

---

## API Related

### `ANTHROPIC_API_KEY`

Anthropic API key.

```bash
# Required
export ANTHROPIC_API_KEY=sk-ant-xxxxx

# Verify
echo $ANTHROPIC_API_KEY
```

### `ANTHROPIC_BASE_URL`

API endpoint URL (for proxy or custom endpoints).

```bash
# Default value
export ANTHROPIC_BASE_URL=https://api.anthropic.com

# Use proxy
export ANTHROPIC_BASE_URL=http://localhost:8080
```

### `ANTHROPIC_AUTH_TOKEN`

Authentication token (for internal communication).

```bash
export ANTHROPIC_AUTH_TOKEN=<token>
```

### `ANTHROPIC_MODEL`

Specify default model.

```bash
# Use Sonnet
export ANTHROPIC_MODEL=claude-sonnet-4-20250514

# Use Opus
export ANTHROPIC_MODEL=claude-opus-4-20250514

# Use Haiku
export ANTHROPIC_MODEL=claude-haiku-4-20250507
```

---

## Configuration Related

### `CLAUDE_CONFIG_DIR`

Configuration directory location.

```bash
# Default value
export CLAUDE_CONFIG_DIR=~/.claude

# Project config takes priority
export CLAUDE_CONFIG_DIR=.claude
```

### `CLAUDE_CODE_SIMPLE`

Simplified mode (disables advanced features).

```bash
export CLAUDE_CODE_SIMPLE=1
```

---

## Proxy Related

### `HTTP_PROXY` / `HTTPS_PROXY`

HTTP/HTTPS proxy.

```bash
export HTTP_PROXY=http://proxy.example.com:8080
export HTTPS_PROXY=http://proxy.example.com:8080
```

### `NO_PROXY`

Addresses to skip proxy.

```bash
export NO_PROXY=localhost,127.0.0.1,.local
```

---

## Feature Flags

### `CLAUDE_CODE_ENABLE_TASKS`

Enable Tasks V2 system.

```bash
export CLAUDE_CODE_ENABLE_TASKS=true
```

### `CLAUDE_CODE_PROACTIVE`

Enable proactive mode.

```bash
export CLAUDE_CODE_PROACTIVE=1
```

### `CLAUDE_CODE_BRIEF`

Enable brief mode.

```bash
export CLAUDE_CODE_BRIEF=1
```

### `CLAUDE_CODE_DISABLE_TERMINAL_TITLE`

Disable terminal title updates.

```bash
export CLAUDE_CODE_DISABLE_TERMINAL_TITLE=1
```

---

## Plan Mode Related

### `CLAUDE_CODE_PLAN_V2_AGENT_COUNT`

Plan Mode V2 Agent count.

```bash
export CLAUDE_CODE_PLAN_V2_AGENT_COUNT=3
```

### `CLAUDE_CODE_PLAN_V2_EXPLORE_AGENT_COUNT`

Plan Mode V2 explore Agent count.

```bash
export CLAUDE_CODE_PLAN_V2_EXPLORE_AGENT_COUNT=5
```

### `CLAUDE_CODE_PLAN_MODE_INTERVIEW_PHASE`

Enable Plan Mode interview phase.

```bash
export CLAUDE_CODE_PLAN_MODE_INTERVIEW_PHASE=1
```

---

## CLI Feature Flags

### `CLAUDE_CODE_CLI`

Enable CLI mode.

```bash
export CLAUDE_CODE_CLI=1
```

---

## Verified Non-Existent Environment Variables

The following environment variables do **NOT exist** in Claude Code source code:

| Variable | Description |
|--------|------|
| `CLAUDE_SESSION_DIR` | Not exist |
| `CLAUDE_SESSION_TIMEOUT` | Not exist |
| `CLAUDE_SETTINGS_FILE` | Not exist |
| `CLAUDE_DEBUG` | Not a formal environment variable |
| `CLAUDE_LOG_LEVEL` | Not exist |
| `CLAUDE_LOG_FILE` | Not exist |
| `CLAUDE_TOOL_TIMEOUT` | Not exist |
| `CLAUDE_BROWSER_TOOL` | Not exist |
| `CLAUDE_THEME` | Not exist |
| `CLAUDE_COLOR_OUTPUT` | Not exist |
| `CLAUDE_HOOKS_DIR` | Not exist |
| `CLAUDE_HOOK_TIMEOUT` | Not exist |
| `CLAUDE_FEATURE_FLAGS` | Not exist |
| `MCP_SERVERS` | Not exist |
| `MCP_SERVER_TIMEOUT` | Not exist |
| `CLAUDE_PERMISSION_MODE` | Not exist, use `--permission-mode` CLI parameter instead |

---

## Permission Configuration

**Note**: `CLAUDE_PERMISSION_MODE` environment variable does **NOT exist**. Permission mode is set via:

```bash
# CLI parameter
claude --permission-mode acceptEdits
claude --permission-mode dontAsk
```

| Value | Description |
|----|------|
| `default` | Ask every time |
| `acceptEdits` | Auto-accept edits |
| `bypassPermissions` | Bypass all checks |
| `dontAsk` | Do not ask, directly refuse |
| `plan` | Only in plan mode |

**settings.json configuration**:
```json
{
  "permissions": {
    "defaultMode": "dontAsk"
  }
}
```

---

## Complete Environment Variable Configuration Example

```bash
# ~/.zshrc or ~/.bashrc

# API configuration (required)
export ANTHROPIC_API_KEY=sk-ant-xxxxx
export ANTHROPIC_BASE_URL=https://api.anthropic.com

# Proxy configuration (if needed)
export HTTP_PROXY=http://localhost:8080
export HTTPS_PROXY=http://localhost:8080

# Config directory
export CLAUDE_CONFIG_DIR=~/.claude
```

---

## Security Notes

### Sensitive Information Protection

```bash
# Do not hardcode in scripts
# Wrong
export ANTHROPIC_API_KEY=sk-ant-xxxxx

# Correct
# Use 1Password or similar tools
op run -- echo $ANTHROPIC_API_KEY
```

### Environment Files

```bash
# Create .env file
cat > ~/.claude/.env << 'EOF'
ANTHROPIC_API_KEY=sk-ant-xxxxx
ANTHROPIC_BASE_URL=https://api.anthropic.com
EOF

# Load
set -a
source ~/.claude/.env
set +a
```

---

## Troubleshooting

### Variables Not Taking Effect

```bash
# Check if variable exists
echo $ANTHROPIC_API_KEY

# Check config file
cat ~/.zshrc | grep ANTHROPIC

# Reload
source ~/.zshrc
```

### Permission Issues

```bash
# Ensure correct file permissions
chmod 600 ~/.claude/.env
```
