# Agent Memory System

> Based on source code `src/tools/AgentTool/agentMemory.ts`, `src/tools/AgentTool/agentMemorySnapshot.ts`

## Overview

Agent Memory System is an independent persistent memory system parallel to Auto Memory, designed specifically for Agents. It allows each Agent type to maintain its own memory with three scope levels.

```
┌────────────────────────────────────────────────────────────┐
│                   Memory System Architecture                │
├────────────────────────────────────────────────────────────┤
│                                                            │
│  Auto Memory                                              │
│  ├── Path: ~/.claude/projects/{project}/memory/          │
│  ├── Scope: Project-level                                 │
│  └── Use: Shared memory for all tasks                    │
│                                                            │
│  Agent Memory                                             │
│  ├── Path: .claude/agent-memory/{agentType}/             │
│  ├── Scope: user / project / local                      │
│  └── Use: Agent-specific persistent knowledge             │
│                                                            │
└────────────────────────────────────────────────────────────┘
```

---

## Differences from Auto Memory

| Feature | Auto Memory | Agent Memory |
|---------|------------|-------------|
| Scope | Project-level | Agent-level |
| Scopes | Single | user / project / local (three) |
| Team Sharing | Via team subdirectory | Via project scope |
| Snapshot | Not supported | Supported |
| Daily Log | Supported (KAIROS) | Not supported |
| Background Extraction | Supported | Not supported |
| Memory Format | MEMORY.md + topic files | MEMORY.md + topic files |

---

## Core API

### Type Definitions

```typescript
export type AgentMemoryScope = 'user' | 'project' | 'local'
```

### Path Functions

```typescript
// Local Scope: Machine-specific, not version controlled
getLocalAgentMemoryDir(agentType): string
// Path: <cwd>/.claude/agent-memory-local/<agentType>/
// Or (Cowork): <CLAUDE_CODE_REMOTE_MEMORY_DIR>/projects/<project>/agent-memory-local/<agentType>/

// Project Scope: Version controlled, team shared
getAgentMemoryDir(agentType): string
// Path: <cwd>/.claude/agent-memory/<agentType>/

// User Scope: Cross-project, global
getAgentMemoryDir(agentType): string
// Path: <memoryBase>/agent-memory/<agentType>/

// Memory entrypoint file
getAgentMemoryEntrypoint(agentType, scope): string
// Path: <agentMemoryDir>/MEMORY.md
```

### Path Validation

```typescript
export function isAgentMemoryPath(absolutePath: string): boolean
```

Checks if a path is within Agent Memory directories, supporting all three scope paths.

### Prompt Building

```typescript
export function loadAgentMemoryPrompt(
  agentType: string,
  scope: AgentMemoryScope,
): string
```

Loads Agent's persistent memory prompt, including scope-specific guidance.

### Scope Display

```typescript
export function getMemoryScopeDisplay(
  memory: AgentMemoryScope | undefined,
): string
```

Returns a human-readable description of the scope.

---

## Three Scopes Explained

### 1. User Scope

**Path**: `~/.claude/agent-memory/<agentType>/`

**Characteristics**:
- Cross-project sharing
- Not version controlled
- Stores general knowledge

**Scope Hint**:
```
keep learnings general since they apply across all projects
```

**Use Cases**:
- Core capability descriptions for Agent
- General best practices
- Cross-project consistent guidance

### 2. Project Scope

**Path**: `<cwd>/.claude/agent-memory/<agentType>/`

**Characteristics**:
- Independent per project
- Version controlled sharing
- Team collaboration

**Scope Hint**:
```
shared with your team via version control
```

**Use Cases**:
- Project-specific Agent customization
- Team-shared Agent knowledge
- Versioned Agent configuration

### 3. Local Scope

**Path**: `<cwd>/.claude/agent-memory-local/<agentType>/`

**Characteristics**:
- Machine-specific
- Not version controlled
- Local machine specific

**Scope Hint**:
```
not checked into version control, tailor to this machine
```

**Use Cases**:
- Machine-specific path configuration
- Local development environment adaptation
- Private information storage

---

## Memory Format

Agent Memory uses the same format as Auto Memory:

```markdown
---
name: agent-capability-notes
description: Key capability notes
type: user
---

# Agent Capability Notes

## Core Capabilities
- Automated testing
- Code review
- Documentation generation

## Limitations
- Does not execute destructive operations
- Always validates input
```

---

## Snapshot Feature

