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

**Explore/Plan Agent Model 配置**：
- Explore/Plan agents 读取 `omitClaudeMd` 字段，省略 CLAUDE.md 上下文以节省 token
- 模型配置: `explore: haiku (非ANT) / inherit (ANT) | plan: inherit`

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

  // 权限与安全
  permissionMode?: PermissionMode  // 权限模式

  // MCP 配置
  mcpServers?: AgentMcpServerSpec[]  // MCP 服务器
  requiredMcpServers?: string[]      // 必需的 MCP 服务器名称（仅限内置 Agent，不支持用户配置）
  // 注意: requiredMcpServers 只能在内置 Agent 代码中设置，无法通过用户 markdown/JSON 配置

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
  source: SettingSource  // 'user' | 'project' | 'policy' | 'local'
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

## Agent 文件格式

### YAML Frontmatter 格式

```markdown
---
name: reviewer
description: 代码审查专家
whenToUse: 当需要进行代码审查时使用
tools:
  - Read
  - Grep
  - Glob
  - Edit
disallowedTools:
  - Bash(rm *)
  - Bash(sudo *)
model: sonnet
effort: medium
permissionMode: default
mcpServers:
  - github
skills:
  - code-review
maxTurns: 50
background: false
initialPrompt: 请仔细审查代码的每个细节
color: blue
---

# 代码审查 Agent

你是一个专业的代码审查专家，负责审查代码质量和最佳实践。

## 审查标准

### 1. 代码质量
- 可读性
- 可维护性
- 性能考虑

### 2. 安全检查
- 注入风险
- 敏感信息暴露
- 权限控制
```

### JSON 配置格式

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

```json
{
  "permissionMode": "default",       // 每次询问
  "permissionMode": "plan",         // 计划模式（只读探索）
  "permissionMode": "acceptEdits",  // 自动接受编辑
  "permissionMode": "dontAsk",      // 不询问（静默允许/拒绝）
  "permissionMode": "bypassPermissions"  // 绕过所有权限检查
}
```

**完整 PermissionMode 列表**（`src/types/permissions.ts`）：
- `default` - 每次询问用户
- `plan` - Plan Mode，只读模式，禁止写文件
- `acceptEdits` - 自动接受所有编辑
- `dontAsk` - 静默允许/拒绝，不显示提示
- `bypassPermissions` - 绕过所有权限检查
- `auto` - 自动模式（需 feature `TRANSCRIPT_CLASSIFIER`，ant-only）

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

## 测试验证

运行测试脚本验证 Agent 配置：
```bash
bash tests/04-agents-test.sh
```
