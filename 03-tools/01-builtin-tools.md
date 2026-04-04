# 内置工具清单

> 基于源码 `src/tools.ts`, `src/Tool.ts` 深度分析

## 工具概览

Claude Code 的工具系统包含 **核心工具** 和 **条件工具** 两类。

### 核心工具（始终可用）

| 工具 | 类名 | 说明 |
|------|------|------|
| AgentTool | AgentTool | 调用子 Agent |
| BashTool | BashTool | Shell 命令执行 |
| FileReadTool | FileReadTool | 读取文件 |
| FileEditTool | FileEditTool | 编辑文件 |
| FileWriteTool | FileWriteTool | 写入文件 |
| NotebookEditTool | NotebookEditTool | Jupyter Notebook 编辑 |
| WebFetchTool | WebFetchTool | 获取网页内容 |
| WebSearchTool | WebSearchTool | 网络搜索 |
| TodoWriteTool | TodoWriteTool | 任务列表管理 |
| TaskStopTool | TaskStopTool | 停止任务 |
| TaskOutputTool | TaskOutputTool | 获取异步任务结果 |
| AskUserQuestionTool | AskUserQuestionTool | 向用户提问 |
| SkillTool | SkillTool | 调用技能 |
| ExitPlanModeV2Tool | ExitPlanModeV2Tool | 退出计划模式 |
| SendUserMessage (BriefTool) | BriefTool | 发送消息给用户（遗留别名：Brief） |

**注意**：
- `GlobTool` 和 `GrepTool` 在以下情况会被静默排除：当 bun 二进制内嵌了 ripgrep 时（与 ripgrep 相同的 ARGV0 trick），find/grep 已在 Claude shell 中别名指向这些内置工具，此时不需要单独的 Glob/Grep 工具。
- `WebFetchTool` 和 `WebSearchTool` 是延迟加载工具（`shouldDefer: true`），需要通过 ToolSearch 加载完整 schema 后才可用。
- `WebSearchTool` 仅对特定 provider 可用：`firstParty`（始终）、`vertex`（Claude 4.0+）、`foundry`（始终），其他 provider（如 Bedrock）不可用。
- `ListMcpResourcesTool` 和 `ReadMcpResourceTool` 是特殊工具（`specialTools`），从常规工具列表中排除，仅在 `assembleToolPool()` 中按需添加，且均为延迟加载。
- `AgentTool` 有遗留别名 `Task`。
- `SendUserMessageTool`（类名 `BriefTool`）有遗留别名 `Brief`。

### ANT 用户专属工具

以下工具仅在 `USER_TYPE === 'ant'` 时可用：

| 工具 | 类名 | 说明 |
|------|------|------|
| ConfigTool | ConfigTool | 配置管理 |
| TungstenTool | TungstenTool | Tungsten 工具 |
| REPLTool | REPLTool | REPL 执行环境 |

### 条件工具（需满足条件）

