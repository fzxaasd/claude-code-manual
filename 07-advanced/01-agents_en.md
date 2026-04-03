# Agent System

> Deep analysis based on source code `src/tools/AgentTool/`

## Core Concepts

### Agent Types

Claude Code has three Agent sources:

| Type | Source | Description |
|------|--------|-------------|
| **Built-in** | Claude Code built-in | General Purpose, Explore, Plan, etc. |
| **Custom** | User/project configuration | `~/.claude/agents/` or `.claude/agents/` |
| **Plugin** | Plugin provided | Agents from plugins |

### Built-in Agent List

Based on standalone files under `src/tools/AgentTool/built-in/`:

| File | Agent | Description |
|------|-------|-------------|
| `generalPurposeAgent.ts` | GENERAL_PURPOSE_AGENT | General-purpose sub-agent |
| `statuslineSetup.ts` | STATUSLINE_SETUP_AGENT | Status bar setup |
| `exploreAgent.ts` | EXPLORE_AGENT | Codebase exploration |
| `planAgent.ts` | PLAN_AGENT | Task planning |
| `claudeCodeGuideAgent.ts` | CLAUDE_CODE_GUIDE_AGENT | Claude Code usage guide |
| `verificationAgent.ts` | VERIFICATION_AGENT | Verification agent |
| `forkSubagent.ts` | FORK_AGENT | Fork sub-agent |
| `coordinator/workerAgent.ts` | COORDINATOR_WORKER_AGENT | Coordinator worker node |

```typescript
export function getBuiltInAgents(): AgentDefinition[] {
  const agents = [
    GENERAL_PURPOSE_AGENT,   // General-purpose sub-agent
    STATUSLINE_SETUP_AGENT, // Status bar setup
  ]

  // EXPLORE/PLAN agents are disabled by default, controlled by feature flag
  if (areExplorePlanAgentsEnabled()) {
    agents.push(EXPLORE_AGENT, PLAN_AGENT)
  }

  // CLAUDE_CODE_GUIDE_AGENT is only included for non-SDK entrypoints
  // SDK entrypoints (sdk-ts, sdk-py, sdk-cli) do not show the guide agent
  const isNonSdkEntrypoint =
    process.env.CLAUDE_CODE_ENTRYPOINT !== 'sdk-ts' &&
    process.env.CLAUDE_CODE_ENTRYPOINT !== 'sdk-py' &&
    process.env.CLAUDE_CODE_ENTRYPOINT !== 'sdk-cli'

  if (isNonSdkEntrypoint) {
    agents.push(CLAUDE_CODE_GUIDE_AGENT)
  }

  // VERIFICATION_AGENT is controlled by feature flag
  if (feature('VERIFICATION_AGENT') && growthbook('tengu_hive_evidence')) {
    agents.push(VERIFICATION_AGENT)
  }

  // COORDINATOR_MODE: multi-worker coordination mode
  if (feature('COORDINATOR_MODE')) {
    if (isEnvTruthy(process.env.CLAUDE_CODE_COORDINATOR_MODE)) {
      agents.push(getCoordinatorAgents())
    }
  }

  return agents
}
```

**Built-in Agent Enable Conditions**:
| Agent | Default State | Control Method |
|-------|---------------|----------------|
| GENERAL_PURPOSE_AGENT | Always enabled | - |
| STATUSLINE_SETUP_AGENT | Always enabled | - |
| EXPLORE_AGENT | Disabled | `BUILTIN_EXPLORE_PLAN_AGENTS` feature + `tengu_amber_stoat` |
| PLAN_AGENT | Disabled | Same as above |
| CLAUDE_CODE_GUIDE_AGENT | Enabled (non-SDK) | Only disabled for `sdk-ts/py/cli` entrypoints |
| VERIFICATION_AGENT | Disabled | `VERIFICATION_AGENT` feature + `tengu_hive_evidence` |
| FORK_AGENT | Enabled | `FORK_SUBAGENT` feature |
| COORDINATOR_WORKER_AGENT | Disabled | `COORDINATOR_MODE` feature |

**One-Shot Agent**:
```typescript
// Explore and Plan are one-shot agents, not continued by SendMessage
export const ONE_SHOT_BUILTIN_AGENT_TYPES = new Set(['Explore', 'Plan'])
```

