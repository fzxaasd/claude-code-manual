# 9.2 Memory API

> 基于源码 `src/memdir/memdir.ts`, `src/memdir/memoryScan.ts`, `src/memdir/paths.ts` 深度分析

## 导出函数概览

```typescript
// src/memdir/memdir.ts
export { buildMemoryPrompt, buildMemoryLines, loadMemoryPrompt }
export { truncateEntrypointContent, ensureMemoryDirExists }
export { findRelevantMemories, type RelevantMemory }
export { buildSearchingPastContextSection }
export { DIR_EXISTS_GUIDANCE, DIRS_EXIST_GUIDANCE }
export { ENTRYPOINT_NAME, MAX_ENTRYPOINT_LINES, MAX_ENTRYPOINT_BYTES }

// src/memdir/paths.ts
export { isAutoMemoryEnabled, getAutoMemPath, getAutoMemDailyLogPath }
export { getAutoMemEntrypoint, getMemoryBaseDir }
export { isAutoMemPath, hasAutoMemPathOverride, isExtractModeActive }

// src/memdir/memoryScan.ts
export { scanMemoryFiles, formatMemoryManifest, type MemoryHeader }

// src/memdir/memoryTypes.ts
export { MEMORY_TYPES, parseMemoryType, type MemoryType }
export { TYPES_SECTION_INDIVIDUAL, TYPES_SECTION_COMBINED }
export { WHAT_NOT_TO_SAVE_SECTION, WHEN_TO_ACCESS_SECTION }
export { TRUSTING_RECALL_SECTION, MEMORY_FRONTMATTER_EXAMPLE }
export { MEMORY_DRIFT_CAVEAT }

// src/memdir/memoryAge.ts
export { memoryAge, memoryAgeDays, memoryFreshnessText, memoryFreshnessNote }

// src/memdir/teamMemPrompts.ts (TEAMMEM feature)
export { buildCombinedMemoryPrompt }
```

---

## 核心 API

### loadMemoryPrompt()

```typescript
async function loadMemoryPrompt(): Promise<string | null>
```

**功能**: 加载统一的内存提示词，用于包含在系统提示词中。

**返回值**:
- 启用时: 返回完整的内存指令字符串
- 禁用时: 返回 `null`，并发送 `tengu_memdir_disabled` 事件

**内部逻辑**:
```typescript
// 优先级判断
if (feature('KAIROS') && autoEnabled && getKairosActive()) {
  return buildAssistantDailyLogPrompt()  // KAIROS 每日日志模式
}

if (feature('TEAMMEM') && isTeamMemoryEnabled()) {
  return buildCombinedMemoryPrompt()  // 团队 + 个人组合模式
}

if (autoEnabled) {
  return buildMemoryLines().join('\n')  // 仅个人模式
}

return null  // 禁用
```

---

### buildMemoryPrompt()

```typescript
function buildMemoryPrompt(params: {
  displayName: string
  memoryDir: string
  extraGuidelines?: string[]
}): string
```

**功能**: 构建包含 MEMORY.md 内容的完整内存提示词。

**参数**:
- `displayName`: 显示名称 (如 "auto memory")
- `memoryDir`: 内存目录路径
- `extraGuidelines`: 额外指导文本

**返回值**: 完整的内存指令字符串，包含 MEMORY.md 内容。

**处理流程**:
1. 读取 MEMORY.md 内容 (同步)
2. 调用 `truncateEntrypointContent()` 截断
3. 记录 `tengu_memdir_loaded` 事件
4. 返回组合后的提示词

---

### buildMemoryLines()

```typescript
function buildMemoryLines(
  displayName: string,
  memoryDir: string,
  extraGuidelines?: string[],
  skipIndex?: boolean
): string[]
```

**功能**: 构建内存行为指令 (不含 MEMORY.md 内容)。

**参数**:
- `skipIndex`: 跳过索引写入说明 (用于 Agent 内存)

