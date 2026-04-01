# 7.5 Team Mode（团队模式）

> 基于源码 `src/tools/TeamCreateTool/`, `src/tools/TeamDeleteTool/`, `src/utils/agentSwarmsEnabled.ts`, `src/utils/swarm/teamHelpers.ts` 深度分析

## 核心概念

Team Mode (Agent Swarms) 是一种多 Agent 协作机制，允许一个 Leader Agent 创建和管理多个 Teammate Agents，协同完成复杂任务。

```
┌────────────────────────────────────────────────────────────┐
│                    Team Mode 架构                           │
├────────────────────────────────────────────────────────────┤
│                                                            │
│  Leader (team-lead)                                        │
│  ├── 创建团队                                              │
│  ├── 分配任务                                              │
│  ├── 审批计划 (Plan Mode 集成)                            │
│  └── 协调工作                                              │
│       │                                                    │
│       ├── teammate-1@teamName                              │
│       ├── teammate-2@teamName                              │
│       └── teammate-N@teamName                              │
│                                                            │
└────────────────────────────────────────────────────────────┘
```

---

## 启用条件

基于 `src/utils/agentSwarmsEnabled.ts`：

```typescript
function isAgentSwarmsEnabled(): boolean {
  // Ant 构建：始终启用
  if (process.env.USER_TYPE === 'ant') {
    return true
  }

  // 外部用户：需要满足以下条件
  // 1. CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS 环境变量开启
  // 2. 或 --agent-teams CLI 标志
  if (!isEnvTruthy(process.env.CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS)
      && !process.argv.includes('--agent-teams')) {
    return false
  }

  // killswitch - GrowthBook feature flag
  if (!getFeatureValue_CACHED_MAY_BE_STALE('tengu_amber_flint', true)) {
    return false
  }

  return true
}
```

**启用方式**：
```bash
# 方式 1：环境变量
export CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=true

# 方式 2：CLI 标志
claude --agent-teams
```

### Team Mode 环境变量

| 环境变量 | 来源 | 说明 |
|----------|------|------|
| `CLAUDE_CODE_TEAMMATE_COMMAND` | constants.ts | 覆盖队友启动命令 |
| `CLAUDE_CODE_AGENT_COLOR` | constants.ts | 队友显示颜色 |
| `CLAUDE_CODE_PLAN_MODE_REQUIRED` | constants.ts | 队友是否强制使用 Plan Mode |
| `CLAUDE_CODE_AGENT_ID` | 全局 | 格式: agentName@teamName |
| `CLAUDE_CODE_AGENT_NAME` | 全局 | 队友显示名称 |

---

## 工具定义

### TeamCreateTool

基于 `src/tools/TeamCreateTool/TeamCreateTool.ts`：

```typescript
interface TeamCreateTool {
  name: "TeamCreate"
  input: {
    team_name: string           // 团队名称 (必须)
    description?: string        // 团队描述/用途
    agent_type?: string         // 团队领导角色 (如 "researcher")
  }
  output: {
    team_name: string           // 最终团队名称
    team_file_path: string      // 团队配置文件路径 (~/.claude/teams/{team-name}/config.json)
    lead_agent_id: string       // 领导 Agent ID (格式: team-lead@teamName)
  }
  enabled: isAgentSwarmsEnabled()  // 功能开关
}
```

**约束**：
- Leader 只能同时管理一个团队
- 团队名称重复时自动生成唯一名称（使用 word slug）
- 团队配置存储在 `~/.claude/teams/{team-name}/config.json`

### TeamDeleteTool

基于 `src/tools/TeamDeleteTool/TeamDeleteTool.ts`：

```typescript
interface TeamDeleteTool {
  name: "TeamDelete"
  input: {}                    // 无需参数
  output: {
    success: boolean           // 是否成功
    message: string            // 结果消息
    team_name?: string         // 团队名称
  }
  enabled: isAgentSwarmsEnabled()
}
```

**清理内容**：
- 团队目录 (`~/.claude/teams/{team-name}/`)
- 任务目录 (`~/.claude/tasks/{sanitized-team-name}/`)
- Git worktrees
- 队友进程 (tmux/iTerm2 pane)

