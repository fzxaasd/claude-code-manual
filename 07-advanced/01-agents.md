# Agent 系统

> 基于源码 `src/tools/AgentTool/` 深度分析

## 核心概念

### Agent 类型

Claude Code 有三种 Agent 来源：

| 类型 | 来源 | 说明 |
|------|------|------|
| **Built-in** | Claude Code 内置 | General Purpose, Explore, Plan 等 |
| **Custom** | 用户/项目配置 | `~/.claude/agents/` 或 `.claude/agents/` |
| **Plugin** | 插件提供 | 来自插件的 Agent |

### 内置 Agent 清单

基于 `src/tools/AgentTool/built-in/` 目录下的独立文件：

| 文件 | Agent | 说明 |
|------|-------|------|
| `generalPurposeAgent.ts` | GENERAL_PURPOSE_AGENT | 通用子 Agent |
| `statuslineSetup.ts` | STATUSLINE_SETUP_AGENT | 状态栏设置 |
| `exploreAgent.ts` | EXPLORE_AGENT | 代码库探索 |
| `planAgent.ts` | PLAN_AGENT | 任务规划 |
| `claudeCodeGuideAgent.ts` | CLAUDE_CODE_GUIDE_AGENT | Claude Code 使用指南 |
| `verificationAgent.ts` | VERIFICATION_AGENT | 验证 Agent |
| `forkSubagent.ts` | FORK_AGENT | Fork 子 Agent |
| `coordinator/workerAgent.ts` | COORDINATOR_WORKER_AGENT | Coordinator 工作节点 |

```typescript
export function getBuiltInAgents(): AgentDefinition[] {
  const agents = [
    GENERAL_PURPOSE_AGENT,   // 通用子 Agent
    STATUSLINE_SETUP_AGENT, // 状态栏设置
  ]

  // EXPLORE/PLAN agents 默认关闭，需 feature flag 控制
  if (areExplorePlanAgentsEnabled()) {
    agents.push(EXPLORE_AGENT, PLAN_AGENT)
  }

  // CLAUDE_CODE_GUIDE_AGENT 仅在非 SDK 入口点时包含
  // SDK 入口点 (sdk-ts, sdk-py, sdk-cli) 不显示指南 agent
  const isNonSdkEntrypoint =
    process.env.CLAUDE_CODE_ENTRYPOINT !== 'sdk-ts' &&
    process.env.CLAUDE_CODE_ENTRYPOINT !== 'sdk-py' &&
    process.env.CLAUDE_CODE_ENTRYPOINT !== 'sdk-cli'

  if (isNonSdkEntrypoint) {
    agents.push(CLAUDE_CODE_GUIDE_AGENT)
  }

  // VERIFICATION_AGENT 由 feature flag 控制
  if (feature('VERIFICATION_AGENT') && growthbook('tengu_hive_evidence')) {
    agents.push(VERIFICATION_AGENT)
  }

  // COORDINATOR_MODE: 多 worker 协调模式
  if (feature('COORDINATOR_MODE')) {
    if (isEnvTruthy(process.env.CLAUDE_CODE_COORDINATOR_MODE)) {
      agents.push(getCoordinatorAgents())
    }
  }

  return agents
}
```

**Built-in Agent 启用条件**：
| Agent | 默认状态 | 控制方式 |
|-------|----------|----------|
| GENERAL_PURPOSE_AGENT | 始终启用 | - |
| STATUSLINE_SETUP_AGENT | 始终启用 | - |
| EXPLORE_AGENT | 关闭 | `BUILTIN_EXPLORE_PLAN_AGENTS` feature + `tengu_amber_stoat` |
| PLAN_AGENT | 关闭 | 同上 |
| CLAUDE_CODE_GUIDE_AGENT | 启用（非 SDK） | 仅 `sdk-ts/py/cli` 入口时禁用 |
| VERIFICATION_AGENT | 关闭 | `VERIFICATION_AGENT` feature + `tengu_hive_evidence` |
| FORK_AGENT | 启用 | `FORK_SUBAGENT` feature |
| COORDINATOR_WORKER_AGENT | 关闭 | `COORDINATOR_MODE` feature |

