# 7.8 Bridge/Remote Control System

> Claude Code Remote Control (Remote Control / CCR) core system documentation

## Overview

The Bridge system is the core mechanism for communication between Claude Code and the claude.ai Remote Control service. It enables local Claude Code sessions to be controlled and observed by remote users via the claude.ai interface. Source code is located in the `src/bridge/` directory.

**Note**: This system is unrelated to IDE integration (no VS Code Extension API), primarily serving remote session control scenarios.

```
┌─────────────────────────────────────────────────────────────┐
│                    CCR System Architecture                   │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  claude.ai Web Interface (Remote Control)                   │
│              │                                              │
│              │ WebSocket / SSE                              │
│              ↓                                              │
│  ┌─────────────────────────────────────────────────────┐   │
│  │           Bridge (src/bridge/)                      │   │
│  │  ┌─────────────┐  ┌──────────────┐  ┌────────────┐ │   │
│  │  │ replBridge  │  │ bridgeMain   │  │ initRepl   │ │   │
│  │  │ (v1 env-    │  │ (CLI entry)   │  │ Bridge     │ │   │
│  │  │  based)      │  │              │  │ (v2 env-   │ │   │
│  │  └─────────────┘  └──────────────┘  │  less)      │ │   │
│  │                                      └────────────┘ │   │
│  └─────────────────────────────────────────────────────┘   │
│              │                                              │
│              ↓                                              │
│  Claude Code (local session)                               │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

## Core Types

### BridgeConfig

Based on `src/bridge/types.ts`:

```typescript
export type BridgeConfig = {
  dir: string
  machineName: string
  branch: string
  gitRepoUrl: string | null
  maxSessions: number
  spawnMode: SpawnMode
  verbose: boolean
  sandbox: boolean
  /** Client-generated UUID identifying this bridge instance. */
  bridgeId: string
  /** Sent as metadata.worker_type so web clients can filter by origin. */
  workerType: string
  /** Client-generated UUID for idempotent environment registration. */
  environmentId: string
  /** Backend-issued environment_id to reuse on re-register. */
  reuseEnvironmentId?: string
  /** API base URL the bridge is connected to (used for polling). */
  apiBaseUrl: string
  /** Session ingress base URL for WebSocket connections. */
  sessionIngressUrl: string
  /** Debug file path passed via --debug-file. */
  debugFile?: string
  /** Per-session timeout in milliseconds. */
  sessionTimeoutMs?: number
}
```

### SpawnMode

Session working directory selection mode:

```typescript
export type SpawnMode = 'single-session' | 'worktree' | 'same-dir'
```

- `single-session`: Run single session in cwd, bridge destroyed when session ends
- `worktree`: Persistent server, each session gets isolated git worktree
- `same-dir`: Persistent server, each session shares cwd (may overwrite each other)

### BridgeWorkerType

```typescript
export type BridgeWorkerType = 'claude_code' | 'claude_code_assistant'
```

Sent to server as `metadata.worker_type`, allowing web clients to filter by origin.

### BridgeApiClient

Bridge API client interface:

```typescript
export type BridgeApiClient = {
  registerBridgeEnvironment(config: BridgeConfig): Promise<{
    environment_id: string
    environment_secret: string
  }>
  pollForWork(
    environmentId: string,
    environmentSecret: string,
    signal?: AbortSignal,
    reclaimOlderThanMs?: number,
  ): Promise<WorkResponse | null>
  acknowledgeWork(
    environmentId: string,
    workId: string,
    sessionToken: string,
  ): Promise<void>
  stopWork(environmentId: string, workId: string, force: boolean): Promise<void>
  deregisterEnvironment(environmentId: string): Promise<void>
  sendPermissionResponseEvent(
    sessionId: string,
    event: PermissionResponseEvent,
    sessionToken: string,
  ): Promise<void>
  archiveSession(sessionId: string): Promise<void>
  reconnectSession(environmentId: string, sessionId: string): Promise<void>
  heartbeatWork(
    environmentId: string,
    workId: string,
    sessionToken: string,
  ): Promise<{
    lease_extended: boolean
    state: string
    last_heartbeat: string    // ISO timestamp
    ttl_seconds: number       // remaining TTL
  }>
}
```

### SessionHandle

Session handle:

```typescript
export type SessionHandle = {
  sessionId: string
  done: Promise<SessionDoneStatus>
  kill(): void
  forceKill(): void
  activities: SessionActivity[]     // Ring buffer of recent activities
  currentActivity: SessionActivity | null
  accessToken: string                // session_ingress_token
  lastStderr: string[]              // Last few lines of stderr
  writeStdin(data: string): void
  updateAccessToken(token: string): void
}
```

### WorkSecret

Work secret from server:

```typescript
export type WorkSecret = {
  version: number
  session_ingress_token: string
  api_base_url: string
  sources: Array<{
    type: string
    git_info?: { type: string; repo: string; ref?: string; token?: string }
  }>
  auth: Array<{ type: string; token: string }>
  claude_code_args?: Record<string, string> | null
  mcp_config?: unknown | null
  environment_variables?: Record<string, string> | null
  /** Server-driven CCR v2 selector (ccr_v2_compat_enabled). */
  use_code_sessions?: boolean
}
```

---

## Feature Flags

### isBridgeEnabled()

Runtime check for bridge mode authorization.

```typescript
export function isBridgeEnabled(): boolean
```

- Requires `feature('BRIDGE_MODE')` build flag
- Requires `isClaudeAISubscriber()` (excludes Bedrock/Vertex/Foundry/apiKey)
- Requires GrowthBook gate `tengu_ccr_bridge` to be true

### isBridgeEnabledBlocking()

Blocking authorization check (used for permission gating).

```typescript
export async function isBridgeEnabledBlocking(): Promise<boolean>
```

Returns cached `true` (fast path), or waits for GrowthBook initialization to get latest value.

### isEnvLessBridgeEnabled()

Check v2 (env-less) REPL bridge path.

```typescript
export function isEnvLessBridgeEnabled(): boolean
```

GrowthBook flag: `tengu_bridge_repl_v2`

### isCcrMirrorEnabled()

CCR mirror mode switch - generates a send-only Remote Control session for each local session.

```typescript
export function isCcrMirrorEnabled(): boolean
```

- Requires `feature('CCR_MIRROR')` build flag
- Environment variable `CLAUDE_CODE_CCR_MIRROR` takes priority
- GrowthBook gate: `tengu_ccr_mirror`

### checkBridgeMinVersion()

v1 (env-based) Remote Control minimum version check.

```typescript
export function checkBridgeMinVersion(): string | null
```

GrowthBook config: `tengu_bridge_min_version`

---

## EnvLessBridgeConfig (v2)

v2 bridge configuration parameters based on `src/bridge/envLessBridgeConfig.ts`:

```typescript
export type EnvLessBridgeConfig = {
  // init-phase retry configuration
  init_retry_max_attempts: number   // Default: 3
  init_retry_base_delay_ms: number   // Default: 500
  init_retry_jitter_fraction: number // Default: 0.25
  init_retry_max_delay_ms: number    // Default: 4000

  // HTTP timeout (POST /sessions, POST /bridge, POST /archive)
  http_timeout_ms: number           // Default: 10_000

  // UUID dedup buffer size
  uuid_dedup_buffer_size: number     // Default: 2000

  // CCRClient heartbeat interval (server TTL 60s)
  heartbeat_interval_ms: number      // Default: 20_000
  heartbeat_jitter_fraction: number  // Default: 0.1

  // JWT refresh buffer
  token_refresh_buffer_ms: number   // Default: 300_000

  // teardown() archive timeout (separate from http_timeout_ms)
  teardown_archive_timeout_ms: number // Default: 1500

  // onConnect timeout after transport.connect()
  connect_timeout_ms: number         // Default: 15_000

  // Minimum version requirement
  min_version: string                // Default: '0.0.0'

  // Whether to prompt user to upgrade claude.ai app
  should_show_app_upgrade_message: boolean // Default: false
}
```

GrowthBook feature key: `tengu_bridge_repl_v2_config`

---

## Environment Variables

### Ant-only Development Overrides (src/bridge/bridgeConfig.ts)

| Variable | Description |
|------|------|
| `CLAUDE_BRIDGE_OAUTH_TOKEN` | Ant-only: Override OAuth token |
| `CLAUDE_BRIDGE_BASE_URL` | Ant-only: Override API base URL |
| `CLAUDE_BRIDGE_SESSION_INGRESS_URL` | Ant-only: Override session ingress URL |

### CCR v2 Related

| Variable | Description |
|------|------|
| `CLAUDE_BRIDGE_USE_CCR_V2` | Force enable CCR v2 (env-less bridge) |

### CCR Mirror

| Variable | Description |
|------|------|
| `CLAUDE_CODE_CCR_MIRROR` | Enable CCR mirror mode |

---

## File Inventory (33 files)

```
src/bridge/
├── bridgeApi.ts              # Bridge API implementation
├── bridgeConfig.ts          # Bridge auth/URL parsing, ant-only overrides
├── bridgeDebug.ts           # Bridge debugging tools
├── bridgeEnabled.ts         # Feature flags (isBridgeEnabled, etc.)
├── bridgeMain.ts            # CLI entry /remote-control command implementation
├── bridgeMessaging.ts       # Bridge message protocol
├── bridgePermissionCallbacks.ts  # Bridge permission callbacks
├── bridgePointer.ts         # Bridge pointer operations
├── bridgeStatusUtil.ts      # Bridge status utilities
├── bridgeUI.ts              # Bridge UI components
├── capacityWake.ts          # Capacity wake
├── codeSessionApi.ts        # Code session API
├── createSession.ts         # Session creation
├── debugUtils.ts            # Debugging utilities
├── envLessBridgeConfig.ts   # v2 EnvLessBridgeConfig
├── flushGate.ts             # Flush gating
├── inboundAttachments.ts    # Inbound attachment handling
├── inboundMessages.ts        # Inbound message handling
├── initReplBridge.ts        # REPL Bridge initialization (v2)
├── jwtUtils.ts              # JWT authentication utilities
├── pollConfig.ts            # Polling configuration
├── pollConfigDefaults.ts    # Polling configuration defaults
├── remoteBridgeCore.ts      # Remote Bridge core logic
├── replBridge.ts            # REPL Bridge implementation
├── replBridgeHandle.ts      # REPL Bridge handle
├── replBridgeTransport.ts   # REPL Bridge transport layer
├── sessionIdCompat.ts       # Session ID compatibility
├── sessionRunner.ts         # Session runner
├── trustedDevice.ts         # Trusted device management
├── types.ts                 # Core type definitions
└── workSecret.ts            # Work secret handling
```

---

## Session Lifecycle

### v1 (env-based) Path

```
1. Get WorkSecret (environment variable)
2. Start Claude Code subprocess
3. Communication:
   - Standalone bridge subprocess mode: via stdio
   - REPL bridge mode: when CLAUDE_BRIDGE_USE_CCR_V2 set, via CCR v2 transport (SSE + WS)
