# 10.1 Task System Overview

> Based on deep analysis of source code `src/utils/tasks.ts`, `src/utils/task/framework.ts`, `src/Task.ts`

---

## Core Concepts

The Task System is Claude Code's core execution unit for managing long-running background processes and workflows.

```
Task = Task + Todo + Notification
```

**Three Elements**:
- **Task** — Background-running process (Bash, Agent, Workflow)
- **Todo** — In-session task list
- **Notification** — Task status change notifications

---

## Task Types

Based on `TaskType` definition in `src/Task.ts`:

```typescript
export type TaskType =
  | 'local_bash'      // Local Bash command
  | 'local_agent'     // Local Agent
  | 'remote_agent'    // Remote Agent
  | 'in_process_teammate'  // In-process teammate
  | 'local_workflow'  // Local workflow
  | 'monitor_mcp'     // MCP monitoring
  | 'dream'           // Dream mode
```

### Task ID Prefixes

```typescript
const TASK_ID_PREFIXES = {
  local_bash: 'b',          // Maintained for backward compatibility
  local_agent: 'a',
  remote_agent: 'r',
  in_process_teammate: 't',
  local_workflow: 'w',
  monitor_mcp: 'm',
  dream: 'd',
}
```

---

## Task Status

```typescript
export type TaskStatus =
  | 'pending'     // Waiting to execute
  | 'running'     // Executing
  | 'completed'   // Completed
  | 'failed'      // Execution failed
  | 'killed'      // Terminated
```

### Terminal Status

```typescript
function isTerminalTaskStatus(status: TaskStatus): boolean {
  return status === 'completed' || status === 'failed' || status === 'killed'
}
```

---

## TaskState Structure

```typescript
export type TaskStateBase = {
  id: string              // Task ID
  type: TaskType          // Task type
  status: TaskStatus      // Task status
  description: string     // Task description
  toolUseId?: string      // Tool call ID
  startTime: number       // Start timestamp
  endTime?: number        // End timestamp
  totalPausedMs?: number  // Total paused duration
  outputFile: string      // Output file path
  outputOffset: number    // Output offset
  notified: boolean       // Whether notification sent
}
```

---

## TodoWrite Tool

Built-in tool for managing in-session task lists.

### Schema Definition

```typescript
const TodoItemSchema = z.object({
  content: z.string().min(1, 'Content cannot be empty'),
  status: z.enum(['pending', 'in_progress', 'completed']),
  activeForm: z.string().min(1, 'Active form cannot be empty'),
})

const TodoListSchema = z.array(TodoItemSchema)

// Input structure: { todos: TodoItem[] } — not a bare array
const inputSchema = z.strictObject({
  todos: TodoListSchema().describe('The updated todo list'),
})
```

### Field Description

| Field | Type | Description |
|------|------|-------------|
| `content` | string | Task content description |
| `status` | enum | Status: `pending`/`in_progress`/`completed` |
| `activeForm` | string | Active form (e.g., "Fixing auth bug") |

### Input Structure

```typescript
// Correct: Wrap in object
{ todos: [{ content: "...", status: "in_progress", activeForm: "..." }] }

// Wrong: Pass array directly (older documentation had this error)
[{ content: "...", status: "in_progress", activeForm: "..." }]
```

### Output Structure

```typescript
{
  oldTodos: TodoItem[]   // Task list before update
  newTodos: TodoItem[]   // Task list after update
  verificationNudgeNeeded?: boolean  // Whether verification prompt needed
}
```

### Features

1. **Multi-session Support**: Uses `agentId ?? sessionId` as todo key
2. **Auto-clear on completion**: Automatically clears list when all tasks complete
3. **Verification Reminder**: Prompts when 3+ tasks completed with no verification steps

### Tasks V2 System (feature-gated)

When `CLAUDE_CODE_ENABLE_TASKS=true` or in non-interactive sessions, TodoWriteTool is disabled and Tasks V2 is enabled:

```typescript
// Source code src/utils/tasks.ts
function isTodoV2Enabled(): boolean {
  if (isEnvTruthy(process.env.CLAUDE_CODE_ENABLE_TASKS)) {
    return true
  }
  return !getIsNonInteractiveSession()
}
```

Tasks V2 includes: `TaskCreateTool`, `TaskUpdateTool`, `TaskGetTool`, `TaskListTool`

---

## Cron Scheduling Tool ⭐ GA Feature

Based on deep analysis of `src/tools/ScheduleCronTool/`. Crontab scheduled task tool.

### Overview

Cron tool allows scheduling timed prompts, supporting one-time and recurring tasks. Recurring tasks expire automatically after 7 days by default.

### CronCreateTool

```typescript
// Schedule timed prompt
input: {
  cron: string          // 5-field cron expression (minute hour day month weekday)
  prompt: string        // Prompt to execute
  recurring?: boolean   // Whether to recur (default true)
  durable?: boolean     // Whether to persist (survive session, GrowthBook: tengu_kairos_cron_durable)
}
```

**Note**: `agentId` and `permanent` are runtime internal fields, set via teammate context, not in input schema.
```

**Feature Flag**: `isKairosCronEnabled()` — GrowthBook `tengu_kairos_cron` feature flag

### CronDeleteTool

```typescript
// Cancel scheduled task
input: {
  id: string  // CronJob ID
}
```

### CronListTool

```typescript
// List active jobs
input: {}  // No parameters

output: {
  jobs: CronJob[]
}
```

Teammates can only view/delete their own cron jobs (cross-session isolation).

### Cron Jitter Configuration

| Parameter | Value | Description |
|-----------|-------|-------------|
| `recurringFrac` | 0.1 (10%) | Recurring task jitter |
| `recurringCapMs` | 15 minutes | Jitter cap |
| `oneShotMaxMs` | 90 seconds | Maximum advance for one-shot tasks |
| one-shot | Random minutes | Random around :00/:30 |

### Usage Examples

```typescript
// Every 30 minutes
cron: "*/30 * * * *"
prompt: "/check-deploy"

// Every day at 9 AM
cron: "0 9 * * *"
prompt: "run smoke tests"
recurring: true

// One-time task (in 5 minutes)
cron: "*/5 * * * *"
prompt: "remind me to review PR"
recurring: false  // One-shot task
```

### Limits

- Maximum jobs: 50 (`MAX_JOBS`)
- Default expiry: 7 days (`DEFAULT_MAX_AGE_DAYS`)
- Teammates don't support durable cron (doesn't survive cross-session)

---

## Task Lifecycle

```
┌─────────────────────────────────────────────────────────────┐
│                    Task Lifecycle                            │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  registerTask()                                              │
│       │                                                     │
│       ▼                                                     │
│  pending ──────► running ──────► completed                   │
│       │             │             │                         │
│       │             │             ▼                         │
│       │             │           evicted (30s grace)         │
│       │             │                                          │
│       │             ▼                                          │
│       │           failed ──────► killed                       │
│       │             │                                          │
│       └─────────────┘                                          │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

## TaskFramework Interface

### Core Functions

```typescript
// Register new task
function registerTask(task: TaskState, setAppState: SetAppState): void

// Update task status
function updateTaskState<T extends TaskState>(
  taskId: string,
  setAppState: SetAppState,
  updater: (task: T) => T,
): void

// Evict terminal task
function evictTerminalTask(
  taskId: string,
  setAppState: SetAppState,
): void

// Get running tasks
function getRunningTasks(state: AppState): TaskState[]
```

### Time Constants

```typescript
const POLL_INTERVAL_MS = 1000        // Polling interval
const STOPPED_DISPLAY_MS = 3000      // Stopped task display duration
const PANEL_GRACE_MS = 30000         // Panel grace period
```