**One-Shot Agent**:
```typescript
// Explore 和 Plan 是 one-shot agent，不会被 SendMessage 继续
export const ONE_SHOT_BUILTIN_AGENT_TYPES = new Set(['Explore', 'Plan'])
```

**Explore/Plan Agent Model 配置**：
- Explore/Plan agents 读取 `omitClaudeMd` 字段，省略 CLAUDE.md 上下文以节省 token
- 模型配置: `explore: haiku (非ANT) / inherit (ANT) | plan: inherit`

**Fork Agent 特性**:
- `maxTurns`: 200
- `permissionMode`: 'bubble'
- 继承父级的完整对话上下文

### Agent 与 Skill 的区别

| 维度 | Skill | Agent |
|------|-------|-------|
| 用途 | 单一任务 | 复杂工作流 |
| 上下文 | 共享主会话 | 独立上下文 |
| 工具限制 | 可限制 | 可限制 |
| 执行方式 | 内联/fork | 子 Agent |
| 触发 | `/skill-name` | `AgentTool` |

---

## Agent 定义结构

基于 `src/tools/AgentTool/loadAgentsDir.ts` 的类型定义：

### BaseAgentDefinition

```typescript
interface BaseAgentDefinition {
  // 必需字段
  agentType: string          // Agent 唯一标识
  whenToUse: string          // 使用场景描述

  // 工具配置
  tools?: string[]           // 允许的工具列表
  disallowedTools?: string[]  // 禁止的工具列表

  // 模型与性能
  model?: string             // 指定模型
  effort?: EffortValue       // 努力级别
  permissionMode?: PermissionMode  // 权限模式（可选）

  // MCP 配置
  mcpServers?: AgentMcpServerSpec[]  // MCP 服务器
  requiredMcpServers?: string[]      // 必需的 MCP 服务器名称

  // 钩子
  hooks?: HooksSettings      // 关联 Hooks

  // 执行控制
  maxTurns?: number         // 最大轮次
  background?: boolean       // 后台运行

  // 技能
  skills?: string[]          // 预加载技能

  // 提示词
  initialPrompt?: string    // 初始提示词
  criticalSystemReminder_EXPERIMENTAL?: string  // 每轮用户消息重新注入的系统提示

  // 记忆
  memory?: AgentMemoryScope // 记忆范围
  pendingSnapshotUpdate?: { snapshotTimestamp: string }  // 等待更新的快照

  // 隔离
  isolation?: 'worktree' | 'remote'  // 隔离模式 (remote 仅 ant)

  // 特殊选项
  omitClaudeMd?: boolean    // 省略 CLAUDE.md (Explore/Plan agents 默认)
  color?: AgentColorName    // Agent 颜色

  // 元数据 (内部字段，由 loader 填充，不属于 frontmatter)
  /** @internal 原始文件名（loader 填充） */
  filename?: string
  /** @internal 基础目录（loader 填充） */
  baseDir?: string
}
```

> 注意: `prompt` 字段仅存在于 JSON 格式（`--agents` CLI 参数），Markdown 文件的提示词来自正文内容

### Agent 定义来源

```typescript
// 内置 Agent - 动态提示词
type BuiltInAgentDefinition = BaseAgentDefinition & {
  source: 'built-in'
  baseDir: 'built-in'
  callback?: () => void
  getSystemPrompt: (params) => string  // 动态生成
}

// 自定义 Agent - 来自配置
type CustomAgentDefinition = BaseAgentDefinition & {
  source: SettingSource  // 'userSettings' | 'projectSettings' | 'policySettings' | 'flagSettings' | 'built-in' | 'plugin'
  getSystemPrompt: () => string
}

// 插件 Agent - 来自插件
type PluginAgentDefinition = BaseAgentDefinition & {
  source: 'plugin'
  plugin: string          // 插件名称
  getSystemPrompt: () => string
}
```