Agent Memory supports snapshot synchronization for syncing Agent configurations across multiple machines.

**File**: `src/tools/AgentTool/agentMemorySnapshot.ts`

### Directory Structure

```
<cwd>/.claude/agent-memory-snapshots/<agentType>/
├── snapshot.json        # Snapshot metadata
└── .snapshot-synced.json  # Sync metadata
```

### Core Functions

| Function | Purpose |
|----------|---------|
| `getSnapshotDirForAgent()` | Get snapshot directory path |
| `checkAgentMemorySnapshot()` | Check if snapshot exists and needs sync |
| `initializeFromSnapshot()` | Initialize local memory from snapshot |
| `replaceFromSnapshot()` | Replace local memory with snapshot |
| `markSnapshotSynced()` | Mark snapshot as synced |

### Sync Conditions

- No local memory files → Initialize
- Snapshot timestamp newer than last sync time → Update

---

## Cowork Integration

### Environment Variables

| Variable | Purpose |
|----------|---------|
| `CLAUDE_CODE_REMOTE_MEMORY_DIR` | Remote memory storage root directory |
| `CLAUDE_COWORK_MEMORY_EXTRA_GUIDELINES` | Extra Agent memory guidance text |

### Cowork Settings File

```typescript
function getSettingsFilename(): string {
  if (useCoworkPlugins()) {
    return 'cowork_settings.json'  // Cowork mode
  }
  return 'settings.json'          // Normal mode
}
```

### Cowork Plugins Directory

```typescript
const COWORK_PLUGINS_DIR = 'cowork_plugins'
```

---

## Security Features

### Path Traversal Protection

- `normalize()` resolves `..` segments
- Prefix matching checks
- Symlink resolution (`realpathDeepestExisting()`)

### Dangerous Pattern Rejection

The following path patterns are rejected (from `validateMemoryPath()` in `paths.ts`, not agentMemory module itself):
- Relative paths (`../foo`)
- Root/near-root paths (length < 3)
- Windows drive roots (`C:\`)
- UNC paths (`\\server\share`)
- Null bytes (`\0`)

> **Note**: The agentMemory module uses simpler `normalize()` + prefix matching. Full path validation is provided by `validateMemoryPath()` in `paths.ts`.

### Agent Type Path Sanitization

```typescript
function sanitizeAgentTypeForPath(agentType: string): string {
  return agentType.replace(/:/g, '-')
}
```

Plugin namespaced Agent types (e.g., `my-plugin:my-agent`) are sanitized.

---

## Synergy with Auto Memory

Agent Memory and Auto Memory can be used simultaneously:

```typescript
// Auto Memory: Shared project memory
<memoryBase>/projects/<project>/memory/

// Agent Memory: Agent-specific memory
<memoryBase>/agent-memory/<agentType>/
```

Both use the same MEMORY.md format and complement each other:
- Auto Memory: Team-shared project knowledge
- Agent Memory: Agent-specific personalized configuration

---

## Usage Examples

### Create Agent Memory

```markdown
# .claude/agent-memory/my-agent/MEMORY.md

---
name: my-agent-knowledge
description: My Agent's core knowledge
type: user
---

# My Agent Configuration

## Specialty Areas
- Python backend development
- Database design
- API design

## Work Style
- First understand requirements
- Provide multiple solutions
- Value code quality
```

### Project Scope Memory

```markdown
# .claude/agent-memory/project-assistant/MEMORY.md
# (will be committed to git, team shared)

---
name: project-assistant-config
description: Project assistant configuration
type: project
---

# Agent Assistant Configuration for This Project

## Project Background
This is a microservices architecture project

## Tech Stack
- Go
- PostgreSQL
- Kubernetes
```

---

## Configuration Options

Agent Memory is currently configured via:

### 1. Environment Variables

```bash
# Set remote memory directory
export CLAUDE_CODE_REMOTE_MEMORY_DIR=/path/to/remote/memory

# Set extra memory guidance
export CLAUDE_COWORK_MEMORY_EXTRA_GUIDELINES="Always use TypeScript 5.0+"
```

### 2. settings.json

Agent Memory configuration is primarily via file path conventions; no dedicated settings.json configuration items exist yet.

---

## Testing Verification

```bash
# Check Agent Memory directory
ls ~/.claude/agent-memory/

# View specific Agent's memory
cat ~/.claude/agent-memory/<agent-type>/MEMORY.md

# Check snapshot directory
ls .claude/agent-memory-snapshots/
```