**Explore/Plan Agent Model Configuration**:
- Explore/Plan agents read the `omitClaudeMd` field to skip CLAUDE.md context for token savings
- Model configuration: `explore: haiku (non-ANT) / inherit (ANT) | plan: inherit`

**Fork Agent Characteristics**:
- `maxTurns`: 200
- `permissionMode`: 'bubble'
- Inherits full conversation context from parent

### Difference Between Agent and Skill

| Dimension | Skill | Agent |
|-----------|-------|-------|
| Use case | Single task | Complex workflow |
| Context | Shared main session | Independent context |
| Tool limits | Can be restricted | Can be restricted |
| Execution | Inline/fork | Sub-agent |
| Trigger | `/skill-name` | `AgentTool` |

---

## Agent Definition Structure

Based on type definitions in `src/tools/AgentTool/loadAgentsDir.ts`:

### BaseAgentDefinition

```typescript
interface BaseAgentDefinition {
  // Required fields
  agentType: string          // Agent unique identifier
  whenToUse: string          // Use case description

  // Tool configuration
  tools?: string[]           // Allowed tool list
  disallowedTools?: string[]  // Disallowed tool list

  // Model and performance
  model?: string             // Specified model
  effort?: EffortValue       // Effort level
  permissionMode?: PermissionMode  // Permission mode (optional)

  // MCP configuration
  mcpServers?: AgentMcpServerSpec[]  // MCP servers
  requiredMcpServers?: string[]      // Required MCP server names (built-in agents only, not supported for user configuration)
  // Note: requiredMcpServers can only be set in built-in agent code, cannot be configured via user markdown/JSON

  // Hooks
  hooks?: HooksSettings      // Associated hooks

  // Execution control
  maxTurns?: number         // Maximum turns
  background?: boolean       // Run in background

  // Skills
  skills?: string[]          // Preloaded skills

  // Prompt
  initialPrompt?: string    // Initial prompt
  criticalSystemReminder_EXPERIMENTAL?: string  // System prompt re-injected on each user message turn

  // Memory
  memory?: AgentMemoryScope // Memory scope
  pendingSnapshotUpdate?: { snapshotTimestamp: string }  // Pending snapshot update

  // Isolation
  isolation?: 'worktree' | 'remote'  // Isolation mode (remote is ant-only)

  // Special options
  omitClaudeMd?: boolean    // Omit CLAUDE.md (default for Explore/Plan agents)
  color?: AgentColorName    // Agent color

  // Metadata (internal fields, populated by loader, not part of frontmatter)
  /** @internal Original filename (populated by loader) */
  filename?: string
  /** @internal Base directory (populated by loader) */
  baseDir?: string
}
```

> Note: The `prompt` field only exists in JSON format (`--agents` CLI argument). Markdown files use body content as prompt.

### Agent Definition Sources

```typescript
// Built-in Agent - Dynamic prompts
type BuiltInAgentDefinition = BaseAgentDefinition & {
  source: 'built-in'
  baseDir: 'built-in'
  callback?: () => void
  getSystemPrompt: (params) => string  // Dynamic generation
}

// Custom Agent - From configuration
type CustomAgentDefinition = BaseAgentDefinition & {
  source: SettingSource  // 'user' | 'project' | 'policy' | 'local'
  getSystemPrompt: () => string
}

// Plugin Agent - From plugin
type PluginAgentDefinition = BaseAgentDefinition & {
  source: 'plugin'
  plugin: string          // Plugin name
  getSystemPrompt: () => string
}
```

### Agent Source Priority

Based on `getActiveAgentsFromList` in `src/tools/AgentTool/loadAgentsDir.ts`:

```typescript
// Agent priority (latter overrides former)
const agentGroups = [
  builtInAgents,    // Lowest priority
  pluginAgents,
  userAgents,       // ~/.agents/
  projectAgents,    // ./.claude/agents/
  flagAgents,      // --agents CLI argument
  managedAgents,   // policySettings (highest priority)
]
```

**Priority Order (low to high)**:
```
built-in < plugin < user < project < flag < managed
```

**Source Details**:
| Source | SettingSource | Configuration Location |
|--------|--------------|------------------------|
| built-in | `built-in` | Claude Code built-in |
| plugin | `plugin` | Plugin provided |
| user | `userSettings` | `~/.claude/agents/*.md` or `settings.json` |
| project | `projectSettings` | `.claude/agents/*.md` or project settings |
| flag | `flagSettings` | `--agents` CLI argument |
| policy | `policySettings` | Enterprise policy managed |

