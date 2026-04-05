# Skill Creation Specification

> In-depth analysis of Claude Code skill creation best practices from source code

## SKILL.md Standard Template

The `/skillify` skill in Claude Code source provides a standard template:

```yaml
---
name: {{skill-name}}
description: {{One-line description}}
allowed-tools:
  {{tool permission patterns}}
when_to_use: |
  Describe in detail when this skill should be automatically invoked, including trigger phrases and example messages.
  Use when the user wants to cherry-pick a PR to a release branch.
  Examples: 'cherry-pick to release', 'CP this PR', 'hotfix.'
argument-hint: "{{Parameter placeholder hint}}"
arguments:
  - name
  - description
context: {{inline or fork}}
model: "{{Optional: specify model}}"
effort: "{{Optional: low/medium/high}}"
---

# Skill Title

Detailed skill description...

## Inputs
- `$arg_name`: Input description

## Objective
Clearly state the objective of this workflow.

## Steps

### 1. Step Name
The specific action to perform.

**Success Criteria**: Define when the step is considered complete.

**Execution**: `Direct` (default), `Task agent`, `Teammate`, `[human]`
**Outputs**: Data/IDs produced by this step for subsequent steps
**Human Checkpoint**: When to pause and ask user
```

---

## Frontmatter Field Details

### 1. Core Metadata

```yaml
---
name: skill-name                    # Skill identifier (optional, defaults to directory name)
description: Short description      # Required, shown in /skills list
when_to_use: |                     # Critical! Tells model when to auto-invoke
  Use when the user wants to...
  Example messages: '...', '...'
---
```

### 2. Parameter Definitions

```yaml
---
argument-hint: "\"param1\" \"param2\""  # Parameter example format
arguments:                            # Parameter list (space-separated string or string array)
  - param1
  - param2
---
```

### 3. Tool Permissions

```yaml
---
allowed-tools: |                    # Principle of least privilege
  Bash(gh:*)
  Read
  Edit
  Write
  Grep
---
```

### 4. Execution Mode

```yaml
---
context: fork                       # Sub-agent execution (independent context)
# Or omit context: inline         # Inline execution (current session)
model: "sonnet"                    # Optional: specify model
effort: "high"                    # Optional: effort level
---
```

### 5. Conditional Activation

```yaml
---
paths:                              # Activate after path pattern match
  - "*.sql"
  - "migrations/*.sql"
  - "**/database/**/*.sql"
---
```

**Path matching rules**:
- The `/**` suffix in patterns is automatically removed (`src/**` → `src/`)
- If all patterns are `**` (match all), the skill is treated as unconditional
- Conditional skills are initially stored in `conditionalSkills`, only activated when matching files are accessed
- Once activated, they move to `dynamicSkills` and cannot be deactivated

**Path pattern examples**:
| Pattern | Matches |
|---------|---------|
| `*.sql` | SQL files in root directory |
| `src/**/*.ts` | TypeScript files in src and subdirectories |
| `tests/` | All files in tests directory |

### 6. Model Control

```yaml
---
model: "sonnet"                    # Specify model (optional)
effort: "high"                    # Effort level (optional)
disable-model-invocation: true     # Disable model auto-invocation (optional)
---
```

**disable-model-invocation**: When set to `true`, disables the model's auto-invocation feature. This field is for advanced scenarios and must be explicitly declared in the frontmatter.

---

## Execution Mode Comparison

| Mode | Description | Use Case |
|------|-------------|----------|
| `inline` (default) | Execute in current session | Requires user involvement in decisions |
| `fork` | Sub-agent execution | Self-contained tasks, no mid-process interaction |

### Fork Mode Characteristics

```yaml
context: fork
```

- Runs in an independent sub-agent
- Has its own token budget
- Tool outputs not in main context
- Suitable for long-running background tasks

---

## Skill Content Structure

### 1. Basic Information

```markdown
# Skill Name

## Overview
Brief description of skill functionality.

## Use Cases
When this skill should be used.
```

### 2. Input Parameters

```markdown
## Inputs
- `$target`: Target file or directory
- `$options`: Optional parameters
```

### 3. Steps

```markdown
## Steps

### 1. Initialization
Check environment and dependencies.

**Success Criteria**:
- Environment is ready
- Dependencies are installed

### 2. Execute Core Logic
Perform the main task.

**Execution**: `Task agent` (optional: parallel execution)
**Outputs**: Key data for subsequent use
```

### 4. Error Handling

```markdown
## Error Handling

If failed:
1. Log error
2. Clean up temporary files
3. Return error message
```

---

## Complete Example

```yaml
---
name: sql-migration
description: Database migration execution and verification
when_to_use: |
  Use when you need to create or execute database migrations.
  Examples: 'run migration', 'create users table migration', 'migrate users'
argument-hint: "\"up\" or \"down\" [migration_name]"
arguments:
  - direction
  - name
allowed-tools:
  Bash(psql:*)
  Bash(psql -h *)
  Read
  Grep
context: inline
---
# SQL Migration Assistant

Execute database migrations and verify results.

## Inputs
- `$direction`: `up` or `down`
- `$name`: Optional migration name

## Steps

### 1. Prepare Migration
Check migration file status.

**Success Criteria**:
- Migration file exists
- Database connection is healthy

### 2. Execute Migration
```bash
alembic upgrade head
```

**Success Criteria**:
- No error output
- Version number updated

### 3. Verify Results
Confirm migration was successfully applied.

**Success Criteria**:
- Table structure is correct
- Data is intact
```

