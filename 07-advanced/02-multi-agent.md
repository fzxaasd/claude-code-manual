# 7.2 多 Agent 协作

> 使用多个 Agent 协同完成复杂任务

---

## Agent 协作模式

### 基本模式

| 模式 | 说明 | 适用场景 |
|------|------|----------|
| 串行 | 一个 Agent 完成后另一个开始 | 流水线任务 |
| 并行 | 多个 Agent 同时工作 | 独立子任务 |
| 分层 | 主 Agent 协调子 Agent | 复杂项目 |

---

## Agent 通信

### 使用 Agent 工具

```bash
# 主 Agent 调用子 Agent
> 使用 reviewer agent 审查 src/auth 模块
```

### 定义子 Agent

Agent 可通过 Markdown 文件或 JSON 格式定义：

**方式一：Markdown 文件**（推荐），存放在 `.claude/agents/` 目录：

```markdown
---
name: reviewer
description: 代码审查 Agent
whenToUse: 当需要进行代码审查时使用
tools:
  - Read
  - Glob
  - Grep
model: sonnet
---

# 代码审查 Agent

你是一个专业的代码审查专家...
```

也支持在 `settings.json` 中通过 JSON 格式定义 agents（源码 `parseAgentFromJson` / `parseAgentsFromJson`），或通过 `--agents` CLI 参数传入。

### Agent 间数据传递

```
主 Agent
    ↓ (任务描述 + 上下文)
子 Agent 1 (reviewer)
    ↓ (审查结果)
子 Agent 2 (fixer)
    ↓ (修复结果)
主 Agent
    ↓
用户
```

---

## Skill 与 Agent 组合

### 场景：自动代码审查与修复

#### 1. 创建审查 Skill

```markdown
---
name: auto-review
description: 自动审查代码变更
paths:
  - "*.ts"
  - "*.tsx"
---

# 自动代码审查

## 审查标准

1. 代码风格
2. 安全漏洞
3. 性能问题
4. 测试覆盖

## 输出格式

```json
{
  "issues": [...],
  "score": 0-100,
  "recommendations": [...]
}
```
```

#### 2. 创建修复 Skill

```markdown
---
name: auto-fix
description: 自动修复审查问题
---

# 自动修复

根据审查结果修复代码问题。
```

#### 3. 配合使用

```bash
# 主 Agent
> 使用 auto-review skill 审查代码，然后使用 auto-fix skill 修复问题
```

---

## 复杂协作示例

### 场景：完整功能开发流程

```
用户请求: 开发用户认证模块

    ↓
主 Agent (Architect)
    ├─ 分析需求
    ├─ 分解任务
    └─ 分配给子 Agent

    ├─ → Agent: 数据库专家
    │       └─ 设计数据模型
    │
    ├─ → Agent: API 专家
    │       └─ 设计接口
    │
    ├─ → Agent: 前端专家
    │       └─ 实现 UI
    │
    └─ → Agent: 测试专家
            └─ 编写测试

    ↓
主 Agent (Integrator)
    ├─ 整合各部分
    ├─ 处理集成问题
    └─ 最终检查
```

### 实现配置

在 `.claude/agents/` 目录创建多个 Markdown 文件：

```markdown
---
name: architect
description: 架构设计 Agent
whenToUse: 需要架构设计时使用
model: opus
---

# 架构设计 Agent

你专注于系统架构和设计模式...
```

```markdown
---
name: db-expert
description: 数据库专家
whenToUse: 需要数据库设计或优化时使用
tools:
  - Read
  - Write
  - Glob
model: sonnet
---

# 数据库专家 Agent

你专注于数据库设计、SQL 优化...
```

---

## 并行执行

### 使用 Skill 的 fork 模式

```markdown
---
name: batch-reviewer
description: 并行审查多个文件
---

# 批量审查

使用 fork 模式并行处理多个文件。
每个文件分配给独立的子 Agent 处理。
```

### 执行脚本

```bash
#!/bin/bash
# parallel_review.sh

FILES=$(find src -name "*.ts" | head -5)

for file in $FILES; do
  claude --skill batch-reviewer --file "$file" &
done

wait
```

---

## Agent 同步与协调

### 使用 Session Hooks

```json
{
  "hooks": {
    "SubagentStop": [
      {
        "matcher": "*",
        "command": "sync_results.sh"
      }
    ]
  }
}
```

**正确格式**：Hooks 直接在根级别定义，无需多余的 `hooks` 嵌套字段。

### 协调脚本示例

```bash
#!/bin/bash
# sync_results.sh
# 收集子 Agent 结果并汇总

RESULT_FILE="/tmp/agent_results/$AGENT_ID.json"

# 保存结果
cat > "$RESULT_FILE"

# 检查是否所有 Agent 完成
COMPLETED=$(ls /tmp/agent_results/*.json 2>/dev/null | wc -l)
TOTAL=$1

if [ "$COMPLETED" -eq "$TOTAL" ]; then
  # 合并结果
  jq -s 'add' /tmp/agent_results/*.json > /tmp/final_report.json
fi
```

---

## Team 协作系统

### TeammateIdle Hook

当队友空闲时触发：

```json
{
  "hooks": {
    "TeammateIdle": [
      {
        "matcher": "*",
        "hooks": [
          {
            "type": "command",
            "command": "reassign_task.sh"
          }
        ]
      }
    ]
  }
}
```

### TaskCreated / TaskCompleted Hooks

