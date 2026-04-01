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
| BriefTool | BriefTool | 摘要生成 |
| ListMcpResourcesTool | ListMcpResourcesTool | 列出 MCP 资源 |
| ReadMcpResourceTool | ReadMcpResourceTool | 读取 MCP 资源 |

**注意**：`GlobTool` 和 `GrepTool` 在以下情况会被静默排除：当 bun 二进制内嵌了 ripgrep 时（与 ripgrep 相同的 ARGV0 trick），find/grep 已在 Claude shell 中别名指向这些内置工具，此时不需要单独的 Glob/Grep 工具。

### ANT 用户专属工具

以下工具仅在 `USER_TYPE === 'ant'` 时可用：

| 工具 | 类名 | 说明 |
|------|------|------|
| EnterPlanModeTool | EnterPlanModeTool | 进入计划模式 |
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
| SendMessageTool | COORDINATOR_MODE feature | 发送消息（协调模式） |
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
  command: string           // 要执行的命令
  timeout?: number         // 超时时间（毫秒）
  current_dir?: string     // 执行目录
  bg?: boolean             // 后台执行
}
```

**权限规则**：BashTool 有自己的 `checkPermissions` 逻辑，权限规则基于命令本身而非 glob 模式匹配参数。请参考 `src/tools/BashTool/` 中的实现了解具体规则。

**搜索/读取分类**：
```typescript
// 这些命令会被识别为只读操作
BASH_SEARCH_COMMANDS = ['find', 'grep', 'rg', 'ag', 'ack', 'locate', 'which']
BASH_READ_COMMANDS = ['cat', 'head', 'tail', 'less', 'more', 'wc', 'stat', 'file']
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
  cwd?: string             // 搜索目录
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
  path?: string            // 搜索路径
  "-n"?: boolean           // 显示行号
  "-i"?: boolean           // 忽略大小写
  "-C"?: number           // 上下文行数
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
  prompt?: string         // 提取提示
}
```

---

### 8. WebSearchTool (WebSearch)

网络搜索。

**输入参数**：
```typescript
interface WebSearchInput {
  query: string            // 搜索查询
  source?: 'news' | 'reddit' | 'wikipedia'
}
```

---

### 9. AgentTool

调用子 Agent。

**输入参数**：
```typescript
interface AgentInput {
  name: string             // Agent 名
  prompt?: string          // 任务描述
  subagent_type?: string   // Agent 类型
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

## 测试验证

运行测试脚本验证工具配置：
```bash
bash tests/03-tools-test.sh
```