**前置条件**：所有队友必须已停止（`isActive === false`）。仍有活跃队友时返回错误。

---

## TeamFile 结构

基于 `src/utils/swarm/teamHelpers.ts`：

```typescript
interface TeamFile {
  name: string                 // 团队名称
  description?: string         // 团队描述
  createdAt: number           // 创建时间戳
  leadAgentId: string         // 领导 Agent ID
  leadSessionId?: string      // 领导会话 UUID (用于团队发现)
  hiddenPaneIds?: string[]    // UI 中隐藏的窗格 ID
  teamAllowedPaths?: TeamAllowedPath[]  // 共享路径权限

  members: Array<{
    agentId: string           // Agent ID (格式: name@teamName)
    name: string              // Agent 名称
    agentType?: string        // Agent 类型/角色
    model?: string           // 使用的模型
    prompt?: string          // 自定义提示词
    color?: string           // UI 显示颜色
    planModeRequired?: boolean // 是否必须使用 Plan Mode
    joinedAt: number          // 加入时间
    tmuxPaneId: string       // tmux 窗格 ID
    cwd: string              // 工作目录
    worktreePath?: string    // Git worktree 路径
    sessionId?: string       // 会话 ID
    subscriptions: string[]   // 订阅的消息类型
    backendType?: BackendType // 后端类型 ('tmux' | 'iterm2' | 'in-process')
    isActive?: boolean       // 是否活跃 (false = 空闲/已完成)
    mode?: PermissionMode    // 当前权限模式
  }>
}

interface TeamAllowedPath {
  path: string        // 目录路径 (绝对路径)
  toolName: string   // 适用的工具 (如 "Edit", "Write")
  addedBy: string    // 添加规则的 Agent
  addedAt: number    // 添加时间
}
```

**BackendType 类型**：
```typescript
type BackendType = 'tmux' | 'iterm2' | 'in-process'
// - 'tmux': tmux 窗格 (需 tmux 安装)
// - 'iterm2': iTerm2 分屏 (需 it2 CLI)
// - 'in-process': 同一进程内运行 (无独立终端)
```

### Team 文件存储

```bash
~/.claude/teams/{team-name}/config.json
~/.claude/tasks/{sanitized-team-name}/  # 任务列表目录
~/.claude/teams/{team-name}/inboxes/    # 消息收件箱
```

---

## 团队生命周期

### 1. 创建团队

```typescript
// 调用 TeamCreateTool
await team({
  team_name: "feature-backend",
  description: "后端功能开发团队",
  agent_type: "tech-lead"
})

// 结果：
// - 创建 ~/.claude/teams/feature-backend/config.json
// - 重置任务列表 (~/.claude/tasks/feature-backend/)
// - 设置 AppState.teamContext
```

### 2. 添加工具人

```
┌────────────────────────────────────────────────────────────┐
│                    添加工具人流程                            │
├────────────────────────────────────────────────────────────┤
│                                                            │
│  1. Leader 调用 spawnTeammate                              │
│     └── 指定 agent_type, prompt, tools 等                   │
│                                                            │
│  2. 选择后端类型                                            │
│     ├── tmux: tmux 窗格                                    │
│     ├── iterm2: iTerm2 分屏                               │
│     └── in-process: 同一进程                               │
│                                                            │
│  3. 创建 Agent 进程                                         │
│     ├── 分配 tmuxPaneId                                    │
│     ├── 设置工作目录 (worktree)                            │
│     └── 初始化权限模式                                      │
│                                                            │
│  4. 注册到 TeamFile                                         │
│     └── members 数组添加新条目                              │
│                                                            │
└────────────────────────────────────────────────────────────┘
```

### 3. 通信机制

**消息传递**：
- 共享 TeamFile (`~/.claude/teams/{team-name}/config.json`)
- 邮箱机制 (`~/.claude/teams/{team-name}/inboxes/`)
- 任务更新 (`~/.claude/tasks/{taskListId}/`)

