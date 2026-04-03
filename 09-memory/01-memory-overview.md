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

## 在推荐前验证 Memory

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

## Memory 类型值

基于 `MEMORY_TYPE_VALUES` (`memoryTypes.ts`):

```typescript
export const MEMORY_TYPE_VALUES = [
  'User',
  'Project',
  'Local',
  'Managed',
  'AutoMem',
  ...(feature('TEAMMEM') ? (['TeamMem'] as const) : []),
] as const
```

| 类型 | 说明 |
|------|------|
| User | 用户级别记忆 |
| Project | 项目级别记忆 |
| Local | 本机专用记忆 |
| Managed | 管理级别记忆 |
| AutoMem | 自动记忆 |
| TeamMem | 团队记忆（需 TEAMMEM feature） |

---

## Session Memory 配置

基于 `src/services/SessionMemory/sessionMemoryUtils.ts`:

### 触发阈值

| 参数 | 默认值 | 说明 |
|------|--------|------|
| `minimumMessageTokensToInit` | 10000 | 初始化所需的最小 token 数 |
| `minimumTokensBetweenUpdate` | 5000 | 更新之间的最小 token 数 |
| `toolCallsBetweenUpdates` | 3 | 更新之间的最小工具调用数 |

**重要规则**: `minimumTokensBetweenUpdate` 阈值**始终必需**，即使其他条件满足。

### 手动触发

`/summary` 命令可手动触发 session memory 提取，绕过阈值检查。

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

## Team Memory Sync Service

基于 `src/services/teamMemorySync/` 的团队记忆同步服务。

### 核心文件

| 文件 | 功能 |
|------|------|
| `index.ts` | 主服务入口 - Pull/Push/Sync 核心逻辑 |
| `watcher.ts` | 文件监视器 - 监听本地变更并触发同步 |
| `types.ts` | 类型定义和 Zod Schema |
| `secretScanner.ts` | Secret 扫描器 - 上传前检测敏感信息 |
| `teamMemSecretGuard.ts` | Secret 防护 - 写入前拦截 |

---

### API 端点

| 方法 | 端点 | 说明 |
|-----|------|------|
| GET | `/api/claude_code/team_memory?repo={owner/repo}` | 获取完整数据 |
| GET | `/api/claude_code/team_memory?repo={owner/repo}&view=hashes` | 仅获取元数据+checksums |
| PUT | `/api/claude_code/team_memory?repo={owner/repo}` | 上传 entries (upsert语义) |

### 返回类型

```typescript
// 获取结果
type TeamMemorySyncFetchResult = {
  success: boolean
  data?: TeamMemoryData
  isEmpty?: boolean      // true if 404
  notModified?: boolean  // true if 304
  checksum?: string      // ETag
  error?: string
  errorType?: 'auth' | 'timeout' | 'network' | 'parse' | 'unknown'
}

// 上传结果
type TeamMemorySyncPushResult = {
  success: boolean
  filesUploaded: number
  checksum?: string
  conflict?: boolean     // true if 412
  skippedSecrets?: SkippedSecretFile[]
  error?: string
  errorType?: 'auth' | 'timeout' | 'network' | 'conflict' | 'unknown' | 'no_oauth' | 'no_repo'
}
```

---

### Delta Upload 机制

**核心流程**:
```
读取本地文件 → 计算SHA256 → 与serverChecksums比较 → 仅上传delta → 批量上传
```

**关键实现**:
```typescript
// Delta计算
const delta: Record<string, string> = {}
for (const [key, localHash] of localHashes) {
  if (state.serverChecksums.get(key) !== localHash) {
    delta[key] = entries[key]!
  }
}

// 批量上传 (防止超过网关限制)
const batches = batchDeltaByBytes(delta)  // 每批 ≤ 200KB
```

**批量分块参数**:
| 参数 | 值 | 说明 |
|------|-----|------|
| `MAX_PUT_BODY_BYTES` | 200,000 (200KB) | 单次 PUT 请求体上限 |
| `MAX_FILE_SIZE_BYTES` | 250,000 (250KB) | 单文件上限 |

**冲突处理 (412 Precondition Failed)**:
1. 检测到 412 → 探测服务器最新 checksums
2. 重新计算 delta 并重试
3. 最多重试 2 次 (`MAX_CONFLICT_RETRIES = 2`)

---

### Secret Scanning

**扫描时机**:
| 位置 | 时机 |
|------|------|
| `readLocalTeamMemory()` | 读取本地文件准备上传前 |
| `checkTeamMemSecrets()` | FileWriteTool/FileEditTool 写入前 |

**检测规则 (来自 Gitleaks)**:
| 类型 | 规则前缀/后缀 |
|------|----------------|
| 云服务商 | `aws-access-token` (AKIA/ASIA/ABIA/ACCA), `gcp-api-key` (AIza) |
| AI API | `anthropic-api-key` (sk-ant-api), `openai-api-key` (sk-proj) |
| 版本控制 | `github-pat` (ghp_), `github-fine-grained-pat` (github_pat_) |
| 通信平台 | `slack-bot-token` (xoxb-), `slack-user-token` (xoxp-) |
| 开发工具 | `npm-access-token` (npm_), `pypi-upload-token` |
| 可观测性 | `grafana-api-key`, `sentry-user-token` (sntryu_) |
| 私钥 | `private-key` (-----BEGIN.*PRIVATE KEY-----) |

