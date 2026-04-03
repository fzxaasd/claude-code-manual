# 7.8 Bridge/Remote Control System

> Claude Code 远程控制 (Remote Control / CCR) 核心系统文档

## 概述

Bridge 系统是 Claude Code 与 claude.ai Remote Control 服务通信的核心机制。它使本地 Claude Code 会话能够被远程用户的 claude.ai 界面控制和观察。源码位于 `src/bridge/` 目录。

**注意**: 此系统与 IDE 集成无关（无 VS Code Extension API），主要服务于远程会话控制场景。

```
┌─────────────────────────────────────────────────────────────┐
│                    CCR 系统架构                               │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  claude.ai Web Interface (Remote Control)                  │
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
│  Claude Code (本地会话)                                      │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

## 核心类型

### BridgeConfig

基于 `src/bridge/types.ts`:

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

会话工作目录选择模式:

```typescript
export type SpawnMode = 'single-session' | 'worktree' | 'same-dir'
```

- `single-session`: 在 cwd 中运行单一会话，bridge 在会话结束时销毁
- `worktree`: 持久化服务器，每个会话获得隔离的 git worktree
- `same-dir`: 持久化服务器，每个会话共享 cwd（可能相互覆盖）

### BridgeWorkerType

```typescript
export type BridgeWorkerType = 'claude_code' | 'claude_code_assistant'
```

发送给服务端作为 `metadata.worker_type`，供 web 客户端按来源过滤。

### BridgeApiClient

Bridge API 客户端接口:

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

会话句柄:

```typescript
export type SessionHandle = {
  sessionId: string
  done: Promise<SessionDoneStatus>
  kill(): void
  forceKill(): void
  activities: SessionActivity[]     // 最近活动的环形缓冲区
  currentActivity: SessionActivity | null
  accessToken: string                // session_ingress_token
  lastStderr: string[]              // 最后几行 stderr
  writeStdin(data: string): void
  updateAccessToken(token: string): void
}
```

### WorkSecret

来自服务端的工作密钥:

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

## 功能开关

### isBridgeEnabled()

运行时检查 bridge 模式授权。

```typescript
export function isBridgeEnabled(): boolean
```

- 需要 `feature('BRIDGE_MODE')` 构建标志
- 需要 `isClaudeAISubscriber()` (排除 Bedrock/Vertex/Foundry/apiKey)
- 需要 GrowthBook gate `tengu_ccr_bridge` 为 true

### isBridgeEnabledBlocking()

阻塞式授权检查（用于权限门控）。

```typescript
export async function isBridgeEnabledBlocking(): Promise<boolean>
```

返回缓存的 `true`（快速路径），或等待 GrowthBook 初始化获取最新值。

### isEnvLessBridgeEnabled()

检查 v2 (env-less) REPL bridge 路径。

```typescript
export function isEnvLessBridgeEnabled(): boolean
```

GrowthBook flag: `tengu_bridge_repl_v2`

### isCcrMirrorEnabled()

CCR 镜像模式开关 - 每个本地会话生成一个只发送的 Remote Control 会话。

```typescript
export function isCcrMirrorEnabled(): boolean
```

- 需要 `feature('CCR_MIRROR')` 构建标志
- 环境变量 `CLAUDE_CODE_CCR_MIRROR` 优先
- GrowthBook gate: `tengu_ccr_mirror`

### checkBridgeMinVersion()

v1 (env-based) Remote Control 最低版本检查。

```typescript
export function checkBridgeMinVersion(): string | null
```

GrowthBook config: `tengu_bridge_min_version`

---

## EnvLessBridgeConfig (v2)

基于 `src/bridge/envLessBridgeConfig.ts` 的 v2 bridge 配置参数:

```typescript
export type EnvLessBridgeConfig = {
  // init-phase 重试配置
  init_retry_max_attempts: number   // 默认: 3
  init_retry_base_delay_ms: number   // 默认: 500
  init_retry_jitter_fraction: number // 默认: 0.25
  init_retry_max_delay_ms: number    // 默认: 4000

  // HTTP 超时 (POST /sessions, POST /bridge, POST /archive)
  http_timeout_ms: number           // 默认: 10_000

  // UUID 去重缓冲区大小
  uuid_dedup_buffer_size: number     // 默认: 2000

  // CCRClient 心跳间隔 (服务器 TTL 60s)
  heartbeat_interval_ms: number      // 默认: 20_000
  heartbeat_jitter_fraction: number  // 默认: 0.1

  // JWT 刷新提前量
  token_refresh_buffer_ms: number   // 默认: 300_000

  // teardown() 归档超时 (独立于 http_timeout_ms)
  teardown_archive_timeout_ms: number // 默认: 1500

  // transport.connect() 后 onConnect 超时
  connect_timeout_ms: number         // 默认: 15_000

  // 最低版本要求
  min_version: string                // 默认: '0.0.0'

  // 是否提示用户升级 claude.ai app
  should_show_app_upgrade_message: boolean // 默认: false
}
```

GrowthBook feature key: `tengu_bridge_repl_v2_config`

---

## 环境变量

### Ant-only 开发覆盖 (src/bridge/bridgeConfig.ts)

| 变量 | 说明 |
|------|------|
| `CLAUDE_BRIDGE_OAUTH_TOKEN` | Ant-only: 覆盖 OAuth token |
| `CLAUDE_BRIDGE_BASE_URL` | Ant-only: 覆盖 API base URL |
| `CLAUDE_BRIDGE_SESSION_INGRESS_URL` | Ant-only: 覆盖 session ingress URL |

### CCR v2 相关

| 变量 | 说明 |
|------|------|
| `CLAUDE_BRIDGE_USE_CCR_V2` | 强制启用 CCR v2 (env-less bridge) |

### CCR Mirror

| 变量 | 说明 |
|------|------|
| `CLAUDE_CODE_CCR_MIRROR` | 启用 CCR 镜像模式 |

---

## 文件清单 (33 个)

```
src/bridge/
├── bridgeApi.ts              # Bridge API 实现
├── bridgeConfig.ts          # Bridge auth/URL 解析, ant-only 覆盖
├── bridgeDebug.ts           # Bridge 调试工具
├── bridgeEnabled.ts         # 功能开关 (isBridgeEnabled 等)
├── bridgeMain.ts            # CLI 入口 /remote-control 命令实现
├── bridgeMessaging.ts       # Bridge 消息协议
├── bridgePermissionCallbacks.ts  # Bridge 权限回调
├── bridgePointer.ts         # Bridge 指针操作
├── bridgeStatusUtil.ts      # Bridge 状态工具
├── bridgeUI.ts              # Bridge UI 组件
├── capacityWake.ts          # 容量唤醒
├── codeSessionApi.ts        # 代码会话 API
├── createSession.ts         # 会话创建
├── debugUtils.ts            # 调试工具
├── envLessBridgeConfig.ts   # v2 EnvLessBridgeConfig
├── flushGate.ts             # 刷新门控
├── inboundAttachments.ts    # 入站附件处理
├── inboundMessages.ts       # 入站消息处理
├── initReplBridge.ts        # REPL Bridge 初始化 (v2)
├── jwtUtils.ts              # JWT 认证工具
├── pollConfig.ts            # 轮询配置
├── pollConfigDefaults.ts    # 轮询配置默认值
├── remoteBridgeCore.ts      # 远程 Bridge 核心逻辑
├── replBridge.ts            # REPL Bridge 实现
├── replBridgeHandle.ts      # REPL Bridge 句柄
├── replBridgeTransport.ts   # REPL Bridge 传输层
├── sessionIdCompat.ts       # 会话 ID 兼容性
├── sessionRunner.ts         # 会话运行器
├── trustedDevice.ts         # 信任设备管理
├── types.ts                 # 核心类型定义
└── workSecret.ts            # 工作密钥处理
```

---

## 会话生命周期

### v1 (env-based) 路径

```
1. 获取 WorkSecret (环境变量)
2. 启动 Claude Code 子进程
3. 通信方式:
   - 独立 bridge 子进程模式: 通过 stdio 通信
   - REPL bridge 模式: 当 CLAUDE_BRIDGE_USE_CCR_V2 设置时，通过 CCR v2 transport (SSE + WS) 通信
