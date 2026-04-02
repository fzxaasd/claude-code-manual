# Claude Code CLI Global Options

> Complete parameter reference based on `claude --help` and source code

## Basic Usage

```bash
claude [options] [command] [prompt]
```

## Core Options

### 1. Authentication and Connection

| Parameter | Description | Example |
|------|------|------|
| `--add-dir <dirs...>` | Additional directories to allow access (repeatable) | `--add-dir /data/projects` |
| `--model <model>` | Specify model | `--model sonnet` |
| `--fallback-model <model>` | Fallback model when primary is overloaded | `--fallback-model opus` |

### 2. Execution Mode

| Parameter | Description | Example |
|------|------|------|
| `-p, --print` | Non-interactive mode, print output | `claude -p "translate code"` |
| `-c, --continue` | Continue previous session | `claude -c` |
| `-r, --resume [id]` | Resume specific session | `claude -r abc123` |
| `-n, --name <name>` | Session name | `claude -n "feature-x"` |
| `--bare` | Minimal mode, skip auto-discovery | `--bare` |
| `--input-format <format>` | Input format (`text`, `stream-json`) | `--input-format stream-json` |
| `--output-format <format>` | Output format (`text`, `json`, `stream-json`) | `--output-format json` |
| `--json-schema <schema>` | Structured output Schema | `--json-schema '{"type":"object"}'` |

### 3. Session Control

| Parameter | Description | Example |
|------|------|------|
| `--session-id <uuid>` | Specify session ID | `--session-id abc-123` |
| `--no-session-persistence` | Disable session persistence | `--no-session-persistence` |
| `--fork-session` | Create new session ID on resume | `--fork-session -r abc123` |
| `--resume-session-at <message id>` | Resume at specific message | `--resume-session-at msg_xyz` |
| `--rewind-files <user-message-id>` | Reset files to specified state | `--rewind-files <id> --resume` |
| `--max-turns <turns>` | Max turns in non-interactive mode | `--max-turns 5` |

### 4. Permission Control

| Parameter | Description | Example |
|------|------|------|
| `--permission-mode <mode>` | Permission mode | `--permission-mode auto` |
| `--dangerously-skip-permissions` | Skip all checks (dangerous) | |
| `--allow-dangerously-skip-permissions` | Allow this option but not enabled by default | |
| `--allowed-tools <tools...>` | Allowed tools whitelist (variadic) | `--allowed-tools Read,Bash(git:*)` |
| `--disallowed-tools <tools...>` | Disallowed tools blacklist (variadic) | `--disallowed-tools Write,Edit` |
| `--tools <tools...>` | Available tools list (variadic) | `--tools Read,Edit` or `--tools ""` to disable all |

### 5. Configuration

| Parameter | Description | Example |
|------|------|------|
| `--settings <file-or-json>` | Settings file path or JSON string | `--settings ./config.json` |
| `--setting-sources <sources>` | Configuration sources to load | `--setting-sources user,project` |
| `--system-prompt <prompt>` | System prompt | `--system-prompt "You are a..."` |
| `--system-prompt-file <file>` | Load system prompt from file | `--system-prompt-file ./system.md` |
| `--append-system-prompt <prompt>` | Append to system prompt | |
| `--append-system-prompt-file <file>` | Append system prompt from file | |
| `--prefill <text>` | Prefill input box (not submitted) | `--prefill "initial content"` |

### 6. Agent Configuration

| Parameter | Description | Example |
|------|------|------|
| `--agent <agent>` | Specify Agent (overrides settings) | `--agent reviewer` |
| `--agents <json>` | Custom Agents JSON | `--agents '{"codewriter":{"prompt":"..."}}'` |
| `--effort <level>` | Effort level (`low`, `medium`, `high`, `max`) | `--effort high` |
| `--betas <betas...>` | Beta feature flags (variadic, API key users) | `--betas feature-x` |

### 7. Debugging

| Parameter | Description | Example |
|------|------|------|
| `-d, --debug [filter]` | Debug mode | `--debug hooks` |
| `--debug-to-stderr` | Debug output to stderr | |
| `--debug-file <path>` | Debug log file | `--debug-file /tmp/debug.log` |
| `--verbose` | Override verbose setting | |
| `--mcp-debug` | MCP debug mode (deprecated, use --debug) | |

### 8. MCP Configuration

| Parameter | Description | Example |
|------|------|------|
| `--mcp-config <configs...>` | MCP config files (variadic) | `--mcp-config ./mcp.json` |
| `--strict-mcp-config` | Only use configs from --mcp-config | |
| `--plugin-dir <path>` | Plugin directory | `--plugin-dir ./plugins` |

### 9. Output Control

| Parameter | Description | Example |
|------|------|------|
| `--include-hook-events` | Include hook lifecycle events (requires --output-format=stream-json) | |
| `--include-partial-messages` | Include partial message chunks (requires --print and --output-format=stream-json) | |
| `--replay-user-messages` | Replay user messages for confirmation (stream-json mode) | |
| `--max-budget-usd <amount>` | Max spending | `--max-budget-usd 1.0` |
| `--task-budget <tokens>` | API endpoint task budget | |
| `--workload <tag>` | Workload identifier (for billing) | `--workload cron-job` |

