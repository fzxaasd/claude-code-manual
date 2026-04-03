# Claude Code Setup Initialization Flow

> Complete analysis based on source code `src/setup.ts`, `src/init.ts`, `src/bootstrap/`

---

## Overview

Claude Code executes a complex initialization flow on startup, involving configuration loading, environment checks, and background task launches.

**18 undocumented initialization behaviors.**

---

## setup() Function Execution Order

### 1. Node.js Version Check

```typescript
// src/setup.ts
require('node:version')
// Minimum requirement: Node.js >= 18
// Exits with error if not met
```

### 2. Custom Session ID

Set session ID via `--session-id` flag:

```bash
claude --session-id <uuid>
```

### 3. UDS Message Server

Enabled via `feature('UDS_INBOX')`:

```typescript
// Creates Unix Domain Socket for inter-process communication
// Default location: /tmpdir
// Can be overridden via `--messaging-socket-path`
export CLAUDE_CODE_MESSAGING_SOCKET
```

### 4. Teammate Snapshot

Captures teammate mode state for Agent Swarm:

```typescript
// Saves current state snapshot of teammate mode
snapshotTeammateState()
```

### 5. iTerm2/Terminal.app Backup Restoration

Automatically restores original settings if Claude Code was interrupted during terminal configuration:

```typescript
// Interactive sessions only
if (isInteractive) {
  restoreITerm2Backup()
  restoreTerminalAppBackup()
}
```

### 6. CWD Initialization

```typescript
setCwd()
// Ensures working directory is correctly set
```

### 7. Hooks Configuration Snapshot

Captures hook configuration for tampering detection:

```typescript
snapshotHooksConfig()
// Stores current hooks configuration for subsequent verification
```

### 7. FileChanged Watcher

Initializes filesystem watcher:

```typescript
initFileChangedWatcher()
// Monitors file change events
```

### 8. Git Worktree Creation

If using `--worktree` flag:

```bash
claude --worktree --tmux
# Creates worktree first, then starts tmux session
```

### 9. Background Job Startup

| Background Task | Description |
|----------|------|
| Session Memory | Session memory management |
| Context Collapse | Context compression |
| Plugin Hooks | Plugin hooks |
| Attribution Hooks | Attribution hooks |
| Team Memory Sync | Team memory synchronization |

### 10. Sinks Initialization

Initializes analytics/error logging sinks:

```typescript
initSinks()
// Sets up log output destinations
```

### 11. Release Notes Check

Interactive sessions only:

```typescript
// Skip condition: --bare flag
// Fetches Logo v2 campaign information
fetchReleaseNotes()
```

### 12. Permission Mode Bypass Verification

Security checks for `--dangerously-skip-permissions` flag:

```typescript
// Root/Sudo guard
if (isRunningAsRoot() && !IS_SANDBOX && !CLAUDE_CODE_BUBBLEWRAP) {
  refuseToRun()
}

// Docker/Sandbox guard
if (process.env.USER_TYPE === 'ant' && isDocker() && hasNoInternet()) {
  // Bypass allowed
}
```

### 13. `tengu_exit` Event

Logs previous session statistics on startup:

```typescript
logEvent('tengu_exit', {
  // Previous session statistics
})
```

### 14. UpstreamProxy Initialization

CCR environment only (`CLAUDE_CODE_REMOTE`):

```typescript
if (process.env.CLAUDE_CODE_REMOTE) {
  initUpstreamProxy()
}
```

### 15. Startup Profiler Checkpoints

Extensive `profileCheckpoint()` calls for startup performance measurement:

```
setup_start
setup_node_version_check
setup_config_load
setup_env_vars
setup_proxy_mtls
setup_remote_managed_settings
setup_opentelemetry
setup_graceful_shutdown
setup_scratchpad
```

---

## --bare Mode

`--bare` skips the following:

- Hooks loading
- LSP initialization
- Plugin sync
- Attribution
- Auto memory
- Background prefetch
- Keychain reading
- CLAUDE.md auto-discovery
- Release notes check

---

## Environment Variables

| Variable | Description |
|------|------|
| `CLAUDE_CODE_EXIT_AFTER_FIRST_RENDER` | Skips all background prefetch (startup performance measurement) |
| `CLAUDE_CODE_REMOTE` | Triggers UpstreamProxy initialization |
| `COREPACK_ENABLE_AUTO_PIN` | Set to `0` to prevent corepack from adding yarnpkg |
| `IS_SANDBOX` | Sandbox detection |
| `CLAUDE_CODE_BUBBLEWRAP` | Bubblewrap detection |
| `USER_TYPE` | `"ant"` or `"external"` — determines access to ant internal features |
| `NODE_ENV` | Skips setup() permission checks when set to `"test"` |

---

## Migration System

11 sequential migrations run at startup:

```typescript
const CURRENT_MIGRATION_VERSION = 11

runMigrations()
// Executes migration_001 through migration_011 in order
```

---

## Deferred Prefetches

Prefetch after rendering:

