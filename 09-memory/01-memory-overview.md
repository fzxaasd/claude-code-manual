# 9.1 内存系统概述

> 基于 `src/memdir/memoryTypes.ts` 完整源码分析

---

## 核心概念

Memory System 是一种持久化上下文机制，用于在会话之间保留关键信息。

```
Memory = 非衍生信息 × 时间 × 作用域
```

**约束**：Memory 仅存储无法从当前项目状态推导的信息。

---

## 四种 Memory 类型

基于 `MEMORY_TYPES` 常量定义 (`memoryTypes.ts:14-21`)：

| 类型 | Scope | 用途 |
|------|-------|------|
| `user` | always private | 用户角色、目标、偏好 |
| `feedback` | private/team | 工作方式指导 |
| `project` | private/team | 项目上下文、目标、事件 |
| `reference` | usually team | 外部系统指针 |

---

## 类型详解

### user

**Scope**: `always private`

**描述**：包含用户角色、目标、职责和知识的信息。

**保存时机**：
- 了解用户的角色偏好时
- 了解用户的知识背景时
- 了解用户的职责范围时

**使用场景**：
- 回答需要考虑用户背景的问题
- 调整解释深度和类比方式
- 定制协作风格

**示例**：
```markdown
user: I'm a data scientist investigating what logging we have in place
assistant: [saves private user memory: user is a data scientist, currently focused on observability/logging]

user: I've been writing Go for ten years but this is my first time touching the React side of this repo
assistant: [saves private user memory: deep Go expertise, new to React and this project's frontend]
```

---

### feedback

**Scope**: `private` (默认), `team` (项目级约定时)

**描述**：用户给出的工作方式指导，包括需要避免和需要保持的行为。

**保存时机**：
- 用户纠正方法时 ("no not that", "don't", "stop doing X")
- 用户确认方案有效时 ("yes exactly", "perfect, keep doing that")
- 用户接受非常规选择时

**内容结构**：
```markdown
rule/fact

**Why:** [用户给出的原因 — 通常是过去的事件或偏好]

**How to apply:** [何时何地应用此指导]
```

**示例**：
```markdown
user: don't mock the database in these tests — we got burned last quarter when mocked tests passed but the prod migration failed
assistant: [saves team feedback memory: integration tests must hit a real database, not mocks. Reason: prior incident where mock/prod divergence masked a broken migration]

user: stop summarizing what you just did at the end of every response, I can read the diff
assistant: [saves private feedback memory: this user wants terse responses with no trailing summaries]
```

---

### project

**Scope**: `private/team` (强烈倾向 team)

**描述**：关于项目中正在进行的工作、目标、举措、bug 或事件的信息。

**保存时机**：
- 了解谁在做什么、为什么、截止时间
- 状态变化时
- 约束、期限或利益相关方要求时

**重要**：始终将相对日期转换为绝对日期 (`"Thursday" → "2026-03-05"`)

**内容结构**：
```markdown
事实/决策

**Why:** [动机 — 通常是约束、期限或利益相关方要求]

**How to apply:** [如何影响建议]
```

**示例**：
```markdown
user: we're freezing all non-critical merges after Thursday — mobile team is cutting a release branch
assistant: [saves team project memory: merge freeze begins 2026-03-05 for mobile release cut]

user: the reason we're ripping out the old auth middleware is that legal flagged it for storing session tokens
assistant: [saves team project memory: auth middleware rewrite driven by compliance requirements]
```

---

### reference

**Scope**: `usually team`

**描述**：存储外部系统中信息的指针。

**保存时机**：
- 了解外部资源及其用途时
- 学习 bug 在 Linear 项目中跟踪时
- 学习反馈在特定 Slack 频道时

**示例**：
```markdown
user: check the Linear project "INGEST" if you want context on these tickets
assistant: [saves team reference memory: pipeline bugs are tracked in Linear project "INGEST"]

user: the Grafana board at grafana.internal/d/api-latency is what oncall watches
assistant: [saves team reference memory: grafana.internal/d/api-latency is the oncall latency dashboard]
```

---

## Memory 文件格式

### Frontmatter 规范

基于 `MEMORY_FRONTMATTER_EXAMPLE` (`memoryTypes.ts:261-271`)：

```markdown
---
name: {{memory name}}
description: {{one-line description — used to decide relevance in future conversations, so be specific}}
type: {{user, feedback, project, reference}}
---

{{memory content — for feedback/project types, structure as: rule/fact, then **Why:** and **How to apply:** lines}}
```

### MEMORY.md 索引文件

路径结构：`~/.claude/memory/projects/{sanitized-git-root}/memory/MEMORY.md`

MEMORY.md 是索引文件，每行一个指向具体 memory 文件的链接：

```markdown
# Memory Index

- [Title](file.md) — one-line hook
```

**限制**：行数超过 200 行后截断，文件大小超过 25,000 字节时截断

---

## 内存目录结构

```
memory/
├── MEMORY.md           # 索引文件
├── user/              # 用户记忆（always private）
│   └── *.md
├── feedback/          # 反馈记忆（private/team）
│   └── *.md
├── project/           # 项目记忆（private/team）
│   └── *.md
└── reference/         # 参考记忆（usually team）
    └── *.md
```

