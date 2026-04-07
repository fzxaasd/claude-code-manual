# Server, Remote, and Coordinator Systems

> Complete analysis based on source code from `src/server/`, `src/remote/`, `src/coordinator/`

---

## Direct Connect Server (`src/server/`)

### Overview

The Server system implements a local HTTP server for direct connections.

### ServerConfig

```typescript
interface ServerConfig {
  idleTimeoutMs: number    // Idle timeout in milliseconds, 0=never expires
  maxSessions: number     // Maximum concurrent sessions
  workspace: string       // Default working directory
}
```

**Note**: `sessionKey` is not part of ServerConfig; it belongs to the SessionInfo type.

### API Endpoints

#### POST /sessions - Create Session

**Request body**:
```json
{
  "cwd": "string",
  "dangerously_skip_permissions": true
}
```

**Response**:
```json
{
  "session_id": "string",
  "ws_url": "string",
  "work_dir": "string"
}
```

### Session Persistence

Session index is persisted to `~/.claude/server-sessions.json`:

```typescript
interface SessionIndexEntry {
  sessionId: string
  transcriptSessionId: string
  cwd: string
  permissionMode?: string
  createdAt: number
  lastActiveAt: number
}
```

### DirectConnectSessionManager

**Undocumented methods**:
- `sendInterrupt()` - Send an interrupt signal
- `sendErrorResponse(requestId, error)` - Error handling

**Control request subtypes**:
- `can_use_tool` - Permission request
- `interrupt` - Cancel current operation
- `error` - Error response

---

## Remote Session System (`src/remote/`)

### RemoteSessionConfig

```typescript
interface RemoteSessionConfig {
  viewerOnly?: boolean     // View-only mode, no interrupts
  hasInitialPrompt?: boolean
}
```

### SessionsWebSocket

**WebSocket close codes**:
- `4001` - Session not found (retry 3 times)
- `4003` - Unauthorized (permanent rejection)

**Constants**:
```typescript
const RECONNECT_DELAY_MS = 2000
const MAX_RECONNECT_ATTEMPTS = 5
const PING_INTERVAL_MS = 30000
const MAX_SESSION_NOT_FOUND_RETRIES = 3
```

**Authentication**:
```
Authorization: Bearer {token}
anthropic-version: 2023-06-01
?organization_uuid=...
```

### Session Status

```typescript
type SessionStatus = 'requires_action' | 'running' | 'idle' | 'archived'
```

### SessionContext

```typescript
interface SessionContext {
  sources: SessionContextSource[]
  cwd: string
  outcomes: Outcome[] | null
  custom_system_prompt: string | null
  append_system_prompt: string | null
  model: string | null
  seed_bundle_file_id?: string
  github_pr?: { owner: string; repo: string; number: number }
  reuse_outcome_branches?: boolean
}
```

---

## Teleport API

### API Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/v1/session_ingress/session/{id}` | GET | Legacy session logs |
| `/v1/code/sessions/{id}/teleport-events` | GET | CCR v2 event stream (paginated) |
| `/v1/sessions/{id}/events` | PUT | Send events to session |
| `/v1/sessions/{id}` | PATCH | Update session title |
| `/v1/code/github/import-token` | POST | Import GitHub token |
| `/v1/environment_providers/cloud/create` | POST | Create default environment |

### GitHub Token Import

```typescript
class RedactedGithubToken {
  reveal(): string           // Get the original value
  toString(): string          // Returns "[REDACTED:gh-token]"
}

interface ImportTokenResult {
  github_username: string
}
```

---

## Coordinator System (`src/coordinator/`)

### Environment Variables

| Variable | Description |
|----------|-------------|
| `CLAUDE_CODE_COORDINATOR_MODE=1` | Enable Coordinator mode |
| `CLAUDE_CODE_SIMPLE=1` | Restrict Worker tools (only Bash/Read/Edit) |

### Internal Worker Tools

```typescript
const INTERNAL_WORKER_TOOLS = new Set([
  'TEAM_CREATE',
  'TEAM_DELETE',
  'SEND_MESSAGE',
  'SYNTHETIC_OUTPUT'
])
// These tools are unavailable to Workers in Coordinator mode
```

### Scratchpad Directory

Temporary directory for knowledge sharing between Workers:

```typescript
interface ScratchpadConfig {
  scratchpadDir?: string
}
```

Enabled via the `tengu_scratch` GrowthBook feature.

### Session Mode Switching

