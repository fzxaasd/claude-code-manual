# 11.3 Plugin API

> Plugin development type reference

---

## Important Note

Claude Code plugins **have no runtime API**. Plugins declare all functionality (Skills, Agents, Hooks, MCP Servers, etc.) through `plugin.json` configuration files. There is no `initPlugin` entry function, nor any runtime APIs like `registerTool` or `registerSkill`.

Plugin manifests are driven by `plugin.json` configuration. There is no `PluginAPI` runtime interface.

---

## Core Types

### PluginManifest

Complete structure definition for plugin manifests (`src/utils/plugins/schemas.ts`):

```typescript
interface PluginManifest {
  // Metadata
  name: string                      // Required, kebab-case
  version?: string                  // semver
  description?: string
  author?: PluginAuthor
  homepage?: string
  repository?: string
  license?: string
  keywords?: string[]
  dependencies?: DependencyRef[]

  // Content paths (only supports path strings or arrays)
  commands?: CommandPath | CommandPath[] | Record<string, CommandMetadata>
  agents?: AgentPath | AgentPath[]
  hooks?: HooksConfig
  skills?: SkillPath | SkillPath[]
  outputStyles?: StylePath | StylePath[]
  strict?: boolean

  // Service configuration
  mcpServers?: McpConfig | McpBPath | RelativeJsonPath
  lspServers?: LspConfig | RelativeJsonPath

  // User configuration
  userConfig?: Record<string, UserConfigOption>
  channels?: ChannelConfig[]

  // Plugin-level settings
  settings?: Record<string, unknown>
}
```

### PluginAuthor

```typescript
interface PluginAuthor {
  name: string        // Required
  email?: string
  url?: string
}
```

### DependencyRef

```typescript
type DependencyRef =
  | "plugin"                           // Bare name
  | "plugin@marketplace"               // Marketplace-qualified
  | "plugin@marketplace@^1.2"          // With version constraint (silently ignored)
  | { name: string; marketplace?: string }  // Object form (other fields ignored)
```

---

## AgentDefinition

Agents use **markdown format** (not JSON), defined through frontmatter:

```typescript
// MCP server specification in agent definitions
// Can be either a reference to an existing server by name, or an inline definition
type AgentMcpServerSpec =
  | string  // Reference to existing server by name (e.g., "slack")
  | { [name: string]: McpServerConfig }  // Inline definition as { name: config }

interface AgentDefinition {
  name: string              // frontmatter: name
  description: string       // frontmatter: description
  model?: string            // frontmatter: model
  tools?: string[]          // frontmatter: tools (not allowedTools!)
  disallowedTools?: string[] // frontmatter: disallowedTools
  color?: 'red' | 'blue' | 'green' | 'yellow' | 'purple' | 'orange' | 'pink' | 'cyan'
                            // frontmatter: color, UI display color
  background?: boolean      // frontmatter: background, always run as background task
  memory?: 'user' | 'project' | 'local'
                            // frontmatter: memory, persistent memory scope
  isolation?: 'worktree'    // frontmatter: isolation, isolation mode
  effort?: string | number  // frontmatter: effort, effort level
  maxTurns?: number         // frontmatter: maxTurns, maximum agentic turns
  skills?: string[]         // frontmatter: skills, preloaded skill list
  permissionMode?: 'default' | 'acceptEdits' | 'bypassPermissions' | 'dontAsk' | 'plan'
                            // frontmatter: permissionMode, permission mode
  mcpServers?: AgentMcpServerSpec[]
                            // frontmatter: mcpServers, agent-specific MCP servers
  hooks?: HooksSettings     // frontmatter: hooks, session-scoped hooks
  initialPrompt?: string    // frontmatter: initialPrompt, prepended to first user turn
  requiredMcpServers?: string[]
                            // frontmatter: requiredMcpServers, MCP server name patterns
                            // that must be configured for agent to be available
  omitClaudeMd?: boolean    // Omit CLAUDE.md hierarchy from agent's userContext
  criticalSystemReminder_EXPERIMENTAL?: string
                            // Short message re-injected at every user turn
  // Note: system_prompt is NOT a frontmatter field!
  // System prompt comes from markdown body content (not frontmatter system_prompt)
}
```

### Example (agents/reviewer.md)

```markdown
---
name: reviewer
description: Code review Agent
model: sonnet
tools:
  - Read
  - Glob
  - Grep
  - Bash(git *)
disallowedTools:
  - Bash(rm *)
  - Write(/etc/**)
color: blue
memory: project
---

# Code Review Agent

Agent detailed description and usage guide.

This content will be used as the system prompt.
```

