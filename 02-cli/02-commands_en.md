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

# Add server (stdio)
claude mcp add <name> <command> [args...]

# Add server (HTTP/SSE/WS)
claude mcp add <name> <url>

# Add server with OAuth/XAA
claude mcp add <name> <url> --xaa --client-id <id> --client-secret <secret>

# Import from Claude Desktop
claude mcp add-from-claude-desktop [--scope <scope>]

# JSON add
claude mcp add-json

# Get server details
claude mcp get <name>

# Reset project choices
claude mcp reset-project-choices

# Remove server
claude mcp remove <name> [--scope <scope>]

# XAA IdP management
claude mcp xaa setup --issuer <url> --client-id <id> [--client-secret] [--callback-port <port>]
claude mcp xaa login
claude mcp xaa show
claude mcp xaa clear

# Start Claude Code as MCP server
claude mcp serve [--debug] [--verbose]
```

**Note**:
- `claude mcp add`'s `<command>` is a **positional argument**, not `--command` option
- `--client-id`, `--client-secret`, `--callback-port`, `--xaa` only work for HTTP/SSE transports, ignored for stdio
- `--issuer` and `--client-id` are **required** for `mcp xaa setup`
- XAA is enabled via `CLAUDE_CODE_ENABLE_XAA=1` env var, not enterprise-only

**mcp xaa subcommands**:
- `xaa setup`: Configure XAA (SEP-990) IdP connection, one-time setup for all XAA servers
  - `--issuer` (required): IdP issuer URL
  - `--client-id` (required): OAuth client ID
  - `--client-secret` (optional): OAuth client secret, read from env var if not provided
  - `--callback-port` (optional): Fixed callback port
- `xaa login`: Login to IdP to get token
  - `--force`: Ignore cached id_token and re-login
  - `--id-token <jwt>`: Write prefetched id_token directly, skip OIDC browser login
- `xaa show`: Show current IdP configuration
- `xaa clear`: Clear IdP configuration and tokens

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

# Marketplace management
claude plugin marketplace add <source> [--sparse <paths...>] [--scope <scope>]
claude plugin marketplace list [--json]
claude plugin marketplace remove <name>
claude plugin marketplace remove <name>  # alias: rm
claude plugin marketplace update [name]

# Install plugin
claude plugin install <plugin>
claude plugin install <plugin> --scope <scope>

# Uninstall plugin
claude plugin uninstall <plugin>
claude plugin uninstall <plugin> --scope <scope> [--keep-data]

# Update plugin
claude plugin update <plugin>
claude plugin update <plugin> --scope <scope>

# Enable/disable plugin
claude plugin enable <plugin>
claude plugin disable <plugin>
claude plugin disable --all
```

**marketplace subcommands**:
- `marketplace add <source>`: Add marketplace from URL, path, or GitHub repo. Use `--sparse` for monorepos, `--scope` for config scope (user/project/local)
- `marketplace list`: List all configured marketplaces
- `marketplace remove <name>`: Remove configured marketplace
- `marketplace update [name]`: Update marketplace(s), updates all if no name specified

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
# Create task
claude task create <subject> [--description <text>] [--list <id>]

# List tasks
claude task list [--list <id>] [--pending] [--json]

# Get task details
claude task get <id> [--list <id>]

# Update task
claude task update <id> [--status <status>] [--subject <text>] [--description <text>] [--owner <agentId>] [--clear-owner]

# Show tasks directory
claude task dir [--list <id>]
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
# Show effective config
claude auto-mode config

# Show default rules (JSON format)
claude auto-mode defaults