**返回内容**:
1. 内存系统介绍
2. 4 种内存类型定义 (`TYPES_SECTION_INDIVIDUAL`)
3. 不应保存的内容 (`WHAT_NOT_TO_SAVE_SECTION`)
4. 如何保存记忆
5. 何时访问记忆 (`WHEN_TO_ACCESS_SECTION`)
6. 信任回忆 (`TRUSTING_RECALL_SECTION`)
7. 内存与其他持久化机制的区别
8. 搜索过去上下文 (`buildSearchingPastContextSection`)

---

### truncateEntrypointContent()

```typescript
function truncateEntrypointContent(raw: string): EntrypointTruncation

interface EntrypointTruncation {
  content: string        // 截断后的内容
  lineCount: number      // 原始行数
  byteCount: number      // 原始字节数
  wasLineTruncated: boolean   // 是否因行数截断
  wasByteTruncated: boolean   // 是否因字节数截断
}
```

**限制**:
- 最多 200 行 (`MAX_ENTRYPOINT_LINES`)
- 最多 25,000 字节 (`MAX_ENTRYPOINT_BYTES`)

**截断逻辑**:
1. 先按行截断
2. 再按字节截断 (确保不切断行中间)
3. 追加警告信息

---

### findRelevantMemories()

```typescript
async function findRelevantMemories(
  query: string,
  memoryDir: string,
  signal: AbortSignal,
  recentTools?: readonly string[],
  alreadySurfaced?: ReadonlySet<string>
): Promise<RelevantMemory[]>

interface RelevantMemory {
  path: string    // 绝对路径
  mtimeMs: number // 修改时间
}
```

**功能**: 基于查询找到相关的记忆文件。

**工作流程**:
```
┌────────────────────────────────────────────────────────────┐
│              findRelevantMemories 流程                      │
├────────────────────────────────────────────────────────────┤
│                                                            │
│  1. scanMemoryFiles(memoryDir)                             │
│     └── 扫描目录，读取 frontmatter，返回 MemoryHeader[]     │
│                                                            │
│  2. 过滤已显示的文件                                        │
│     └── 排除 alreadySurfaced 中的文件                       │
│                                                            │
│  3. selectRelevantMemories()                               │
│     └── 调用 Sonnet 模型选择最多 5 个相关文件               │
│                                                            │
│  4. 返回 RelevantMemory[]                                   │
│     └── { path, mtimeMs }                                  │
│                                                            │
└────────────────────────────────────────────────────────────┘
```

**选择提示词** (SELECT_MEMORIES_SYSTEM_PROMPT):
```
You are selecting memories that will be useful to Claude Code as it processes a user's query.
Return a list of filenames for the memories that will clearly be useful (up to 5).
- If you are unsure if a memory will be useful, do not include it.
- If there are no useful memories, return an empty list.
- Do not select memories that are usage reference or API documentation for recently used tools.
  BUT: Still select memories containing warnings, gotchas, or known issues about those tools.
  Active use is exactly when those matter.
```

**输出格式**: JSON schema `{selected_memories: string[]}`

---

### scanMemoryFiles()

```typescript
async function scanMemoryFiles(
  memoryDir: string,
  signal: AbortSignal
): Promise<MemoryHeader[]>

interface MemoryHeader {
  filename: string           // 文件名
  filePath: string           // 绝对路径
  mtimeMs: number           // 修改时间
  description: string | null  // frontmatter.description
  type: MemoryType | undefined  // frontmatter.type
}
```

**限制**:
- 最多扫描 200 个 .md 文件 (`MAX_MEMORY_FILES`)
- frontmatter 最多读取前 30 行 (`FRONTMATTER_MAX_LINES`)

**排序**: 按 mtimeMs 降序 (最新的在前)

---

### formatMemoryManifest()

```typescript
function formatMemoryManifest(memories: MemoryHeader[]): string
```