| 工具 | 条件 | 说明 |
|------|------|------|
| TaskCreateTool | isTodoV2Enabled() | 创建任务 |
| TaskGetTool | isTodoV2Enabled() | 获取任务 |
| TaskUpdateTool | isTodoV2Enabled() | 更新任务 |
| TaskListTool | isTodoV2Enabled() | 列出任务 |
| EnterWorktreeTool | isWorktreeModeEnabled() | 进入 Worktree |
| ExitWorktreeTool | isWorktreeModeEnabled() | 退出 Worktree |
| ToolSearchTool | isToolSearchEnabledOptimistic() | 工具搜索 |
| SendMessageTool | isAgentSwarmsEnabled() | 发送消息（Team 模式） |
| LSPTool | ENABLE_LSP_TOOL 环境变量 | LSP 语言服务 |
| TeamCreateTool | isAgentSwarmsEnabled() | 创建团队 |
| TeamDeleteTool | isAgentSwarmsEnabled() | 删除团队 |
| WorkflowTool | WORKFLOW_SCRIPTS feature | 工作流脚本 |
| WebBrowserTool | WEB_BROWSER_TOOL feature | 网页浏览器 |
| SleepTool | PROACTIVE or KAIROS feature | 睡眠工具 |
| CronCreateTool | AGENT_TRIGGERS feature | 创建定时任务 |
| CronDeleteTool | AGENT_TRIGGERS feature | 删除定时任务 |
| CronListTool | AGENT_TRIGGERS feature | 列出定时任务 |
| SnipTool | HISTORY_SNIP feature | 历史摘要 |
| MonitorTool | MONITOR_TOOL feature | 监控工具 |
| SendUserFileTool | KAIROS feature | 发送用户文件 |
| PushNotificationTool | KAIROS or KAIROS_PUSH_NOTIFICATION feature | 推送通知 |
| SubscribePRTool | KAIROS_GITHUB_WEBHOOKS feature | 订阅 PR |
| RemoteTriggerTool | AGENT_TRIGGERS_REMOTE feature | 远程触发器 |
| ListPeersTool | UDS_INBOX feature | 列出对等节点 |
| OverflowTestTool | OVERFLOW_TEST_TOOL feature | 溢出测试 |
| CtxInspectTool | CONTEXT_COLLAPSE feature | 上下文检查 |
| TerminalCaptureTool | TERMINAL_PANEL feature | 终端捕获 |
| SuggestBackgroundPRTool | USER_TYPE === 'ant' | 建议后台 PR |
| VerifyPlanExecutionTool | CLAUDE_CODE_VERIFY_PLAN=true | 验证计划执行 |
| TestingPermissionTool | NODE_ENV === 'test' | 测试权限工具 |
| PowerShellTool | PowerShell 可用且启用 | PowerShell 执行 |

---

## 工具定义结构

基于源码 `src/Tool.ts`，每个工具都是 `Tool` 类型：