**处理逻辑**:
```typescript
// 发现 secret 后，仅记录规则ID，不记录实际secret
skippedSecrets.push({
  path: relPath,
  ruleId: firstMatch.ruleId,
  label: firstMatch.label,
})
return  // 跳过该文件，不上传
```

---

### 路径结构

```
<memoryBase>/projects/<project>/memory/team/
└── MEMORY.md  (入口文件)
└── patterns.md
└── <subdir>/
    └── ...
```

**注意**: 团队内存是个人内存的**子目录**，而非独立顶层目录。

---

### 常量与配置

| 参数 | 值 | 说明 |
|------|-----|------|
| `TEAM_MEMORY_SYNC_TIMEOUT_MS` | 30,000 | API 请求超时 |
| `MAX_RETRIES` | 3 | 拉取重试次数 |
| `MAX_CONFLICT_RETRIES` | 2 | 冲突重试次数 |
| `DEBOUNCE_MS` | 2,000 | 文件变更防抖延迟 |

**功能开关**:
```typescript
feature('TEAMMEM')              // 构建标志，禁用整个功能
isAutoMemoryEnabled()         // 需要自动记忆启用
isTeamMemoryEnabled()          // 'tengu_herring_clock' 功能标志
isUsingOAuth()                 // 需要第一方 OAuth 认证
```

---

## 未文档化的功能

### autoMemoryDirectory 安全限制

**重要**: `.claude/settings.json` (projectSettings) **不能**设置 `autoMemoryDirectory`，因为恶意仓库可能设置 `autoMemoryDirectory: "~/.ssh"` 来获取静默写权限。只有 policy、flag、local 和 user settings 可以配置此目录。

### CLAUDE_CODE_DISABLE_AUTO_MEMORY 行为

`CLAUDE_CODE_DISABLE_AUTO_MEMORY` 的值有特殊行为：
- `=1` 或 `=true`: 禁用自动记忆
- `=0` 或 `=false`: **强制启用**自动记忆（忽略其他设置）
- 未设置: 使用默认行为

### Agent Memory Snapshots

Agent Memory 有完整的快照同步系统，用于跨机器同步 agent memory：
- 快照存储在 `.claude/agent-memory-snapshots/<agentType>/`
- `checkAgentMemorySnapshot()` - 检查快照
- `initializeFromSnapshot()` - 从快照初始化
- `replaceFromSnapshot()` - 替换为快照
- `markSnapshotSynced()` - 标记已同步

### autoDream 锁机制

autoDream 使用文件锁防止并发冲突：
- 锁文件位置: `<memoryDir>/.consolidate-lock`
- PID-based 锁
- 1 小时过期保护 (`HOLDER_STALE_MS = 60 * 60 * 1000`)
- 失败时支持锁回滚

### Session Memory

Session Memory 是与 Auto Memory 完全独立的系统：
- 在 `<sessionMemoryDir>/session-memory.md` 维护当前会话的笔记
- 运行在分叉的 subagent 上
- 使用 `tengu_sm_config` GrowthBook feature 的阈值
- 默认值: `minimumMessageTokensToInit: 10000`, `minimumTokensBetweenUpdate: 5000`, `toolCallsBetweenUpdates: 3`

### Memory Shape Telemetry

通过 `MEMORY_SHAPE_TELEMETRY` feature flag 启用，记录 memory recall 模式。

### 其他 Secret 扫描规则

除了文档列出的规则外，还有以下未文档化的扫描规则：

| 规则名 | 匹配模式 |
|--------|----------|
| `azure-ad-client-secret` | Azure AD 客户端密钥 |
| `digitalocean-pat` | DigitalOcean PAT |
| `digitalocean-access-token` | DigitalOcean Access Token |
| `anthropic-admin-api-key` | Admin API Keys (`sk-ant-admin01-*`) |
| `github-app-token` | GitHub App Tokens (`ghu_*`, `ghs_*`) |
| `github-oauth` | OAuth Tokens (`gho_*`) |
| `github-refresh-token` | Refresh Tokens (`ghr_*`) |
| `gitlab-pat` | GitLab PAT |
| `gitlab-deploy-token` | GitLab Deploy Token |
| `twilio-api-key` | Twilio API Keys |
| `databricks-api-token` | Databricks Tokens |
| `hashicorp-tf-api-token` | Terraform Cloud Tokens |
| `pulumi-api-token` | Pulumi Tokens |
| `postman-api-token` | Postman API Keys |
| `grafana-cloud-api-token` | Grafana Cloud Tokens |
| `grafana-service-account-token` | Grafana Service Account Tokens |
| `sentry-org-token` | Sentry Organization Tokens |
| `stripe-access-token` | Stripe Keys (`sk_*`, `rk_*`) |
| `shopify-access-token` | Shopify Access Tokens |
| `shopify-shared-secret` | Shopify Shared Secrets |

---

### 安全特性

1. **路径遍历防护** (`teamMemPaths.ts`):
   - Null byte 检测
   - URL 编码检测 (`%2e%2e%2f`)
   - Unicode 规范化攻击防护 (NFKC)
   - Symlink 解析验证

2. **Secret 防护**:
   - 上传前扫描，secret 不离开本地
   - 写入前拦截

3. **OAuth 认证**:
   - 需要 `CLAUDE_AI_INFERENCE_SCOPE` + `CLAUDE_AI_PROFILE_SCOPE`
   - Token 自动刷新

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