4. Session ends → archive
```

### v2 (env-less) Path

```
1. Build BridgeConfig
2. registerBridgeEnvironment() → get environment_id/secret
3. pollForWork() loop
4. Get WorkSecret then spawn session
5. Communicate via transport (WebSocket/SSE)
6. heartbeatWork() keep-alive
7. archiveSession() archive
```

---

## Authentication and Authorization

### Prerequisites

1. **Must use claude.ai login** - Requires OAuth token
   - Excludes: Bedrock/Vertex/Foundry, apiKey, Console API
2. **Requires user:profile scope** - setup-token and CLAUDE_CODE_OAUTH_TOKEN are not enough
3. **Organization policy check** - `isPolicyAllowed('allow_remote_control')` must allow
4. **GrowthBook gate** - `tengu_ccr_bridge` must be true

### getBridgeDisabledReason()

Get detailed disabled reason:

```typescript
export async function getBridgeDisabledReason(): Promise<string | null>
```

Check order: `BRIDGE_MODE` build flag → `isClaudeAISubscriber()` → `hasProfileScope()` → `organizationUuid` → GrowthBook gate

Possible return values:
- `"Remote Control requires a claude.ai subscription..."`
- `"Remote Control requires a full-scope login token..."`
- `"Unable to determine your organization..."` + suffix `Run \`claude auth login\` to refresh your account information`
- `"Remote Control is not yet enabled for your account."`
- `"Remote Control is not available in this build."`