```typescript
type Tool<Input, Output, P> = {
  // === 基本信息 ===

  // 工具名称
  name: string

  // 可选别名（用于向后兼容重命名的工具）
  aliases?: string[]

  // 3-10 词的能力短语，供 ToolSearch 关键词匹配使用
  searchHint?: string

  // 输入模式 (Zod schema)
  inputSchema: Input

  // 可选：MCP 工具可直接指定 JSON Schema 格式的输入 schema
  readonly inputJSONSchema?: ToolInputJSONSchema

  // 输出模式
  outputSchema?: z.ZodType<unknown>

  // 工具描述
  description(input): Promise<string>

  // 执行函数
  call(args, context, canUseTool, parentMessage, onProgress?): Promise<ToolResult<Output>>

  // === 权限与状态 ===

  // 是否启用
  isEnabled(): boolean

  // 是否只读
  isReadOnly(input): boolean

  // 是否破坏性操作（仅在执行不可逆操作时设置，如删除、覆盖、发送）
  isDestructive?(input): boolean

  // 是否并发安全
  isConcurrencySafe(input): boolean

  // 中断行为（'cancel' = 停止并丢弃结果；'block' = 继续运行，新消息等待）
  interruptBehavior?(): 'cancel' | 'block'

  // === 权限检查 ===

  // 输入验证
  validateInput?(input, context): Promise<ValidationResult>

  // 权限检查
  checkPermissions(input, context): Promise<PermissionResult>

  // 权限匹配器（用于 hook `if` 条件中的规则模式匹配）
  preparePermissionMatcher?(input): Promise<(pattern: string) => boolean>

  // === UI 渲染 ===

  // 渲染工具使用消息
  renderToolUseMessage(input, options): ReactNode

  // 渲染工具结果
  renderToolResultMessage?(content, progress, options): ReactNode

  // 渲染进度消息
  renderToolUseProgressMessage?(progress, options): ReactNode

  // 渲染排队消息
  renderToolUseQueuedMessage?(): ReactNode

  // 渲染拒绝消息
  renderToolUseRejectedMessage?(input, options): ReactNode

  // 渲染错误消息
  renderToolUseErrorMessage?(result, options): ReactNode

  // 分组渲染（多条并行工具调用作为一组展示）
  renderGroupedToolUse?(toolUses, options): ReactNode | null

  // 渲染工具使用标签（超时、模型、resume ID 等元信息）
  renderToolUseTag?(input): ReactNode

  // 判断输出在非 verbose 模式下是否被截断（决定是否显示点击展开）
  isResultTruncated?(output): boolean

  // === 摘要与分类 ===

  // 工具用途摘要
  getToolUseSummary?(input): string | null

  // 活动描述（用于 spinner 显示，如 "Reading src/foo.ts"）
  getActivityDescription?(input): string | null

  // 自动分类器输入
  toAutoClassifierInput(input): unknown

  // 搜索文本提取（用于 transcript 搜索索引）
  extractSearchText?(output): string

  // === 搜索/读取标识 ===

  // 是否为搜索或读取操作
  isSearchOrReadCommand?(input): { isSearch: boolean; isRead: boolean; isList?: boolean }

  // 是否为开放世界操作
  isOpenWorld?(input): boolean

  // 是否需要用户交互
  requiresUserInteraction?(): boolean

  // === 延迟加载（ToolSearch） ===

  // 当为 true 时，工具会被延迟加载（defer_loading: true），需先使用 ToolSearch
  readonly shouldDefer?: boolean

  // 当为 true 时，即使 ToolSearch 启用，工具的完整 schema 也会出现在初始 prompt 中
  readonly alwaysLoad?: boolean

  // === 透明包装器 ===

  // 透明包装器（如 REPL）将所有渲染委托给 progress handler 本身不显示任何内容
  isTransparentWrapper?(): boolean

  // === 输入回填 ===

  // 在 observer 看到工具输入前调用（SDK stream、transcript、canUseTool、hooks）
  // 必须幂等，原始 API 输入永远不会被改变
  backfillObservableInput?(input): void

  // === 输入等价性 ===

  // 判断两个输入是否等价（用于工具去重）
  inputsEquivalent?(a, b): boolean

  // === 文件路径 ===

  // 可选方法，适用于操作文件路径的工具
  getPath?(input): string

  // === 严格模式 ===

  // 当为 true 时启用严格模式，要求 API 更严格遵循工具指令和参数 schema
  // 仅在 tengu_tool_pear 启用时生效
  readonly strict?: boolean

  // === MCP 相关 ===

  // 是否为 MCP 工具
  isMcp?: boolean

  // 是否为 LSP 工具
  isLsp?: boolean

  // MCP 信息（服务器名和工具名，来自 MCP server 的原始名称）
  mcpInfo?: { serverName: string; toolName: string }

  // === 其他 ===

  // 最大结果大小（字符）；超出时结果持久化到磁盘，Claude 收到预览和路径
  maxResultSizeChars: number

  // 用户可见名称（默认使用 tool name）
  userFacingName(input): string

  // 用户可见名称的背景色
  userFacingNameBackgroundColor?(input): keyof Theme | undefined
}
```

---

## 核心工具详解

### 1. BashTool (Bash)

Shell 命令执行工具。

**输入参数**：
```typescript
interface BashInput {
  command: string                       // 要执行的命令
  timeout?: number                      // 超时时间（毫秒）
  description?: string                  // 命令描述（用于日志）
  run_in_background?: boolean           // 后台执行（不是 bg）
  dangerouslyDisableSandbox?: boolean   // 禁用沙箱
}
```

**权限规则**：BashTool 有自己的 `checkPermissions` 逻辑，权限规则基于命令本身而非 glob 模式匹配参数。请参考 `src/tools/BashTool/` 中的实现了解具体规则。