### 10. Thinking Mode

| Parameter | Description | Example |
|------|------|------|
| `--thinking <mode>` | Thinking mode (`enabled`, `adaptive`, `disabled`) | `--thinking enabled` |
| `--max-thinking-tokens <tokens>` | Max thinking tokens (deprecated) | |

### 11. Experimental Features

| Parameter | Description | Example |
|------|------|------|
| `--betas <betas...>` | Beta feature flags (variadic) | `--betas feature-x` |
| `--chrome` | Enable Chrome integration | |
| `--no-chrome` | Disable Chrome integration | |
| `--ide` | Auto-connect to IDE | |
| `--tmux` | Create tmux session (requires --worktree) | `--tmux --worktree feature-x` |
| `-w, --worktree [name]` | Git worktree | `-w feature-auth` |
| `--init` | Run init hooks then continue | `--init` |
| `--init-only` | Run init hooks then exit | `--init-only` |
| `--maintenance` | Run maintenance hooks | `--maintenance` |

### 12. Remote Control

| Parameter | Description | Example |
|------|------|------|
| `--remote` | Enable remote control | `--remote "task description"` |
| `--remote-control [name]` | Remote control (optional name) | |
| `--rc [name]` | Alias for `--remote-control` | |

### 13. Other

| Parameter | Description | Example |
|------|------|------|
| `-v, --version` | Version info | |
| `-h, --help` | Help info | |
| `--disable-slash-commands` | Disable all skills | |
| `--file <specs...>` | File resources to download on startup | `--file file_abc:doc.txt` |
| `--deep-link-origin` | Deep link startup signal | |
| `--from-pr [value]` | Resume session from PR | `--from-pr 123` |

---

## Permission Mode

| Mode | Description |
|------|------|
| `default` | Default behavior, ask user |
| `acceptEdits` | Auto-accept edit operations |
| `bypassPermissions` | Bypass all checks (dangerous) |
| `dontAsk` | Do not ask, directly refuse |
| `plan` | Only allow in plan mode |
| `auto` | Auto mode, based on classifier |

---

## Output Format

| Format | Description |
|------|------|
| `text` | Plain text (default) |
| `json` | JSON structured output |
| `stream-json` | Streaming JSON |

---

## Input Format

| Format | Description |
|------|------|
| `text` | Plain text (default) |
| `stream-json` | Streaming JSON input |

---

## Usage Examples

### 1. Basic Usage

```bash
# Interactive mode
claude

# Non-interactive mode
claude -p "explain this code"

# Continue previous session
claude -c
```

### 2. Session Management

```bash
# Named session
claude -n "feature-auth"

# Resume specific session
claude -r session-123

# Continue with new session name
claude -c -n "new-session-name"

# Fork new session
claude --fork-session -r session-123
```

### 3. Permission Control

```bash
# Read-only access
claude --allowed-tools Read

# Auto-accept edits
claude --permission-mode acceptEdits

# Whitelist mode
claude --allowed-tools "Read,Bash(git:*)"
```

### 4. Configuration

```bash
# Use config file
claude --settings ./config.json

# Load project config only
claude --setting-sources project

# Custom system prompt
claude --append-system-prompt "always respond in English"

# Load system prompt from file
claude --system-prompt-file ./system.md
```

### 5. Debugging

```bash
# Debug everything
claude --debug

# Debug specific modules
claude --debug hooks,settings

# Exclude specific modules
claude --debug "!file,!1p"

# Output to file
claude --debug-file /tmp/claude-debug.log
```

### 6. Advanced

```bash
# Git worktree
claude -w feature-x

# Specify model
claude --model opus

# High effort level
claude --effort max

# MCP config
claude --mcp-config ./mcp.json

# Limit spending
claude --max-budget-usd 5.0

# Thinking mode
claude --thinking enabled "analyze this code"

# Max turns
claude --print --max-turns 3 "execute task"
```

### 7. Custom Agent

```bash
# Use built-in agent
claude --agent reviewer "review code changes"

# Custom agent
claude --agents '{"myagent":{"description":"Custom agent","prompt":"You are..."}}'
```

### 8. Prefill and Partial Messages

```bash
# Prefill input
claude --prefill "code review completed"

# Include partial messages (stream-json)
claude --print --output-format stream-json --include-partial-messages "analyze"
```

---

## Environment Variables

### Authentication

```bash
export ANTHROPIC_API_KEY="sk-ant-..."
export ANTHROPIC_AUTH_TOKEN="..."
export ANTHROPIC_BASE_URL="https://api.anthropic.com"
```

### Debugging

```bash
export CLAUDE_DEBUG=1
export CLAUDE_DEBUG_FILTER="hooks"
```

### Proxy

```bash
export HTTP_PROXY="http://proxy:8080"
export HTTPS_PROXY="http://proxy:8080"
```

### Other

```bash
export CLAUDE_CODE_SIMPLE=1          # Minimal mode
export CLAUDE_CODE_DISABLE_TERMINAL_TITLE=1  # Disable terminal title changes
```