**输出格式**:
```markdown
- [user] user_role.md (2026-04-01T10:30:00.000Z): 用户角色和专业知识
- [feedback] testing_policy.md (2026-03-28T14:20:00.000Z)
- [project] v2_release.md (2026-03-25T09:00:00.000Z): 4月15日发布
```

---

## 路径 API

### isAutoMemoryEnabled()

```typescript
function isAutoMemoryEnabled(): boolean
```

**启用优先级** (第一个匹配生效):
1. `CLAUDE_CODE_DISABLE_AUTO_MEMORY=1/true` → 禁用
2. `CLAUDE_CODE_DISABLE_AUTO_MEMORY=0/false` → 强制启用
3. `CLAUDE_CODE_SIMPLE` (--bare) → 禁用
4. CCR 无持久存储 → 禁用
5. `settings.autoMemoryEnabled` → 显式设置
6. 默认 → 启用

### getAutoMemPath()

```typescript
const getAutoMemPath = memoize((): string => { ... }, () => getProjectRoot())
```

**路径解析**:
1. `CLAUDE_COWORK_MEMORY_PATH_OVERRIDE` 环境变量
2. `settings.autoMemoryDirectory` (优先级: policySettings > flagSettings > localSettings > userSettings)
3. `{memoryBase}/projects/{sanitized-git-root}/memory/`

**注意**: 内部缓存，按 `getProjectRoot()` 失效

### getAutoMemDailyLogPath()

```typescript
function getAutoMemDailyLogPath(date: Date = new Date()): string
```

**KAIROS 模式专用**: 返回每日日志文件路径

```typescript
// 输出: <autoMemPath>/logs/YYYY/MM/YYYY-MM-DD.md
// 例如: ~/.claude/projects/my-project/memory/logs/2026/04/2026-04-01.md
```

### isAutoMemPath()

```typescript
function isAutoMemPath(absolutePath: string): boolean
```

**功能**: 检查路径是否在内存目录内

**安全**: 内部会 normalize 防止路径遍历攻击

### getAutoMemEntrypoint()

```typescript
function getAutoMemEntrypoint(): string
```

**功能**: 返回 MEMORY.md 索引文件的完整路径

**路径**: `<autoMemPath>/MEMORY.md`

**注意**: 遵循与 `getAutoMemPath()` 相同的解析顺序

### getMemoryBaseDir()

```typescript
function getMemoryBaseDir(): string
```

**功能**: 返回持久化内存存储的基础目录

**解析顺序**:
1. `CLAUDE_CODE_REMOTE_MEMORY_DIR` 环境变量 (CCR 设置)
2. `~/.claude` (默认配置目录)

### hasAutoMemPathOverride()

```typescript
function hasAutoMemPathOverride(): boolean
```

**功能**: 检查是否设置了 Cowork 内存路径覆盖

**用途**: SDK 调用者可以通过设置 `CLAUDE_COWORK_MEMORY_PATH_OVERRIDE` 环境变量来显式启用自动内存机制，用于决定是否注入内存提示词

### buildSearchingPastContextSection()

```typescript
function buildSearchingPastContextSection(autoMemDir: string): string[]
```

**功能**: 构建"搜索过去上下文"提示词段落

**Feature Flag**: `tengu_coral_fern`

**返回内容**:
- 搜索内存目录中的 topic 文件
- 搜索会话转录日志 (`.jsonl` 文件)

**注意**: 仅当 `tengu_coral_fern` 特性启用时返回内容，否则返回空数组

---

## 类型定义

### MemoryType

```typescript
const MEMORY_TYPES = ['user', 'feedback', 'project', 'reference'] as const
type MemoryType = 'user' | 'feedback' | 'project' | 'reference'

function parseMemoryType(raw: unknown): MemoryType | undefined
```

**解析规则**:
- 字符串且在 MEMORY_TYPES 中 → 返回该类型
- 其他情况 → 返回 undefined

---

## 内存新鲜度系统 (memoryAge.ts)

### memoryAge()

