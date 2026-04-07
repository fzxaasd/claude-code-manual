# Server, Remote 和 Coordinator 系统

> 基于源码 `src/server/`, `src/remote/`, `src/coordinator/` 完整分析

---

## Direct Connect Server (`src/server/`)

### 概述

Server 系统实现本地 HTTP 服务器用于直接连接。

### ServerConfig

```typescript
interface ServerConfig {
  idleTimeoutMs: number    // 空闲超时（毫秒），0=永不过期
  maxSessions: number     // 最大并发会话数
  workspace: string       // 默认工作目录
}
```

**注意**: `sessionKey` 不在 ServerConfig 中，它属于 SessionInfo 类型。

### API 端点

#### POST /sessions - 创建会话

**请求体**：
```json
{
  "cwd": "string",
  "dangerously_skip_permissions": true
}
```

**响应**：
```json
{
  "session_id": "string",
  "ws_url": "string",
  "work_dir": "string"
}
```

### Session Persistence

会话索引持久化到 `~/.claude/server-sessions.json`：

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

**未记录的方法**：
- `sendInterrupt()` - 发送中断信号
- `sendErrorResponse(requestId, error)` - 错误处理

**控制请求子类型**：
- `can_use_tool` - 权限请求
- `interrupt` - 取消当前操作
- `error` - 错误响应

---

## Remote Session System (`src/remote/`)

### RemoteSessionConfig

```typescript
interface RemoteSessionConfig {
  viewerOnly?: boolean     // 纯查看模式，无中断
  hasInitialPrompt?: boolean
}
```

### SessionsWebSocket

**WebSocket 关闭码**：
- `4001` - 会话未找到（重试 3 次）
- `4003` - 未授权（永久拒绝）

**常量**：
```typescript
const RECONNECT_DELAY_MS = 2000
const MAX_RECONNECT_ATTEMPTS = 5
const PING_INTERVAL_MS = 30000
const MAX_SESSION_NOT_FOUND_RETRIES = 3
```

**认证**：
```
Authorization: Bearer {token}
anthropic-version: 2023-06-01
?organization_uuid=...
```

### Session 状态

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

### API 端点

| 端点 | 方法 | 说明 |
|------|------|------|
| `/v1/session_ingress/session/{id}` | GET | 旧版会话日志 |
| `/v1/code/sessions/{id}/teleport-events` | GET | CCR v2 事件流（分页） |
| `/v1/sessions/{id}/events` | PUT | 发送事件到会话 |
| `/v1/sessions/{id}` | PATCH | 更新会话标题 |
| `/v1/code/github/import-token` | POST | 导入 GitHub token |
| `/v1/environment_providers/cloud/create` | POST | 创建默认环境 |

### GitHub Token 导入

```typescript
class RedactedGithubToken {
  reveal(): string           // 获取原始值
  toString(): string          // 返回 "[REDACTED:gh-token]"
}

interface ImportTokenResult {
  github_username: string
}
```

---

## Coordinator 系统 (`src/coordinator/`)

### 环境变量

| 变量 | 说明 |
|------|------|
| `CLAUDE_CODE_COORDINATOR_MODE=1` | 启用 Coordinator 模式 |
| `CLAUDE_CODE_SIMPLE=1` | 限制 Worker 工具（仅 Bash/Read/Edit） |

### 内部 Worker 工具

```typescript
const INTERNAL_WORKER_TOOLS = new Set([
  'TEAM_CREATE',
  'TEAM_DELETE',
  'SEND_MESSAGE',
  'SYNTHETIC_OUTPUT'
])
// 这些工具在 Coordinator 模式下对 Worker 不可用
```

### Scratchpad 目录

Worker 间知识共享的临时目录：

```typescript
interface ScratchpadConfig {
  scratchpadDir?: string
}
```

通过 `tengu_scratch` GrowthBook 功能启用。

### Session Mode 切换

```typescript
function matchSessionMode(
  sessionMode: 'coordinator' | 'normal' | undefined
): string | undefined
```

自动切换 Coordinator 模式以匹配恢复的会话。

### 未记录的函数

```typescript
getCoordinatorUserContext()    // 构建 Worker 工具上下文
getCoordinatorSystemPrompt()    // 完整的 Coordinator 系统提示
isScratchpadGateEnabled()      // tengu_scratch GrowthBook 门控
```

