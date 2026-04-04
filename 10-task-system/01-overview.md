# 10.1 任务系统概述

> 基于源码 `src/utils/tasks.ts`, `src/utils/task/framework.ts`, `src/Task.ts` 深度分析

---

## 核心概念

任务系统（Task System）是 Claude Code 的核心执行单元，用于管理后台长时间运行的进程和工作流。

```
任务 = Task + Todo + Notification
```

**三要素**：
- **Task** — 后台运行的进程（Bash、Agent、Workflow）
- **Todo** — 会话内的任务清单
- **Notification** — 任务状态变更通知

---

## Task 类型

基于 `src/Task.ts` 中的 `TaskType` 定义：

```typescript
export type TaskType =
  | 'local_bash'      // 本地 Bash 命令
  | 'local_agent'     // 本地 Agent
  | 'remote_agent'    // 远程 Agent
  | 'in_process_teammate'  // 进程内团队成员
  | 'local_workflow'  // 本地工作流
  | 'monitor_mcp'     // MCP 监控
  | 'dream'           // 梦境模式
```

### Task ID 前缀

```typescript
const TASK_ID_PREFIXES = {
  local_bash: 'b',          // 保持向后兼容
  local_agent: 'a',
  remote_agent: 'r',
  in_process_teammate: 't',
  local_workflow: 'w',
  monitor_mcp: 'm',
  dream: 'd',
}
```

---

## Task 状态

```typescript
export type TaskStatus =
  | 'pending'     // 等待执行
  | 'running'     // 执行中
  | 'completed'   // 已完成
  | 'failed'      // 执行失败
  | 'killed'      // 已终止
```

### 终端状态

```typescript
function isTerminalTaskStatus(status: TaskStatus): boolean {
  return status === 'completed' || status === 'failed' || status === 'killed'
}
```

---

## TaskState 结构

```typescript
export type TaskStateBase = {
  id: string              // 任务 ID
  type: TaskType          // 任务类型
  status: TaskStatus      // 任务状态
  description: string     // 任务描述
  toolUseId?: string      // 工具调用 ID
  startTime: number       // 开始时间戳
  endTime?: number        // 结束时间戳
  totalPausedMs?: number  // 暂停总时长
  outputFile: string      // 输出文件路径
  outputOffset: number    // 输出偏移量
  notified: boolean       // 是否已通知
}

// Tasks V2 TaskSchema (src/utils/tasks.ts)
export type TaskSchema = {
  id: string
  subject: string
  description: string
  activeForm?: string     // 进行中的动作描述
  owner?: string          // 任务所有者
  status: 'pending' | 'in_progress' | 'completed'  // ⚠️ Tasks V2 使用独立的状态枚
  blocks: string[]       // 被此任务阻塞的任务
  blockedBy?: string[]    // 阻塞此任务的任务
  metadata?: Record<string, unknown>  // 自定义元数据
}
```

---

## TodoWrite Tool

用于管理会话内任务清单的内置工具。

### Schema 定义

```typescript
const TodoItemSchema = z.object({
  content: z.string().min(1, 'Content cannot be empty'),
  status: z.enum(['pending', 'in_progress', 'completed']),
  activeForm: z.string().min(1, 'Active form cannot be empty'),
})

const TodoListSchema = z.array(TodoItemSchema)

// 输入结构: { todos: TodoItem[] } — 不是裸数组
const inputSchema = z.strictObject({
  todos: TodoListSchema().describe('The updated todo list'),
})
```

### 字段说明

| 字段 | 类型 | 说明 |
|------|------|------|
| `content` | string | 任务内容描述 |
| `status` | enum | 状态：`pending`/`in_progress`/`completed` |
| `activeForm` | string | 进行时形式（如"修复认证 bug"） |

### 输入结构

```typescript
// 正确: 使用对象包裹
{ todos: [{ content: "...", status: "in_progress", activeForm: "..." }] }

// 错误: 直接传入数组（文档旧版本曾有此错误）
[{ content: "...", status: "in_progress", activeForm: "..." }]
```

### 输出结构

```typescript
{
  oldTodos: TodoItem[]   // 更新前的任务列表
  newTodos: TodoItem[]   // 更新后的任务列表
  verificationNudgeNeeded?: boolean  // 是否需要验证提示
}
```

### 特性

1. **多会话支持**：使用 `agentId ?? sessionId` 作为 todo key
2. **全完成清空**：所有任务完成时自动清空列表
3. **验证提醒**：3+ 任务完成且无验证步骤时提示

### Tasks V2 系统 (feature-gated)

当 `CLAUDE_CODE_ENABLE_TASKS=true` 或**交互会话**时，启用 Tasks V2，TodoWriteTool 被禁用：