4. 会话结束 → archive
```

### v2 (env-less) 路径

```
1. BridgeConfig 构建
2. registerBridgeEnvironment() → 获取 environment_id/secret
3. pollForWork() 循环
4. 获取 WorkSecret 后 spawn 会话
5. 通过 transport (WebSocket/SSE) 通信
6. heartbeatWork() 保活
7. archiveSession() 归档
```

---

## 认证与授权

### 前置条件

1. **必须使用 claude.ai 登录** - 需要 OAuth token
   - 排除: Bedrock/Vertex/Foundry, apiKey, Console API
2. **需要 user:profile scope** - setup-token 和 CLAUDE_CODE_OAUTH_TOKEN 不够
3. **组织策略检查** - `isPolicyAllowed('allow_remote_control')` 必须允许
4. **GrowthBook gate** - `tengu_ccr_bridge` 必须为 true

### getBridgeDisabledReason()

获取详细的禁用原因:

```typescript
export async function getBridgeDisabledReason(): Promise<string | null>
```

检测顺序: `BRIDGE_MODE` 构建标志 → `isClaudeAISubscriber()` → `hasProfileScope()` → `organizationUuid` → GrowthBook gate

可能返回值:
- `"Remote Control requires a claude.ai subscription..."`
- `"Remote Control requires a full-scope login token..."`
- `"Unable to determine your organization..."` + 后缀 `Run \`claude auth login\` to refresh your account information`
- `"Remote Control is not yet enabled for your account."`
- `"Remote Control is not available in this build."`