---

## CCR v2 特性

### CCR v2 Headers

```typescript
export const CCR_BYOC_BETA = 'ccr-byoc-2025-07-29'
```

### CCRClient 常量

```typescript
MAX_CONSECUTIVE_AUTH_FAILURES = 10  // 放弃前的最大认证失败次数
STREAM_EVENT_FLUSH_INTERVAL_MS = 100  // 文本增量批处理窗口
DEFAULT_HEARTBEAT_INTERVAL_MS = 20000  // CCRClient 心跳
```

### EnvLessBridgeConfig

v2 bridge 的配置参数：

```typescript
interface EnvLessBridgeConfig {
  init_retry_max_attempts: number      // 默认 3
  init_retry_base_delay_ms: number   // 默认 500
  init_retry_jitter_fraction: number  // 默认 0.25
  init_retry_max_delay_ms: number     // 默认 4000
  http_timeout_ms: number             // 默认 10_000
  uuid_dedup_buffer_size: number      // 默认 2000
  heartbeat_interval_ms: number        // 默认 20_000
  heartbeat_jitter_fraction: number   // 默认 0.1
  token_refresh_buffer_ms: number     // 默认 300_000
  teardown_archive_timeout_ms: number  // 默认 1500
  connect_timeout_ms: number          // 默认 15_000
  min_version: string                 // 默认 '0.0.0'
  should_show_app_upgrade_message: boolean  // 默认 false
}
```

---

## Bridge Multi-Session

### Spawn Modes

```typescript
type SpawnMode = 'single-session' | 'worktree' | 'same-dir'
```

- `single-session`: 单一会话，结束后 bridge 关闭
- `worktree`: 持久化，每个会话隔离 git worktree
- `same-dir`: 持久化，所有会话共享 cwd

### 未记录的 CLI 标志

```bash
--spawn <mode>          # 启动模式
--capacity <N>          # 最大并发会话数
--[no-]create-session-in-dir  # 在 cwd 预创建会话
-w                      # 运行时切换 same-dir/worktree
--permission-mode <mode>  # 控制生成会话的权限
```

### Session ID 兼容性

```typescript
toCompatSessionId(cse_* -> session_*)   // v1 兼容 API
toInfraSessionId(session_* -> cse_*)    // 基础设施层
setCseShimGate()                        // 动态 kill switch
```

---

## GrowthBook Features

| Feature | 说明 |
|---------|------|
| `tengu_scratch` | Worker Scratchpad 目录 |
| `tengu_amber_flint` | Agent teams kill switch |
| `tengu_ccr_bridge_multi_session` | 每个环境多会话 |
| `tengu_ccr_bridge_multi_environment` | 每个 host:dir 多环境 |
| `tengu_bridge_initial_history_cap` | 最大初始回放消息数（默认 200） |
| `tengu_cobalt_harbor` | CCR 自动连接默认值（ant 专用） |
| `tengu_cobalt_lantern` | Web 设置可用性 |
| `tengu_sessions_elevated_auth_enforcement` | 受信任设备令牌 |

---

## 认证环境变量

| 变量 | 说明 |
|------|------|
| `CLAUDE_CODE_OAUTH_REFRESH_TOKEN` | 跳过浏览器 OAuth（需要预先存在的 refresh token） |
| `CLAUDE_CODE_OAUTH_SCOPES` | 与 refresh token 一起使用 |
| `CLAUDE_TRUSTED_DEVICE_TOKEN` | 测试用覆盖 |

---

## FileIndex 替代实现

`src/native-ts/file-index/index.ts` 是 Rust NAPI 模块的纯 TypeScript 替代：

```typescript
class FileIndex {
  loadFromFileList(fileList: string[]): void

  loadFromFileListAsync(fileList: string[]): {
    queryable: Promise<void>  // 首块索引后解析
    done: Promise<void>       // 完全构建后解析
  }

  search(query: string, limit: number): SearchResult[]
}

interface SearchResult {
  path: string
  score: number  // 越低越好
}
```

**评分规则**：
- 包含 "test" 的路径 +1.05x 惩罚
- 顶层缓存：100 条目
- 块大小：4ms（异步索引）