### Agent 来源优先级

基于 `src/tools/AgentTool/loadAgentsDir.ts` 的 `getActiveAgentsFromList`：

```typescript
// Agent 优先级（后者覆盖前者）
const agentGroups = [
  builtInAgents,    // 优先级最低
  pluginAgents,
  userAgents,       // ~./agents/
  projectAgents,    // ./.claude/agents/
  flagAgents,      // --agents CLI 参数
  managedAgents,   // policySettings (最高优先级)
]
```

**优先级顺序（低 → 高）**：
```
built-in < plugin < user < project < flag < managed
```

**来源详解**：
| 来源 | SettingSource | 配置位置 |
|------|--------------|----------|
| built-in | `built-in` | Claude Code 内置 |
| plugin | `plugin` | 插件提供 |
| user | `userSettings` | `~/.claude/agents/*.md` 或 `settings.json` |
| project | `projectSettings` | `.claude/agents/*.md` 或项目 settings |
| flag | `flagSettings` | `--agents` CLI 参数 |
| policy | `policySettings` | 企业策略托管 |

---

## Agent YAML Frontmatter 字段详解

```markdown
---
# 必需字段
name: reviewer
description: 代码审查专家

# 工具配置
tools:
  - Read
  - Grep
  - Glob
  - Edit
disallowedTools:
  - Bash(rm *)
  - Bash(sudo *)

# 模型与性能
model: sonnet           # 指定模型，或 "inherit" 继承父 Agent
effort: medium          # 努力级别: low/medium/high 或整数

# 权限模式
permissionMode: acceptEdits  # default/plan/acceptEdits/dontAsk/bypassPermissions/auto

# MCP 配置
mcpServers:             # MCP 服务器配置
  - github              # 引用已有服务器
  - slack               # 或内联定义: { slack: { command: "npx", args: [...] } }
requiredMcpServers:     # 必需的 MCP 服务器
  - database

# 执行控制
maxTurns: 50            # 最大 agentic 轮次
background: false      # 始终后台运行
isolation: worktree    # worktree(外部) 或 worktree/remote(ant)

# 技能预加载
skills:                 # 预加载的技能列表
  - code-review
  - security-check

# 提示词配置
initialPrompt: 请仔细审查代码的每个细节  # 添加到首轮用户消息

# 记忆配置
memory: project         # user/project/local - 持久化记忆范围

# Agent 级别 Hooks
hooks:                  # Session 级别的 hooks
  PreToolUse:
    - matcher: "Bash"
      hooks:
        - type: command
          command: "./hooks/security-check.sh"
          timeout: 5

# 显示配置
color: blue             # Agent 在 UI 中的显示颜色

# 特殊选项
omitClaudeMd: false     # 跳过 CLAUDE.md 层级（Explore/Plan 默认 true）
---
```

### 必需字段

| 字段 | 类型 | 说明 |
|------|------|------|
| `name` | string | Agent 唯一标识符 |
| `description` | string | Agent 功能描述 |

### 工具配置

| 字段 | 类型 | 说明 |
|------|------|------|
| `tools` | string[] | 允许的工具列表（白名单） |
| `disallowedTools` | string[] | 禁止的工具列表（黑名单） |

**规则语法**：
- `ToolName` - 整个工具
- `ToolName(operation)` - 特定操作
- `ToolName(!operation)` - 排除操作

### 模型与性能

| 字段 | 类型 | 说明 |
|------|------|------|
| `model` | string | 指定模型，或 `inherit` 继承父 Agent |
| `effort` | string \| number | 努力级别: `low`/`medium`/`high` 或整数 |

### 权限模式

| 字段 | 类型 | 说明 |
|------|------|------|
| `permissionMode` | string | 见下方权限模式列表 |