**订阅机制**：
```typescript
// 工具人订阅的消息类型 (可为任意自定义字符串)
subscriptions: [
  "task_assignment",
  "plan_approval_request",
  "shutdown_request"
]
// 注意: subscriptions 是 string[]，无固定枚举值

### SendMessageTool 完整协议

基于 `src/tools/SendMessageTool/SendMessageTool.ts`：

```typescript
interface SendMessageTool {
  name: "SendMessage"
  input: {
    to: string          // 收件人: teammate name, "*" 广播, 或 "bridge:<session-id>" 跨会话
    summary?: string    // 5-10 词预览 (string 消息时必须)
    message: string | StructuredMessage
  }
}
```

**StructuredMessage 类型**：

```typescript
// 关闭请求
{ type: 'shutdown_request', reason?: string }

// 关闭批准 (不是 shutdown_response)
{ type: 'shutdown_approved', request_id: string, reason?: string }

// 关闭拒绝 (不是 shutdown_response)
{ type: 'shutdown_rejected', request_id: string, reason?: string }

// 计划审批响应
{ type: 'plan_approval_response', requestId: string, approved: boolean, feedback?: string, timestamp?: string, permissionMode?: PermissionMode }
```

**输出类型**：

```typescript
// 普通消息
type MessageOutput = {
  success: boolean
  message: string
  routing?: { sender, target, summary, content }
}

// 广播
type BroadcastOutput = {
  success: boolean
  message: string
  recipients: string[]
  routing?: MessageRouting
}

// 请求/响应
type RequestOutput = { success: boolean, request_id: string, target: string }
type ResponseOutput = { success: boolean, request_id?: string }
```

**协议规则**：
- `shutdown_response` 必须发送给 `team-lead`
- 拒绝关闭必须提供 `reason`
- 结构化消息不可广播 (`to: "*"`)
- 跨会话消息只能是纯文本

### In-Process Backend

同进程内运行工具人（无独立终端）：

```typescript
type BackendType = 'in-process'

// 特点：
// - 同一 Node.js 进程内运行
// - 无独立 tmux/iTerm2 窗格
// - 通过 AbortController 信号终止
// - 适合轻量级任务

// 关闭流程：
// 1. 发送 shutdown_request 到目标
// 2. 目标调用 shutdown_response (approve: true)
// 3. leader 调用 AbortController.abort()
// 4. 目标进程检查 abort 信号并退出
```

### Swarm Permission Sync

跨 Agent 权限协调机制（`src/utils/swarm/teamHelpers.ts`）：

```typescript
// 同步工具人权限到 TeamFile
syncTeammateMode(mode: PermissionMode, teamNameOverride?: string): void

// 批量更新多个工具人权限
setMultipleMemberModes(
  teamName: string,
  modeUpdates: Array<{ memberName: string, mode: PermissionMode }>
): boolean

// 设置单个工具人权限
setMemberMode(teamName: string, memberName: string, mode: PermissionMode): boolean
```

**使用场景**：
- Leader 统一调整团队权限模式
- 工具人权限变更时自动同步到 TeamFile
- 批量设置多个工具人权限

```typescript
// 示例：Leader 调整团队权限
setMemberMode("my-team", "backend-dev", "acceptEdits")