---

## Agent YAML Frontmatter Fields

```markdown
---
# Required fields
name: reviewer
description: Code review expert

# Tool configuration
tools:
  - Read
  - Grep
  - Glob
  - Edit
disallowedTools:
  - Bash(rm *)
  - Bash(sudo *)

# Model and performance
model: sonnet           # Specify model, or "inherit" to use parent agent
effort: medium          # Effort level: low/medium/high or integer

# Permission mode
permissionMode: acceptEdits  # default/plan/acceptEdits/dontAsk/bypassPermissions/auto

# MCP configuration
mcpServers:             # MCP server configuration
  - github              # Reference existing server
  - slack               # Or inline: { slack: { command: "npx", args: [...] } }
requiredMcpServers:     # Required MCP servers (built-in agents only)
  - database

# Execution control
maxTurns: 50            # Maximum agentic turns before stopping
background: false       # Always run in background
isolation: worktree     # worktree (external) or worktree/remote (ant)

# Skills preloading
skills:                 # Skills to preload
  - code-review
  - security-check

# Prompt configuration
initialPrompt: Please review every detail carefully  # Prepended to first user turn

# Memory configuration
memory: project         # user/project/local - persistent memory scope

# Agent-level hooks
hooks:                  # Session-scoped hooks
  PreToolUse:
    - matcher: "Bash"
      hooks:
        - type: command
          command: "./hooks/security-check.sh"
          timeout: 5

# Display configuration
color: blue             # Agent display color

# Special options
omitClaudeMd: false     # Skip CLAUDE.md hierarchy (Explore/Plan default true)
---
```

### Required Fields

| Field | Type | Description |
|-------|------|-------------|
| `name` | string | Agent unique identifier |
| `description` | string | Agent functional description |

### Tool Configuration

| Field | Type | Description |
|-------|------|-------------|
| `tools` | string[] | Allowed tools (whitelist) |
| `disallowedTools` | string[] | Prohibited tools (blacklist) |

**Rule Syntax**:
- `ToolName` - Entire tool
- `ToolName(operation)` - Specific operation
- `ToolName(!operation)` - Exclude operation

### Model and Performance

| Field | Type | Description |
|-------|------|-------------|
| `model` | string | Specify model, or `inherit` to use parent agent |
| `effort` | string \| number | Effort level: `low`/`medium`/`high` or integer |

### Permission Mode

| Field | Type | Description |
|-------|------|-------------|
| `permissionMode` | string | See PermissionMode list below |

**PermissionMode Options**:
- `default` - Ask user each time
- `plan` - Read-only Plan Mode
- `acceptEdits` - Auto-accept all edits
- `dontAsk` - Silently allow/deny
- `bypassPermissions` - Bypass all permission checks
- `auto` - Auto mode (ant-only)

### MCP Configuration

| Field | Type | Description |
|-------|------|-------------|
| `mcpServers` | array | MCP servers (reference or inline) |
| `requiredMcpServers` | string[] | Required server patterns for agent availability |

```yaml
# Reference existing servers
mcpServers:
  - github
  - filesystem

# Inline configuration
mcpServers:
  - slack:
      command: npx
      args: ["-y", "@modelcontextprotocol/server-slack"]
```

### Execution Control

| Field | Type | Description |
|-------|------|-------------|
| `maxTurns` | number | Stop after maximum agentic turns |
| `background` | boolean | Always run in background |
| `isolation` | string | `worktree` (external) or `worktree`/`remote` (ant) |

### Skills Preloading

| Field | Type | Description |
|-------|------|-------------|
| `skills` | string[] | Skills to preload when agent starts |

### Prompt Configuration

| Field | Type | Description |
|-------|------|-------------|
| `initialPrompt` | string | Prefix prepended to first user message |

### Memory Configuration

| Field | Type | Description |
|-------|------|-------------|
| `memory` | string | Persistent memory scope: `user`/`project`/`local` |

### Agent Hooks

| Field | Type | Description |
|-------|------|-------------|
| `hooks` | object | Session-scoped hooks, registered when agent starts |

**Supported events**: `PreToolUse`, `PostToolUse`, `UserPromptSubmit`, `UserPromptEdit`, `MessageCreate`, `AgentStart`, `AgentEnd`