---

## GrowthBook Feature Gates

| Feature Key | 类型 | 说明 |
|-------------|------|------|
| `tengu_ccr_bridge` | gate | Remote Control 总开关 |
| `tengu_bridge_repl_v2` | value | 启用 v2 env-less bridge |
| `tengu_bridge_repl_v2_config` | config | v2 bridge 详细配置 (EnvLessBridgeConfig) |
| `tengu_bridge_repl_v2_cse_shim_enabled` | config | cse_* → session_* 兼容 shim |
| `tengu_bridge_min_version` | config | v1 最低版本要求 |
| `tengu_bridge_poll_interval_config` | config | PollIntervalConfig 轮询参数 |
| `tengu_sessions_elevated_auth_enforcement` | gate | Trusted Device Token 功能开关 |
| `tengu_ccr_mirror` | value | CCR 镜像模式 |

---

## Trusted Device Token

基于 `src/bridge/trustedDevice.ts` 的可信设备令牌机制：

### 机制概述

- **GrowthBook Gate**: `tengu_sessions_elevated_auth_enforcement`
- **用途**: 设备注册认证，token 有效期 90 天（服务端滚动过期）

### 核心 API

```typescript
// 获取 token（用于请求头 X-Trusted-Device-Token）
export function getTrustedDeviceToken(): string | undefined

// 清除缓存
export function clearTrustedDeviceTokenCache(): void

// 注册设备到服务端
export async function enrollTrustedDevice(): Promise<void>
```

### Token 获取优先级

```typescript
const readStoredToken = memoize((): string | undefined => {
  // 1. 环境变量优先
  const envToken = process.env.CLAUDE_TRUSTED_DEVICE_TOKEN
  if (envToken) {
    return envToken
  }
  // 2. macOS Keychain 回退
  return getSecureStorage().read()?.trustedDeviceToken
})
```

### Enrollment 流程

```typescript
async function enrollTrustedDevice(): Promise<void> {
  // POST /api/auth/trusted_devices
  // 请求体: { display_name: "Claude Code on {hostname} · {platform}" }
  // 响应: { device_token, device_id }
  // Token 存储到 Keychain
}
```

### 使用示例