```typescript
// 源码 src/utils/tasks.ts
function isTodoV2Enabled(): boolean {
  if (isEnvTruthy(process.env.CLAUDE_CODE_ENABLE_TASKS)) {
    return true
  }
  return !getIsNonInteractiveSession()  // 在交互会话中返回 true
}
```

**注意**：Tasks V2 在**交互会话**中启用，在非交互会话中禁用（除非设置了 `CLAUDE_CODE_ENABLE_TASKS=true`）。

Tasks V2 包含: `TaskCreateTool`, `TaskUpdateTool`, `TaskGetTool`, `TaskListTool`

### 未文档化的任务工具

#### TaskOutputTool

获取任何后台任务的输出：

```typescript
interface TaskOutputToolInput {
  task_id: string      // 任务 ID
  block?: boolean      // 等待任务完成
  timeout?: number     // 超时时间（毫秒），默认 30000，最大 600000
}
```

返回：`task_id, task_type, status, output, exitCode`

#### TaskStopTool

停止运行中的后台任务：

```typescript
interface TaskStopToolInput {
  task_id?: string           // 任务 ID
  shell_id?: string         // 已废弃，使用 task_id
}
```

别名：`KillShell`（SDK 兼容性）

---

## Cron 调度工具

基于 `src/tools/ScheduleCronTool/` 深度分析。Crontab 定时任务工具。

> **注意**：Cron 功能由 `tengu_kairos_cron` GrowthBook feature 控制（需要 `AGENT_TRIGGERS` feature 启用）。

### 概述

Cron 工具允许调度定时提示，支持一次性任务和循环任务。循环任务默认 7 天后自动过期。

### CronCreateTool

```typescript
// 调度定时提示
input: {
  cron: string          // 5字段 cron 表达式 (分钟 小时 日 月 星期)
  prompt: string        // 要执行的提示
  recurring?: boolean   // 是否循环 (默认 true)
  durable?: boolean     // 是否持久化 (session外存活, GrowthBook: tengu_kairos_cron_durable)
}
```

**注意**: `agentId` 和 `permanent` 是运行时内部字段，通过 teammate context 设置，不在输入 schema 中。
```

**功能开关**: `isKairosCronEnabled()` — GrowthBook `tengu_kairos_cron` feature flag

### CronDeleteTool

```typescript
// 取消定时任务
input: {
  id: string  // CronJob ID
}
```

### CronListTool

```typescript
// 列出活跃任务
input: {}  // 无参数

output: {
  jobs: CronJob[]
}
```

队友只能查看/删除自己的 cron jobs (跨会话隔离)。

### Cron 抖动配置

| 参数 | 值 | 说明 |
|------|-----|------|
| `recurringFrac` | 0.1 (10%) | 循环任务 jitter |
| `recurringCapMs` | 15分钟 | 抖动上限 |
| `recurringMaxAgeMs` | 7天 | 循环任务最大存活时间 |
| `oneShotMaxMs` | 90秒 | 单次任务最多提前 |
| `oneShotFloorMs` | 0 | 单次任务最少延迟 |
| `oneShotMinuteMod` | 30 | 单次任务分钟取模（:00/:30 前后随机） |

### 使用示例

```typescript
// 每 30 分钟检查一次
cron: "*/30 * * * *"
prompt: "/check-deploy"

// 每天早上 9 点
cron: "0 9 * * *"
prompt: "run smoke tests"
recurring: true

// 一次性任务 (5分钟后)
cron: "*/5 * * * *"
prompt: "remind me to review PR"
recurring: false  // 单次任务
```

### 限制

- 最大任务数: 50 (`MAX_JOBS`)
- 默认过期: 7 天 (`DEFAULT_MAX_AGE_DAYS`)
- 队友不支持持久化 cron (跨会话不存活)

---

## 任务生命周期

```
┌─────────────────────────────────────────────────────────────┐
│                    任务生命周期                                │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  registerTask()                                              │
│       │                                                     │
│       ▼                                                     │
│  pending ──────► running ──────► completed                   │
│       │             │             │                         │
│       │             │             ▼                         │
│       │             │           evicted (30s grace)          │
│       │             │                                          │
│       │             ▼                                          │
│       │           failed ──────► killed                       │
│       │             │                                          │
│       └─────────────┘                                          │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

## TaskFramework 接口

### 核心函数

```typescript
// 注册新任务
function registerTask(task: TaskState, setAppState: SetAppState): void

// 更新任务状态
function updateTaskState<T extends TaskState>(
  taskId: string,
  setAppState: SetAppState,
  updater: (task: T) => T,
): void

// 驱逐终端任务
function evictTerminalTask(
  taskId: string,
  setAppState: SetAppState,
): void

// 获取运行中的任务
function getRunningTasks(state: AppState): TaskState[]
```