```json
{
  "hooks": {
    "TaskCreated": [
      {
        "matcher": "*",
        "hooks": [
          {
            "type": "command",
            "command": "log_task.sh create"
          }
        ]
      }
    ],
    "TaskCompleted": [
      {
        "matcher": "*",
        "hooks": [
          {
            "type": "command",
            "command": "log_task.sh complete"
          }
        ]
      }
    ]
  }
}
```

---

## 最佳实践

### 1. 明确职责边界

在 `.claude/agents/` 中创建独立的 agent 文件：

```markdown
---
name: frontend
description: 只处理前端代码
whenToUse: 需要前端开发时使用
tools:
  - Read
  - Write
  - Glob(src/**/*.tsx)
---

# 前端专家 Agent
```

```markdown
---
name: backend
description: 只处理后端代码
whenToUse: 需要后端开发时使用
tools:
  - Read
  - Write
  - Glob(server/**/*.ts)
---

# 后端专家 Agent
```

### 2. 限制工具范围

```markdown
---
name: safe-agent
description: 安全模式 Agent，只读操作
whenToUse: 需要安全审查时使用
tools:
  - Read
  - Glob
  - Grep
---

# 安全审查 Agent
```

### 3. 使用 Skill 分层

```
root skill (协调)
├── sub-skill-1 (具体任务)
├── sub-skill-2 (具体任务)
└── sub-skill-3 (具体任务)
```

### 4. 结果聚合

- 统一输出格式
- 集中日志记录
- 定期同步状态

---

## 监控与调试

### 启用调试日志

```bash
export CLAUDE_DEBUG=agent
export CLAUDE_LOG_LEVEL=debug
```

### 查看 Agent 执行

```bash
# 列出所有 Agent
claude agents list

# 查看 Agent 执行历史
claude agents history <agent-id>
```

### 常见问题

| 问题 | 解决方案 |
|------|----------|
| Agent 无响应 | 检查工具权限配置 |
| 结果不一致 | 统一输出格式模板 |
| 死锁 | 添加超时机制 |
| 资源竞争 | 使用文件锁协调 |

---

## 未文档化的功能

### TeamFile 完整结构

源码中的完整 `TeamFile` 结构：

```typescript
type TeamFile = {
  name: string
  description?: string
  createdAt: number
  leadAgentId: string
  leadSessionId?: string      // Leader 的 session UUID
  hiddenPaneIds?: string[]    // 从 swarm UI 隐藏的窗格
  teamAllowedPaths?: TeamAllowedPath[]  // 所有 teammate 可编辑的路径
  members: Array<{
    agentId: string
    name: string
    agentType?: string
    model?: string
    prompt?: string
    color?: string
    planModeRequired?: boolean
    joinedAt: number
    tmuxPaneId: string
    cwd: string
    worktreePath?: string    // Git worktree 路径
    sessionId?: string       // Teammate 的 session UUID
    subscriptions: string[]  // 主题订阅数组
    backendType?: BackendType  // 'tmux' | 'iterm2' | 'in-process'
    isActive?: boolean      // false = 空闲
    mode?: PermissionMode   // 当前权限模式
  }>
}

type TeamAllowedPath = {
  path: string
  toolName: string
  addedBy: string
  addedAt: number
}
```

### 未文档化的环境变量

| 变量 | 说明 |
|------|------|
| `CLAUDE_CODE_TEAMMATE_COMMAND` | 覆盖 teammate spawn 二进制 |
| `CLAUDE_CODE_AGENT_COLOR` | Teammate 的 UI 颜色 |
| `CLAUDE_CODE_PLAN_MODE_REQUIRED` | 要求 teammate 使用 plan mode |
| `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` | 启用 agent teams (外部用户需要) |
| `--agent-teams` | CLI 标志用于 opt-in |

### BackendType 执行后端

3 种执行模式：
- `in-process`: 使用 AsyncLocalStorage 在同一 Node.js 进程中运行
- `tmux`: 使用 tmux 窗格
- `iterm2`: 使用原生 iTerm2 split 窗格

### Teammate Mode Selection

`teammateMode` 设置：
```typescript
teammateMode: 'auto' | 'tmux' | 'in-process'
```

### 结构化消息协议

Mailbox 支持的结构化消息类型：

| 消息类型 | 说明 |
|---------|------|
| `idle_notification` | teammate 空闲时发送 |
| `permission_request/response` | 工具权限桥接 |
| `sandbox_permission_request/response` | 网络访问请求 |
| `shutdown_request/approved/rejected` | 优雅关闭 |
| `plan_approval_request/response` | Plan mode 批准 |
| `task_assignment` | 任务分配 |
| `team_permission_update` | 广播权限变更 |
| `mode_set_request` | 更改 teammate 权限模式 |

### Auto-registration

Spawn teammate 而不调用 `TeamCreate` 会自动设置 leader 为 team lead。

### Color Assignment

Agents 通过 `assignTeammateColor()` 获取确定性颜色。

### Hook 转换

对于 agents，`Stop` hooks 会自动转换为 `SubagentStop` hooks。

---

## 模板配置

### 快速启动模板

在 `.claude/agents/` 目录创建 agent 文件：

```markdown
---
name: main
description: 主协调 Agent
whenToUse: 作为主协调器管理任务流程
model: opus
---

# 主协调 Agent

你负责协调多个子 Agent 完成复杂任务...
```

```markdown
---
name: worker
description: 工作 Agent
whenToUse: 执行具体开发任务
tools:
  - Read
  - Write
  - Glob
  - Grep
  - Bash
model: sonnet
---

# 工作 Agent

你负责执行具体的开发任务...
```

**注意**: 推荐通过 Markdown 文件定义 agents。也支持 JSON 格式（settings.json 的 `agents` 字段或 `--agents` CLI 参数）。