```yaml
hooks:
  PreToolUse:
    - matcher: "Bash"
      hooks:
        - type: command
          command: "./hooks/security-check.sh"
          timeout: 5
  AgentEnd:
    - matcher: "*"
      hooks:
        - type: agent
          prompt: "Verify task completion"
          timeout: 60
```

### Display Configuration

| Field | Type | Description |
|-------|------|-------------|
| `color` | string | Agent display color in UI |

### Special Options

| Field | Type | Description |
|-------|------|-------------|
| `omitClaudeMd` | boolean | Skip CLAUDE.md hierarchy (saves tokens) |

### Important Notes

1. **`system_prompt` is NOT a frontmatter field** - Markdown files use body content
2. **`allowed_tools` is deprecated** - Use `tools`
3. **`disallowed_tools` is deprecated** - Use `disallowedTools`
4. **`requiredMcpServers` only for built-in agents** - Not configurable via user settings

---

## Agent File Format (Legacy Reference)

```json
// settings.json
{
  "agents": {
    "reviewer": {
      "description": "Code review expert",
      "tools": ["Read", "Grep", "Glob", "Edit"],
      "disallowedTools": ["Bash(rm *)", "Bash(sudo *)"],
      "prompt": "You are a professional code review expert...",
      "model": "sonnet",
      "skills": ["security-check", "best-practices"]
    }
  }
}
```

---

## Agent Configuration Details

### 1. Tool Configuration

```json
{
  "tools": ["Read", "Grep", "Glob"],
  "disallowedTools": ["Bash(rm *)", "Bash(sudo *)", "Write"]
}
```

**Rule Syntax**:
- `ToolName` - Entire tool
- `ToolName(operation)` - Specific operation
- `ToolName(!operation)` - Exclude operation

### 2. Model Configuration

```json
{
  "model": "sonnet",
  "model": "opus",
  "model": "inherit"  // Inherit parent agent model
}
```

### 3. Effort Level

```json
{
  "effort": "low",      // Quick response
  "effort": "medium",   // Balanced
  "effort": "high"      // In-depth analysis
}
```

### 4. Permission Mode

Agents can set permission mode via `permissionMode` field in frontmatter:

```yaml
---
name: reviewer
permissionMode: acceptEdits
---
```

Or configure globally via settings.json:

```json
// settings.json
{
  "permissions": {
    "defaultMode": "default"
  }
}
```

**permissionMode vs permissions.defaultMode**:
- `permissionMode` (agent level): Set in agent frontmatter or settings.json agents.*.permissionMode, only affects that agent
- `permissions.defaultMode` (global level): Set in settings.json top level, affects the entire session's default permission mode

**Complete PermissionMode List** (`src/types/permissions.ts`):
- `default` - Ask user every time
- `plan` - Plan Mode, read-only, disallow file writing
- `acceptEdits` - Auto-accept all edits
- `dontAsk` - Silently allow/deny without prompts
- `bypassPermissions` - Bypass all permission checks
- `auto` - Auto mode (requires TRANSCRIPT_CLASSIFIER feature, ant-only)

### 5. MCP Servers

```json
{
  "mcpServers": ["github", "filesystem"],
  "mcpServers": [{ "slack": { "command": "npx", "args": ["-y", "..."] } }]
}
```

### 6. Isolation Mode

```json
{
  "isolation": "worktree"  // Run in isolated git worktree
}
```

**Note**: `remote` isolation mode is only for ant (internal users).

### 7. Memory Configuration

```json
{
  "memory": "user",      // User-level memory
  "memory": "project",   // Project-level memory
  "memory": "local"      // Local session memory
}
```

### 8. Agent Priority/Override Mechanism

Override rules when multiple sources define agents with the same name:

```
builtInAgents < pluginAgents < userAgents < projectAgents < flagAgents < managedAgents
```

**Actual Behavior**:
- Higher priority agent definitions completely override lower-priority ones with the same name
- Implemented via `getActiveAgentsFromList()` deduplication
- managedAgents (policySettings) have highest priority and can override flagAgents passed via CLI `--agents`
- Uses `Map` to keep the last occurring definition

```typescript
// Example: agent in settings.json overrides same-named definition in .md file
// .claude/agents/reviewer.md (user level)
// settings.json { "agents": { "reviewer": {...} } } (project level)
// → Final definition uses settings.json
```

