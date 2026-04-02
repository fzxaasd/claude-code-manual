# 9.1 Memory System Overview

> Based on complete source code analysis of `src/memdir/memoryTypes.ts`

---

## Core Concepts

Memory System is a persistent context mechanism for retaining key information between sessions.

```
Memory = Non-derivable Information × Time × Scope
```

**Constraint**: Memory only stores information that cannot be derived from the current project state.

---

## Four Memory Types

Based on `MEMORY_TYPES` constant definition (`memoryTypes.ts:14-21`):

| Type | Scope | Purpose |
|------|-------|---------|
| `user` | always private | User role, goals, preferences |
| `feedback` | private/team | Work style guidance |
| `project` | private/team | Project context, goals, events |
| `reference` | usually team | External system pointers |

---

## Type Details

### user

**Scope**: `always private`

**Description**: Information containing user role, goals, responsibilities, and knowledge.

**When to Save**:
- When learning user's role preferences
- When learning user's knowledge background
- When learning user's scope of responsibilities

**Use Cases**:
- Answering questions that require considering user background
- Adjusting explanation depth and analogy styles
- Customizing collaboration style

**Examples**:
```markdown
user: I'm a data scientist investigating what logging we have in place
assistant: [saves private user memory: user is a data scientist, currently focused on observability/logging]

user: I've been writing Go for ten years but this is my first time touching the React side of this repo
assistant: [saves private user memory: deep Go expertise, new to React and this project's frontend]
```

---

### feedback

**Scope**: `private` (default), `team` (when project-wide convention)

**Description**: Work style guidance given by users, including behaviors to avoid and behaviors to maintain.

**When to Save**:
- When user corrects approach ("no not that", "don't", "stop doing X")
- When user confirms effective approach ("yes exactly", "perfect, keep doing that")
- When user accepts unconventional choices

**Content Structure**:
```markdown
rule/fact

**Why:** [User's stated reason — typically a past event or preference]

**How to apply:** [When and where to apply this guidance]
```

**Examples**:
```markdown
user: don't mock the database in these tests — we got burned last quarter when mocked tests passed but the prod migration failed
assistant: [saves team feedback memory: integration tests must hit a real database, not mocks. Reason: prior incident where mock/prod divergence masked a broken migration]

user: stop summarizing what you just did at the end of every response, I can read the diff
assistant: [saves private feedback memory: this user wants terse responses with no trailing summaries]
```

---

### project

**Scope**: `private/team` (strongly bias toward team)

**Description**: Information about ongoing work, goals, initiatives, bugs, or events in the project.

**When to Save**:
- When learning who is doing what, why, and by when
- When status changes
- When constraints, deadlines, or stakeholder requirements emerge

**Important**: Always convert relative dates to absolute dates (`"Thursday" → "2026-03-05"`)

**Content Structure**:
```markdown
fact/decision

**Why:** [Rationale — typically constraints, deadlines, or stakeholder requirements]

**How to apply:** [How it affects recommendations]
```

**Examples**:
```markdown
user: we're freezing all non-critical merges after Thursday — mobile team is cutting a release branch
assistant: [saves team project memory: merge freeze begins 2026-03-05 for mobile release cut]

user: the reason we're ripping out the old auth middleware is that legal flagged it for storing session tokens
assistant: [saves team project memory: auth middleware rewrite driven by compliance requirements]
```

---

### reference

**Scope**: `usually team`

**Description**: Pointers to information stored in external systems.

**When to Save**:
- When learning about external resources and their purposes
- When learning that bugs are tracked in Linear projects
- When learning that feedback is in specific Slack channels

**Examples**:
```markdown
user: check the Linear project "INGEST" if you want context on these tickets
assistant: [saves team reference memory: pipeline bugs are tracked in Linear project "INGEST"]

user: the Grafana board at grafana.internal/d/api-latency is what oncall watches
assistant: [saves team reference memory: grafana.internal/d/api-latency is the oncall latency dashboard]
```

---

## Memory File Format

### Frontmatter Specification

Based on `MEMORY_FRONTMATTER_EXAMPLE` (`memoryTypes.ts:261-271`):

```markdown
---
name: {{memory name}}
description: {{one-line description — used to decide relevance in future conversations, so be specific}}
type: {{user, feedback, project, reference}}
---

{{memory content — for feedback/project types, structure as: rule/fact, then **Why:** and **How to apply:** lines}}
```

### MEMORY.md Index File

Path structure: `~/.claude/memory/projects/{sanitized-git-root}/memory/MEMORY.md`

MEMORY.md is an index file with one link per line pointing to specific memory files:

```markdown
# Memory Index

- [Title](file.md) — one-line hook
```

**Limits**: Truncated after 200 lines, truncated when file size exceeds 25,000 bytes

---

## Memory Directory Structure