---

## HookDefinition

Hooks are defined through `hooks.json` configuration files:

```typescript
interface HooksConfig {
  description?: string
  hooks: {
    PreToolUse?: HookRule[]
    PostToolUse?: HookRule[]
    PostToolUseFailure?: HookRule[]
    Notification?: HookRule[]
    UserPromptSubmit?: HookRule[]
    SessionStart?: HookRule[]
    SessionEnd?: HookRule[]
    Stop?: HookRule[]
    StopFailure?: HookRule[]
    SubagentStart?: HookRule[]
    SubagentStop?: HookRule[]
    PreCompact?: HookRule[]
    PostCompact?: HookRule[]
    PermissionRequest?: HookRule[]
    PermissionDenied?: HookRule[]
    Setup?: HookRule[]
    TeammateIdle?: HookRule[]
    TaskCreated?: HookRule[]
    TaskCompleted?: HookRule[]
    Elicitation?: HookRule[]
    ElicitationResult?: HookRule[]
    ConfigChange?: HookRule[]
    WorktreeCreate?: HookRule[]
    WorktreeRemove?: HookRule[]
    InstructionsLoaded?: HookRule[]
    CwdChanged?: HookRule[]
    FileChanged?: HookRule[]
  }
}
```

### Hook Event Details

Total **27 Hook events**:

| Event | Trigger Timing | Common Uses |
|-------|----------------|-------------|
| `PreToolUse` | Before tool execution | Security checks, permission verification |
| `PostToolUse` | After tool execution | Logging, notifications |
| `PostToolUseFailure` | Tool execution failed | Error handling |
| `Notification` | Notification events | Message notifications |
| `UserPromptSubmit` | User submits prompt | Content moderation, filtering |
| `SessionStart` | Session starts | Initialization |
| `SessionEnd` | Session ends | Resource cleanup |
| `Stop` | Session stops | Graceful shutdown |
| `StopFailure` | Session stop failure | Error handling |
| `SubagentStart` | Subagent starts | Monitoring agents |
| `SubagentStop` | Subagent stops | Cleaning up agent resources |
| `PreCompact` | Before context compaction | Prepare compaction data |
| `PostCompact` | After context compaction | Verify compaction results |
| `PermissionRequest` | Permission request | Custom permission handling |
| `PermissionDenied` | Permission denied | Denial logging |
| `Setup` | Setup complete | Initialize plugin |
| `TeammateIdle` | Teammate idle | Task assignment |
| `TaskCreated` | Task created | Track tasks |
| `TaskCompleted` | Task completed | Aggregate results |
| `Elicitation` | Requesting user input | Custom input collection |
| `ElicitationResult` | User input result | Process user response |
| `ConfigChange` | Configuration changed | Respond to config changes |
| `WorktreeCreate` | Git worktree created | Workspace management |
| `WorktreeRemove` | Git worktree deleted | Clean up workspace |
| `InstructionsLoaded` | Instructions loaded | Modify system instructions |
| `CwdChanged` | Working directory changed | Path-related operations |
| `FileChanged` | File changed | File monitoring |

### HookRule

```typescript
interface HookRule {
  matcher?: string   // Matcher (tool name or "*"), optional
  hooks: HookEntry[] // Hook execution list
}
```

### HookEntry

Supports **4 Hook types**:

```typescript
// Type 1: Shell command
interface CommandHook {
  type: 'command'
  command: string       // Command path
  timeout?: number      // Timeout (seconds)
  shell?: 'bash' | 'powershell'  // Shell type
  if?: string           // Conditional rule, e.g., "Bash(git *)"
  once?: boolean        // Whether to run once
  async?: boolean       // Whether to run async in background
  asyncRewake?: boolean // Async execution, wake model on exit code 2
  statusMessage?: string // Custom status message
}

// Type 2: LLM prompt
interface PromptHook {
  type: 'prompt'
  prompt: string        // Prompt content
  model?: string        // Specified model
  if?: string           // Conditional rule
  once?: boolean        // Whether to run once
  statusMessage?: string // Custom status message
}

// Type 3: Agent verification
interface AgentHook {
  type: 'agent'
  agent: string         // Agent name
  model?: string        // Specified model
  if?: string           // Conditional rule
  once?: boolean        // Whether to run once
  statusMessage?: string // Custom status message
}

// Type 4: HTTP request (always uses POST)
interface HttpHook {
  type: 'http'
  url: string           // URL to POST the hook input JSON to
  headers?: Record<string, string> // Request headers
  allowedEnvVars?: string[] // Allowed environment variables
  statusMessage?: string // Custom status message
  once?: boolean        // Whether to run once
  if?: string           // Conditional rule
  timeout?: number      // Timeout (seconds)
}
```