---

## Agent Lifecycle

```
┌─────────────────────────────────────────────────────────┐
│                    Agent Lifecycle                       │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  1. Creation (AgentTool.call)                           │
│     ├── Parse agent definition                          │
│     ├── Validate tool permissions                       │
│     └── Initialize context                              │
│                                                         │
│  2. Execution (runAgent.ts)                            │
│     ├── Load system prompt                              │
│     ├── Register session hooks                          │
│     ├── Preload skills                                  │
│     └── Start subprocess/thread                         │
│                                                         │
│  3. Running                                             │
│     ├── Loop execution                                  │
│     ├── Tool calls                                     │
│     └── Response generation                             │
│                                                         │
│  4. Completion                                          │
│     ├── Trigger stop hook                              │
│     ├── Save memory snapshot                            │
│     └── Return result                                   │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

---

## Usage

### 1. CLI Specification

```bash
# Use specified agent
claude --agent reviewer

# Custom agents
claude --agents '{"reviewer":{"description":"Code review","prompt":"You are a review expert..."}}'
```

### 2. Invoke Sub-agent

```typescript
// Start sub-agent using AgentTool
await agent({
  name: "reviewer",
  prompt: "Review code in src/ directory"
})
```

### 3. Specify in Skill

```yaml
---
name: sql-review
agent: dba
---

Execute SQL code review...
```

---

## Configuration Examples

### 1. Code Review Agent

```json
{
  "agents": {
    "reviewer": {
      "description": "Code review expert",
      "tools": ["Read", "Grep", "Glob"],
      "disallowedTools": ["Bash(rm *)", "Bash(sudo *)"],
      "model": "sonnet",
      "skills": ["security-check", "best-practices"]
    }
  }
}
```

### 2. Explorer Agent

```json
{
  "agents": {
    "explorer": {
      "description": "Codebase exploration expert",
      "tools": ["Read", "Grep", "Glob"],
      "disallowedTools": ["Bash(*)", "Write", "Edit"],
      "model": "sonnet",
      "maxTurns": 20,
      "memory": "project"
    }
  }
}
```

### 3. Database Expert Agent

```json
{
  "agents": {
    "dba": {
      "description": "Database expert",
      "tools": ["Bash(psql:*)", "Read", "Glob"],
      "mcpServers": ["database"],
      "requiredMcpServers": ["database"],
      "prompt": "You focus on database design, SQL optimization..."
    }
  }
}
```

---

## Best Practices

### 1. Tool Limits

```json
// ✅ Principle of least privilege
{
  "tools": ["Read", "Grep"],
  "disallowedTools": ["Bash(*)", "Write", "Edit"]
}

// ✅ Precise limits
{
  "tools": ["Bash(git *)", "Bash(npm *)", "Read", "Glob"]
}
```

### 2. Use Case Description

```markdown
# ✅ Detailed use case
whenToUse: |
  Use this when you need code review.
  Applicable scenarios:
  - PR review
  - Pre-merge checks
  - Important change reviews

# ❌ Vague description
whenToUse: "Review code"
```

### 3. Resource Control

```json
// ✅ Limit execution turns
{
  "maxTurns": 50
}

// ✅ Force background execution
{
  "background": true
}
```

---

## Debugging Agents

### View Available Agents

```bash
claude agents list
```

### Test Agent

```bash
# Use specified agent
claude --agent reviewer -p "Review this code"
```

### Debug Mode

```bash
claude --debug agent
```

---

## Undocumented Agent Features

### Fork Subagent Feature (`FORK_SUBAGENT`)

When `FORK_SUBAGENT` feature is enabled, omitting `subagent_type` triggers implicit fork:
- Fork agents inherit parent's full conversation context
- Uses `permissionMode: 'bubble'`
- Default `maxTurns: 200`
- Fork children have strict output format requirements (Scope:, Result:, etc.)

### Coordinator Mode (`COORDINATOR_MODE`)

Main agent becomes coordinator orchestrating worker agents:
- Workers spawned via `Agent(subagent_type: "worker")`
- Uses `SEND_MESSAGE_TOOL_NAME` to continue workers
- Workers have tool access based on `ASYNC_AGENT_ALLOWED_TOOLS`
- Can optionally provide scratchpad directory to workers

### Agent Swarms / Teams (`ENABLE_AGENT_SWARMS`)

Multi-agent system includes:
- **TeamCreateTool**: Creates team + task list
- **spawnTeammate()**: Spawns teammates in tmux/iTerm2 panes or in-process
- **In-process teammates**: Uses AsyncLocalStorage in same Node.js process
- **Mailbox system**: File-based inter-agent communication
- **Permission bridging**: Teammates can request permissions from leader

### criticalSystemReminder_EXPERIMENTAL

Short message re-injected at every user turn:

```typescript
criticalSystemReminder_EXPERIMENTAL?: string
```

Used by `VERIFICATION_AGENT`:
```typescript
criticalSystemReminder_EXPERIMENTAL:
  'CRITICAL: This is a VERIFICATION-ONLY task...'
