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
| EnterPlanModeTool | EnterPlanModeTool | Enter plan mode (deferred) |
| SendUserMessageTool | SendUserMessageTool | Send message to user |
| ListMcpResourcesTool | ListMcpResourcesTool | List MCP resources |
| ReadMcpResourceTool | ReadMcpResourceTool | Read MCP resources |

**Note**: `GlobTool` and `GrepTool` are silently excluded in the following cases: when the bun binary embeds ripgrep (using the same ARGV0 trick as ripgrep), and when find/grep are already aliased to these built-in tools in the Claude shell, the separate Glob/Grep tools are not needed.

### ANT User Exclusive Tools

The following tools are only available when `USER_TYPE === 'ant'`:

| Tool | Class Name | Description |
|------|------------|-------------|
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
| SendMessageTool | isAgentSwarmsEnabled() | Send message (Team mode) |
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
  command: string                       // Command to execute
  timeout?: number                     // Timeout in milliseconds
  description?: string                 // Command description (for logging)
  run_in_background?: boolean        // Run in background (not bg)
  dangerouslyDisableSandbox?: boolean // Disable sandbox
}
```

**Permission rules**: BashTool has its own `checkPermissions` logic, permission rules are based on the command itself rather than glob pattern matching parameters. Refer to implementation in `src/tools/BashTool/` for specific rules.

**Search/Read classification**:
```typescript
// These commands are recognized as read-only operations
BASH_SEARCH_COMMANDS = ['find', 'grep', 'rg', 'ag', 'ack', 'locate', 'which', 'whereis']
BASH_READ_COMMANDS = ['cat', 'head', 'tail', 'less', 'more', 'wc', 'stat', 'file', 'strings', 'jq', 'awk', 'cut', 'sort', 'uniq', 'tr']
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
  path?: string           // Search directory (not cwd)
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
  path?: string           // Search path
  glob?: string           // Filename filter pattern
  "-n"?: boolean          // Show line numbers
  "-i"?: boolean          // Case insensitive
  "-C"?: number          // Context lines
  "-B"?: number          // Lines before match
  "-A"?: number          // Lines after match
  context?: number        // Alias for -C
  type?: string            // File type filter (e.g., "js", "py")
  head_limit?: number     // Limit result count
  offset?: number         // Skip results
  multiline?: boolean     // Multiline mode
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
  prompt: string            // Extraction prompt (required)
}
```

---

### 8. WebSearchTool (WebSearch)

Web search.

**Input parameters**:
```typescript
interface WebSearchInput {
  query: string                       // Search query
  allowed_domains?: string[]          // Restrict to domains
  blocked_domains?: string[]         // Exclude domains
}
```

---

### 9. AgentTool

Invoke sub-agent.

**Input parameters**:
```typescript
interface AgentInput {
  description: string                  // Agent description (required, 3-5 words)
  prompt: string                      // Task description (required)
  subagent_type?: string             // Agent type
  model?: 'sonnet' | 'opus' | 'haiku' // Specify model
  run_in_background?: boolean        // Run in background
  // Multi-agent mode parameters
  name?: string                      // Agent instance name
  team_name?: string                 // Team name
  mode?: PermissionMode              // Permission mode
  isolation?: 'worktree'             // Isolation mode
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

## Undocumented Tool Features

The following features exist in source code but are not covered in the main documentation:

### Read Tool (FileReadTool)

| Feature | Description |
|---------|-------------|
| `pages` | PDF page range (e.g., `"1-5"`, `"3"`, `"10-20"`) |
| File de-duplication | Returns `file_unchanged` for unchanged files |
| Device path blocking | `/dev/zero`, `/dev/random` would block |
| Image dimension metadata | Returns `dimensions` for coordinate mapping |

### Write Tool (FileWriteTool)

| Feature | Description |
|---------|-------------|
| `structuredPatch` | Returns diff patch |
| `originalFile` | Returns content before write |
| `gitDiff` | Available when `tengu_quartz_lantern` feature enabled |
| LSP notification | Notifies LSP servers of file changes |

### Edit Tool (FileEditTool)

| Feature | Description |
|---------|-------------|
| `replace_all` | Boolean to replace all matches |
| Quote preservation | Automatically preserves curly quotes |
| 1GB file limit | Files over 1GB cannot be edited |

### Glob Tool

| Feature | Description |
|---------|-------------|
| 100 file limit | Maximum 100 results by default |
| `truncated` | Indicates if results were truncated |
| `durationMs` | Returns execution time |

### Grep Tool

| Feature | Description |
|---------|-------------|
| `-C` alias | Same as `context` parameter |
| `offset` | Skip first N results |
| `multiline` | `.` matches newlines |
| `type` | Filter by file type (js, py, rust) |
| VCS exclusion | Auto-excludes `.git`, `.svn`, `.hg` |

### Bash Tool

| Feature | Description |
|---------|-------------|
| `run_in_background` | Run command in background |
| `dangerouslyDisableSandbox` | Override sandbox mode |
| Auto-backgrounding | 15s auto-background in assistant mode |
| Large output persistence | `persistedOutputPath` |

### NotebookEdit Tool

| Feature | Description |
|---------|-------------|
| `cell_id` | Supports numeric indices (cell-N format) |
| `edit_mode` | `replace`, `insert`, `delete` |
| `cell_type` | `code` or `markdown` (required for insert) |

### LSP Tool

| Feature | Description |
|---------|-------------|
| 8 operations | goToDefinition, findReferences, hover, etc. |
| 10MB file limit | Maximum file size for LSP analysis |
| Gitignore filtering | Filters gitignored results |

### Task V2

| Feature | Description |
|---------|-------------|
| `addBlocks` | Add blocking tasks |
| `blockedBy` | Task dependencies |
| `metadata` | Supports null deletion |
| `activeForm` | Spinner text |

### SendMessage Tool

| Feature | Description |
|---------|-------------|
| Structured messages | `shutdown_request`, `shutdown_response` |
| Cross-session | UDS/bridge messaging |
| Auto-resume | Stopped agents auto-resume |

---

## Undocumented Tools

The following tools exist in source code but are not documented:

| Tool Name | Feature Gate | Description |
|---------|-------------|-------------|
| `PowerShellTool` | PowerShell available | PowerShell execution |
| `SnipTool` | `HISTORY_SNIP` | History snippet tool |
| `MonitorTool` | `MONITOR_TOOL` | Monitoring tool |
| `SendUserFileTool` | `KAIROS` | Send user file |
| `PushNotificationTool` | `KAIROS_PUSH_NOTIFICATION` | Push notifications |
| `SubscribePRTool` | `KAIROS_GITHUB_WEBHOOKS` | PR subscription |
| `RemoteTriggerTool` | `AGENT_TRIGGERS_REMOTE` | Remote trigger management |
| `ListPeersTool` | `UDS_INBOX` | List UDS peers |
| `CtxInspectTool` | `CONTEXT_COLLAPSE` | Context inspection |
| `TerminalCaptureTool` | `TERMINAL_PANEL` | Terminal capture |
| `VerifyPlanExecutionTool` | `CLAUDE_CODE_VERIFY_PLAN=true` | Plan verification |
| `MCPTool` | MCP tools | MCP tool wrapper |
| `McpAuthTool` | MCP auth | MCP authentication |
| `SyntheticOutputTool` | Hook structured output | Structured output (internal special tool, runtime name `StructuredOutput`, used for Hook JSON Schema results) |

---

## Undocumented Tool Parameters

### BashTool Additional Parameters

```typescript
{
  command: string,
  timeout?: number,
  description?: string,              // Command description for logging
  run_in_background?: boolean,        // Background execution
  dangerouslyDisableSandbox?: boolean,
}
```

### AgentTool Runtime Parameters

```typescript
{
  description: string,
  prompt: string,
  subagent_type?: string,
  model?: 'sonnet' | 'opus' | 'haiku',  // model override for THIS call
  run_in_background?: boolean,
  name?: string,           // teammate name
  team_name?: string,      // team name
  mode?: PermissionMode,   // spawn permission mode
  isolation?: 'worktree' | 'remote',  // isolation mode
  cwd?: string,            // KAIROS only
}
```

### SendMessageTool Routing Prefixes

```typescript
// Supported prefix formats:
// "uds:<socket-path>" - Unix Domain Socket
// "bridge:<session-id>" - Remote Control peer
// "team-lead" - Team leader
```

### TaskOutputTool Parameters

```typescript
{
  task_id: string,
  block?: boolean,        // default true
  timeout?: number,       // default 30000ms, max 600000ms
}
```

### SkillTool Output Types

```typescript
// inline response
{ success: true, commandName: string, allowedTools?: string[], model?: string, status: 'inline' }

// forked response
{ success: true, commandName: string, status: 'forked', agentId: string, result: unknown }
```

---

## Testing

Run the test script to verify tool configuration:
```bash
bash tests/03-tools-test.sh
```

---

## Context Collapse: Four-Layer Context Management System

Claude Code uses a **four-layer context management strategy** to optimize context efficiency in long sessions.

### Four-Layer Architecture

| Layer | Feature Flag | Mechanism | Description |
|-------|-------------|-----------|-------------|
| 1 | `CACHED_MICROCOMPACT` | Microcompact | Deduplicates repeated tool results, caches edits |
| 2 | `HISTORY_SNIP` | History Snip | Deletes messages before the pre-compression protection tail |
| 3 | `CONTEXT_COLLAPSE` | Context Collapse | Granular-to-summary projection (core layer) |
| 4 | - | Autocompact | Traditional full-history summarization |

### Context Collapse Core Mechanism

`src/services/contextCollapse/` implements the context collapse strategy:

```typescript
// Primary functions
applyCollapsesIfNeeded()     // Apply collapses
isContextCollapseEnabled()   // Check if enabled
getStats()                  // Retrieve statistics
recoverFromOverflow()        // Handle 413 errors
```

### Collapse View Projection

Context Collapse projects collapsed views through a **commit log**:

- Summarized messages are stored in the collapse store
- They are not stored in the REPL array
- **This is the key to collapse persistence across turns**

### CtxInspectTool

Used to inspect context collapse state:

```bash
/CtxInspect    # Requires CONTEXT_COLLAPSE feature flag
```

### SnipTool and /force-snip

The `/force-snip` command forces compression:

```bash
/force-snip
```

It triggers the `snipCompactIfNeeded()` function to check whether compression is needed.

### Token Budget System

`query/tokenBudget.ts` implements token budget management:

```typescript
interface TokenBudgetConfig {
  completionThreshold: number      // Default 0.9 (stop at 90%)
  diminishingThreshold: number      // Default 500 (diminishing returns threshold)
  maxContinuations: number        // Maximum continuation count
}

// Event tracking
tengu_token_budget_completed: {
  continuationCount: number
  pct: number
  diminishingReturns: boolean
}
```

### Context Suggestions

`src/utils/contextSuggestions.ts` generates context optimization suggestions:

```typescript
generateContextSuggestions()    // Generate suggestions
checkNearCapacity()             // Warn at 80% capacity
checkLargeToolResults()        // Tool results > 15% or 10k tokens
checkReadResultBloat()         // Read results > 5% or 10k tokens
checkMemoryBloat()             // Memory > 5% or 5k tokens
checkAutoCompactDisabled()     // Warn at 50%+ when autocompact is disabled
```

### Message Types

| Type | File | Description |
|------|------|-------------|
| `compact_boundary` | query.ts | Compression boundary with preservedSegment metadata |
| `tool_use_summary` | query.ts | Haiku-generated tool summary |
| `api_retry` | query.ts | API retry notification |
| `hook_stopped_continuation` | stopHooks.ts | Stop hook prevented continuation |
| `max_turns_reached` | query.ts | Maximum turns reached |
| `structured_output` | query.ts | Structured output for tools |
| `queued_command` | query.ts | Queued command for SDK user messages |
| `tombstone` | query.ts | Control signal to delete messages |
| `microcompact_boundary` | microCompact.ts | Cached microcompact token deletion |
| `edited_text_file` | attachments.ts | File change attachment |

### Context Window Management

Context window management in `src/utils/context.ts`:

```typescript
has1mContext()              // Detect [1m] suffix
modelSupports1M()           // Supported by Opus 4, Opus 4.6, Sonnet 4.6
getContextWindowForModel()   // Full resolution chain

// Environment variables
CLAUDE_CODE_DISABLE_1M_CONTEXT    // Hard-disable 1M context
CLAUDE_CODE_MAX_CONTEXT_TOKENS    // ANT-specific context upper limit
CLAUDE_CODE_EMIT_TOOL_USE_SUMMARIES  // Emit Haiku tool summaries
```

### Query Loop State Machine

`queryLoop()` in `query.ts` is a state machine:

```typescript
type State = 'running' | 'completed' | 'stop_hook_prevented' | 'blocking_limit' | 'max_turns' | 'aborted_streaming'
```

### Query Checkpoint Profiling

Performance analysis checkpoint markers:

```
query_fn_entry, query_snip_start, query_snip_end,
query_microcompact_start, query_microcompact_end,
query_autocompact_start, query_autocompact_end,
query_setup_start, query_setup_end,
query_api_loop_start, query_api_streaming_start, query_api_streaming_end,
query_tool_execution_start, query_tool_execution_end,
query_recursive_call
```

### /context Command

View current context usage:

```bash
/context
```

Output includes:
- MCP tools usage
- System tools usage
- System Prompt size
- Custom Agents
- Memory Files
- Skills
- Message Breakdown