```typescript
function matchSessionMode(
  sessionMode: 'coordinator' | 'normal' | undefined
): string | undefined
```

Automatically switches Coordinator mode to match the restored session.

### Undocumented Functions

```typescript
getCoordinatorUserContext()    // Build Worker tool context
getCoordinatorSystemPrompt()    // Full Coordinator system prompt
isScratchpadGateEnabled()      // tengu_scratch GrowthBook gate
```

---

## CCR v2 Features

### CCR v2 Headers

```typescript
export const CCR_BYOC_BETA = 'ccr-byoc-2025-07-29'
```

### CCRClient Constants

```typescript
MAX_CONSECUTIVE_AUTH_FAILURES = 10  // Max auth failures before giving up
STREAM_EVENT_FLUSH_INTERVAL_MS = 100  // Text delta batching window
DEFAULT_HEARTBEAT_INTERVAL_MS = 20000  // CCRClient heartbeat
```

### EnvLessBridgeConfig

Configuration parameters for the v2 bridge:

```typescript
interface EnvLessBridgeConfig {
  init_retry_max_attempts: number      // Default 3
  init_retry_base_delay_ms: number   // Default 500
  init_retry_jitter_fraction: number  // Default 0.25
  init_retry_max_delay_ms: number     // Default 4000
  http_timeout_ms: number             // Default 10_000
  uuid_dedup_buffer_size: number      // Default 2000
  heartbeat_interval_ms: number        // Default 20_000
  heartbeat_jitter_fraction: number   // Default 0.1
  token_refresh_buffer_ms: number     // Default 300_000
  teardown_archive_timeout_ms: number  // Default 1500
  connect_timeout_ms: number          // Default 15_000
  min_version: string                 // Default '0.0.0'
  should_show_app_upgrade_message: boolean  // Default false
}
```

---

## Bridge Multi-Session

### Spawn Modes

```typescript
type SpawnMode = 'single-session' | 'worktree' | 'same-dir'
```

- `single-session`: Single session; bridge shuts down after completion
- `worktree`: Persistent; each session gets an isolated git worktree
- `same-dir`: Persistent; all sessions share the same cwd

### Undocumented CLI Flags

```bash
--spawn <mode>          # Spawn mode
--capacity <N>          # Maximum concurrent sessions
--[no-]create-session-in-dir  # Pre-create session in cwd
-w                      # Toggle same-dir/worktree at runtime
--permission-mode <mode>  # Control spawned session permissions
```

### Session ID Compatibility

```typescript
toCompatSessionId(cse_* -> session_*)   // v1 compatible API
toInfraSessionId(session_* -> cse_*)    // Infrastructure layer
setCseShimGate()                        // Dynamic kill switch
```

---

## GrowthBook Features

| Feature | Description |
|---------|-------------|
| `tengu_scratch` | Worker Scratchpad directory |
| `tengu_amber_flint` | Agent teams kill switch |
| `tengu_ccr_bridge_multi_session` | Multiple sessions per environment |
| `tengu_ccr_bridge_multi_environment` | Multiple environments per host:dir |
| `tengu_bridge_initial_history_cap` | Max initial replay messages (default 200) |
| `tengu_cobalt_harbor` | CCR auto-connect default (ant-specific) |
| `tengu_cobalt_lantern` | Web settings availability |
| `tengu_sessions_elevated_auth_enforcement` | Trusted device tokens |

---

## Authentication Environment Variables

| Variable | Description |
|----------|-------------|
| `CLAUDE_CODE_OAUTH_REFRESH_TOKEN` | Skip browser OAuth (requires pre-existing refresh token) |
| `CLAUDE_CODE_OAUTH_SCOPES` | Used in conjunction with refresh token |
| `CLAUDE_TRUSTED_DEVICE_TOKEN` | Test override |

---

## FileIndex Fallback Implementation

`src/native-ts/file-index/index.ts` is a pure TypeScript fallback for the Rust NAPI module:

```typescript
class FileIndex {
  loadFromFileList(fileList: string[]): void

  loadFromFileListAsync(fileList: string[]): {
    queryable: Promise<void>  // Resolves after first chunk is indexed
    done: Promise<void>       // Resolves after fully built
  }

  search(query: string, limit: number): SearchResult[]
}

interface SearchResult {
  path: string
  score: number  // Lower is better
}
```

**Scoring rules**:
- Paths containing "test" receive a +1.05x penalty
- Top-level cache: 100 entries
- Chunk size: 4ms (async indexing)
