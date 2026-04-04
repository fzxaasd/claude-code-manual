# Agent Memory System（Agent 记忆系统）

> 基于源码 `src/tools/AgentTool/agentMemory.ts`, `src/tools/AgentTool/agentMemorySnapshot.ts` 深度分析

## 概述

Agent Memory System 是与 Auto Memory 并行的独立持久化记忆系统，专门为 Agent 设计。它允许每个 Agent 类型维护自己的记忆，支持三种作用域级别。

```
┌────────────────────────────────────────────────────────────┐
│                   Memory 系统架构                            │
├────────────────────────────────────────────────────────────┤
│                                                            │
│  Auto Memory                                              │
│  ├── 路径: ~/.claude/projects/{project}/memory/           │
│  ├── 作用域: 项目级                                       │
│  └── 适用: 所有任务的共享记忆                              │
│                                                            │
│  Agent Memory                                             │
│  ├── 路径: .claude/agent-memory/{agentType}/             │
│  ├── 作用域: user / project / local                      │
│  └── 适用: Agent 特定的持久化知识                          │
│                                                            │
└────────────────────────────────────────────────────────────┘
```

---

## 与 Auto Memory 的区别

| 特性 | Auto Memory | Agent Memory |
|------|------------|-------------|
| 范围 | 项目级 | Agent 级 |
| 作用域 | 单一 | user / project / local 三种 |
| Team 共享 | 通过 team 子目录 | 通过 project scope |
| Snapshot | 不支持 | 支持 |
| Daily Log | 支持 (KAIROS) | 不支持 |
| 背景提取 | 支持 | 不支持 |
| 记忆格式 | MEMORY.md + 主题文件 | MEMORY.md + 主题文件 |

---

## 核心 API

### 类型定义

```typescript
export type AgentMemoryScope = 'user' | 'project' | 'local'
```

### 路径获取

```typescript
// Local Scope: 本机专用，不版本控制
getLocalAgentMemoryDir(agentType): string
// 路径: <cwd>/.claude/agent-memory-local/<agentType>/
// 或 (Cowork): <CLAUDE_CODE_REMOTE_MEMORY_DIR>/projects/<project>/agent-memory-local/<agentType>/

// Project Scope: 版本控制，团队共享
getAgentMemoryDir(agentType): string
// 路径: <cwd>/.claude/agent-memory/<agentType>/

// User Scope: 跨项目，全局
getAgentMemoryDir(agentType): string
// 路径: <memoryBase>/agent-memory/<agentType>/

// 记忆入口文件
getAgentMemoryEntrypoint(agentType, scope): string
// 路径: <agentMemoryDir>/MEMORY.md
```

### 路径检查

```typescript
export function isAgentMemoryPath(absolutePath: string): boolean
```

检查路径是否在 Agent Memory 目录中，支持三种作用域的路径检查。

### 提示构建

```typescript
export function loadAgentMemoryPrompt(
  agentType: string,
  scope: AgentMemoryScope,
): string
```

加载 Agent 的持久化记忆提示，包含作用域特定的指导说明。

### 作用域显示

```typescript
export function getMemoryScopeDisplay(
  memory: AgentMemoryScope | undefined,
): string
```

返回作用域的可读描述。

---

## 三种作用域详解

### 1. User Scope

**路径**: `~/.claude/agent-memory/<agentType>/`

**特性**:
- 跨项目共享
- 不版本控制
- 存储通用知识

**Scope 提示**:
```
keep learnings general since they apply across all projects
```

**适用场景**:
- Agent 的核心能力描述
- 通用最佳实践
- 跨项目一致的指导

### 2. Project Scope

**路径**: `<cwd>/.claude/agent-memory/<agentType>/`

**特性**:
- 每个项目独立
- 版本控制共享
- 团队协作

**Scope 提示**:
```
shared with your team via version control
```

**适用场景**:
- 项目特定的 Agent 定制
- 团队共享的 Agent 知识
- 版本化的 Agent 配置

### 3. Local Scope

**路径**: `<cwd>/.claude/agent-memory-local/<agentType>/`

**特性**:
- 本机专用
- 不版本控制
- 本地机器特定

**Scope 提示**:
```
not checked into version control, tailor to this machine
```

**适用场景**:
- 本机特定路径配置
- 本地开发环境适配
- 私密信息存储

---

## 记忆格式

Agent Memory 使用与 Auto Memory 相同的格式：

```markdown
---
name: agent-capability-notes
description: 关键能力说明
type: user
---

# Agent 能力说明

## 核心能力
- 自动化测试
- 代码审查
- 文档生成

## 限制
- 不执行破坏性操作
- 始终验证输入
```

---

## Snapshot 功能