```typescript
function memoryAge(mtimeMs: number): string
```

**功能**: 返回人类可读的内存年龄字符串

**返回值**: `'today'` | `'yesterday'` | `'N days ago'`

### memoryAgeDays()

```typescript
function memoryAgeDays(mtimeMs: number): number
```

**功能**: 返回自文件修改以来的天数（向下取整）

**注意**: 未来时间或时钟偏移会钳制为 0

### memoryFreshnessText()

```typescript
function memoryFreshnessText(mtimeMs: number): string
```

**功能**: 返回超过 1 天的内存的陈旧性警告文本

**返回值**:
- 1 天以内: 返回空字符串
- 超过 1 天: 返回警告文本

### memoryFreshnessNote()

```typescript
function memoryFreshnessNote(mtimeMs: number): string
```

**功能**: 返回包装在 `<system-reminder>` 标签中的陈旧性说明

---

## 团队记忆 (TEAMMEM feature)

### buildCombinedMemoryPrompt()

```typescript
function buildCombinedMemoryPrompt(
  extraGuidelines?: string[],
  skipIndex = false,
): string
```

**功能**: 构建同时启用个人内存和团队记忆时的组合提示词

**团队内存结构**:
- 个人内存: `<autoMemPath>/` 即 `~/.claude/projects/{project}/memory/`
- 团队内存: `<autoMemPath>/team/` 即 `~/.claude/projects/{project}/memory/team/`
- 团队内存是个人内存的**子目录**，而非独立顶层目录

**返回内容**:
- 双目录内存系统介绍
- 内存作用域说明 (private/team)
- 4 种内存类型定义 (`TYPES_SECTION_COMBINED`)
- 不应保存的内容
- 如何保存记忆
- 何时访问记忆
- 信任回忆
- 额外指导 (`extraGuidelines`)
- 搜索过去上下文 (`buildSearchingPastContextSection`)

### Cowork Extra Guidelines

Cowork 通过环境变量注入额外的内存策略指导：

```typescript
const coworkExtraGuidelines = process.env.CLAUDE_COWORK_MEMORY_EXTRA_GUIDELINES
```

这些指导会被添加到内存提示词中，通过 `extraGuidelines` 参数传递给 `buildMemoryLines()` 和 `buildCombinedMemoryPrompt()`。

---

## 提示词片段

### TYPES_SECTION_INDIVIDUAL

单人模式使用的内存类型说明，包含:
- user: 用户记忆
- feedback: 反馈记忆
- project: 项目记忆
- reference: 参考记忆

### TYPES_SECTION_COMBINED

团队模式使用的内存类型说明，包含 `<scope>` 标签:
- `<scope>always private</scope>`
- `<scope>default to private</scope>`
- `<scope>private or team, but strongly bias toward team</scope>`
- `<scope>usually team</scope>`

### WHAT_NOT_TO_SAVE_SECTION

不应保存的内容:
- 代码模式 (可从代码派生)
- Git 历史 (可从 git 派生)
- 调试方案 (代码中有)
- CLAUDE.md 已记录的内容
- 进行中的任务细节

### WHEN_TO_ACCESS_SECTION

何时访问记忆:
- 记忆看起来相关时
- 用户明确要求检查/回忆时
- 用户说 "ignore" 时 → 忽略记忆
- 记忆可能过时 → 验证后使用

### TRUSTING_RECALL_SECTION

使用记忆前的验证:
- 记忆命名了文件路径 → 检查文件是否存在
- 记忆命名了函数/标志 → grep 查找
- 用户要基于记忆行动 → 先验证

---

## 事件追踪

### telemetry 事件

总计 45 个 memory 相关 telemetry 事件：

#### 1. Memdir (Auto Memory) 事件