---

## GrowthBook Feature Gates

| Feature Key | Type | Description |
|-------------|------|------|
| `tengu_ccr_bridge` | gate | Remote Control main switch |
| `tengu_bridge_repl_v2` | value | Enable v2 env-less bridge |
| `tengu_bridge_repl_v2_config` | config | v2 bridge detailed configuration (EnvLessBridgeConfig) |
| `tengu_bridge_repl_v2_cse_shim_enabled` | config | cse_* → session_* compatibility shim |
| `tengu_bridge_min_version` | config | v1 minimum version requirement |
| `tengu_bridge_poll_interval_config` | config | PollIntervalConfig polling parameters |
| `tengu_sessions_elevated_auth_enforcement` | gate | Trusted Device Token feature gate |
| `tengu_ccr_mirror` | value | CCR mirror mode |

---

## Trusted Device Token

Based on `src/bridge/trustedDevice.ts` - trusted device token mechanism:

### Overview

- **GrowthBook Gate**: `tengu_sessions_elevated_auth_enforcement`
- **Purpose**: Device registration authentication, token validity 90 days (server-side rolling expiration)

### Core API

```typescript
// Get token (for X-Trusted-Device-Token header)
export function getTrustedDeviceToken(): string | undefined

// Clear cache
export function clearTrustedDeviceTokenCache(): void

// Register device to server
export async function enrollTrustedDevice(): Promise<void>
```

