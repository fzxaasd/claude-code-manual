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

**Explore/Plan Agent Model Configuration**:
- Explore/Plan agents read the `omitClaudeMd` field to skip CLAUDE.md context for token savings
- Model configuration: `explore: haiku (non-ANT) / inherit (ANT) | plan: inherit`

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

## Agent File Format

### YAML Frontmatter Format

```markdown
---
name: reviewer
description: Code review expert
whenToUse: Use this when you need code review
tools:
  - Read
  - Grep
  - Glob
  - Edit
disallowedTools:
  - Bash(rm *)
  - Bash(sudo *)
model: sonnet
effort: medium
mcpServers:
  - github
skills:
  - code-review
maxTurns: 50
background: false
initialPrompt: Please review every detail of the code carefully
color: blue
---

# Code Review Agent

You are a professional code review expert, responsible for reviewing code quality and best practices.

## Review Standards

### 1. Code Quality
- Readability
- Maintainability
- Performance considerations

### 2. Security Check
- Injection risks
- Sensitive information exposure
- Permission control
```

### JSON Configuration Format

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

## Testing Verification

Run test script to verify agent configuration:
```bash
bash tests/04-agents-test.sh
```