**搜索/读取分类**：
```typescript
// 这些命令会被识别为只读操作
BASH_SEARCH_COMMANDS = ['find', 'grep', 'rg', 'ag', 'ack', 'locate', 'which']
BASH_READ_COMMANDS = ['cat', 'head', 'tail', 'less', 'more', 'wc', 'stat', 'file', 'strings', 'jq', 'awk', 'cut', 'sort', 'uniq', 'tr']
BASH_LIST_COMMANDS = ['ls', 'tree', 'du']
```

---

### 2. FileReadTool (Read)

读取文件内容。

**输入参数**：
```typescript
interface ReadInput {
  file_path: string        // 文件路径
  limit?: number          // 限制行数
  offset?: number         // 起始行
  pages?: string          // PDF 页码范围
}
```

**功能**：
- 读取普通文件
- 读取图片（base64 编码）
- 读取 PDF（支持分页）
- 读取 Jupyter Notebook

---

### 3. FileWriteTool (Write)

创建或覆盖文件。

**输入参数**：
```typescript
interface WriteInput {
  file_path: string        // 文件路径
  content: string         // 文件内容
}
```

---

### 4. FileEditTool (Edit)

部分修改文件。

**输入参数**：
```typescript
interface EditInput {
  file_path: string        // 文件路径
  old_string: string       // 要替换的文本
  new_string: string       // 替换后的文本
  replace_all?: boolean    // 替换所有匹配
}
```

---

### 5. GlobTool (Glob)

文件模式匹配。

**输入参数**：
```typescript
interface GlobInput {
  pattern: string          // glob 模式
  path?: string           // 搜索目录（不是 cwd）
}
```

**示例**：
```
**/*.ts              # 所有 TypeScript 文件
src/**/*.{js,ts}    # src 下的 JS/TS 文件
!test/**             # 排除 test 目录
**/node_modules/**  # 排除 node_modules
```

**注意**：当 bun 二进制内嵌了 ripgrep/fastglob 时，此工具会被静默排除。

---

### 6. GrepTool (Grep)

正则表达式搜索。

**输入参数**：
```typescript
interface GrepInput {
  pattern: string          // 正则表达式
  path?: string           // 搜索路径
  glob?: string           // 文件名过滤模式
  "-n"?: boolean          // 显示行号
  "-i"?: boolean          // 忽略大小写
  "-C"?: number           // 上下文行数
  "-B"?: number           // 匹配前的行数
  "-A"?: number           // 匹配后的行数
  context?: number         // -C 的别名
  type?: string            // 文件类型过滤（如 "js", "py"）
  head_limit?: number      // 限制结果数量
  offset?: number          // 跳过结果数
  multiline?: boolean      // 多行模式
  output_mode?: 'content' | 'files_with_matches' | 'count'
}
```

**注意**：当 bun 二进制内嵌了 ripgrep 时，此工具会被静默排除。

---

### 7. WebFetchTool (WebFetch)

获取网页内容。

**输入参数**：
```typescript
interface WebFetchInput {
  url: string              // 网页 URL
  prompt: string               // 提取提示（必需）
}
```

---

### 8. WebSearchTool (WebSearch)

网络搜索。

**输入参数**：
```typescript
interface WebSearchInput {
  query: string                      // 搜索查询
  allowed_domains?: string[]         // 限制搜索的域名
  blocked_domains?: string[]         // 排除的域名
}
```

---

### 9. AgentTool

调用子 Agent。

**输入参数**：
```typescript
interface AgentInput {
  description: string                 // Agent 描述（必需，3-5 词）
  prompt: string                      // 任务描述（必需）
  subagent_type?: string             // Agent 类型
  model?: 'sonnet' | 'opus' | 'haiku'  // 指定模型
  run_in_background?: boolean        // 后台执行
  // 以下为多 Agent 模式参数
  name?: string                      // Agent 实例名称（多 Agent 模式）
  team_name?: string                 // 团队名称
  mode?: PermissionMode              // 权限模式
  isolation?: 'worktree'             // 隔离模式
}
```

---

### 10. TaskOutputTool

获取异步任务结果。