```typescript
// in codeSessionApi.ts
export async function fetchRemoteCredentials(
  sessionId: string,
  baseUrl: string,
  accessToken: string,
  timeoutMs: number,
  trustedDeviceToken?: string,  // 可选参数
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

基于 `src/bridge/pollConfig.ts` 和 `src/bridge/pollConfigDefaults.ts` 的轮询配置：

### 类型定义

```typescript
export type PollIntervalConfig = {
  poll_interval_ms_not_at_capacity: number           // 活跃轮询间隔
  poll_interval_ms_at_capacity: number               // 容量满时轮询间隔
  non_exclusive_heartbeat_interval_ms: number         // 非独占心跳间隔
  multisession_poll_interval_ms_not_at_capacity: number  // 多会话：非满负荷
  multisession_poll_interval_ms_partial_capacity: number  // 多会话：部分容量
  multisession_poll_interval_ms_at_capacity: number     // 多会话：满容量
  reclaim_older_than_ms: number                       // 拾取超时阈值
  session_keepalive_interval_v2_ms: number            // Session-ingress keep-alive 间隔
}
```

### 默认值

| 参数 | 默认值 | 说明 |
|------|--------|------|
| `poll_interval_ms_not_at_capacity` | `2000` | 活跃轮询间隔(毫秒) |
| `poll_interval_ms_at_capacity` | `600000` (10分钟) | 容量满时轮询，0=禁用 |
| `non_exclusive_heartbeat_interval_ms` | `0` | 非独占心跳间隔 |
| `multisession_poll_interval_ms_not_at_capacity` | `2000` | 多会话：非满负荷 |
| `multisession_poll_interval_ms_partial_capacity` | `2000` | 多会话：部分容量 |
| `multisession_poll_interval_ms_at_capacity` | `600000` | 多会话：满容量 |
| `reclaim_older_than_ms` | `5000` | 拾取超时工作的阈值 |
| `session_keepalive_interval_v2_ms` | `120000` (2分钟) | Session-ingress keep-alive 帧间隔 |

### 配置来源

- **GrowthBook feature**: `tengu_bridge_poll_interval_config`
- **刷新间隔**: 5 分钟 (`5 * 60 * 1000`)
- **回退机制**: Zod schema 验证失败时回退到 `DEFAULT_POLL_CONFIG`

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

基于 `src/bridge/replBridgeTransport.ts` 和 `src/cli/transports/` 的传输层实现：

### 架构概览

```
Bridge Sessions
    │
    ├── v1: HybridTransport (WS读取 + HTTP POST写入)
    │       └── WebSocketTransport (reconnect, ping/pong)
    │
    └── v2: SSETransport (SSE读取) + CCRClient (HTTP写入/心跳)
```

### v1 HybridTransport

```typescript
export class HybridTransport extends WebSocketTransport {
  // 写入: WebSocket → SerialBatchEventUploader → HTTP POST
  // stream_event: 100ms 缓冲批量发送
  // 其他消息: 直接入队
  
  // URL 转换
  // wss://api.example.com/v2/session_ingress/ws/<session_id>
  // → https://api.example.com/v2/session_ingress/session/<session_id>/events
}
```

### v2 SSETransport (读取)

```typescript
export class SSETransport implements Transport {
  // SSE → parseSSEFrames → onData callback
  // 自动重连: 指数退避 + 抖动
  // 重连预算: 10分钟 (RECONNECT_GIVE_UP_MS = 600000)
  // 存活检测: 45秒无活动视为断开 (LIVENESS_TIMEOUT_MS)
  // 序列号: Last-Event-ID 用于断点续传
}
```

### v2 CCRClient (写入 + 心跳)

```typescript
export class CCRClient {
  // PUT /worker - worker 状态报告
  // POST /worker/events - 客户端事件
  // POST /worker/heartbeat - 心跳 (默认 20s，server TTL 60s)
  // POST /worker/events/delivery - 投递状态
  