// 示例：批量更新
setMultipleMemberModes("my-team", [
  { memberName: "backend-dev", mode: "acceptEdits" },
  { memberName: "tester", mode: "default" }
])
```

### Mailbox-Based Permission Sync

基于 `src/utils/swarm/permissionSync.ts` 的完整权限协调机制：

#### 核心流程

```
┌────────────────────────────────────────────────────────────┐
│           Swarm Permission Sync 流程                       │
├────────────────────────────────────────────────────────────┤
│                                                            │
│  1. Worker Agent 遇到需要权限的工具调用                     │
│                                                            │
│  2. Worker 发送 permission_request 到 Leader 邮箱          │
│     └── writePermissionRequest() / sendPermissionRequestViaMailbox()
│                                                            │
│  3. Leader 轮询邮箱，检测到权限请求                        │
│     └── readPendingPermissions()
│                                                            │
│  4. 用户通过 Leader UI 审批/拒绝                           │
│                                                            │
│  5. Leader 发送 permission_response 到 Worker 邮箱         │
│     └── sendPermissionResponseViaMailbox()
│                                                            │
│  6. Worker 轮询邮箱，获取响应并继续执行                     │
│     └── pollForResponse() / readResolvedPermission()
│                                                            │
└────────────────────────────────────────────────────────────┘
```

#### 请求数据结构

```typescript
interface SwarmPermissionRequest {
  id: string                    // 唯一请求 ID
  workerId: string             // Worker 的 CLAUDE_CODE_AGENT_ID
  workerName: string           // Worker 的 CLAUDE_CODE_AGENT_NAME
  workerColor?: string         // Worker 的 CLAUDE_CODE_AGENT_COLOR
  teamName: string             // 团队名称
  toolName: string             // 工具名称 (如 "Bash", "Edit")
  toolUseId: string            // 原始 toolUseID
  description: string          // 人类可读的描述
  input: Record<string, unknown>  // 序列化的工具输入
  permissionSuggestions: unknown[]  // 权限建议
  status: 'pending' | 'approved' | 'rejected'
  resolvedBy?: 'worker' | 'leader'
  resolvedAt?: number
  feedback?: string            // 拒绝反馈消息
  updatedInput?: Record<string, unknown>  // 修改后的输入
  permissionUpdates?: PermissionUpdate[]  // 应用的权限规则
  createdAt: number
}
```

#### 响应数据结构

```typescript
interface PermissionResolution {
  decision: 'approved' | 'rejected'
  resolvedBy: 'worker' | 'leader'
  feedback?: string
  updatedInput?: Record<string, unknown>
  permissionUpdates?: PermissionUpdate[]
}

// Legacy response type (worker polling)
interface PermissionResponse {
  requestId: string
  decision: 'approved' | 'denied'
  timestamp: string
  feedback?: string
  updatedInput?: Record<string, unknown>
  permissionUpdates?: unknown[]
}
```

#### 核心 API

```typescript
// ============ 文件基础操作 ============

// 创建权限请求
async function writePermissionRequest(request: SwarmPermissionRequest): Promise<SwarmPermissionRequest>

// 读取待处理权限请求 (Leader 端)
async function readPendingPermissions(teamName?: string): Promise<SwarmPermissionRequest[]>

// 读取已解决的权限请求 (Worker 端)
async function readResolvedPermission(requestId: string, teamName?: string): Promise<SwarmPermissionRequest | null>

// 解决权限请求 (Leader 端)
async function resolvePermission(
  requestId: string,
  resolution: PermissionResolution,
  teamName?: string
): Promise<boolean>

// 轮询权限响应 (Worker 端)
async function pollForResponse(
  requestId: string,
  agentName?: string,
  teamName?: string
): Promise<PermissionResponse | null>

// ============ 邮箱基础操作 ============

// 发送权限请求到 Leader (Worker 端)
async function sendPermissionRequestViaMailbox(
  request: SwarmPermissionRequest
): Promise<boolean>

// 发送权限响应到 Worker (Leader 端)
async function sendPermissionResponseViaMailbox(
  workerName: string,
  resolution: PermissionResolution,
  requestId: string,
  teamName?: string
): Promise<boolean>

// ============ Sandbox 权限 ============

// Worker 请求沙箱网络访问权限
async function sendSandboxPermissionRequestViaMailbox(
  host: string,
  requestId: string,
  teamName?: string
): Promise<boolean>

// Leader 响应沙箱权限请求
async function sendSandboxPermissionResponseViaMailbox(
  workerName: string,
  requestId: string,
  host: string,
  allow: boolean,
  teamName?: string
): Promise<boolean>

// ============ 辅助函数 ============

// 检查是否是团队领导
function isTeamLeader(teamName?: string): boolean

// 检查是否是 Swarm Worker
function isSwarmWorker(): boolean

// 获取团队领导名称
async function getLeaderName(teamName?: string): Promise<string | null>

// 生成唯一请求 ID
function generateRequestId(): string

// 清理旧的已解决请求
async function cleanupOldResolutions(
  teamName?: string,
  maxAgeMs?: number
): Promise<number>
```

#### 文件存储结构

```
~/.claude/teams/{team-name}/
├── config.json              # 团队配置
├── permissions/
│   ├── pending/             # 待处理请求
│   │   └── perm-{timestamp}-{random}.json
│   └── resolved/            # 已解决请求
│       └── perm-{timestamp}-{random}.json
└── inboxes/                 # 消息收件箱
    └── {teammate-name}/
        └── messages.json
