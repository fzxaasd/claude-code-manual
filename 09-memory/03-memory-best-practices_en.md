# 9.3 Memory Best Practices

> Based on source code implementation and eval-validated guides

## Core Principles

### 1. Only Save Non-derivable Information

Claude Code continuously optimizes its ability to derive information. The following **should NOT** be saved to memories:

| Should Save | Should NOT Save |
|-------------|------------------|
| User preferences and role background | Code patterns, architecture |
| Team conventions and workflows | Git history, file structure |
| Project goals and deadlines | Debugging solutions (in code) |
| External system references | Content already in CLAUDE.md |
| User feedback and corrections | Ongoing tasks |

**Reason**: Memories become stale, while derived information stays current.

### 2. Immediately Save Explicit Requests

```typescript
// ✅ Save immediately
if (user.explicitly.asksToRemember(something)) {
  saveMemory(something)
}

// ✅ Remove immediately
if (user.explicitly.asksToForget(something)) {
  removeMemory(something)
}
```

### 3. Include Why, Not Just What

```markdown
<!-- ❌ Only describes What -->
Integration tests must use a real database.

<!-- ✅ Includes Why -->
Integration tests must use a real database.

**Why:** We had a case where mocked tests passed but production migration failed.

**How to apply:** When writing tests, prefer using real database connections.
```

---

## Four Memory Types Usage Guide

### User (User Memory)

**Scope**: `always private`

**When to Save**:
- When user introduces themselves for the first time
- When user mentions professional domain
- When user states experience level
- When user expresses preferences

**Example**:

```markdown
---
name: user_role
description: Data scientist focused on observability
type: user
---

User is a data scientist, currently focused on observability/logging systems.

**Why:** Help AI adjust explanation depth based on user background.

**How to apply:** Prioritize data science analogies when explaining technical concepts.
```

**Common Save Triggers**:
```
User: "I've been doing backend development for ten years"
→ Save: User has deep backend experience

User: "This is my first time using Docker"
→ Save: Docker beginner, needs more guidance
```

### Feedback (Feedback Memory)

**Scope**: `default to private. Save as team only when clearly a project-wide convention`

**When to Save**:
- When user corrects AI behavior ("no not that", "don't", "stop doing X")
- When user confirms effective approach ("yes exactly", "perfect", "keep doing that")
- When user accepts unusual choices

**Example**:

```markdown
---
name: feedback_testing
description: Integration tests must use real database
type: feedback
---

Integration tests must use a real database, not mocks.

**Why:** We had a case where mocked tests passed but production migration failed.

**How to apply:** When writing tests, prefer using real database connections.
```

**Save Format**:
1. The rule itself
2. **Why:** Reason
3. **How to apply:** Application scenario

**Conflict Handling**:
```typescript
// Check for team memory conflicts before saving
if (privateMemory.conflictsWith(teamMemory)) {
  // Option 1: Don't save
  // Option 2: Record as override note
}
```

### Project (Project Memory)

**Scope**: `private or team, but strongly bias toward team`

**When to Save**:
- Project milestones or goals
- Deadlines or constraints
- Decisions and their reasons
- Work in progress

**⚠️ Date Handling**:

```markdown
<!-- ❌ Relative dates (will expire) -->
User: Freeze starts Thursday

<!-- ✅ Absolute dates (stay valid) -->
**Why:** User said Thursday
**How to apply:** Convert: Thursday → 2026-04-02
```

**Example**:

```markdown
---
name: project_status
description: merge freeze 2026-04-02
type: project
---

Merge freeze starts 2026-04-02, mobile team is cutting a release branch.

**Why:** Key Q2 objective.

**How to apply:** Flag any non-critical PR work after this date.
```

### Reference (Reference Memory)

**Scope**: `usually team`

**When to Save**:
- External system information
- Documentation locations
- Communication channels

**Example**:

```markdown
---
name: reference_jira
description: Linear project INGEST for pipeline bugs
type: reference
---

Pipeline bugs are tracked in Linear project "INGEST".

**Why:** Quick location of relevant information sources.

**How to apply:** Reference this memory when pipeline bugs are mentioned.
```

---

## Save Process

### Two-Step Save Method

**Step 1**: Write memory file

```markdown
---
name: {{unique identifier}}
description: {{one-line description for relevance checking}}
type: {{type}}
---

Memory content...

**Why:** {{reason}}
**How to apply:** {{application scenario}}
```

**Step 2**: Update MEMORY.md index

```markdown
<!-- MEMORY.md -->
- [User Role](user/role.md) — Data scientist focused on observability
- [Testing Policy](feedback/testing.md) — Must use real database
- [v2.0 Release](project/v2-launch.md) — Release on April 15th
```

**Index Rules**:
- One link per line
- Maximum ~150 characters
- Include title + one-line hook

---

## Accessing Memories

### When to Access

```
✅ Access:
- Memories appear relevant
- User explicitly asks to check/recall
- Starting new task

❌ Ignore:
- User says "ignore memory about X" → Completely ignore
- Memories may be stale → Verify first
```