**PermissionMode 列表**：
- `default` - 每次询问用户
- `plan` - Plan Mode，只读模式
- `acceptEdits` - 自动接受所有编辑
- `dontAsk` - 静默允许/拒绝
- `bypassPermissions` - 绕过所有权限检查
- `auto` - 自动模式（ant-only）

### MCP 配置

| 字段 | 类型 | 说明 |
|------|------|------|
| `mcpServers` | array | MCP 服务器列表（引用或内联） |
| `requiredMcpServers` | string[] | Agent 可用的必需服务器模式 |

```yaml
# 引用已有服务器
mcpServers:
  - github
  - filesystem

# 内联配置
mcpServers:
  - slack:
      command: npx
      args: ["-y", "@modelcontextprotocol/server-slack"]
```

### 执行控制

| 字段 | 类型 | 说明 |
|------|------|------|
| `maxTurns` | number | 最大 agentic 轮次后停止 |
| `background` | boolean | 始终后台运行 |
| `isolation` | string | `worktree`(外部) 或 `worktree`/`remote`(ant) |

### 技能预加载

| 字段 | 类型 | 说明 |
|------|------|------|
| `skills` | string[] | Agent 启动时预加载的技能列表 |

### 提示词配置

| 字段 | 类型 | 说明 |
|------|------|------|
| `initialPrompt` | string | 添加到首轮用户消息的前缀 |

### 记忆配置

| 字段 | 类型 | 说明 |
|------|------|------|
| `memory` | string | 持久化记忆范围: `user`/`project`/`local` |

### Agent Hooks

| 字段 | 类型 | 说明 |
|------|------|------|
| `hooks` | object | Session 级别的 hooks，Agent 启动时注册 |

**支持的事件**：`PreToolUse`, `PostToolUse`, `UserPromptSubmit`, `UserPromptEdit`, `MessageCreate`, `AgentStart`, `AgentEnd`

```yaml
hooks:
  PreToolUse:
    - matcher: "Bash"
      hooks:
        - type: command
          command: "./hooks/security-check.sh"
          timeout: 5
  AgentEnd:
    - matcher: "*"
      hooks:
        - type: agent
          prompt: "验证任务完成情况"
          timeout: 60
```

### 显示配置

| 字段 | 类型 | 说明 |
|------|------|------|
| `color` | string | Agent 在 UI 中的显示颜色 |

### 特殊选项

| 字段 | 类型 | 说明 |
|------|------|------|
| `omitClaudeMd` | boolean | 跳过 CLAUDE.md 层级（节省 token） |

### 注意事项

1. **`system_prompt` 不是 frontmatter 字段** - Markdown 文件的提示词来自文件正文内容
2. **`allowed_tools` 已废弃** - 请使用 `tools`
3. **`disallowed_tools` 已废弃** - 请使用 `disallowedTools`
4. **`requiredMcpServers`** - 支持在任何 Agent 配置中设置（包括用户自定义 Agent）

---

## Agent 文件格式（旧版参考）

```json
// settings.json
{
  "agents": {
    "reviewer": {
      "description": "代码审查专家",
      "tools": ["Read", "Grep", "Glob", "Edit"],
      "disallowedTools": ["Bash(rm *)", "Bash(sudo *)"],
      "prompt": "你是一个专业的代码审查专家...",
      "model": "sonnet",
      "skills": ["security-check", "best-practices"]
    }
  }
}
```

---

## Agent 配置详解

### 1. 工具配置

```json
{
  "tools": ["Read", "Grep", "Glob"],
  "disallowedTools": ["Bash(rm *)", "Bash(sudo *)", "Write"]
}
```

**规则语法**：
- `ToolName` - 整个工具
- `ToolName(operation)` - 特定操作
- `ToolName(!operation)` - 排除操作

### 2. 模型配置

```json
{
  "model": "sonnet",
  "model": "opus",
  "model": "inherit"  // 继承父 Agent 模型
}
```