```

#### 使用示例

```typescript
// Worker: 发送权限请求
const request = createPermissionRequest({
  toolName: 'Bash',
  toolUseId: 'toolu_xxx',
  input: { command: 'rm -rf node_modules' },
  description: 'Remove node_modules directory'
})
await sendPermissionRequestViaMailbox(request)

// Leader: 读取并处理请求
const pending = await readPendingPermissions()
for (const req of pending) {
  // 显示给用户审批
  const decision = await showPermissionDialog(req)
  await resolvePermission(req.id, decision)
}

// Worker: 轮询响应
const response = await pollForResponse(request.id)
if (response?.decision === 'approved') {
  // 继续执行
}
```

#### Sandbox 权限同步

用于 Worker Agent 的沙箱需要网络访问时的权限协调：

```typescript
// Worker: 请求沙箱访问网络
const sandboxReqId = generateSandboxRequestId()
await sendSandboxPermissionRequestViaMailbox('npmjs.com', sandboxReqId)

// Leader: 审批沙箱网络请求
await sendSandboxPermissionResponseViaMailbox(
  workerName,
  sandboxReqId,
  'npmjs.com',
  true  // allow
)
```

### TeammateSpawnConfig

基于 `src/utils/swarm/backends/types.ts`：

```typescript
type TeammateSpawnConfig = TeammateIdentity & {
  prompt: string           // 初始提示词
  cwd: string             // 工作目录
  model?: string          // 指定模型
  systemPrompt?: string   // 系统提示词
  systemPromptMode?: 'default' | 'replace' | 'append'  // 系统提示词模式
  worktreePath?: string   // Git worktree 路径
  parentSessionId: string // 父会话 ID
  permissions?: string[] // 工具权限列表
  allowPermissionPrompts?: boolean  // 是否允许权限提示
}

type TeammateIdentity = {
  name: string           // 工具人名称
  teamName: string      // 团队名称
  color?: AgentColorName  // UI 颜色
  planModeRequired?: boolean  // 是否必须 Plan Mode
}
```

### 4. 团队删除

```typescript
// 约束：不能有活跃的工具人
if (activeMembers.length > 0) {
  return {
    success: false,
    message: "Cannot cleanup team with N active member(s)"
  }
}

// 清理流程
await cleanupTeamDirectories(teamName)
// ├── 销毁 git worktrees
// ├── 删除团队目录
// └── 删除任务目录
```

---

## 与 AgentTool 的区别

| 特性 | AgentTool | Team Mode |
|------|-----------|-----------|
| 上下文 | 共享主会话 | 独立进程 |
| 通信 | 直接调用 | 异步消息 |
| 任务管理 | 无 | 内置 |
| 并发控制 | 无 | 多任务协调 |
| 权限控制 | 统一 | 每个 Agent 可独立 |
| 适用场景 | 简单子任务 | 复杂协作 |

---

## Plan Mode 集成

### 团队领导审批流程

```typescript
// Teammate 调用 ExitPlanMode
if (isTeammate() && isPlanModeRequired()) {
  // 发送审批请求到 leader
  await writeToMailbox('team-lead', {
    type: 'plan_approval_request',
    planContent: plan,
    requestId: generateRequestId(...)
  })

  return {
    awaitingLeaderApproval: true,
    requestId: ...
  }
}

// 注意: isTeammate() 对队友返回 true，team-lead 不是 teammate
// 实际 leader 端检查用 isTeamLead() (src/tools/ExitPlanModeTool/ExitPlanModeV2Tool.ts)
```

### 权限模式同步

```typescript
// 工具人权限变更时同步到 TeamFile
function syncTeammateMode(mode: PermissionMode): void {
  if (!isTeammate()) return
  setMemberMode(teamName, agentName, mode)
}

// 团队领导可查看所有工具人的权限模式
```

---

## 配置选项

### 团队文件路径

```bash
# 默认位置
~/.claude/teams/{team-name}/