| 事件 | 时机 | 字段 |
|------|------|------|
| `tengu_memdir_loaded` | memdir 目录加载 | total_file_count, total_subdir_count, memory_type |
| `tengu_memdir_disabled` | auto memory 未启用 | disabled_by_env_var, disabled_by_setting |
| `tengu_memdir_accessed` | memory 文件被访问 | tool, subagent_name |
| `tengu_memdir_file_read` | memory 文件被读取 | subagent_name |
| `tengu_memdir_file_edit` | memory 文件被编辑 | subagent_name |
| `tengu_memdir_file_write` | memory 文件被写入 | subagent_name |
| `tengu_memdir_prefetch_collected` | memory 预取被收集 | hidden_by_first_iteration, consumed_on_iteration, latency_ms |
| `tengu_auto_memory_toggled` | auto memory 开关切换 | enabled |

#### 2. Team Memory Sync 事件

| 事件 | 时机 | 字段 |
|------|------|------|
| `tengu_team_memdir_disabled` | team memory 未启用 | - |
| `tengu_team_mem_accessed` | team memory 文件访问 | tool, subagent_name |
| `tengu_team_mem_file_read` | team memory 文件读取 | subagent_name |
| `tengu_team_mem_file_edit` | team memory 文件编辑 | subagent_name |
| `tengu_team_mem_file_write` | team memory 文件写入 | subagent_name |
| `tengu_team_mem_entries_capped` | 条目超服务器上限 | total_entries, dropped_count, max_entries |
| `tengu_team_mem_secret_skipped` | secret 检测跳过 | file_count, rule_ids |
| `tengu_team_mem_sync_started` | 同步启动 | initial_pull_success, initial_files_pulled, watcher_started |
| `tengu_team_mem_sync_pull` | 拉取完成 | success, files_written, duration_ms, errorType |
| `tengu_team_mem_sync_push` | 推送完成 | success, files_uploaded, conflict, duration_ms, errorType |
| `tengu_team_mem_push_suppressed` | 推送被抑制 | reason, status |

#### 3. Extract Memories 事件

| 事件 | 时机 | 字段 |
|------|------|------|
| `tengu_auto_mem_tool_denied` | 工具使用被拒绝 | tool_name |
| `tengu_extract_memories_gate_disabled` | 功能未启用 | - |
| `tengu_extract_memories_skipped_direct_write` | 主 agent 已写入 | message_count |
| `tengu_extract_memories_coalesced` | 请求合并 | - |
| `tengu_extract_memories_extraction` | 提取完成 | input_tokens, output_tokens, message_count, turn_count, files_written, memories_saved |
| `tengu_extract_memories_error` | 提取出错 | duration_ms |

#### 4. Session Memory 事件

| 事件 | 时机 | 字段 |
|------|------|------|
| `tengu_session_memory_accessed` | session memory 访问 | subagent_name |
| `tengu_session_memory_gate_disabled` | 功能未启用 | - |
| `tengu_session_memory_loaded` | 内容加载 | content_length |
| `tengu_session_memory_file_read` | 文件读取 | content_length |
| `tengu_session_memory_init` | 初始化 | auto_compact_enabled |
| `tengu_session_memory_extraction` | 提取完成 | input_tokens, output_tokens, cache_creation_input_tokens |
| `tengu_session_memory_manual_extraction` | 手动提取 | - |

#### 5. Session Memory Compact 事件

| 事件 | 时机 | 字段 |
|------|------|------|
| `tengu_sm_compact_flag_check` | 功能检查 | tengu_session_memory, tengu_sm_compact, should_use |
| `tengu_sm_compact_no_session_memory` | 无 session memory | - |
| `tengu_sm_compact_empty_template` | memory 为空模板 | - |
| `tengu_sm_compact_summarized_id_not_found` | 找不到已摘要 ID | - |
| `tengu_sm_compact_resumed_session` | 恢复的会话 | - |
| `tengu_sm_compact_threshold_exceeded` | 超过 token 阈值 | postCompactTokenCount, autoCompactThreshold |
| `tengu_sm_compact_error` | compaction 出错 | - |

#### 6. Auto Dream 事件