**输入参数**：
```typescript
interface TaskOutputInput {
  task_id: string          // 任务 ID
  block?: boolean          // 是否阻塞等待
  timeout?: number         // 超时时间
}
```

---

## 工具权限模式

### PermissionMode 类型

```typescript
type PermissionMode =
  | "default"              // 默认，每次询问
  | "acceptEdits"          // 自动接受编辑
  | "bypassPermissions"    // 绕过所有检查
  | "dontAsk"             // 不询问，直接拒绝
  | "plan"                // 仅在计划模式
  | "auto"                // 自动模式
```

### ToolPermissionContext

```typescript
interface ToolPermissionContext {
  mode: PermissionMode
  additionalWorkingDirectories: Map<string, AdditionalWorkingDirectory>
  alwaysAllowRules: ToolPermissionRulesBySource
  alwaysDenyRules: ToolPermissionRulesBySource
  alwaysAskRules: ToolPermissionRulesBySource
  isBypassPermissionsModeAvailable: boolean
  isAutoModeAvailable?: boolean
  strippedDangerousRules?: ToolPermissionRulesBySource
  shouldAvoidPermissionPrompts?: boolean
  awaitAutomatedChecksBeforeDialog?: boolean
  prePlanMode?: PermissionMode
}
```

### 权限规则语法

```bash
# 基本格式
ToolName(pattern)

# 示例
Bash(git *)               # git 开头的所有命令
Read(*.md)                # 只读 markdown 文件
Write(*.ts)               # 只写 TypeScript 文件
Edit(!*.json)             # 除 JSON 外的文件
Glob(**/*.tsx)             # 所有 TSX 文件
mcp__server__*            # 某 MCP 服务器的所有工具
```

---

## 配置示例

### settings.json 权限配置

```json
{
  "permissions": {
    "allow": [
      "Read",
      "Write",
      "Edit",
      "Glob",
      "Grep"
    ],
    "deny": [
      "Bash(sudo *)",
      "Bash(:(){:|:&};:)",
      "Bash(rm -rf /)",
      "Bash(chmod 777 *)"
    ],
    "defaultMode": "default",
    "additionalDirectories": ["/tmp/work"]
  }
}
```

---

## 工具默认行为

从 `src/Tool.ts` 中的 `TOOL_DEFAULTS`：

```typescript
const TOOL_DEFAULTS = {
  isEnabled: () => true,                              // 默认启用
  isConcurrencySafe: (_input?: unknown) => false,      // 默认不并发安全
  isReadOnly: (_input?: unknown) => false,             // 默认可写
  isDestructive: (_input?: unknown) => false,         // 默认非破坏性
  checkPermissions: (input) => ({ behavior: 'allow', updatedInput: input }),
  toAutoClassifierInput: (_input?: unknown) => '',     // 跳过分类器
  userFacingName: (_input?: unknown) => ''
}
```

---

## 未文档化的工具功能

以下功能在源码中存在，但主要文档未覆盖：

### Read Tool (FileReadTool)

| 功能 | 说明 |
|------|------|
| `pages` | PDF 页码范围 (如 `"1-5"`, `"3"`, `"10-20"`) |
| 文件去重 | 相同文件范围无变化时返回 `file_unchanged` |
| 设备路径阻塞 | `/dev/zero`, `/dev/random` 等会被阻塞 |
| 图片维度元数据 | 返回 `dimensions` 用于坐标映射 |

### Write Tool (FileWriteTool)

| 功能 | 说明 |
|------|------|
| `structuredPatch` | 返回 diff patch |
| `originalFile` | 返回写入前的原始内容 |
| `gitDiff` | `tengu_quartz_lantern` 特性启用时返回 git diff |
| LSP 通知 | 文件变更时通知 LSP 服务器 |

### Edit Tool (FileEditTool)

| 功能 | 说明 |
|------|------|
| `replace_all` | 布尔参数，替换所有匹配 |
| 引号保留 | 自动保留文件中的弯引号 |
| 1GB 文件限制 | 超过 1GB 的文件无法编辑 |