# 团队配置
~/.claude/teams/{team-name}/config.json

# 消息邮箱
~/.claude/teams/{team-name}/inboxes/

# 任务列表
~/.claude/tasks/{sanitized-team-name}/
```

### 任务列表隔离

```typescript
// 团队 = 项目 = 任务列表
// 每个团队有独立的任务编号空间
setLeaderTeamName(sanitizeName(teamName))
// 任务编号从 1 开始
```

---

## 使用示例

### 创建团队

```json
{
  "tool": "TeamCreate",
  "input": {
    "team_name": "api-refactor",
    "description": "API 重构团队",
    "agent_type": "architect"
  }
}
```

### 响应

```json
{
  "team_name": "api-refactor",
  "team_file_path": "/home/user/.claude/teams/api-refactor/config.json",
  "lead_agent_id": "team-lead@api-refactor"
}
```

### 删除团队

```json
{
  "tool": "TeamDelete",
  "input": {}
}
```

---

## 最佳实践

### 1. 团队结构

```
✅ 推荐结构:
├── tech-lead     (Leader) - 架构决策、任务分配
├── backend-dev   (Teammate) - 后端开发
├── frontend-dev  (Teammate) - 前端开发
└── tester       (Teammate) - 测试验证

❌ 避免:
├── manager       (Leader) - 只分配任务
├── developer     (Teammate) - 角色模糊
└── developer2    (Teammate) - 职责不清
```

### 2. 权限管理

```typescript
// 共享路径 - 工具人可直接编辑
teamAllowedPaths: [
  { path: "/project/src", toolName: "Edit", addedBy: "team-lead" }
]

// 权限模式 - 每个工具人可独立设置
members: [
  { name: "backend-dev", mode: "acceptEdits" },
  { name: "tester", mode: "default" }
]
```

### 3. Worktree 隔离

```typescript
// 每个工具人使用独立 worktree
members: [
  {
    name: "backend-dev",
    worktreePath: "/project/.git/worktrees/backend-dev"
  }
]
// 避免文件冲突
```

---

## 会话清理

### 自动清理

```typescript
// 注册会话创建的团队
registerTeamForSessionCleanup(teamName)

// 会话结束时清理
cleanupSessionTeams()
// ├── killOrphanedTeammatePanes()
// └── cleanupTeamDirectories()
```

### 清理流程

```
┌────────────────────────────────────────────────────────────┐
│                    会话清理流程                              │
├────────────────────────────────────────────────────────────┤
│                                                            │
│  1. SIGINT/SIGTERM 触发 gracefulShutdown                   │
│                                                            │
│  2. cleanupSessionTeams() 被调用                           │
│                                                            │
│  3. 对每个会话创建的团队：                                   │
│     ├── killOrphanedTeammatePanes()                        │
│     │   └── 杀掉 tmux/iTerm2 窗格进程                       │
│     └── cleanupTeamDirectories()                           │
│         ├── 销毁 git worktrees                             │
│         ├── 删除团队目录                                    │
│         └── 删除任务目录                                    │
│                                                            │
└────────────────────────────────────────────────────────────┘
```

---

## 故障排除

### 无法创建团队

```bash
# 检查功能是否启用
echo $CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS

# 检查 GrowthBook feature flag
# tengu_amber_flint 必须为 true
```

### 团队目录残留

```bash
# 查看残留团队
ls ~/.claude/teams/

# 手动清理
rm -rf ~/.claude/teams/{team-name}/
rm -rf ~/.claude/tasks/{sanitized-name}/
```

### 工具人活跃状态问题

```typescript
// 工具人崩溃后 isActive 仍为 true
// TeamDelete 会拒绝清理
// 解决方案：
// 1. 等待工具人真正停止
// 2. 手动杀掉 tmux/iTerm2 窗格
// 3. 重新启动 Claude Code
```

---

## 测试验证

```bash
# 验证功能启用
node -e "console.log(require('./src/utils/agentSwarmsEnabled').isAgentSwarmsEnabled())"

# 检查团队目录
ls ~/.claude/teams/

# 查看团队配置
cat ~/.claude/teams/{team-name}/config.json
```
