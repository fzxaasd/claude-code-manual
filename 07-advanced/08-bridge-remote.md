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
| `tengu_bridge_repl_v2_config` | config | v2 bridge 详细配置 |
| `tengu_bridge_min_version` | config | v1 最低版本要求 |
| `tengu_ccr_mirror` | value | CCR 镜像模式 |
| `tengu_bridge_repl_v2_cse_shim_enabled` | value | cse_* → session_* 兼容 shim |

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