### 时间常量

```typescript
const POLL_INTERVAL_MS = 1000        // 轮询间隔
const STOPPED_DISPLAY_MS = 3000      // 终止任务显示时长
const PANEL_GRACE_MS = 30000         // 面板宽限期
```

---

## 任务执行参数

### LocalShellSpawnInput

```typescript
interface LocalShellSpawnInput {
  command: string           // Bash 命令
  description: string       // 任务描述
  timeout?: number          // 超时时间（毫秒）
  toolUseId?: string        // 工具调用 ID
  agentId?: AgentId         // Agent ID（用于多会话）
  kind?: 'bash' | 'monitor' // 显示类型
}
```

---

## TaskOutput

### Attachment 类型

```typescript
type TaskAttachment = {
  type: 'task_status'
  taskId: string
  toolUseId?: string
  taskType: TaskType
  status: TaskStatus
  description: string
  deltaSummary: string | null  // 自上次附件后的新输出
}
```

### 输出文件管理

```typescript
// 获取任务输出路径
getTaskOutputPath(taskId: string): string

// 获取任务输出增量
getTaskOutputDelta(taskId: string, offset: number): Promise<string>
```

---

## 后台任务执行

### 常用模式

```typescript
// 使用 & 在后台运行
command &

// nohup 防止挂断
nohup command > output.log 2>&1 &
```

### 任务标识

Claude Code 会为后台任务分配唯一 ID：
- `b[8位随机字符]` — 本地 Bash
- `a[8位随机字符]` — 本地 Agent
- `r[8位随机字符]` — 远程 Agent
- `w[8位随机字符]` — 本地 Workflow
- `m[8位随机字符]` — MCP 监控
- `t[8位随机字符]` — 团队成员

---

## 任务通知

### 通知机制

```typescript
// SDK 事件
enqueueSdkEvent({
  type: 'system',
  subtype: 'task_started',
  task_id: task.id,
  tool_use_id: task.toolUseId,
  description: task.description,
  task_type: task.type,
})
```

### 轮询机制

```typescript
// 定期检查任务状态
setInterval(() => {
  const running = getRunningTasks(appState)
  for (const task of running) {
    checkTaskOutput(task)
  }
}, POLL_INTERVAL_MS)
```

---

## 任务持久化

### 磁盘输出

```typescript
// 输出文件位置
outputFile: `~/.claude/tasks/${taskId}.log`

// 持久化格式
output: {
  id: string
  type: TaskType
  status: TaskStatus
  output: string
}
```

### 状态恢复

```typescript
// 重启时恢复未完成的任务
if (existing && 'retain' in existing) {
  return {
    ...task,
    retain: existing.retain,
    startTime: existing.startTime,
    messages: existing.messages,
    diskLoaded: existing.diskLoaded,
  }
}
```

---

## 配置相关

### hooks 与任务

任务系统可与 hooks 配合使用：

```json
{
  "hooks": {
    "OnToolCall": [
      {
        "name": "track-task-progress",
        "path": "./hooks/track-progress.py"
      }
    ]
  }
}
```

---

## 最佳实践

### 1. 使用 TodoWriteTool 管理复杂任务

```typescript
// 创建待办清单
todos: [
  { content: "分析需求文档", status: "completed", activeForm: "分析需求文档" },
  { content: "实现后端 API", status: "in_progress", activeForm: "实现后端 API" },
  { content: "编写单元测试", status: "pending", activeForm: "编写单元测试" },
]
```

### 2. 后台任务使用描述性名称

```bash
# 好的做法
nohup npm run build:prod > build.log 2>&1 &
echo "构建任务已启动: $!"

# 描述任务目的
# "部署构建任务已后台启动"
```

### 3. 长任务设置超时

```typescript
// 设置任务超时
timeout: 3600000  // 1 小时
```

### 4. 任务完成后验证

```typescript
// 包含验证步骤
todos: [
  { content: "实现功能", status: "completed", activeForm: "实现功能" },
  { content: "运行测试验证", status: "pending", activeForm: "运行测试验证" },
]
```

---

## 故障排除

### 任务卡住

```bash
# 查看运行中的任务
ps aux | grep -E "b[0-9a-z]+|a[0-9a-z]+"

# 手动终止
kill <pid>
```

### 输出丢失

```bash
# 检查输出文件
cat ~/.claude/tasks/${taskId}.log
```

### 任务不通知

检查 `notified` 标志和通知配置。

---

## 相关文档

- [Team Mode 任务协作](../07-advanced/05-team-mode.md)

---

## 测试验证

```bash
# 验证任务系统
bash tests/07-tasks-test.sh
```