```

### Verification Agent Nudge (`tengu_hive_evidence`)

When completing 3+ tasks without a verification step, the system prompts to spawn the verification agent:

**Trigger Conditions**:
1. `VERIFICATION_AGENT` feature enabled
2. `tengu_hive_evidence` feature enabled
3. Main session (not sub-agent)
4. Just completed 3+ tasks
5. None of those tasks were verification steps

**Prompt Message**:
```
NOTE: You just closed out 3+ tasks and none of them was a verification step.
Before writing your final summary, spawn the verification agent (subagent_type="verification").
You cannot self-assign PARTIAL by listing caveats in your summary — only the verifier issues a verdict.
```

**Source Files**:
- `src/tools/TodoWriteTool/TodoWriteTool.ts` - V1 session nudge
- `src/tools/TaskUpdateTool/TaskUpdateTool.ts` - V2 session nudge

### Agent Memory Snapshots

Agents with `memory: 'user'` can have memory snapshots:
- Snapshots stored in `~/.claude/agent-memory/` (user)
- `.claude/agent-memory/` (project)
- `.claude/agent-memory-local/` (local)

### omitClaudeMd Flag

Excludes CLAUDE.md hierarchy from agent's context to save tokens:
- Kill-switch: `tengu_slim_subagent_claudemd`

### Auto-Background Feature

After enabling via feature flag or environment variable, agents can auto-background after 2 minutes:
```typescript
if (isEnvTruthy(process.env.CLAUDE_AUTO_BACKGROUND_TASKS) ||
    getFeatureValue_CACHED_MAY_BE_STALE('tengu_auto_background_agents', false)) {
  return 120_000;  // 2 minutes
}
```

### Async Agent Tool Restrictions

Async agents have hardcoded tool allowlist:
```typescript
export const ASYNC_AGENT_ALLOWED_TOOLS = new Set([
  FILE_READ_TOOL_NAME,
  WEB_SEARCH_TOOL_NAME,
  TODO_WRITE_TOOL_NAME,
  GREP_TOOL_NAME,
  WEB_FETCH_TOOL_NAME,
  GLOB_TOOL_NAME,
  ...SHELL_TOOL_NAMES,
  FILE_EDIT_TOOL_NAME,
  FILE_WRITE_TOOL_NAME,
  NOTEBOOK_EDIT_TOOL_NAME,
  SKILL_TOOL_NAME,
  SYNTHETIC_OUTPUT_TOOL_NAME,
  TOOL_SEARCH_TOOL_NAME,
  ENTER_WORKTREE_TOOL_NAME,
  EXIT_WORKTREE_TOOL_NAME,
])
```

Async agents cannot use `AgentTool` (would cause recursion).

### Agent Definition Undocumented Fields

```typescript
interface BaseAgentDefinition {
  criticalSystemReminder_EXPERIMENTAL?: string
  pendingSnapshotUpdate?: { snapshotTimestamp: string }
  requiredMcpServers?: string[]
  omitClaudeMd?: boolean
  background?: boolean
  initialPrompt?: string
  color?: string
}
```

### AgentTool Runtime Parameters

```typescript
{
  description: string,
  prompt: string,
  subagent_type?: string,
  model?: 'sonnet' | 'opus' | 'haiku',
  run_in_background?: boolean,
  name?: string,           // teammate name
  team_name?: string,      // team name
  mode?: PermissionMode,   // spawn permission mode
  isolation?: 'worktree' | 'remote',
  cwd?: string,            // KAIROS only
}
```

---

## Testing Verification

Run test script to verify agent configuration:
```bash
bash tests/04-agents-test.sh
```