# Get AI feedback on custom rules
claude auto-mode critique [--model <model>]
```

---

## Undocumented Subcommand Options

> The following options exist in source code but are not documented officially

### `claude server` - Direct Connect Options

| Option | Type | Description |
|------|------|------|
| `--port <number>` | string | HTTP port, default '0' |
| `--host <string>` | string | Bind address, default '0.0.0.0' |
| `--auth-token <token>` | string | Bearer token for authentication |
| `--unix <path>` | string | Listen on Unix domain socket |
| `--workspace <dir>` | string | Default working directory for sessions without cwd |
| `--idle-timeout <ms>` | string | Idle timeout in ms for detached sessions, default '600000' |
| `--max-sessions <n>` | string | Max concurrent sessions, default '32' |

### `claude ssh` - SSH Remote Options

| Option | Type | Description |
|------|------|------|
| `--permission-mode <mode>` | string | Permission mode for remote session |
| `--dangerously-skip-permissions` | boolean | Skip all remote permission prompts (dangerous) |
| `--local` | boolean | e2e test mode - spawn sub-CLI locally (skip ssh/deploy) |

### `claude rollback` - Rollback Options

| Option | Type | Description |
|------|------|------|
| `-l, --list` | boolean | List recent releases with timestamps |
| `--dry-run` | boolean | Show what would be installed without installing |
| `--safe` | boolean | Roll back to server-pinned safe version |

### `claude completion` - Completion Options

| Option | Type | Description |
|------|------|------|
| `--output <file>` | string | Write directly to file instead of stdout |

### `claude mcp` - MCP Options

| Command | Option | Type | Description |
|------|------|------|------|
| `mcp serve` | `--verbose` | boolean | Override config verbose mode setting |
| `mcp add` | `--xaa` | boolean | Enable XAA (SEP-990) for this server, requires `claude mcp xaa setup` first |
| `mcp xaa login` | `--force` | boolean | Ignore cached id_token and re-login |
| `mcp xaa login` | `--id-token <jwt>` | string | Write prefetched id_token directly, skip OIDC browser login |

### Cowork Options (Hidden)

All plugin and marketplace subcommands support `--cowork` parameter to use `cowork_plugins` directory:

| Command | Description |
|------|------|
| `plugin validate --cowork` | Validate using cowork_plugins directory |
| `plugin list --cowork` | List using cowork_plugins directory |
| `plugin install --cowork` | Install using cowork_plugins directory |
| `plugin uninstall --cowork` | Uninstall using cowork_plugins directory |
| `plugin enable --cowork` | Enable using cowork_plugins directory |
| `plugin disable --cowork` | Disable using cowork_plugins directory |
| `plugin update --cowork` | Update using cowork_plugins directory |
| `marketplace add --cowork` | Add using cowork_plugins directory |
| `marketplace list --cowork` | List using cowork_plugins directory |
| `marketplace remove --cowork` | Remove using cowork_plugins directory |
| `marketplace update --cowork` | Update using cowork_plugins directory |

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

### Missing CLI Subcommands

The following commands **exist in source code** but are not documented in the detailed command list above:

| Command | Description | Feature Gate |
|------|------|--------------|
| `claude login` | Login to Anthropic account | - |
| `claude logout` | Logout | - |
| `claude install-github-app` | Setup Claude GitHub Actions | - |
| `claude install-slack-app` | Install Claude Slack app | - |
| `claude usage` | View usage limits | - |
| `claude privacy-settings` | View/update privacy settings | - |
| `claude release-notes` | View release notes | - |
| `claude stickers` | Order Claude Code stickers | - |
| `claude mobile` (aliases: `ios`, `android`) | Show mobile app QR code | - |
| `claude resume` (alias: `continue`) | Resume previous session | - |
| `claude rename` | Rename current session | - |
| `claude tasks` (alias: `bashes`) | List and manage background tasks | - |
| `claude agents` | Manage Agent configurations | - |
| `claude memory` | Edit Claude memory files | - |
| `claude skills` | List available skills | - |
| `claude status` | Show Claude Code status | - |
| `claude terminal-setup` | Terminal keybinding setup | - |
| `claude reload-plugins` | Activate pending plugin changes | - |
| `claude remote-env` | Configure remote environment | - |
| `claude env` | ANT only: Environment info | `USER_TYPE === 'ant'` |
| `claude chrome` | Claude in Chrome setup | Beta |
| `claude pr-comments` | Fetch GitHub PR comments | - |
| `claude tag` | Toggle session tags | `USER_TYPE === 'ant'` |
| `claude files` | List context files | `USER_TYPE === 'ant'` |
| `claude summary` | Summarize session | - |
| `claude thinkback` | Claude Code year in review | - |
| `claude teleport` | Remote session navigation | - |
| `claude sandbox-toggle` | Sandbox config toggle | - |
| `claude rate-limit-options` | Rate limit options (hidden) | Hidden |
| `claude heapdump` | Dump JS heap to desktop (hidden) | `isHidden: true` |
| `claude thinkback-play` | Play thinkback animation (hidden) | `isHidden: true` |
| `claude output-style` | Output style config (deprecated, hidden) | `isHidden: true` |

### Command Aliases

The following aliases are not documented in the detailed sections:

| Command | Aliases | Documentation Status |
|------|------|----------|
| `/clear` | `reset`, `new` | Only `clear` |
| `/exit` | `quit` | Only `exit` |
| `/session` | `remote` | Undocumented |
| `/config` | `settings` | Undocumented |
| `/permissions` | `allowed-tools` | Undocumented |
| `/desktop` | `app` | Undocumented |
| `/feedback` | `bug` | Undocumented |
| `/rewind` | `checkpoint` | Undocumented |
| `/branch` | `fork` | Undocumented |

### Feature-Gated Commands

The following commands require specific features to be enabled:

| Command | Feature Gate | Description |
|------|-------------|------|
| `/proactive` | `PROACTIVE` or `KAIROS` | Proactive mode |
| `/brief` | `KAIROS` or `KAIROS_BRIEF` | Brief mode |
| `/assistant` | `KAIROS` | Kairos assistant mode |
| `/voice` | `VOICE_MODE` | Voice mode toggle |
| `/workflows` | `WORKFLOW_SCRIPTS` | Workflow scripts |
| `/web-setup` | `CCR_REMOTE_SETUP` | Web setup |
| `/peers` | `UDS_INBOX` | Peer node commands |
| `/fork` | `FORK_SUBAGENT` | Fork sub-agent |
| `/buddy` | `BUDDY` | Buddy desktop companion |
| `/subscribe-pr` | `KAIROS_GITHUB_WEBHOOKS` | Subscribe to PR |
| `/ultraplan` | `ULTRAPLAN` | Ultra plan mode |
| `/torch` | `TORCH` | Torch mode |
| `/remote-control` (alias: `rc`) | `BRIDGE_MODE` | Remote control |
| `/backfill-sessions` | `USER_TYPE === 'ant'` | Backfill session data |
| `/bughunter` | `USER_TYPE === 'ant'` | Bug hunter tool |
| `/commit` | `USER_TYPE === 'ant'` | Git commit |
| `/commit-push-pr` | `USER_TYPE === 'ant'` | Commit, push and create PR |
| `/ctx_viz` | `USER_TYPE === 'ant'` | Context visualization |
| `/autofix-pr` | `KAIROS_GITHUB_WEBHOOKS` | Auto-fix PR |
| `/init-verifiers` | `USER_TYPE === 'ant'` | Create verifier skills |
| `/version` | `USER_TYPE === 'ant'` | Print version |

### MCP Subcommands Supplement

The following MCP subcommands are not documented in the detailed sections above:

| Subcommand | Description |
|--------|------|
| `claude mcp reconnect <server>` | Reconnect specified MCP server |
| `claude mcp enable [server-name]` | Enable MCP server |
| `claude mcp disable [server-name]` | Disable MCP server |
| `claude mcp no-redirect` | Test mode (no redirect) |
| `mcp add --header <header>` | Add custom HTTP header |
| `mcp add --transport <type>` | Specify transport type |

### CLI Entry Points (Non-REPL Commands)

The following commands are handled as CLI arguments in `main.tsx`, not slash commands:

| Command | Description | Feature Gate |
|------|------|--------------|
| `claude ssh <host> [dir]` | SSH remote session | `SSH_REMOTE` |
| `claude open <cc-url>` | Open CCR session | `DIRECT_CONNECT` |
| `claude assistant [sessionId]` | Kairos assistant | `KAIROS` |

### Environment Variable Controlled Commands

The following commands can be disabled via environment variables:

| Command | Environment Variable |
|------|----------|
| `login` | `DISABLE_LOGIN_COMMAND` |
| `logout` | `DISABLE_LOGOUT_COMMAND` |
| `install-github-app` | `DISABLE_INSTALL_GITHUB_APP_COMMAND` |
| `feedback` | `DISABLE_FEEDBACK_COMMAND`, `DISABLE_BUG_COMMAND` |
| `extra-usage` | `DISABLE_EXTRA_USAGE_COMMAND` |
| `compact` | `DISABLE_COMPACT` |
| `upgrade` | `DISABLE_UPGRADE_COMMAND` |
