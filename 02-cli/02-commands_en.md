# 2.2 CLI Subcommands Reference

> Complete reference for Claude Code CLI subcommands. **Note**: Claude Code has two types of commands:
> 1. **CLI Subcommands** - Executed directly in the terminal, e.g., `claude mcp list`
> 2. **REPL Slash Commands** - Entered in Claude Code session, e.g., `/mcp`

---

## Actual CLI Subcommands

### `claude mcp` - MCP Server Management

```bash
# List MCP servers
claude mcp list

# Add a server
claude mcp add github --command "npx @modelcontextprotocol/server-github"

# Import from Claude Desktop
claude mcp add-from-claude-desktop

# JSON add
claude mcp add-json <name> <json>

# Get server details
claude mcp get <name>

# Reset project choices
claude mcp reset-project-choices

# Remove server
claude mcp remove <name>

# Start Claude Code as MCP server
claude mcp serve
```

### `claude auth` - Authentication Management

```bash
# Start login flow
claude auth login

# Login with options
claude auth login --console
claude auth login --claudeai
claude auth login --email user@example.com
claude auth login --sso

# Check authentication status
claude auth status

# Logout
claude auth logout
```

### `claude plugin` / `claude plugins` - Plugin Management

```bash
# List installed plugins
claude plugin list
claude plugins list

# Validate plugin
claude plugin validate <path>

# View marketplace
claude plugin marketplace

# Install plugin
claude plugin install <plugin>

# Uninstall plugin
claude plugin uninstall <plugin>

# Update plugin
claude plugin update <plugin>

# Enable/disable plugin
claude plugin enable <plugin>
claude plugin disable <plugin>
claude plugin disable --all
```

### `claude agents` - Agent Management

```bash
# List available agents
claude agents list
```

### `claude doctor` - Health Check

```bash
# Run diagnostics
claude doctor
```

### `claude update` / `claude upgrade` - Update Check

```bash
# Check for updates
claude update

# Upgrade
claude upgrade
```

### `claude install` - Installation

```bash
# Install Claude Code
claude install
```

### `claude setup-token` - Token Setup

```bash
# Set API token
claude setup-token
```

---

## ANT-ONLY CLI Commands

The following commands are only available in ANT (Anthropic Team) environment:

### `claude up` - Environment Initialization

```bash
# Initialize environment
claude up
```

### `claude rollback` - Rollback

```bash
# Rollback version
claude rollback [target]
```

### `claude log` - Log Management

```bash
# View logs
claude log
```

### `claude error` - Error Logs

```bash
# View error logs
claude error
```

### `claude task` - Task Management

```bash
# Task management
claude task
```

### `claude completion` - Shell Completion

```bash
# Generate completion script
claude completion bash
claude completion zsh
claude completion fish
```

---

## Feature-Gated CLI Commands

The following commands require specific feature flags:

### `claude server` - Direct Connection (DIRECT_CONNECT)

```bash
# Direct connection
claude server
```

### `claude ssh` - SSH Remote (SSH_REMOTE)

```bash
# SSH remote connection
claude ssh <host> [dir]
```

### `claude open` - Open Claude.ai Session (DIRECT_CONNECT)

```bash
# Open Claude.ai session
claude open <cc-url>
```

### `claude remote-control` / `claude rc` - Remote Control (BRIDGE_MODE)

```bash
# Remote control
claude remote-control [name]
claude rc [name]
```

### `claude assistant` - Assistant Mode (KAIROS)

```bash
# Start assistant
claude assistant [sessionId]
```

### `claude auto-mode` - Auto Mode Configuration (TRANSCRIPT_CLASSIFIER)

```bash
# Configure auto mode
claude auto-mode config
```

---

## Important Notes

### CLI vs REPL Command Differences

The following are **NOT CLI subcommands**, but **REPL slash commands** (entered in Claude Code session with `/command`):

| Falsely Listed as CLI | Correct Type | Actual Usage |
|----------------|----------|----------|
| `claude session` | REPL command | `/session` |
| `claude compact` | REPL command | `/compact` |
| `claude config` | REPL command | `/config` |
| `claude init` | REPL command | `/init` |
| `claude model` | REPL command | `/model` |
| `claude permissions` | REPL command | `/permissions` |
| `claude hooks` | REPL command | `/hooks` |
| `claude skills` | REPL command | `/skills` |
| `claude btw` | REPL command | `/btw` |
| `claude feedback` | REPL command | `/feedback` |
| `claude cost` | REPL command | `/cost` |
| `claude stats` | REPL command | `/stats` |
| `claude effort` | REPL command | `/effort` |
| `claude insights` | REPL command | `/insights` |
| `claude diff` | REPL command | `/diff` |
| `claude commit` | REPL command | `/commit` |
| `claude branch` | REPL command | `/branch` |
| `claude context` | REPL command | `/context` |
| `claude files` | REPL command | `/files` |
| `claude think-back` | REPL command | `/think-back` |
| `claude rewind` | REPL command | `/rewind` |
| `claude export` | REPL command | `/export` |
| `claude theme` | REPL command | `/theme` |
| `claude color` | REPL command | `/color` |
| `claude vim` | REPL command | `/vim` |
| `claude statusline` | REPL command | `/statusline` |
| `claude ide` | REPL command | `/ide` |
| `claude keybindings` | REPL command | `/keybindings` |
| `claude plan` | REPL command | `/plan` |
| `claude memory` | REPL command | `/memory` |
| `claude exit` | REPL command | `/exit` |

### Non-Existent Commands

The following commands do **NOT exist** in Claude Code:

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