### 3. 努力级别

```json
{
  "effort": "low",      // 快速响应
  "effort": "medium",   // 平衡
  "effort": "high"      // 深入分析
}
```

### 4. 权限模式

Agent 可以通过 `permissionMode` 字段在 frontmatter 中设置权限模式：

```yaml
---
name: reviewer
permissionMode: acceptEdits
---
```

也可以通过 settings.json 全局配置：

```json
// settings.json
{
  "permissions": {
    "defaultMode": "default"
  }
}
```

**permissionMode vs permissions.defaultMode**:
- `permissionMode`（agent 级别）: 在 agent frontmatter 或 settings.json 的 agents.*.permissionMode 中设置，仅影响该 agent
- `permissions.defaultMode`（全局级别）: 在 settings.json 顶层设置，影响整个会话的默认权限模式

**完整 PermissionMode 列表**（`src/types/permissions.ts`）：
- `default` - 每次询问用户
- `plan` - Plan Mode，只读模式，禁止写文件
- `acceptEdits` - 自动接受所有编辑
- `dontAsk` - 静默允许/拒绝，不显示提示
- `bypassPermissions` - 绕过所有权限检查
- `auto` - 自动模式（需 TRANSCRIPT_CLASSIFIER feature，ant-only）

### 5. MCP 服务器

```json
{
  "mcpServers": ["github", "filesystem"],
  "mcpServers": [{ "slack": { "command": "npx", "args": ["-y", "..."] } }]
}
```

### 6. 隔离模式

```json
{
  "isolation": "worktree"  // 在独立 git worktree 中运行
}
```

**注意**：`remote` 隔离模式仅限 ant (内部用户) 使用。

### 7. 记忆配置

```json
{
  "memory": "user",      // 用户级别记忆
  "memory": "project",   // 项目级别记忆
  "memory": "local"      // 本地会话记忆
}
```

### 8. Agent 优先级/覆盖机制

多个来源定义同名 Agent 时的覆盖规则：

```
builtInAgents < pluginAgents < userAgents < projectAgents < flagAgents < managedAgents
```

**实际行为**：
- 优先级高的 Agent 定义会完全覆盖低的同名 Agent
- 通过 `getActiveAgentsFromList()` 实现去重
- managedAgents (policySettings) 最高，可覆盖 CLI `--agents` 传入的 flagAgents
- 使用 `Map` 保留最后一个出现的定义

```typescript
// 示例：settings.json 中的 agent 会覆盖 .md 文件中的同名定义
// .claude/agents/reviewer.md (user level)
// settings.json { "agents": { "reviewer": {...} } } (project level)
// → 最终使用 settings.json 中的定义
```

---

## Agent 生命周期

```
┌─────────────────────────────────────────────────────────┐
│                    Agent 生命周期                         │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  1. 创建 (AgentTool.call)                               │
│     ├── 解析 Agent 定义                                  │
│     ├── 验证工具权限                                     │
│     └── 初始化上下文                                     │
│                                                         │
│  2. 执行 (runAgent.ts)                                  │
│     ├── 加载系统提示词                                   │
│     ├── 注册会话 Hooks                                  │
│     ├── 预加载 Skills                                   │
│     └── 启动子进程/线程                                 │
│                                                         │
│  3. 运行                                                │
│     ├── 循环执行                                         │
│     ├── 工具调用                                         │
│     └── 响应生成                                         │
│                                                         │
│  4. 结束                                                │
│     ├── 触发 Stop Hook                                  │
│     ├── 保存记忆快照                                     │
│     └── 返回结果                                         │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

---

## 使用方式

### 1. CLI 指定

```bash
# 使用指定 Agent
claude --agent reviewer