### Glob Tool

| 功能 | 说明 |
|------|------|
| 100 文件限制 | 默认最多返回 100 个结果 |
| `truncated` | 指示结果是否被截断 |
| `durationMs` | 返回执行时间 |

### Grep Tool

| 功能 | 说明 |
|------|------|
| `-C` 别名 | 与 `context` 参数相同 |
| `offset` | 跳过前 N 个结果 |
| `multiline` | `.` 匹配换行符 |
| `type` | 按文件类型过滤 (js, py, rust) |
| VCS 目录排除 | 自动排除 `.git`, `.svn`, `.hg`, `.bzr`, `.jj`, `.sl` |

### Bash Tool

| 功能 | 说明 |
|------|------|
| `run_in_background` | 后台运行命令 |
| `dangerouslyDisableSandbox` | 覆盖沙箱模式 |
| 自动后台化 | 助手模式下 15 秒后自动后台化 |
| 大输出持久化 | `persistedOutputPath` |

### NotebookEdit Tool

| 功能 | 说明 |
|------|------|
| `cell_id` | 支持数值索引 (cell-N 格式) |
| `edit_mode` | `replace`, `insert`, `delete` |
| `cell_type` | `code` 或 `markdown` (insert 模式需要) |

### LSP Tool

| 功能 | 说明 |
|------|------|
| 8 种操作 | goToDefinition, findReferences, hover 等 |
| 10MB 文件限制 | LSP 分析的最大文件大小 |
| Gitignore 过滤 | 过滤 gitignore 中的结果 |

### Task V2

| 功能 | 说明 |
|------|------|
| `addBlocks` | 添加阻塞任务 |
| `blockedBy` | 任务依赖关系 |
| `metadata` | 元数据支持 null 删除 |
| `activeForm` | 旋转器文本 |

### SendMessage Tool

| 功能 | 说明 |
|------|------|
| 结构化消息 | `shutdown_request`, `shutdown_response` |
| 跨会话通信 | UDS/bridge 消息传递 |
| 自动恢复 | 停止的 agent 自动恢复 |

---

## 工具别名（Legacy Names）

以下工具有遗留别名，用于向后兼容：

| 当前名称 | 遗留别名 | 说明 |
|---------|---------|------|
| `Agent` | `Task` | AgentTool 的旧名称 |
| `SendUserMessage` | `Brief` | BriefTool 的旧名称 |

---

## 延迟加载工具（Deferred Tools）

多个工具设置了 `shouldDefer: true`，它们不会出现在初始 prompt 中，需要通过 `ToolSearch` 动态加载。以下为核心延迟工具清单：

| 工具 | 说明 |
|------|------|
| `WebFetchTool` | 网页获取 |
| `WebSearchTool` | 网络搜索（受 Provider 限制） |
| `NotebookEditTool` | Notebook 编辑 |
| `TodoWriteTool` | 任务列表 |
| `TaskListTool` | 任务列表 V2 |
| `TaskStopTool` | 停止任务 |
| `TaskOutputTool` | 任务结果 |
| `CronCreateTool` | 创建定时任务 |
| `CronDeleteTool` | 删除定时任务 |
| `CronListTool` | 列出定时任务 |
| `LSPTool` | LSP 语言服务 |
| `AskUserQuestionTool` | 用户提问 |
| `EnterPlanModeTool` | 进入计划模式 |
| `ExitPlanModeV2Tool` | 退出计划模式 |
| `EnterWorktreeTool` | 进入 Worktree |
| `ExitWorktreeTool` | 退出 Worktree |
| `SendMessageTool` | Team 消息 |
| `TeamCreateTool` | 创建团队 |
| `TeamDeleteTool` | 删除团队 |

**WebSearchTool Provider 限制**：

| Provider | 可用性 |
|----------|--------|
| `firstParty` | 始终可用 |
| `vertex` | 仅 Claude 4.0+ 模型 |
| `foundry` | 始终可用 |
| 其他（如 Bedrock） | 不可用 |