### Token Acquisition Priority

```typescript
const readStoredToken = memoize((): string | undefined => {
  // 1. Environment variable takes priority
  const envToken = process.env.CLAUDE_TRUSTED_DEVICE_TOKEN
  if (envToken) {
    return envToken
  }
  // 2. macOS Keychain fallback
  return getSecureStorage().read()?.trustedDeviceToken
})
```

### Enrollment Flow

```typescript
async function enrollTrustedDevice(): Promise<void> {
  // POST /api/auth/trusted_devices
  // Request body: { display_name: "Claude Code on {hostname} · {platform}" }
  // Response: { device_token, device_id }
  // Token stored in Keychain
}
```

### Usage Example

```typescript
// in codeSessionApi.ts
export async function fetchRemoteCredentials(
  sessionId: string,
  baseUrl: string,
  accessToken: string,
  timeoutMs: number,
  trustedDeviceToken?: string,  // Optional parameter
): Promise<RemoteCredentials | null> {
  const headers = oauthHeaders(accessToken)
  if (trustedDeviceToken) {
    headers['X-Trusted-Device-Token'] = trustedDeviceToken
  }
  // ... POST /v1/code/sessions/{id}/bridge
}
```

---

## PollIntervalConfig

Based on `src/bridge/pollConfig.ts` and `src/bridge/pollConfigDefaults.ts` - polling configuration:

### Type Definition

```typescript
export type PollIntervalConfig = {
  poll_interval_ms_not_at_capacity: number           // Active polling interval
  poll_interval_ms_at_capacity: number               // Polling interval at capacity
  non_exclusive_heartbeat_interval_ms: number        // Non-exclusive heartbeat interval
  multisession_poll_interval_ms_not_at_capacity: number  // Multi-session: non-full
  multisession_poll_interval_ms_partial_capacity: number  // Multi-session: partial capacity
  multisession_poll_interval_ms_at_capacity: number     // Multi-session: at capacity
  reclaim_older_than_ms: number                      // Reclaim timeout threshold
  session_keepalive_interval_v2_ms: number            // Session-ingress keep-alive interval
}
```