# 自定义 Agents
claude --agents '{"reviewer":{"description":"代码审查","prompt":"你是审查专家..."}}'
```

### 2. 调用子 Agent

```typescript
// 使用 AgentTool 启动子 Agent
await agent({
  name: "reviewer",
  prompt: "审查 src/ 目录的代码"
})
```

### 3. 在 Skill 中指定

```yaml
---
name: sql-review
agent: dba
---

执行 SQL 代码审查...
```

---

## 配置示例

### 1. 代码审查 Agent

```json
{
  "agents": {
    "reviewer": {
      "description": "代码审查专家",
      "tools": ["Read", "Grep", "Glob"],
      "disallowedTools": ["Bash(rm *)", "Bash(sudo *)"],
      "model": "sonnet",
      "skills": ["security-check", "best-practices"]
    }
  }
}
```

### 2. 探索 Agent

```json
{
  "agents": {
    "explorer": {
      "description": "代码库探索专家",
      "tools": ["Read", "Grep", "Glob"],
      "disallowedTools": ["Bash(*)", "Write", "Edit"],
      "model": "sonnet",
      "maxTurns": 20,
      "memory": "project"
    }
  }
}
```

### 3. 数据库专家 Agent

```json
{
  "agents": {
    "dba": {
      "description": "数据库专家",
      "tools": ["Bash(psql:*)", "Read", "Glob"],
      "mcpServers": ["database"],
      "requiredMcpServers": ["database"],
      "prompt": "你专注于数据库设计、SQL 优化..."
    }
  }
}
```

---

## 最佳实践

### 1. 工具限制

```json
// ✅ 最小权限原则
{
  "tools": ["Read", "Grep"],
  "disallowedTools": ["Bash(*)", "Write", "Edit"]
}

// ✅ 精确限制
{
  "tools": ["Bash(git *)", "Bash(npm *)", "Read", "Glob"]
}
```

### 2. 场景描述

```markdown
# ✅ 详细的使用场景
whenToUse: |
  当需要进行代码审查时使用。
  适用场景：
  - PR 审查
  - 代码合并前检查
  - 重要变更审查

# ❌ 模糊描述
whenToUse: "审查代码"
```

### 3. 资源控制

```json
// ✅ 限制执行轮次
{
  "maxTurns": 50
}

// ✅ 强制后台运行
{
  "background": true
}
```

---

## 调试 Agent

### 查看可用 Agents

```bash
claude agents list
```

### 测试 Agent

```bash
# 使用指定 Agent
claude --agent reviewer -p "审查这段代码"
```

### 调试模式

```bash
claude --debug agent
```

---

## 未文档化的 Agent 功能

### Fork Subagent Feature (`FORK_SUBAGENT`)

当启用 `FORK_SUBAGENT` feature 时，省略 `subagent_type` 会触发隐式 fork：
- Fork agents 继承父级的完整对话上下文
- 使用 `permissionMode: 'bubble'`
- 默认 `maxTurns: 200`
- Fork 子级有严格的输出格式要求 (Scope:, Result:, etc.)

### Coordinator Mode (`COORDINATOR_MODE`)

主 agent 成为协调者编排 worker agents：
- Workers 通过 `Agent(subagent_type: "worker")` spawn
- 使用 `SEND_MESSAGE_TOOL_NAME` 继续 workers
- Workers 工具访问基于 `ASYNC_AGENT_ALLOWED_TOOLS`
- 可选提供 scratchpad 目录给 workers

### Agent Swarms / Teams (`ENABLE_AGENT_SWARMS`)

多 agent 系统包括：
- **TeamCreateTool**: 创建团队 + 任务列表
- **spawnTeammate()**: 在 tmux/iTerm2 窗格或进程内 spawn teammates
- **进程内 teammates**: 使用 AsyncLocalStorage 在同一 Node.js 进程中运行
- **Mailbox 系统**: 基于文件的 agent 间通信
- **权限桥接**: teammates 可以向 leader 请求权限

### criticalSystemReminder_EXPERIMENTAL

在每个用户轮次重新注入的简短消息：

```typescript
criticalSystemReminder_EXPERIMENTAL?: string
```

由 `VERIFICATION_AGENT` 使用：
```typescript
criticalSystemReminder_EXPERIMENTAL:
  'CRITICAL: This is a VERIFICATION-ONLY task...'