---

## 未文档化的工具

以下工具存在于源码中但未在文档中记录：

| 工具名称 | Feature Gate | 说明 |
|---------|-------------|------|
| `PowerShellTool` | PowerShell 可用时 | PowerShell 执行 |
| `SnipTool` | `HISTORY_SNIP` | 历史片段工具 |
| `MonitorTool` | `MONITOR_TOOL` | 监控工具 |
| `SendUserFileTool` | `KAIROS` | 发送用户文件 |
| `PushNotificationTool` | `KAIROS_PUSH_NOTIFICATION` | 推送通知 |
| `SubscribePRTool` | `KAIROS_GITHUB_WEBHOOKS` | PR 订阅 |
| `RemoteTriggerTool` | `AGENT_TRIGGERS_REMOTE` | 远程触发管理 |
| `ListPeersTool` | `UDS_INBOX` | 列出 UDS 对等端 |
| `CtxInspectTool` | `CONTEXT_COLLAPSE` | 上下文检查 |
| `TerminalCaptureTool` | `TERMINAL_PANEL` | 终端捕获 |
| `VerifyPlanExecutionTool` | `CLAUDE_CODE_VERIFY_PLAN=true` | 计划验证 |
| `MCPTool` | MCP 工具 | MCP 工具包装器 |
| `McpAuthTool` | MCP auth | MCP 认证 |

---

## 未文档化的工具参数

### BashTool 额外参数

```typescript
{
  command: string,
  timeout?: number,
  description?: string,              // 命令描述（用于日志）
  run_in_background?: boolean,       // 后台执行
  dangerouslyDisableSandbox?: boolean,
}
```

### AgentTool 运行时参数

```typescript
{
  description: string,
  prompt: string,
  subagent_type?: string,
  model?: 'sonnet' | 'opus' | 'haiku',  // 本次调用的模型覆盖
  run_in_background?: boolean,
  name?: string,           // teammate 名称
  team_name?: string,      // 团队名称
  mode?: PermissionMode,   // spawn 权限模式
  isolation?: 'worktree' | 'remote',  // 隔离模式
  cwd?: string,            // KAIROS 专用
}
```

### SendMessageTool 路由前缀

```typescript
// 支持的前缀格式：
// "uds:<socket-path>" - Unix Domain Socket
// "bridge:<session-id>" - Remote Control peer
// "team-lead" - 团队领导
```

### TaskOutputTool 参数

```typescript
{
  task_id: string,
  block?: boolean,        // 默认 true
  timeout?: number,       // 默认 30000ms，最大 600000ms
}
```

### SkillTool 输出类型

```typescript
// inline 响应
{ success: true, commandName: string, allowedTools?: string[], model?: string, status: 'inline' }

// forked 响应
{ success: true, commandName: string, status: 'forked', agentId: string, result: unknown }
```

---

## 测试验证

运行测试脚本验证工具配置：
```bash
bash tests/03-tools-test.sh
```

---

## Context Collapse 四层上下文管理系统

Claude Code 使用**四层上下文管理策略**来优化长会话的上下文效率。

### 四层架构

| 层级 | Feature Flag | 机制 | 说明 |
|------|-------------|------|------|
| 1 | `CACHED_MICROCOMPACT` | 微压缩 | 去重重复工具结果，缓存编辑 |
| 2 | `HISTORY_SNIP` | 历史剪裁 | 删除预压缩保护尾之前的消息 |
| 3 | `CONTEXT_COLLAPSE` | 上下文折叠 | 新粒度 → 摘要投影（核心） |
| 4 | - | Autocompact | 传统全历史摘要 |

### Context Collapse 核心机制

`src/services/contextCollapse/` 实现上下文折叠策略：

```typescript
// 主要函数
applyCollapsesIfNeeded()     // 应用折叠
isContextCollapseEnabled()   // 检查是否启用
getStats()                  // 获取统计
recoverFromOverflow()        // 处理 413 错误
```