Agent Memory 支持快照同步，用于在多台机器间同步 Agent 配置。

**文件**: `src/tools/AgentTool/agentMemorySnapshot.ts`

### 目录结构

```
<cwd>/.claude/agent-memory-snapshots/<agentType>/
├── snapshot.json        # 快照元数据
└── .snapshot-synced.json  # 同步元数据
```

### 核心函数

| 函数 | 功能 |
|------|------|
| `getSnapshotDirForAgent()` | 获取快照目录路径 |
| `checkAgentMemorySnapshot()` | 检查快照是否存在及是否需要同步 |
| `initializeFromSnapshot()` | 从快照初始化本地记忆 |
| `replaceFromSnapshot()` | 用快照替换本地记忆 |
| `markSnapshotSynced()` | 标记快照已同步 |

### 同步条件

- 本地无记忆文件时 → 初始化
- 快照时间戳新于上次同步时间 → 更新

---

## Cowork 集成

### 环境变量

| 变量 | 用途 |
|------|------|
| `CLAUDE_CODE_REMOTE_MEMORY_DIR` | 远程记忆存储根目录 |
| `CLAUDE_COWORK_MEMORY_EXTRA_GUIDELINES` | 额外的 Agent 记忆指导文本 |

### Cowork 设置文件

```typescript
function getSettingsFilename(): string {
  if (useCoworkPlugins()) {
    return 'cowork_settings.json'  // Cowork 模式
  }
  return 'settings.json'          // 普通模式
}
```

### Cowork Plugins 目录

```typescript
const COWORK_PLUGINS_DIR = 'cowork_plugins'
```

---

## 安全特性

### 路径遍历防护

- `normalize()` 解析 `..` 段
- 前缀匹配检查
- 符号链接解析 (`realpathDeepestExisting()`)

### 危险模式拒绝

以下路径模式会被拒绝（来自 `validateMemoryPath()` in `paths.ts`，非 agentMemory 模块自身）：
- 相对路径 (`../foo`)
- 根/近根路径 (长度 < 3)
- Windows 驱动器根 (`C:\`)
- UNC 路径 (`\\server\share`)
- 空字节 (`\0`)

> **注意**: agentMemory 模块本身使用更简单的 `normalize()` + 前缀匹配检查，完整路径验证由 `paths.ts` 的 `validateMemoryPath()` 提供。

### Agent Type 路径处理

```typescript
function sanitizeAgentTypeForPath(agentType: string): string {
  return agentType.replace(/:/g, '-')
}
```

插件名称空间的代理类型 (如 `my-plugin:my-agent`) 会被 sanitize。

---

## 与 Auto Memory 的协同

Agent Memory 和 Auto Memory 可以同时使用：

```typescript
// Auto Memory: 共享的项目记忆
<memoryBase>/projects/<project>/memory/

// Agent Memory: Agent 特定的记忆
<memoryBase>/agent-memory/<agentType>/
```

两者使用相同的 MEMORY.md 格式，可以互补：
- Auto Memory: 团队共享的项目知识
- Agent Memory: Agent 特定的个性化配置

---

## 使用示例

### 创建 Agent Memory

```markdown
# .claude/agent-memory/my-agent/MEMORY.md

---
name: my-agent-knowledge
description: My Agent 的核心知识
type: user
---

# My Agent 配置

## 专业领域
- Python 后端开发
- 数据库设计
- API 设计

## 工作风格
- 先理解需求
- 提供多种方案
- 重视代码质量
```

### Project Scope 记忆

```markdown
# .claude/agent-memory/project-assistant/MEMORY.md
# (会被提交到 git，团队共享)

---
name: project-assistant-config
description: 项目助手配置
type: project
---

# 本项目的 Agent 助手配置

## 项目背景
这是一个微服务架构项目

## 技术栈
- Go
- PostgreSQL
- Kubernetes
```

---

## 配置选项

Agent Memory 目前通过以下方式配置：

### 1. 环境变量

```bash
# 设置远程记忆目录
export CLAUDE_CODE_REMOTE_MEMORY_DIR=/path/to/remote/memory

# 设置额外的记忆指导
export CLAUDE_COWORK_MEMORY_EXTRA_GUIDELINES="始终使用 TypeScript 5.0+"
```

### 2. settings.json

当前 Agent Memory 配置主要通过文件路径约定，暂无专门的 settings.json 配置项。

---

## 测试验证

```bash
# 检查 Agent Memory 目录
ls ~/.claude/agent-memory/

# 查看特定 Agent 的记忆
cat ~/.claude/agent-memory/<agent-type>/MEMORY.md

# 检查快照目录
ls .claude/agent-memory-snapshots/
```