```

### Verification Agent Nudge (`tengu_hive_evidence`)

当完成 3+ 任务而没有验证步骤时，系统会提示启动验证 agent：

**触发条件**：
1. `VERIFICATION_AGENT` feature 已启用
2. `tengu_hive_evidence` feature 已启用
3. 主会话（非子 agent）
4. 刚完成 3+ 个任务
5. 这些任务中没有验证步骤

**提示消息**：
```
NOTE: You just closed out 3+ tasks and none of them was a verification step.
Before writing your final summary, spawn the verification agent (subagent_type="verification").
You cannot self-assign PARTIAL by listing caveats in your summary — only the verifier issues a verdict.
```

**涉及的源文件**：
- `src/tools/TodoWriteTool/TodoWriteTool.ts` - V1 会话提示
- `src/tools/TaskUpdateTool/TaskUpdateTool.ts` - V2 会话提示

### Agent Memory Snapshots

具有 `memory: 'user'` 的 agents 可以有 memory snapshots：
- 快照存储在 `~/.claude/agent-memory/` (user)
- `.claude/agent-memory/` (project)
- `.claude/agent-memory-local/` (local)

### omitClaudeMd Flag

排除 CLAUDE.md 层级从 agent 的上下文中以节省 tokens：
- Kill-switch: `tengu_slim_subagent_claudemd`

### Auto-Background Feature

通过 feature flag 或环境变量启用后，agents 可以在 2 分钟后自动后台化：
```typescript
if (isEnvTruthy(process.env.CLAUDE_AUTO_BACKGROUND_TASKS) ||
    getFeatureValue_CACHED_MAY_BE_STALE('tengu_auto_background_agents', false)) {
  return 120_000;  // 2 minutes
}
```

### Async Agent 工具限制

Async agents 有硬编码的工具白名单：
```typescript
export const ASYNC_AGENT_ALLOWED_TOOLS = new Set([
  FILE_READ_TOOL_NAME,
  WEB_SEARCH_TOOL_NAME,
  TODO_WRITE_TOOL_NAME,
  GREP_TOOL_NAME,
  WEB_FETCH_TOOL_NAME,
  GLOB_TOOL_NAME,
  ...SHELL_TOOL_NAMES,
  FILE_EDIT_TOOL_NAME,
  FILE_WRITE_TOOL_NAME,
  NOTEBOOK_EDIT_TOOL_NAME,
  SKILL_TOOL_NAME,
  SYNTHETIC_OUTPUT_TOOL_NAME,
  TOOL_SEARCH_TOOL_NAME,
  ENTER_WORKTREE_TOOL_NAME,
  EXIT_WORKTREE_TOOL_NAME,
])
```

Async agents 不能使用 `AgentTool`（会导致递归）。

### Agent 定义未文档化字段

```typescript
interface BaseAgentDefinition {
  criticalSystemReminder_EXPERIMENTAL?: string
  pendingSnapshotUpdate?: { snapshotTimestamp: string }
  requiredMcpServers?: string[]
  omitClaudeMd?: boolean
  background?: boolean
  initialPrompt?: string
  color?: string
}
```

### AgentTool 运行时参数

```typescript
{
  description: string,
  prompt: string,
  subagent_type?: string,
  model?: 'sonnet' | 'opus' | 'haiku',
  run_in_background?: boolean,
  name?: string,           // teammate 名称
  team_name?: string,      // 团队名称
  mode?: PermissionMode,   // spawn 权限模式
  isolation?: 'worktree' | 'remote',
  cwd?: string,            // KAIROS 专用
}
```

---

## 测试验证

运行测试脚本验证 Agent 配置：
```bash
bash tests/04-agents-test.sh
```