### Default Values

| Parameter | Default | Description |
|-----------|---------|-------------|
| `poll_interval_ms_not_at_capacity` | `2000` | Active polling interval (ms) |
| `poll_interval_ms_at_capacity` | `600000` (10min) | Polling at capacity, 0=disabled |
| `non_exclusive_heartbeat_interval_ms` | `0` | Non-exclusive heartbeat interval |
| `multisession_poll_interval_ms_not_at_capacity` | `2000` | Multi-session: non-full |
| `multisession_poll_interval_ms_partial_capacity` | `2000` | Multi-session: partial capacity |
| `multisession_poll_interval_ms_at_capacity` | `600000` | Multi-session: at capacity |
| `reclaim_older_than_ms` | `5000` | Reclaim timeout threshold |
| `session_keepalive_interval_v2_ms` | `120000` (2min) | Session-ingress keep-alive frame interval |

### Configuration Source

- **GrowthBook feature**: `tengu_bridge_poll_interval_config`
- **Refresh interval**: 5 minutes (`5 * 60 * 1000`)
- **Fallback**: Zod schema validation failure → `DEFAULT_POLL_CONFIG`

```typescript
export function getPollIntervalConfig(): PollIntervalConfig {
  const raw = getFeatureValue_CACHED_WITH_REFRESH<unknown>(
    'tengu_bridge_poll_interval_config',
    DEFAULT_POLL_CONFIG,
    5 * 60 * 1000,
  )
  const parsed = pollIntervalConfigSchema().safeParse(raw)
  return parsed.success ? parsed.data : DEFAULT_POLL_CONFIG
}
```

---

## Transport Layer

Based on `src/bridge/replBridgeTransport.ts` and `src/cli/transports/` - transport layer implementation:

### Architecture Overview

```
Bridge Sessions
    │
    ├── v1: HybridTransport (WS read + HTTP POST write)
    │       └── WebSocketTransport (reconnect, ping/pong)
    │
    └── v2: SSETransport (SSE read) + CCRClient (HTTP write/heartbeat)
```

### v1 HybridTransport

```typescript
export class HybridTransport extends WebSocketTransport {
  // Write: WebSocket → SerialBatchEventUploader → HTTP POST
  // stream_event: 100ms buffer batch send
  // Other messages: direct enqueue
  
  // URL conversion
  // wss://api.example.com/v2/session_ingress/ws/<session_id>
  // → https://api.example.com/v2/session_ingress/session/<session_id>/events
}
```

### v2 SSETransport (Read)

```typescript
export class SSETransport implements Transport {
  // SSE → parseSSEFrames → onData callback
  // Auto reconnect: exponential backoff + jitter
  // Reconnect budget: 10 minutes (RECONNECT_GIVE_UP_MS = 600000)
  // Liveness detection: 45s no activity = disconnected (LIVENESS_TIMEOUT_MS)
  // Sequence number: Last-Event-ID for resume from checkpoint
}
```

### v2 CCRClient (Write + Heartbeat)

```typescript
export class CCRClient {
  // PUT /worker - worker state report
  // POST /worker/events - client events
  // POST /worker/heartbeat - heartbeat (default 20s, server TTL 60s)
  // POST /worker/events/delivery - delivery status
  
  // Epoch management: 409 = epoch mismatch → rebuild transport
  // Stream events: 100ms buffer + text_delta merge
}
```

### ReplBridgeTransport Interface

```typescript
export type ReplBridgeTransport = {
  write(message: StdoutMessage): Promise<void>
  writeBatch(messages: StdoutMessage[]): Promise<void>
  close(): void
  isConnectedStatus(): boolean
  getStateLabel(): string
  setOnData(callback: (data: string) => void): void
  setOnClose(callback: (closeCode?: number) => void): void
  setOnConnect(callback: () => void): void
  connect(): void
  getLastSequenceNum(): number  // v2 SSE sequence number
  reportState(state: SessionState): void
  reportDelivery(eventId: string, status: 'processing' | 'processed'): void
  flush(): Promise<void>
}
```