### 折叠视图投影

Context Collapse 通过**提交日志**投影折叠视图：

- 摘要后的消息存储在 collapse store 中
- 不存储在 REPL 数组中
- **这是折叠持久化跨轮次的关键**

### CtxInspectTool

用于检查上下文折叠状态：

```bash
/CtxInspect    # 需要 CONTEXT_COLLAPSE feature
```

### SnipTool 与 /force-snip

`/force-snip` 命令强制执行压缩：

```bash
/force-snip
```

通过 `snipCompactIfNeeded()` 函数检查是否需要压缩。

### Token Budget System

`query/tokenBudget.ts` 实现 Token 预算管理：

```typescript
interface TokenBudgetConfig {
  completionThreshold: number      // 默认 0.9 (90% 时停止)
  diminishingThreshold: number      // 默认 500 ( diminishing returns 阈值)
  maxContinuations: number        // 最大继续次数
}

// 事件追踪
tengu_token_budget_completed: {
  continuationCount: number
  pct: number
  diminishingReturns: boolean
}
```

### Context Suggestions

`src/utils/contextSuggestions.ts` 生成上下文优化建议：

```typescript
generateContextSuggestions()    // 生成建议
checkNearCapacity()             // 80% 时警告
checkLargeToolResults()        // 工具结果 > 15% 或 10k tokens
checkReadResultBloat()         // Read 结果 > 5% 或 10k tokens
checkMemoryBloat()             // Memory > 5% 或 5k tokens
checkAutoCompactDisabled()     // 50%+ 且 autocompact 关闭时警告
```

### 消息类型

| 类型 | 文件 | 说明 |
|------|------|------|
| `compact_boundary` | query.ts | 压缩边界，带 preservedSegment 元数据 |
| `tool_use_summary` | query.ts | Haiku 生成的工具摘要 |
| `api_retry` | query.ts | API 重试通知 |
| `hook_stopped_continuation` | stopHooks.ts | Stop hook 阻止继续 |
| `max_turns_reached` | query.ts | 达到最大轮次 |
| `structured_output` | query.ts | 工具的结构化输出 |
| `queued_command` | query.ts | SDK 用户消息的排队命令 |
| `tombstone` | query.ts | 删除消息的控制信号 |
| `microcompact_boundary` | microCompact.ts | 缓存微压缩 token 删除 |
| `edited_text_file` | attachments.ts | 文件更改附件 |

### Context Window 管理

`src/utils/context.ts` 中的上下文窗口管理：

```typescript
has1mContext()              // 检测 [1m] 后缀
modelSupports1M()           // Opus 4, Opus 4.6, Sonnet 4.6 支持
getContextWindowForModel()   // 完整解析链

// 环境变量
CLAUDE_CODE_DISABLE_1M_CONTEXT    // 硬禁用 1M 上下文
CLAUDE_CODE_MAX_CONTEXT_TOKENS    // ANT 专用上下文上限
CLAUDE_CODE_EMIT_TOOL_USE_SUMMARIES  // 发出 Haiku 工具摘要
```

### Query Loop State Machine

`query.ts` 的 queryLoop() 是状态机：

```typescript
type State = 'running' | 'completed' | 'stop_hook_prevented' | 'blocking_limit' | 'max_turns' | 'aborted_streaming'
```

### Query Checkpoint Profiling

性能分析检查点标记：

```
query_fn_entry, query_snip_start, query_snip_end,
query_microcompact_start, query_microcompact_end,
query_autocompact_start, query_autocompact_end,
query_setup_start, query_setup_end,
query_api_loop_start, query_api_streaming_start, query_api_streaming_end,
query_tool_execution_start, query_tool_execution_end,
query_recursive_call
```

### /context 命令

查看当前上下文使用情况：

```bash
/context
```

输出包含：
- MCP tools 使用量
- System tools 使用量
- System Prompt 大小
- Custom Agents
- Memory Files
- Skills
- Message Breakdown