```
memory/
├── MEMORY.md           # Index file
├── user/              # User memories (always private)
│   └── *.md
├── feedback/          # Feedback memories (private/team)
│   └── *.md
├── project/           # Project memories (private/team)
│   └── *.md
└── reference/         # Reference memories (usually team)
    └── *.md
```

**Note**: `{project}` in path `~/.claude/memory/projects/{project}/memory/` is a sanitized git root path. All worktrees of the same git repo share one memory directory.

---

## What NOT to Save

Based on `WHAT_NOT_TO_SAVE_SECTION` (`memoryTypes.ts:183-195`):

| Category | Reason | Authoritative Source |
|----------|--------|----------------------|
| Code patterns, architecture, conventions | Can be derived from current project state | grep / read code |
| Git history, change records | `git log` / `git blame` are authoritative sources | Git |
| Debugging solutions or fixes | Fixes are in code; commit messages have context | Code itself |
| Content already in CLAUDE.md | Already documented | CLAUDE.md |
| Temporary task details | Ongoing work, temporary state, current session context | - |

### Team Memory Security Warning ⚠️

**Must avoid saving sensitive data in shared team memories**. For example: never save API keys or user credentials.

---

## Advanced Features

### Auto Memory Index Limits

| Limit | Value |
|-------|-------|
| MEMORY.md max lines | 200 lines |
| MEMORY.md max bytes | 25,000 bytes |
| Memory file scan limit | 200 files |
| Frontmatter max lines | 30 lines |

### AI-driven Memory Relevance Selection

The `findRelevantMemories()` function uses Sonnet model for relevance selection of scanned headers, returning up to 5 relevant memories.

### Auto Memory Enable Conditions

`isAutoMemoryEnabled()` resolution chain:

1. `CLAUDE_CODE_DISABLE_AUTO_MEMORY` environment variable
2. `CLAUDE_CODE_SIMPLE` (`--bare`) → Disabled
3. CCR without `CLAUDE_CODE_REMOTE_MEMORY_DIR` → Disabled
4. `autoMemoryEnabled` in `settings.json`
5. Default: Enabled

**Note**: Even if the user explicitly asks to save the above content, ask "what's surprising or non-obvious about this?" That's what deserves to be retained.

---

## When to Access

Based on `WHEN_TO_ACCESS_SECTION` (`memoryTypes.ts:216-222`):

| Trigger | Behavior |
|---------|----------|
| Memories appear relevant | Read |
| User references previous session | Read |
| User explicitly asks to check/recall/remember | Must read |
| User says "ignore" or "not use" memory | Ignore, as if MEMORY.md is empty |

---

## Memory Expiration Handling

Based on `MEMORY_DRIFT_CAVEAT` (`memoryTypes.ts:201-202`):

> Memory records may become stale over time. Before answering questions or building hypotheses based on memory records, verify that the memory is still correct by reading the current state of files or resources.

**Principles**:
- If recalled memory conflicts with current information, trust observed current state
- Update or delete expired memories rather than acting on them

---

## Trusting Information in Memory

Based on `TRUSTING_RECALL_SECTION` (`memoryTypes.ts:240-256`):

### Verify Before Recommending

Specific functions, files, or flags mentioned in Memory are **declarations**, not facts:

| Memory Says | Needs Verification |
|-------------|-------------------|
| File path exists | Check if file exists |
| Function or flag exists | grep search |
| User will take action | Verify first |

### Repo State Snapshots

Memory summarizing repo state (like activity logs, architecture snapshots) is **frozen in time**.

If user asks about "recent" or "current" state, prefer `git log` or reading code over memory snapshots.

---

## Memory System Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Memory System                             │
├─────────────────────────────────────────────────────────────┤
│  ~/.claude/memory/projects/{project}/memory/                │
│  ├── MEMORY.md (index)                                      │
│  ├── user/              # always private                    │
│  │   └── *.md                                                │
│  ├── feedback/          # private or team                   │
│  │   └── *.md                                                │
│  ├── project/           # private or team                   │
│  │   └── *.md                                                │
│  └── reference/         # usually team                       │
│      └── *.md                                                │
├─────────────────────────────────────────────────────────────┤
│  Frontmatter                                                  │
│  ├── name: Memory name                                      │
│  ├── description: One-line description                      │
│  └── type: user/feedback/project/reference                  │
├─────────────────────────────────────────────────────────────┤
│  MemoryTypes (memoryTypes.ts)                               │
│  ├── MEMORY_TYPES = ['user', 'feedback', 'project', 'reference']
│  ├── TYPES_SECTION_COMBINED (private + team)                │
│  └── TYPES_SECTION_INDIVIDUAL (private only)                │
└─────────────────────────────────────────────────────────────┘
```

---

## Testing Verification

Run test script to verify Memory configuration:
```bash
bash tests/06-memory-test.sh
```

---

## Next Steps

- [9.2 Memory API](./02-memory-api.md) - Memory operation interfaces
- [9.3 Memory Best Practices](./03-memory-best-practices.md) - Usage guide