### Adapter Factory Functions

```typescript
// v1 adapter
export function createV1ReplTransport(hybrid: HybridTransport): ReplBridgeTransport

// v2 adapter
export async function createV2ReplTransport(opts: {
  sessionUrl: string
  ingressToken: string
  sessionId: string
  initialSequenceNum?: number
  epoch?: number
  heartbeatIntervalMs?: number
  heartbeatJitterFraction?: number
  outboundOnly?: boolean
  getAuthToken?: () => string | undefined
}): Promise<ReplBridgeTransport>
```

### Heartbeat and Reconnect Configuration

| Constant | Value | Description |
|----------|-------|-------------|
| `DEFAULT_HEARTBEAT_INTERVAL_MS` | `20000` | CCRClient default heartbeat interval |
| `MAX_CONSECUTIVE_AUTH_FAILURES` | `10` | Auth failure retries before giving up |
| `RECONNECT_BASE_DELAY_MS` | `1000` | WebSocket reconnect base delay |
| `RECONNECT_MAX_DELAY_MS` | `30000` | WebSocket reconnect max delay |
| `RECONNECT_GIVE_UP_MS` | `600000` | Reconnect give-up threshold (10 minutes) |
| `LIVENESS_TIMEOUT_MS` | `45000` | SSE inactivity disconnect threshold (45 seconds) |

### Epoch Management

- Epoch returned by server in `/sessions/{id}/bridge` response
- `409 Conflict` = Epoch mismatch → rebuild transport layer
- Client passes epoch for server-side validation

---

## Build Flags (Feature Flags)

| Flag | Description |
|------|------|
| `BRIDGE_MODE` | Enable Bridge functionality |
| `CCR_AUTO_CONNECT` | Ant-only: Auto-connect CCR |
| `CCR_MIRROR` | Enable CCR mirror mode |

---

## Status Constants

Based on `src/bridge/types.ts`:

```typescript
export const DEFAULT_SESSION_TIMEOUT_MS = 24 * 60 * 60 * 1000

export const BRIDGE_LOGIN_ERROR =
  'Error: You must be logged in to use Remote Control.\n\n' +
  'Remote Control is only available with claude.ai subscriptions...'

export const REMOTE_CONTROL_DISCONNECTED_MSG = 'Remote Control disconnected.'
```

---

## CLI Commands

### /remote-control

Main entry command, defined in `bridgeMain.ts`:

```bash
claude remote-control [options]

# Full help description
# Remote Control lets you access this CLI session from the web (claude.ai/code)
# or the Claude app, so you can pick up where you left off on any device.

Options:
  --session-id <id>    Resume specified session (alias: --continue)
  --name <name>        Specify session name
  --debug-file <path>  Debug log file path
```

---

## Bridge vs Remote System Differences

Two remote-related systems exist in the source code:

| Feature | Bridge (src/bridge/) | Remote (src/remote/) |
|---------|---------------------|---------------------|
| **Purpose** | CCR Remote Control (bridge) | Remote Session Manager |
| **Protocol** | SSE + HTTP PUT | WebSocket (`/v1/sessions/ws/{id}/subscribe`) |
| **Direction** | claude.ai → local REPL | Generic WebSocket session subscription |
| **Auth** | OAuth + Trusted Device Token | Token-based |
| **Entry** | `claude remote-control` | RemoteSessionManager |

### RemoteSessionManager Overview

Based on `src/remote/RemoteSessionManager.ts`:

```typescript
export class RemoteSessionManager {
  // WebSocket connection management
  subscribe(sessionId: string): Promise<void>
  unsubscribe(): void

  // Session status
  getStatus(): SessionStatus
  onStatusChange(callback: (status: SessionStatus) => void): void
}
```

**Use case**: Remote viewing/interacting with sessions via WebSocket subscription.

---

## Undocumented Features

### Undocumented GrowthBook Features