### HookEntry Field Description

| Field | Type | Description |
|------|------|-------------|
| `type` | enum | Hook type: `command`/`prompt`/`agent`/`http` |
| `if` | string | Conditional rule, format like `"Bash(git commit)"` |
| `once` | boolean | When `true`, auto-remove after execution |
| `async` | boolean | When `true`, execute in background without blocking model |
| `asyncRewake` | boolean | When `true`, async execution, wake model on exit code 2 |
| `statusMessage` | string | Custom status message |

---

## MCP Server Configuration

### McpServerConfig

```typescript
interface McpServerConfig {
  command: string
  args?: string[]
  env?: Record<string, string>
  transport?: 'stdio' | 'sse' | 'sse-ide' | 'http' | 'ws' | 'sdk' | 'ws-ide' | 'claudeai-proxy'
}
```

### Transport Types

| Type | Description | Additional Fields |
|------|-------------|------------------|
| `stdio` | Standard input/output | `command`, `args`, `env` |
| `sse` | Server-Sent Events | `url`, `headers?`, `oauth?` |
| `sse-ide` | IDE SSE connection | - |
| `http` | HTTP POST | `url`, `headers?`, `oauth?` |
| `ws` | WebSocket | `url`, `headers?` |
| `sdk` | SDK server | `name` |
| `ws-ide` | IDE WebSocket | `url`, `authToken?` |
| `claudeai-proxy` | Claude.ai proxy | `url`, `id` |

### OAuth Configuration

```typescript
interface McpOAuthConfig {
  clientId?: string
  callbackPort?: number
  authServerMetadataUrl?: string  // Must be https://
  xaa?: boolean  // Cross-App Access (SEP-990)
}
```

### ws-ide Authentication

```typescript
interface WsIdeConfig {
  url: string
  authToken?: string
}
```

### Claude.ai Proxy Configuration

```typescript
interface McpClaudeAIProxyServerConfig {
  type: 'claudeai-proxy'
  url: string
  id: string
}
```

### ConfigScope

MCP server configuration scope:

```typescript
type ConfigScope = 'local' | 'user' | 'project' | 'dynamic' | 'enterprise' | 'claudeai' | 'managed'
```

### MCPServerConnection States

```typescript
type ConnectedMCPServer = {
  status: 'connected'
  name: string
  tools: Tool[]
  resources: Resource[]
}

type FailedMCPServer = {
  status: 'failed'
  name: string
  error: string
}

type NeedsAuthMCPServer = {
  status: 'needs_auth'
  name: string
  authType: 'oauth' | 'xaa'
}

type PendingMCPServer = {
  status: 'pending'
  name: string
}

type DisabledMCPServer = {
  status: 'disabled'
  name: string
}
```

### mcpServers Format

`mcpServers` in `plugin.json` supports the following formats:

```json
// Format 1: Inline object
{
  "mcpServers": {
    "db-server": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-postgres"],
      "env": { "DATABASE_URL": "${user_config.DATABASE_URL}" }
    }
  }
}

// Format 2: MCPB file path
{
  "mcpServers": "./servers.mcpb"
}

// Format 3: Remote MCPB URL
{
  "mcpServers": "https://example.com/servers.mcpb"
}

// Format 4: Configuration file path
{
  "mcpServers": "./.mcp.json"
}

// Format 5: Array (mixed)
{
  "mcpServers": ["./local.mcp.json", "./remote.mcpb"]
}
```

---

## LSP Server Configuration

### LspServerConfig

```typescript
interface LspServerConfig {
  command: string
  args?: string[]
  extensionToLanguage: Record<string, string>  // { ".ts": "typescript" }
  transport?: 'stdio' | 'socket'  // Only stdio and socket are supported
  env?: Record<string, string>
  initializationOptions?: unknown
  settings?: unknown
  workspaceFolder?: string
  startupTimeout?: number
  shutdownTimeout?: number
  restartOnCrash?: boolean
  maxRestarts?: number
}
```

**Note**: `transport` field only supports `'stdio'` and `'socket'`. `'sse'`, `'http'`, `'ws'` are **NOT** valid LSP transport types.

---

## PermissionUpdate Type

Permission update operation types:

```typescript
type PermissionUpdate =
  | { op: 'addRules'; rules: PermissionRule[] }
  | { op: 'replaceRules'; rules: PermissionRule[] }
  | { op: 'removeRules'; rules: PermissionRule[] }
  | { op: 'setMode'; mode: PermissionMode }
  | { op: 'addDirectories'; directories: AdditionalWorkingDirectory[] }
  | { op: 'removeDirectories'; directories: string[] }
```

### PermissionUpdateDestination

Destination for permission updates:

```typescript
type PermissionUpdateDestination =
  | 'userSettings'
  | 'projectSettings'
  | 'localSettings'
  | 'session'
  | 'cliArg'
```

### AdditionalWorkingDirectory

Additional allowed working directories:

```typescript
interface AdditionalWorkingDirectory {
  path: string
  source: 'cliArg' | 'hook'
}
```

---

## LoadedPlugin Type

Complete type after plugin loading:

```typescript
interface LoadedPlugin {
  name: string
  manifest: PluginManifest
  path: string
  source: string
  repository: string    // Repository identifier, usually same as source
  enabled?: boolean
  isBuiltin?: boolean   // true for built-in plugins
  sha?: string          // Git commit SHA (from marketplace entry source)

  // Component paths
  commandsPath?: string
  commandsPaths?: string[]
  agentsPath?: string
  agentsPaths?: string[]
  skillsPath?: string
  skillsPaths?: string[]
  outputStylesPath?: string
  outputStylesPaths?: string[]

  // Component metadata
  commandsMetadata?: Record<string, CommandMetadata>
  hooksConfig?: HooksSettings
  mcpServers?: Record<string, McpServerConfig>
  lspServers?: Record<string, LspServerConfig>
  settings?: Record<string, unknown>
}
```

### PluginRepository

```typescript
interface PluginRepository {
  url: string
  branch: string
  lastUpdated?: string
  commitSha?: string
}
```

---

## MarketplaceSource Type

```typescript
type MarketplaceSource =
  | { source: 'url'; url: string; headers?: Record<string, string> }
  | { source: 'github'; repo: string; sparsePaths?: string[]; path?: string; ref?: string }
  | { source: 'git'; url: string; sparsePaths?: string[]; path?: string; ref?: string }
  | { source: 'npm'; package: string }
  | { source: 'file'; path: string }
  | { source: 'directory'; path: string }
  | { source: 'hostPattern'; hostPattern: string }
  | { source: 'pathPattern'; pathPattern: string }
  | { source: 'settings'; name: string; plugins: SettingsMarketplacePlugin[]; owner?: PluginAuthor }
```

---

## InstalledPlugins Format

### V1 Format

```json
{
  "plugins": {
    "plugin-name": {
      "source": "...",
      "scope": "user",
      "gitCommitSha": "abc123..."
    }
  }
}
```

### V2 Format

```json
{
  "plugins": {
    "plugin-name": [
      {
        "source": "...",
        "scope": "user",
        "gitCommitSha": "abc123..."
      },
      {
        "source": "...",
        "scope": "project",
        "projectPath": "/path/to/project"
      }
    ]
  }
}
```

---

## PluginError Types

The plugin system defines 25 error types (`src/types/plugin.ts`):

| Error Type | Description |
|------------|-------------|
| `path-not-found` | Component path does not exist |
| `git-auth-failed` | Git authentication failed |
| `git-timeout` | Git operation timeout |
| `network-error` | Network error |
| `manifest-parse-error` | Manifest file parse failed |
| `manifest-validation-error` | Manifest field validation failed |
| `plugin-not-found` | Plugin not found in marketplace |
| `marketplace-not-found` | Marketplace not found |
| `marketplace-load-failed` | Marketplace load failed |
| `mcp-config-invalid` | MCP configuration invalid |
| `mcp-server-suppressed-duplicate` | MCP server duplicate suppressed |
| `hook-load-failed` | Hook load failed |
| `component-load-failed` | Component load failed |
| `mcpb-download-failed` | MCPB file download failed |
| `mcpb-extract-failed` | MCPB file extraction failed |
| `mcpb-invalid-manifest` | MCPB manifest invalid |
| `marketplace-blocked-by-policy` | Marketplace blocked by enterprise policy |
| `dependency-unsatisfied` | Dependency unsatisfied |
| `lsp-config-invalid` | LSP configuration invalid |
| `lsp-server-start-failed` | LSP server start failed |
| `lsp-server-crashed` | LSP server crashed |
| `lsp-request-timeout` | LSP request timeout |
| `lsp-request-failed` | LSP request failed |
| `plugin-cache-miss` | Plugin cache miss |
| `generic-error` | Generic error |

---

## Next Steps

- [11.4 Development Examples](./04-examples.md) - Complete development examples
