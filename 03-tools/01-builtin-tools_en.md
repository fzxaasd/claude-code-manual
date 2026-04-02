# Built-in Tools Reference

> In-depth analysis based on source code `src/tools.ts`, `src/Tool.ts`

## Tools Overview

Claude Code's tool system consists of **core tools** and **conditional tools**.

### Core Tools (Always Available)

| Tool | Class Name | Description |
|------|------------|-------------|
| AgentTool | AgentTool | Invoke sub-agent |
| BashTool | BashTool | Shell command execution |
| FileReadTool | FileReadTool | Read files |
| FileEditTool | FileEditTool | Edit files |
| FileWriteTool | FileWriteTool | Write files |
| NotebookEditTool | NotebookEditTool | Jupyter Notebook editing |
| WebFetchTool | WebFetchTool | Fetch web content |
| WebSearchTool | WebSearchTool | Web search |
| TodoWriteTool | TodoWriteTool | Task list management |
| TaskStopTool | TaskStopTool | Stop task |
| TaskOutputTool | TaskOutputTool | Get async task results |
| AskUserQuestionTool | AskUserQuestionTool | Ask user questions |
| SkillTool | SkillTool | Invoke skills |
| ExitPlanModeV2Tool | ExitPlanModeV2Tool | Exit plan mode |
| BriefTool | BriefTool | Summary generation |
| ListMcpResourcesTool | ListMcpResourcesTool | List MCP resources |
| ReadMcpResourceTool | ReadMcpResourceTool | Read MCP resources |

**Note**: `GlobTool` and `GrepTool` are silently excluded in the following cases: when the bun binary embeds ripgrep (using the same ARGV0 trick as ripgrep), and when find/grep are already aliased to these built-in tools in the Claude shell, the separate Glob/Grep tools are not needed.

### ANT User Exclusive Tools

The following tools are only available when `USER_TYPE === 'ant'`:

| Tool | Class Name | Description |
|------|------------|-------------|
| EnterPlanModeTool | EnterPlanModeTool | Enter plan mode |
| ConfigTool | ConfigTool | Configuration management |
| TungstenTool | TungstenTool | Tungsten tool |
| REPLTool | REPLTool | REPL execution environment |

### Conditional Tools (Requires Conditions)

| Tool | Condition | Description |
|------|-----------|-------------|
| TaskCreateTool | isTodoV2Enabled() | Create task |
| TaskGetTool | isTodoV2Enabled() | Get task |
| TaskUpdateTool | isTodoV2Enabled() | Update task |
| TaskListTool | isTodoV2Enabled() | List tasks |
| EnterWorktreeTool | isWorktreeModeEnabled() | Enter worktree |
| ExitWorktreeTool | isWorktreeModeEnabled() | Exit worktree |
| ToolSearchTool | isToolSearchEnabledOptimistic() | Tool search |
| SendMessageTool | COORDINATOR_MODE feature | Send message (coordinator mode) |
| LSPTool | ENABLE_LSP_TOOL environment variable | LSP language service |
| TeamCreateTool | isAgentSwarmsEnabled() | Create team |
| TeamDeleteTool | isAgentSwarmsEnabled() | Delete team |
| WorkflowTool | WORKFLOW_SCRIPTS feature | Workflow scripts |
| WebBrowserTool | WEB_BROWSER_TOOL feature | Web browser |
| SleepTool | PROACTIVE or KAIROS feature | Sleep tool |
| CronCreateTool | AGENT_TRIGGERS feature | Create scheduled task |
| CronDeleteTool | AGENT_TRIGGERS feature | Delete scheduled task |
| CronListTool | AGENT_TRIGGERS feature | List scheduled tasks |
| SnipTool | HISTORY_SNIP feature | History snippet |
| MonitorTool | MONITOR_TOOL feature | Monitor tool |
| SendUserFileTool | KAIROS feature | Send user file |
| PushNotificationTool | KAIROS or KAIROS_PUSH_NOTIFICATION feature | Push notification |
| SubscribePRTool | KAIROS_GITHUB_WEBHOOKS feature | Subscribe to PR |
| RemoteTriggerTool | AGENT_TRIGGERS_REMOTE feature | Remote trigger |
| ListPeersTool | UDS_INBOX feature | List peers |
| OverflowTestTool | OVERFLOW_TEST_TOOL feature | Overflow test |
| CtxInspectTool | CONTEXT_COLLAPSE feature | Context inspection |
| TerminalCaptureTool | TERMINAL_PANEL feature | Terminal capture |
| SuggestBackgroundPRTool | USER_TYPE === 'ant' | Suggest background PR |
| VerifyPlanExecutionTool | CLAUDE_CODE_VERIFY_PLAN=true | Verify plan execution |
| TestingPermissionTool | NODE_ENV === 'test' | Testing permission tool |
| PowerShellTool | PowerShell available and enabled | PowerShell execution |

---

## Tool Definition Structure

Based on source code `src/Tool.ts`, each tool is of type `Tool`:

```typescript
type Tool<Input, Output, P> = {
  // === Basic Info ===

  // Tool name
  name: string

  // Optional aliases (for backward compatibility with renamed tools)
  aliases?: string[]

  // 3-10 word capability phrase for ToolSearch keyword matching
  searchHint?: string

  // Input schema (Zod schema)
  inputSchema: Input

  // Optional: MCP tools can directly specify JSON Schema format input schema
  readonly inputJSONSchema?: ToolInputJSONSchema

  // Output schema
  outputSchema?: z.ZodType<unknown>

  // Tool description
  description(input): Promise<string>

  // Execution function
  call(args, context, canUseTool, parentMessage, onProgress?): Promise<ToolResult<Output>>

  // === Permissions & State ===

  // Whether enabled
  isEnabled(): boolean

  // Whether read-only
  isReadOnly(input): boolean

  // Whether destructive (only set when performing irreversible operations like delete, overwrite, send)
  isDestructive?(input): boolean

  // Whether concurrency-safe
  isConcurrencySafe(input): boolean

  // Interrupt behavior ('cancel' = stop and discard results; 'block' = continue running, new messages wait)
  interruptBehavior?(): 'cancel' | 'block'

  // === Permission Checks ===

  // Input validation
  validateInput?(input, context): Promise<ValidationResult>

  // Permission check
  checkPermissions(input, context): Promise<PermissionResult>

  // Permission matcher (for hook `if` condition rule pattern matching)
  preparePermissionMatcher?(input): Promise<(pattern: string) => boolean>

  // === UI Rendering ===

  // Render tool use message
  renderToolUseMessage(input, options): ReactNode

  // Render tool result
  renderToolResultMessage?(content, progress, options): ReactNode

  // Render progress message
  renderToolUseProgressMessage?(progress, options): ReactNode

  // Render queued message
  renderToolUseQueuedMessage?(): ReactNode

  // Render rejected message
  renderToolUseRejectedMessage?(input, options): ReactNode

  // Render error message
  renderToolUseErrorMessage?(result, options): ReactNode

  // Grouped rendering (multiple parallel tool calls displayed as a group)
  renderGroupedToolUse?(toolUses, options): ReactNode | null

  // Render tool use tag (timeout, model, resume ID etc metadata)
  renderToolUseTag?(input): ReactNode

  // Determine if output is truncated in non-verbose mode (decides whether to show click to expand)
  isResultTruncated?(output): boolean

  // === Summary & Classification ===

  // Tool use summary
  getToolUseSummary?(input): string | null

  // Activity description (for spinner display, e.g. "Reading src/foo.ts")
  getActivityDescription?(input): string | null

  // Auto-classifier input
  toAutoClassifierInput(input): unknown

  // Search text extraction (for transcript search indexing)
  extractSearchText?(output): string

  // === Search/Read Identification ===

  // Whether search or read operation
  isSearchOrReadCommand?(input): { isSearch: boolean; isRead: boolean; isList?: boolean }

  // Whether open-world operation
  isOpenWorld?(input): boolean

  // Whether requires user interaction
  requiresUserInteraction?(): boolean

  // === Lazy Loading (ToolSearch) ===

  // When true, tool is lazily loaded (defer_loading: true), requires ToolSearch first
  readonly shouldDefer?: boolean

  // When true, even with ToolSearch enabled, tool's full schema appears in initial prompt
  readonly alwaysLoad?: boolean

  // === Transparent Wrapper ===

  // Transparent wrapper (like REPL) delegates all rendering to progress handler, shows nothing itself
  isTransparentWrapper?(): boolean

  // === Input Backfill ===

  // Called before observer sees tool input (SDK stream, transcript, canUseTool, hooks)
  // Must be idempotent, original API input is never changed
  backfillObservableInput?(input): void

  // === Input Equivalence ===

  // Determine if two inputs are equivalent (for tool deduplication)
  inputsEquivalent?(a, b): boolean

  // === File Path ===

  // Optional method, applicable to tools that operate on file paths
  getPath?(input): string

  // === Strict Mode ===

  // When true, enables strict mode requiring API to more strictly follow tool instructions and parameter schema
  // Only takes effect when tengu_tool_pear is enabled
  readonly strict?: boolean

  // === MCP Related ===

  // Whether MCP tool
  isMcp?: boolean

  // Whether LSP tool
  isLsp?: boolean

  // MCP info (server name and tool name, from MCP server's original name)
  mcpInfo?: { serverName: string; toolName: string }

  // === Other ===

  // Max result size (characters); when exceeded, result is persisted to disk, Claude receives preview and path
  maxResultSizeChars: number

  // User-facing name (defaults to tool name)
  userFacingName(input): string

  // User-facing name background color
  userFacingNameBackgroundColor?(input): keyof Theme | undefined
}
```

---

## Core Tools Detail

### 1. BashTool (Bash)

Shell command execution tool.

**Input parameters**:
```typescript
interface BashInput {
  command: string           // Command to execute
  timeout?: number         // Timeout in milliseconds
  current_dir?: string     // Working directory
  bg?: boolean             // Run in background
}
```