| Feature Key | Description |
|-------------|-------------|
| `tengu_bridge_initial_history_cap` | Max initial messages to replay (default 200) |
| `tengu_cobalt_harbor` | CCR auto-connect default (ant-only) |
| `tengu_ccr_bridge_multi_session` | Multiple sessions per environment |
| `tengu_ccr_bridge_multi_environment` | Multiple environments per host:dir |

### Undocumented Environment Variables

| Variable | Scope | Description |
|----------|-------|-------------|
| `CLAUDE_BRIDGE_SESSION_INGRESS_URL` | Ant-only | Override session ingress URL |
| `CLAUDE_CODE_SESSION_ACCESS_TOKEN` | Process-wide | Single-session OAuth token fallback |
| `CLAUDE_TRUSTED_DEVICE_TOKEN` | Testing | Override trusted device token |
| `CLAUDE_BRIDGE_USE_CCR_V2` | CCR v2 | Force CCR v2 transport in standalone bridge |

### heartbeatWork Response Fields

Undocumented response fields:
```typescript
{
  lease_extended: boolean,
  state: string,
  last_heartbeat: string,    // ISO timestamp
  ttl_seconds: number         // remaining TTL
}
```

### BridgeState Type

```typescript
export type BridgeState = 'ready' | 'connected' | 'reconnecting' | 'failed'
```

### Essential Traffic Check

Trusted Device Token enrollment is gated by `isEssentialTrafficOnly()` check - skips enrollment in essential traffic mode.

### Fault Injection System (Ant-only)

Development features for manually testing bridge recovery paths:
- `/bridge-kick <subcommand>` slash command
- `injectFault()` - Queue faults for testing
- `fireClose()` - Test ws_closed → reconnect escalation
- `forceReconnect()` - Trigger reconnectEnvironmentWithSession

### Session ID Compatibility Layer

```typescript
toCompatSessionId(cse_* → session_*)  // v1 compat API
toInfraSessionId(session_* → cse_*)  // infrastructure layer calls
setCseShimGate()  // Dynamic kill switch injection
```

### Token Refresh Scheduler

```typescript
scheduleFromExpiresIn()  // Schedule refresh using explicit TTL
cancel() / cancelAll()   // Cancel scheduled refreshes
```

### CCRClient Constants

```typescript
MAX_CONSECUTIVE_AUTH_FAILURES = 10  // Auth failure threshold before giving up
STREAM_EVENT_FLUSH_INTERVAL_MS = 100  // Text delta batching window
```

### OAuth 401 Retry Logic

```typescript
withOAuthRetry()  // Attempts token refresh on 401
```

---

## Comparison with Legacy Documentation

### Removed Fictional Content

- `RemoteBridgeConfig` interface - Does not exist
- `VSCodeBridgeAPI` interface - Does not exist (no IDE integration API)
- `BridgeSession` interface - Does not exist
- `BridgeStatus` / `BridgeStatusInfo` - Do not exist
- `BridgeMessage` interface (generic) - Does not exist
- `CodeSession` interface - Does not exist
- `TrustedDevice` (with deviceName/publicKey) - In source code it's TrustedDeviceToken
- `settings.json` bridge configuration - Does not exist
- Fictional environment variables like `CLAUDE_BRIDGE_ENABLED`, `CLAUDE_BRIDGE_PORT`, etc.

### New Real Content

- Correct `BridgeConfig` type definition
- `SpawnMode` / `BridgeWorkerType` types
- `EnvLessBridgeConfig` v2 configuration parameters
- `BridgeApiClient` / `SessionHandle` / `BridgeLogger` interfaces
- `isBridgeEnabled()` / `isBridgeEnabledBlocking()`
- `isEnvLessBridgeEnabled()` / `isCcrMirrorEnabled()`
- Real ant-only environment variables (CLAUDE_BRIDGE_OAUTH_TOKEN, etc.)
- Complete 33-file inventory
- GrowthBook feature gates documentation
- Build flags (BRIDGE_MODE, CCR_MIRROR, etc.)