---

## Task Execution Parameters

### LocalShellSpawnInput

```typescript
interface LocalShellSpawnInput {
  command: string           // Bash command
  description: string       // Task description
  timeout?: number          // Timeout (milliseconds)
  toolUseId?: string        // Tool call ID
  agentId?: AgentId         // Agent ID (for multi-session)
  kind?: 'bash' | 'monitor' // Display type
}
```

---

## TaskOutput

### Attachment Type

```typescript
type TaskAttachment = {
  type: 'task_status'
  taskId: string
  toolUseId?: string
  taskType: TaskType
  status: TaskStatus
  description: string
  deltaSummary: string | null  // New output since last attachment
}
```

### Output File Management

```typescript
// Get task output path
getTaskOutputPath(taskId: string): string

// Get task output delta
getTaskOutputDelta(taskId: string, offset: number): Promise<string>
```

---

## Background Task Execution

### Common Patterns

```typescript
// Run in background with &
command &

// nohup to prevent hangup
nohup command > output.log 2>&1 &
```

### Task Identifiers

Claude Code assigns unique IDs to background tasks:
- `b[8 random chars]` — Local Bash
- `a[8 random chars]` — Local Agent
- `r[8 random chars]` — Remote Agent
- `w[8 random chars]` — Local Workflow
- `m[8 random chars]` — MCP monitoring
- `t[8 random chars]` — Teammate

---

## Task Notifications

### Notification Mechanism

```typescript
// SDK events
enqueueSdkEvent({
  type: 'system',
  subtype: 'task_started',
  task_id: task.id,
  tool_use_id: task.toolUseId,
  description: task.description,
  task_type: task.type,
})
```

### Polling Mechanism

```typescript
// Periodically check task status
setInterval(() => {
  const running = getRunningTasks(appState)
  for (const task of running) {
    checkTaskOutput(task)
  }
}, POLL_INTERVAL_MS)
```

---

## Task Persistence

### Disk Output

```typescript
// Output file location
outputFile: `~/.claude/tasks/${taskId}.log`

// Persistence format
output: {
  id: string
  type: TaskType
  status: TaskStatus
  output: string
}
```

### State Recovery

```typescript
// Restore incomplete tasks on restart
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

## Configuration Related

### Hooks and Tasks

The task system can work with hooks:

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

## Best Practices

### 1. Use TodoWriteTool for Complex Tasks

```typescript
// Create todo list
todos: [
  { content: "Analyze requirements document", status: "completed", activeForm: "Analyzing requirements document" },
  { content: "Implement backend API", status: "in_progress", activeForm: "Implementing backend API" },
  { content: "Write unit tests", status: "pending", activeForm: "Writing unit tests" },
]
```

### 2. Use Descriptive Names for Background Tasks

```bash
# Good practice
nohup npm run build:prod > build.log 2>&1 &
echo "Build task started: $!"

# Describe task purpose
# "Deploy build task started in background"
```

### 3. Set Timeouts for Long Tasks

```typescript
// Set task timeout
timeout: 3600000  // 1 hour
```

### 4. Verify After Task Completion

```typescript
// Include verification steps
todos: [
  { content: "Implement feature", status: "completed", activeForm: "Implementing feature" },
  { content: "Run tests to verify", status: "pending", activeForm: "Running tests to verify" },
]
```

---

## Troubleshooting

### Task Stuck

```bash
# View running tasks
ps aux | grep -E "b[0-9a-z]+|a[0-9a-z]+"

# Manually terminate
kill <pid>
```

### Output Lost

```bash
# Check output file
cat ~/.claude/tasks/${taskId}.log
```

### Task Not Notifying

Check `notified` flag and notification configuration.

---

## Related Documentation

- [Team Mode Task Collaboration](../07-advanced/05-team-mode.md)

---

## Testing Verification

```bash
# Verify task system
bash tests/07-tasks-test.sh
```