**Permission rules**: BashTool has its own `checkPermissions` logic, permission rules are based on the command itself rather than glob pattern matching parameters. Refer to implementation in `src/tools/BashTool/` for specific rules.

**Search/Read classification**:
```typescript
// These commands are recognized as read-only operations
BASH_SEARCH_COMMANDS = ['find', 'grep', 'rg', 'ag', 'ack', 'locate', 'which']
BASH_READ_COMMANDS = ['cat', 'head', 'tail', 'less', 'more', 'wc', 'stat', 'file']
BASH_LIST_COMMANDS = ['ls', 'tree', 'du']
```

---

### 2. FileReadTool (Read)

Read file contents.

**Input parameters**:
```typescript
interface ReadInput {
  file_path: string        // File path
  limit?: number          // Limit number of lines
  offset?: number         // Starting line
  pages?: string          // PDF page range
}
```

**Features**:
- Read regular files
- Read images (base64 encoded)
- Read PDFs (with pagination support)
- Read Jupyter Notebooks

---

### 3. FileWriteTool (Write)

Create or overwrite files.

**Input parameters**:
```typescript
interface WriteInput {
  file_path: string        // File path
  content: string         // File content
}
```

---

### 4. FileEditTool (Edit)

Partially modify files.

**Input parameters**:
```typescript
interface EditInput {
  file_path: string        // File path
  old_string: string       // Text to replace
  new_string: string       // Replacement text
  replace_all?: boolean    // Replace all matches
}
```

---

### 5. GlobTool (Glob)

File pattern matching.

**Input parameters**:
```typescript
interface GlobInput {
  pattern: string          // Glob pattern
  cwd?: string             // Search directory
}
```

**Examples**:
```
**/*.ts              # All TypeScript files
src/**/*.{js,ts}    # JS/TS files under src
!test/**             # Exclude test directory
**/node_modules/**  # Exclude node_modules
```

**Note**: This tool is silently excluded when the bun binary embeds ripgrep/fastglob.

---

### 6. GrepTool (Grep)

Regular expression search.

**Input parameters**:
```typescript
interface GrepInput {
  pattern: string          // Regular expression
  path?: string            // Search path
  "-n"?: boolean           // Show line numbers
  "-i"?: boolean           // Case insensitive
  "-C"?: number           // Context lines
  output_mode?: 'content' | 'files_with_matches' | 'count'
}
```

**Note**: This tool is silently excluded when the bun binary embeds ripgrep.

---

### 7. WebFetchTool (WebFetch)

Fetch web page content.

**Input parameters**:
```typescript
interface WebFetchInput {
  url: string              // Web URL
  prompt?: string         // Extraction prompt
}
```

---

### 8. WebSearchTool (WebSearch)

Web search.

**Input parameters**:
```typescript
interface WebSearchInput {
  query: string            // Search query
  source?: 'news' | 'reddit' | 'wikipedia'
}
```

---

### 9. AgentTool

Invoke sub-agent.

**Input parameters**:
```typescript
interface AgentInput {
  name: string             // Agent name
  prompt?: string          // Task description
  subagent_type?: string   // Agent type
}
```

---

### 10. TaskOutputTool

Get async task results.

**Input parameters**:
```typescript
interface TaskOutputInput {
  task_id: string          // Task ID
  block?: boolean          // Whether to block and wait
  timeout?: number         // Timeout
}
```

---

## Tool Permission Modes

### PermissionMode Type

```typescript
type PermissionMode =
  | "default"              // Default, ask each time
  | "acceptEdits"          // Auto-accept edits
  | "bypassPermissions"    // Bypass all checks
  | "dontAsk"             // Don't ask, silently deny unauthorized operations
  | "plan"                // Plan mode only, analyze without executing
  | "auto"                // Auto mode
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

### Permission Rule Syntax

```bash
# Basic format
ToolName(pattern)

# Examples
Bash(git *)               # All commands starting with git
Read(*.md)                # Only read markdown files
Write(*.ts)               # Only write TypeScript files
Edit(!*.json)             # All files except JSON
Glob(**/*.tsx)             # All TSX files
mcp__server__*            # All tools from a specific MCP server
```

---

## Configuration Examples

### settings.json Permission Configuration

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

## Tool Default Behavior

From `TOOL_DEFAULTS` in `src/Tool.ts`:

```typescript
const TOOL_DEFAULTS = {
  isEnabled: () => true,                              // Enabled by default
  isConcurrencySafe: (_input?: unknown) => false,      // Not concurrency-safe by default
  isReadOnly: (_input?: unknown) => false,             // Writable by default
  isDestructive: (_input?: unknown) => false,         // Non-destructive by default
  checkPermissions: (input) => ({ behavior: 'allow', updatedInput: input }),
  toAutoClassifierInput: (_input?: unknown) => '',     // Skip classifier
  userFacingName: (_input?: unknown) => ''
}
```

---

## Testing

Run the test script to verify tool configuration:
```bash
bash tests/03-tools-test.sh
```