### Trusting Memories

**Verification Rules**:

```typescript
// Memory names file path
if (memory.namesFilePath) {
  verifyFileExists(memory)
}

// Memory names function/flag
if (memory.namesFunctionOrFlag) {
  grepForIt(memory)
}

// User will act on memory
if (memory.willActOnRecommendation) {
  verifyFirst()  // Verify first
}
```

**Staleness Handling**:
```markdown
When memory conflicts with current information:
1. Trust observed current state
2. Update or delete stale memory
3. Don't act on stale memory
```

---

## Naming Conventions

### Good Names

```markdown
user_role.md
feedback_testing_policy.md
project_v2_release.md
reference_linear_ingest.md
```

### Avoid

```markdown
memory.md        # Too generic
notes.md         # Too vague
untitled.md      # Meaningless
important.md     # Everything is important
```

---

## Team Memory

### Difference from Personal Memory

| Dimension | Personal Memory | Team Memory |
|-----------|---------------|-------------|
| Location | `~/.claude/projects/...` | `{project}/.claude/` |
| Access | Only owner | Team members |
| Scope | private | team |

### Scope Selection

```typescript
user:     "always private"
// Always private in any situation

feedback: "default to private"
// Private unless clearly team convention
// Must be a project-wide convention that every contributor should follow
// Example: Testing policy → team
// Example: Communication preference → private
// Example: Personal style preference → private

project:  "private or team, bias toward team"
// Strongly bias toward team
// Example: Deadlines → team

reference: "usually team"
// Usually team
// Example: Jira project → team
```

---

## Common Questions

### Q: User asks me to save a PR list

```markdown
<!-- ❌ This creates noise -->
User: Save this week's PR list

<!-- ✅ Ask what's worth remembering first -->
User: Save this week's PR list
AI: What from this PR list is worth saving:
- [ ] What's surprising?
- [ ] What's non-obvious?
```

### Q: Personal preference vs team convention

```typescript
// User says "stop summarizing"
feedback_testing: private
// Reason: Personal communication preference

// User says "always use real db in tests"
feedback_testing: team
// Reason: Project testing policy
```

### Q: Memory is stale

```markdown
<!-- When memory conflicts with reality -->
If memory conflicts:
1. Trust current observation
2. Update/delete memory immediately
3. Don't wait for next conversation
```

### Q: Too many memory files

```markdown
<!-- MEMORY.md limits: -->
- Maximum 200 lines
- Maximum 25,000 bytes
- Each index entry < ~150 characters

<!-- Solutions: -->
1. Merge related memories
2. Keep index entries short
3. Detailed memories in topic files
```

---

## Eval Validation Results

The following guides have been validated through eval as effective:

### ✅ H1: Verify Function/File Declarations

**Problem**: Memory claims function/file exists, but may have been renamed/deleted

**Verification Method**:
```bash
# File path
ls path/to/file

# Function/flag
grep -rn "functionName" --include="*.ts"
```

**Eval Result**: 0/2 → 3/3 (passed)

### ✅ H5: Read-side Noise Rejection

**Problem**: Memory is a snapshot of repo state and becomes stale

**Guide**:
```
If user asks about recent/current state:
→ Prefer git log or reading code
→ Don't rely on memory snapshots
```

**Eval Result**: 0/2 → 3/3 (passed)

### ✅ H6: Ignore Instructions

**Problem**: User says "ignore memory about X", Claude quotes then overrides it

**Correct Behavior**:
```
User: ignore memory about X
→ Behavior: As if MEMORY.md is empty
→ Do not apply, reference, or mention
```

**Eval Result**: Significant improvement

---

## KAIROS Daily Log Mode

### Mode Description

```typescript
// When KAIROS feature is enabled:
// - Memories appended to daily log file
// - No real-time MEMORY.md index maintained
// - Nightly /dream skill distills to topic files

// Log path
getAutoMemDailyLogPath(date)
// <autoMemPath>/logs/YYYY/MM/YYYY-MM-DD.md
```

### When to Use

- Assistant mode (long-lived sessions)
- Need to keep complete history
- No need for cross-session sharing

### Log Format

```markdown
<!-- Daily log entry format -->
[2026-04-01 09:15]
- User correction: Don't summarize at end of diff
- Discovery: Project uses pnpm, not npm
- Saved: user_dev_preference.md

[2026-04-01 14:30]
- User confirmed: Single PR优于多个小PR
- Deadline: v2 release on April 15th
```

---

## Best Practices Checklist

### Pre-save Checks

- [ ] Is this non-derivable information?
- [ ] Does it include **Why**?
- [ ] Have relative dates been converted to absolute dates?
- [ ] Is there conflicting team memory?
- [ ] Is the filename unique and meaningful?

### Access-time Checks

- [ ] Did user explicitly request?
- [ ] Does memory reference files/functions?
- [ ] If yes, needs verification first?
- [ ] Could memory be stale?

### Maintenance Checks

- [ ] Is MEMORY.md over 200 lines?
- [ ] Are there stale memories to clean?
- [ ] Are there duplicate memories to merge?