| 事件 | 时机 | 字段 |
|------|------|------|
| `tengu_auto_dream_fired` | dream 触发 | hours_since, sessions_since |
| `tengu_auto_dream_completed` | dream 完成 | cache_read, cache_created, output, sessions_reviewed |
| `tengu_auto_dream_failed` | dream 失败 | - |
| `tengu_auto_dream_toggled` | 开关切换 | enabled |

#### 7. Agent Memory 事件

| 事件 | 时机 | 字段 |
|------|------|------|
| `tengu_agent_memory_loaded` | agent memory 加载 | agent_type, scope, source |

#### 8. Memory Survey 事件

| 事件 | 时机 | 字段 |
|------|------|------|
| `tengu_memory_survey_event` | survey 触发 | - |

### Feature Flags

| Flag | 功能 |
|------|------|
| `TEAMMEM` | 团队记忆功能 |
| `KAIROS` | 每日日志模式 |
| `EXTRACT_MEMORIES` | 提取记忆后台代理 |
| `tengu_coral_fern` | 搜索过去上下文 (`buildSearchingPastContextSection`) |
| `tengu_moth_copse` | 跳过 MEMORY.md 索引写入说明 |
| `tengu_passport_quail` | 提取记忆后台代理激活 |
| `tengu_slate_thimble` | 非交互会话强制激活提取 |
| `tengu_herring_clock` | 团队记忆禁用遥测 |
| `tengu_onyx_plover` | autoDream 配置开关 |

---

## Background Extract Memories

基于 `src/services/extractMemories/extractMemories.ts` 的后台记忆提取机制。

### 核心机制

**触发时机**:
- 每个完整查询循环结束时触发（模型产生最终响应且无 tool calls 时）
- 通过 `handleStopHooks` 调用 `executeExtractMemories`
- Fire-and-forget 模式运行

### 工作流程

```
1. 互斥保护: 检查主 agent 是否已写入记忆文件
   - 若已写入，跳过 forked agent，直接移动游标

2. 节流控制: 通过 tengu_bramble_lintel 控制频率
   - 默认每 1 个 eligible turn 执行一次

3. Forked Agent 执行:
   runForkedAgent({
     promptMessages: [createUserMessage({ content: userPrompt })],
     cacheSafeParams,
     canUseTool: createAutoMemCanUseTool(),
     querySource: 'extract_memories',
     forkLabel: 'extract_memories',
     skipTranscript: true,
     maxTurns: 5,  // 硬性限制
   })
```

### 5 Max Turns 限制

**位置**: `extractMemories.ts:426`

```typescript
const result = await runForkedAgent({
  // ...
  // Well-behaved extractions complete in 2-4 turns (read → write).
  // A hard cap prevents verification rabbit-holes from burning turns.
  maxTurns: 5,
})
```

**说明**: 良好的提取在 2-4 个 turn 内完成（read → write）。硬性上限防止验证兔子洞消耗 turn。

### Forked Agent 实现

**核心函数**: `runForkedAgent` (`forkedAgent.ts`)

**关键特性**:

1. **Cache Safe Params**: 确保 fork 与父进程共享相同的 cache-critical 参数
2. **状态隔离**: `createSubagentContext` 创建完全隔离的上下文
3. **Prompt Cache 共享**: 通过 `cacheSafeParams` 确保 API cache hits
4. **使用追踪**: 累积所有 API 调用的使用量

**工具权限限制** (`createAutoMemCanUseTool`):
| 工具类型 | 权限 |
|----------|------|
| FileRead, Grep, Glob | 无限制 |
| read-only Bash (ls, find, grep, cat, stat, wc, head, tail) | 允许 |
| FileEdit, FileWrite | 仅限 auto-memory 目录内 |
| 其他所有工具 | 拒绝 |

### Prompt 策略

```
Turn 1: 并行发出所有 FileRead 调用读取可能更新的文件
Turn 2: 并行发出所有 FileWrite/FileEdit 调用
```