```typescript
startDeferredPrefetches()
// Includes:
// - initUser
// - getUserContext
// - getRelevantTips
// - AWS/GCP credential prefetch
// - File count
// - GrowthBook
// - Model capabilities
```

### prefetchSystemContextIfSafe()

Skips git context prefetch only after trust is established:

```typescript
prefetchSystemContextIfSafe()
// Non-interactive or trusted → prefetch immediately
// Interactive and untrusted → defer until trust is established
```

---

## Beta Headers

Complete list of Beta Headers (`src/constants/betas.ts`):

| Header | Value | Feature Gate |
|--------|-----|--------------|
| `CLAUDE_CODE_20250219_BETA_HEADER` | `claude-code-20250219` | - |
| `INTERLEAVED_THINKING_BETA_HEADER` | `interleaved-thinking-2025-05-14` | - |
| `CONTEXT_1M_BETA_HEADER` | `context-1m-2025-08-07` | - |
| `CONTEXT_MANAGEMENT_BETA_HEADER` | `context-management-2025-06-27` | - |
| `STRUCTURED_OUTPUTS_BETA_HEADER` | `structured-outputs-2025-12-15` | - |
| `WEB_SEARCH_BETA_HEADER` | `web-search-2025-03-05` | - |
| `TOOL_SEARCH_BETA_HEADER_1P` | `advanced-tool-use-2025-11-20` | Claude API / Foundry |
| `TOOL_SEARCH_BETA_HEADER_3P` | `tool-search-tool-2025-10-19` | Vertex AI / Bedrock |
| `EFFORT_BETA_HEADER` | `effort-2025-11-24` | - |
| `TASK_BUDGETS_BETA_HEADER` | `task-budgets-2026-03-13` | - |
| `PROMPT_CACHING_SCOPE_BETA_HEADER` | `prompt-caching-scope-2026-01-05` | - |
| `FAST_MODE_BETA_HEADER` | `fast-mode-2026-02-01` | - |
| `REDACT_THINKING_BETA_HEADER` | `redact-thinking-2026-02-12` | - |
| `TOKEN_EFFICIENT_TOOLS_BETA_HEADER` | `token-efficient-tools-2026-03-28` | - |
| `SUMMARIZE_CONNECTOR_TEXT_BETA_HEADER` | `summarize-connector-text-2026-03-13` | `feature('CONNECTOR_TEXT')` |
| `AFK_MODE_BETA_HEADER` | `afk-mode-2026-01-31` | `feature('TRANSCRIPT_CLASSIFIER')` |
| `CLI_INTERNAL_BETA_HEADER` | `cli-internal-2026-02-09` | `USER_TYPE === 'ant'` |
| `ADVISOR_BETA_HEADER` | `advisor-tool-2026-03-01` | - |

### Bedrock-Specific Headers

These headers are placed in `extraBodyParams` (not headers):

```typescript
const BEDROCK_EXTRA_PARAMS_HEADERS = [
  INTERLEAVED_THINKING_BETA_HEADER,
  CONTEXT_1M_BETA_HEADER,
  TOOL_SEARCH_BETA_HEADER_3P
]
```

### Vertex Allowlist

Beta headers allowed for Vertex `countTokens` API:

```typescript
const VERTEX_COUNT_TOKENS_ALLOWED_BETAS = [
  CLAUDE_CODE_20250219_BETA_HEADER,
  INTERLEAVED_THINKING_BETA_HEADER,
  CONTEXT_MANAGEMENT_BETA_HEADER
]
```

---

## Feature Flags

Features enabled via `feature('NAME')`:

| Feature | Location | Description |
|---------|------|------|
| `UDS_INBOX` | setup.ts | Starts UDS message server |
| `DUMP_SYSTEM_PROMPT` | cli.tsx | `--dump-system-prompt` fast path |
| `CHICAGO_MCP` | cli.tsx | `--computer-use-mcp` fast path |
| `DAEMON` | cli.tsx | `--daemon-worker` and `daemon` subcommand |
| `BRIDGE_MODE` | cli.tsx | `remote-control`/`bridge`/`sync`/`rc` |
| `BG_SESSIONS` | cli.tsx | `ps`/`logs`/`attach`/`kill`/`--bg` |
| `TEMPLATES` | cli.tsx | `new`/`list`/`reply` template commands |
| `LODESTONE` | cli.tsx | `--handle-uri` and macOS URL handling |
| `KAIROS` | cli.tsx | `assistant` mode |
| `SSH_REMOTE` | cli.tsx | `ssh` subcommand |
| `DIRECT_CONNECT` | cli.tsx | `server` and `open` subcommands |
| `TRANSCRIPT_CLASSIFIER` | cli.tsx | Auto Mode (AFK) |
| `CONTEXT_COLLAPSE` | cli.tsx | Context compression service |

---

## CLI Entry Point Differences

| Entry Point | File | Characteristics |
|--------|------|------|
| CLI (main.tsx) | main.tsx | Full REPL |
| MCP (mcp.ts) | mcp.ts | Built-in tools only, no MCP tools |
| SDK | agentSdkTypes.ts | SDKMessage streaming |