**注意**：`~/.claude/memory/projects/{project}/memory/` 路径中的 `{project}` 是经过 sanitize 的 git root 路径，同一 git repo 的所有 worktree 共享一个内存目录。

---

## 不应保存的内容

基于 `WHAT_NOT_TO_SAVE_SECTION` (`memoryTypes.ts:183-195`)：

| 类别 | 原因 | 权威来源 |
|------|------|----------|
| 代码模式、架构、约定 | 可从当前项目状态推导 | grep / 读代码 |
| Git 历史、变更记录 | `git log` / `git blame` 是权威来源 | Git |
| 调试方案或修复方法 | 修复在代码中；提交消息有上下文 | 代码本身 |
| CLAUDE.md 中已记录内容 | 已有文档 | CLAUDE.md |
| 临时任务细节 | 进行中的工作、临时状态、当前会话上下文 | - |

### 团队记忆安全警告 ⚠️

**必须避免在共享团队记忆中保存敏感数据**。例如：绝不保存 API keys 或用户凭据。

---

## 高级功能

### 自动内存索引限制

| 限制 | 值 |
|------|-----|
| MEMORY.md 最大行数 | 200 行 |
| MEMORY.md 最大字节 | 25,000 bytes |
| Memory 文件扫描上限 | 200 个文件 |
| Frontmatter 最大行数 | 30 行 |

### AI 驱动的记忆相关性选择

`findRelevantMemories()` 函数使用 Sonnet 模型对扫描的头部进行相关性选择，返回最多 5 个相关记忆。

### 自动内存启用条件

`isAutoMemoryEnabled()` 解析链：

1. `CLAUDE_CODE_DISABLE_AUTO_MEMORY` 环境变量
2. `CLAUDE_CODE_SIMPLE` (`--bare`) → 禁用
3. CCR 无 `CLAUDE_CODE_REMOTE_MEMORY_DIR` → 禁用
4. `settings.json` 中 `autoMemoryEnabled`
5. 默认：启用

**注意**：即使用户明确要求保存以上内容，也应询问"有什么出乎意料或非显而易见的？"那才是值得保留的部分。

---

## 访问时机

基于 `WHEN_TO_ACCESS_SECTION` (`memoryTypes.ts:216-222`)：

| 触发条件 | 行为 |
|----------|------|
| memories 看起来相关时 | 读取 |
| 用户引用之前会话时 | 读取 |
| 用户明确要求检查/回忆/记住时 | 必须读取 |
| 用户说 "ignore" 或 "not use" memory 时 | 忽略，如同 MEMORY.md 为空 |

---

## Memory 过期处理

基于 `MEMORY_DRIFT_CAVEAT` (`memoryTypes.ts:201-202`)：

> Memory 记录可能随时间过期。在根据 memory 记录回答问题或构建假设之前，通过读取文件或资源的当前状态来验证 memory 是否仍然正确。

**原则**：
- 如果 recall 的 memory 与当前信息冲突，相信观察到的现状
- 更新或删除过期的 memory，而不是基于它行动

---

## 信任 Memory 中的信息

基于 `TRUSTING_RECALL_SECTION` (`memoryTypes.ts:240-256`)：

### 在推荐前验证

Memory 中提到的具体 function、file、flag 是**声明**，不是事实：

| Memory 说 | 需要验证 |
|-----------|----------|
| 文件路径存在 | 检查文件是否存在 |
| function 或 flag 存在 | grep 搜索 |
| 用户要采取行动 | 验证后再行动 |

### Repo 状态快照

Memory 总结的 repo 状态（如活动日志、架构快照）是**时间冻结**的。

如果用户问"最近的"或"当前的"状态，优先使用 `git log` 或读代码，而不是回忆快照。

---

## Memory System 架构

```
┌─────────────────────────────────────────────────────────────┐
│                    Memory System                             │
├─────────────────────────────────────────────────────────────┤
│  ~/.claude/memory/projects/{project}/memory/                │
│  ├── MEMORY.md (索引)                                       │
│  ├── user/              # always private                   │
│  │   └── *.md                                               │
│  ├── feedback/          # private 或 team                   │
│  │   └── *.md                                               │
│  ├── project/           # private 或 team                   │
│  │   └── *.md                                               │
│  └── reference/         # usually team                      │
│      └── *.md                                               │
├─────────────────────────────────────────────────────────────┤
│  Frontmatter                                                │
│  ├── name: 内存名称                                         │
│  ├── description: 单行描述                                  │
│  └── type: user/feedback/project/reference                  │
├─────────────────────────────────────────────────────────────┤
│  MemoryTypes (memoryTypes.ts)                               │
│  ├── MEMORY_TYPES = ['user', 'feedback', 'project', 'reference']
│  ├── TYPES_SECTION_COMBINED (private + team)              │
│  └── TYPES_SECTION_INDIVIDUAL (private only)               │
└─────────────────────────────────────────────────────────────┘
```

---

## 测试验证

运行测试脚本验证 Memory 配置：
```bash
bash tests/06-memory-test.sh
```

---

## 下一步

- [9.2 Memory API](./02-memory-api.md) - Memory 操作接口
- [9.3 Memory 最佳实践](./03-memory-best-practices.md) - 使用指南