  // Epoch 管理: 409 = epoch 不匹配 → 重建传输
  // 流事件: 100ms 缓冲 + text_delta 合并
}
```

### ReplBridgeTransport 接口

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
  getLastSequenceNum(): number  // v2 SSE 序列号
  reportState(state: SessionState): void
  reportDelivery(eventId: string, status: 'processing' | 'processed'): void
  flush(): Promise<void>
}
```

### 适配器工厂函数

```typescript
// v1 适配器
export function createV1ReplTransport(hybrid: HybridTransport): ReplBridgeTransport

// v2 适配器
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

### 心跳与重连配置

| 常量 | 值 | 说明 |
|------|-----|------|
| `DEFAULT_HEARTBEAT_INTERVAL_MS` | `20000` | CCRClient 默认心跳间隔 |
| `MAX_CONSECUTIVE_AUTH_FAILURES` | `10` | 认证失败后放弃重连次数 |
| `RECONNECT_BASE_DELAY_MS` | `1000` | WebSocket 重连基础延迟 |
| `RECONNECT_MAX_DELAY_MS` | `30000` | WebSocket 重连最大延迟 |
| `RECONNECT_GIVE_UP_MS` | `600000` | 重连放弃阈值 (10分钟) |
| `LIVENESS_TIMEOUT_MS` | `45000` | SSE 无活动断开阈值 (45秒) |

### Epoch 管理

- Epoch 由服务端在 `/sessions/{id}/bridge` 响应中返回
- `409 Conflict` = Epoch 不匹配 → 重建传输层
- 客户端传入 epoch 用于服务端校验

---

## 构建标志 (Feature Flags)

| 标志 | 说明 |
|------|------|
| `BRIDGE_MODE` | 启用 Bridge 功能 |
| `CCR_AUTO_CONNECT` | Ant-only: 自动连接 CCR |
| `CCR_MIRROR` | 启用 CCR 镜像模式 |

---

## 状态常量

基于 `src/bridge/types.ts`:

```typescript
export const DEFAULT_SESSION_TIMEOUT_MS = 24 * 60 * 60 * 1000

export const BRIDGE_LOGIN_ERROR =
  'Error: You must be logged in to use Remote Control.\n\n' +
  'Remote Control is only available with claude.ai subscriptions...'

export const REMOTE_CONTROL_DISCONNECTED_MSG = 'Remote Control disconnected.'
```

---

## CLI 命令

### /remote-control

主入口命令，定义在 `bridgeMain.ts`:

```bash
claude remote-control [options]

# 完整帮助信息
# Remote Control lets you access this CLI session from the web (claude.ai/code)
# or the Claude app, so you can pick up where you left off on any device.

Options:
  --session-id <id>    恢复指定会话 (别名: --continue)
  --name <name>        指定会话名称
  --debug-file <path>  调试日志文件路径
```

---

## Bridge vs Remote 系统区别

源码中存在两个远程相关的系统：

| 特性 | Bridge (src/bridge/) | Remote (src/remote/) |
|------|---------------------|---------------------|
| **用途** | CCR Remote Control（远程控制桥接） | Remote Session Manager（远程会话管理） |
| **协议** | SSE + HTTP PUT | WebSocket (`/v1/sessions/ws/{id}/subscribe`) |
| **方向** | claude.ai → 本地 REPL | 通用 WebSocket 会话订阅 |
| **认证** | OAuth + Trusted Device Token | Token-based |
| **入口** | `claude remote-control` | RemoteSessionManager |

### RemoteSessionManager 简介

基于 `src/remote/RemoteSessionManager.ts`:

```typescript
export class RemoteSessionManager {
  // WebSocket 连接管理
  subscribe(sessionId: string): Promise<void>
  unsubscribe(): void