### autoDream (后台记忆整合)

**触发条件**:
1. **时间门**: 距离上次整合 >= minHours (默认 24h)
2. **会话门**: 自上次整合以来有新会话 >= minSessions (默认 5)
3. **锁**: 无其他进程正在整合

**流程**:
```
1. 读取 lastConsolidatedAt 时间戳
2. 扫描 session 文件计算新会话数
3. 获取分布式锁
4. 运行 forked agent 执行整合 prompt
5. 注册为后台任务 (DreamTask)
6. 更新 lastConsolidatedAt
```

### 相关 Feature Flags

| Feature Flag | 默认值 | 说明 |
|--------------|--------|------|
| `tengu_passport_quail` | false | extractMemories 开关 |
| `tengu_bramble_lintel` | 1 | 提取频率（每 N 个 eligible turns） |
| `tengu_moth_copse` | false | 跳过 MEMORY.md index 更新 |
| `tengu_onyx_plover` | `{ enabled: false, minHours: 24, minSessions: 5 }` | autoDream 配置 |
| `tengu_slate_thimble` | false | 非交互模式提取 |

### 优雅关闭

```typescript
// 优雅关闭前 drain pending extraction
if (feature('EXTRACT_MEMORIES') && isExtractModeActive()) {
  await extractMemoriesModule!.drainPendingExtraction()
}
// 默认超时 60 秒，确保 forked agent 在 5 秒 shutdown failsafe 前完成
```

---

## 使用示例

### 构建内存提示词

```typescript
import { buildMemoryPrompt, getAutoMemPath } from './memdir/memdir.ts'

const memoryDir = getAutoMemPath()
const prompt = buildMemoryPrompt({
  displayName: 'auto memory',
  memoryDir,
  extraGuidelines: ['优先使用 TypeScript']
})

// prompt 包含:
// - 内存系统介绍
// - 4种类型定义
// - 保存/访问指南
// - MEMORY.md 内容 (截断后)
```

### 查找相关记忆

```typescript
import { findRelevantMemories } from './memdir/memdir.ts'

const memories = await findRelevantMemories(
  '用户如何处理数据库测试?',
  memoryDir,
  abortSignal,
  ['Bash', 'Edit'],  // 最近使用的工具
  new Set(['already-loaded-memory.md'])  // 已显示的
)

// 返回最相关的 5 个记忆
for (const m of memories) {
  console.log(`${m.path} (mtime: ${m.mtimeMs})`)
}
```

### 扫描内存目录

```typescript
import { scanMemoryFiles, formatMemoryManifest } from './memdir/memoryScan.ts'

const headers = await scanMemoryFiles(memoryDir, abortSignal)
const manifest = formatMemoryManifest(headers)
console.log(manifest)
```

### 检查路径

```typescript
import { isAutoMemPath, isAutoMemoryEnabled } from './memdir/paths.ts'

if (isAutoMemoryEnabled()) {
  const file = '/home/user/.claude/projects/my-repo/memory/user/test.md'
  console.log(isAutoMemPath(file)) // true
}
```

---

## 与其他模块的关系

```
┌────────────────────────────────────────────────────────────┐
│                    Memory API 依赖关系                       │
├────────────────────────────────────────────────────────────┤
│                                                            │
│  memdir.ts                                                 │
│      ├── memoryTypes.ts  (类型定义)                        │
│      ├── memoryScan.ts   (扫描)                            │
│      ├── paths.ts        (路径)                            │
│      └── 依赖:                                                     │
│            ├── utils/frontmatterParser.ts                  │
│            ├── utils/fsOperations.js                       │
│            ├── utils/sideQuery.js                          │
│            └── bootstrap/state.js                         │
│                                                            │
│  teamMemPaths.ts (TEAMMEM feature)                        │
│  teamMemPrompts.ts (TEAMMEM feature)                     │
│                                                            │
└────────────────────────────────────────────────────────────┘
```