---

## Best Practices

### 1. when_to_use is Critical

```yaml
# ❌ Vague description
when_to_use: "Process data"

# ✅ Specific description
when_to_use: |
  Use when the user needs to create new database tables.
  Examples: 'create users table', 'add table', 'new table users'
```

### 2. Principle of Least Privilege

```yaml
# ❌ Too permissive
allowed-tools: "Bash|Read|Write|Edit"

# ✅ Precisely specify
allowed-tools:
  Bash(npm:*)
  Bash(node:*)
  Read
```

### 3. Clear Success Criteria

Each step must have `**Success Criteria:**` to tell the model when to proceed.

### 4. Fork vs Inline Selection

```yaml
# ✅ Fork: Self-contained tasks
context: fork
# Example: code formatting, dependency checks, static analysis

# ✅ Inline: Requires interaction
# (omit context or explicitly inline)
# Example: refactoring requires review, debugging needs feedback
```

### 5. Output Chain

If steps have data dependencies, use `**Outputs:**` annotation:

```markdown
### 1. Generate Code
Generate code files.

**Outputs**: `{file_path}` - Generated file path

### 2. Verify Code
Verify generated files.

**Success Criteria**: File exists and is executable
```

---

## Undocumented Features

### Variable Substitution

| Variable | Description | Scope |
|----------|-------------|-------|
| `${CLAUDE_SKILL_DIR}` | Skill's own directory path | File and plugin skills |
| `${CLAUDE_SESSION_ID}` | Current session identifier | All skill types |
| `${CLAUDE_PLUGIN_ROOT}` | Plugin root directory | Plugin skills |
| `${CLAUDE_PLUGIN_DATA}` | Plugin data directory | Plugin skills |

### Undocumented Frontmatter Fields

| Field | Description |
|-------|-------------|
| `hide-from-slash-command-tool` | Controls visibility in SlashCommand tool |
| `immediate` | When true, bypasses queue and executes immediately |
| `skills` | List of skills to preload for agents |

> **Note**: The following fields do NOT exist in the source code and should not be used: `isSensitive`, `kind`, `availability`, `disableNonInteractive`.

### Shell Command Blocks

```markdown
!`shell command`                    // Inline execution

```!
echo "shell command"
```
```

Shell blocks execute during skill loading to prepare context. Note: The `!` block syntax is `` ```! `` followed directly by a newline (no language name) — any language name would be executed as part of the command.

### Skill Permission Auto-Grant

Skills using only "safe" properties are auto-granted permission:

```typescript
const SAFE_SKILL_PROPERTIES = new Set([
  'type', 'progressMessage', 'contentLength', 'argNames', 'model',
  'effort', 'source', 'pluginInfo', 'disableNonInteractive', 'skillRoot',
  'context', 'agent', 'getPromptForCommand', 'frontmatterKeys',
  'name', 'description', 'hasUserSpecifiedDescription', 'isEnabled',
  'isHidden', 'aliases', 'isMcp', 'argumentHint', 'whenToUse', 'paths',
  'version', 'disableModelInvocation', 'userInvocable', 'loadedFrom',
  'immediate', 'userFacingName'
])
```

### Remote Skills (Experimental)

Feature flag: `EXPERIMENTAL_SKILL_SEARCH` + `USER_TYPE === 'ant'`

Remote skills with `_canonical_` prefix are loaded from AKI/GCS.

### Bundled Skill File Extraction

Bundled skills can specify files to extract to disk on first invocation:

```typescript
files?: Record<string, string>  // { "path": "content" }
```

### model: inherit

Syntax to explicitly use parent model:

```yaml
model: inherit  # Use the model of the invoking skill
```

### effort Values

effort can be a string or positive integer:

```yaml
effort: low      # String
effort: 42        # Integer
```

---

## Skill Format Reference

| Field | Description | Required |
|-------|-------------|----------|
| `name` | Skill identifier | Yes |
| `description` | One-line description | Yes |
| `when_to_use` | When to auto-invoke | Recommended |
| `allowed-tools` | Tool permission whitelist | Optional |
| `arguments` | Parameter definitions | Optional |
| `argument-hint` | Parameter example format | Optional |
| `context` | `inline` or `fork` | Optional |
| `model` | Specify model, `inherit` for parent model | Optional |
| `effort` | `low`/`medium`/`high` or positive integer | Optional |
| `agent` | Agent type for fork mode | Optional |
| `shell` | Shell type for execution | Optional |
| `hide-from-slash-command-tool` | Hide from /skills list | Optional |
| `disable-model-invocation` | Disable model invocation | Optional |
| `paths` | Path pattern activation | Optional |
| `files` | Related files | Optional |
| `immediate` | Bypass queue and execute immediately | Optional |
| `skills` | List of skills to preload | Optional |

### Complete Example

Use the following format when creating skills:

```yaml
---
name: my-skill
description: Skill description
when_to_use: |
  Use when processing SQL files
paths:
  - "*.sql"
  - "migrations/*.sql"
allowed-tools: "Read|Edit|Bash(psql *)"
context: inline
---
```