  // 会话状态
  getStatus(): SessionStatus
  onStatusChange(callback: (status: SessionStatus) => void): void
}
```

**使用场景**：需要远程查看/交互会话时，通过 WebSocket 订阅实时更新。

---

## 未文档化的功能

### 未文档化的 GrowthBook Features

| Feature Key | 说明 |
|-------------|------|
| `tengu_bridge_initial_history_cap` | 重播的最大初始消息数 (默认 200) |
| `tengu_cobalt_harbor` | CCR auto-connect 默认 (ant-only) |
| `tengu_ccr_bridge_multi_session` | 每个环境多个 sessions |
| `tengu_ccr_bridge_multi_environment` | 每个 host:dir 多个环境 |

### 未文档化的环境变量

| 变量 | 作用域 | 说明 |
|------|--------|------|
| `CLAUDE_BRIDGE_SESSION_INGRESS_URL` | Ant-only | 覆盖 session ingress URL |
| `CLAUDE_CODE_SESSION_ACCESS_TOKEN` | Process-wide | 单会话 OAuth token 回退 |
| `CLAUDE_TRUSTED_DEVICE_TOKEN` | Testing | 覆盖 trusted device token |
| `CLAUDE_BRIDGE_USE_CCR_V2` | CCR v2 | 强制 standalone bridge 使用 CCR v2 transport |

### heartbeatWork 响应字段

文档未记录的响应字段：
```typescript
{
  lease_extended: boolean,
  state: string,
  last_heartbeat: string,    // ISO 时间戳
  ttl_seconds: number         // 剩余 TTL
}
```

### BridgeState 类型

```typescript
export type BridgeState = 'ready' | 'connected' | 'reconnecting' | 'failed'
```

### Essential Traffic 检查

Trusted Device Token enrollment 受 `isEssentialTrafficOnly()` 检查保护 - 在 essential traffic 模式下跳过 enrollment。

### Fault Injection System (Ant-only)

用于手动测试 bridge 恢复路径的开发功能：
- `/bridge-kick <subcommand>` slash command
- `injectFault()` - 队列 fault 用于测试
- `fireClose()` - 测试 ws_closed → reconnect 升级
- `forceReconnect()` - 触发 reconnectEnvironmentWithSession

### Session ID 兼容层

```typescript
toCompatSessionId(cse_* → session_*)  // v1 compat API
toInfraSessionId(session_* → cse_*)  // infrastructure 层调用
setCseShimGate()  // 动态 kill switch 注入
```

### Token Refresh Scheduler

```typescript
scheduleFromExpiresIn()  // 使用显式 TTL 调度刷新
cancel() / cancelAll()   // 取消调度的刷新
```

### CCRClient 常量

```typescript
MAX_CONSECUTIVE_AUTH_FAILURES = 10  // 放弃前的认证失败阈值
STREAM_EVENT_FLUSH_INTERVAL_MS = 100  // 文本增量批处理窗口
```

### OAuth 401 Retry Logic

```typescript
withOAuthRetry()  // 401 时尝试 token 刷新
```

---

## 与旧文档对比

### 已删除的虚构内容

- `RemoteBridgeConfig` 接口 - 不存在
- `VSCodeBridgeAPI` 接口 - 不存在 (无 IDE 集成 API)
- `BridgeSession` 接口 - 不存在
- `BridgeStatus` / `BridgeStatusInfo` - 不存在
- `BridgeMessage` 接口 (通用) - 不存在
- `CodeSession` 接口 - 不存在
- `TrustedDevice` (含 deviceName/publicKey) - 源码中为 TrustedDeviceToken
- `settings.json` bridge 配置 - 不存在
- `CLAUDE_BRIDGE_ENABLED`, `CLAUDE_BRIDGE_PORT` 等虚构环境变量

### 新增的真实内容

- 正确的 `BridgeConfig` 类型定义
- `SpawnMode` / `BridgeWorkerType` 类型
- `EnvLessBridgeConfig` v2 配置参数
- `BridgeApiClient` / `SessionHandle` / `BridgeLogger` 接口
- `isBridgeEnabled()` / `isBridgeEnabledBlocking()`
- `isEnvLessBridgeEnabled()` / `isCcrMirrorEnabled()`
- 真实的 ant-only 环境变量 (CLAUDE_BRIDGE_OAUTH_TOKEN 等)
- 完整的 33 个文件清单
- GrowthBook feature gates 文档
- 构建标志 (BRIDGE_MODE, CCR_MIRROR 等)
