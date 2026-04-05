# Claude Code Native Skills Mechanism

> In-depth analysis based on source code `src/skills/loadSkillsDir.ts`, `src/utils/frontmatterParser.ts`

## Core Concepts

### Skill Sources

```
policySettings > userSettings > projectSettings > bundled > plugin
```

| Source | Path | Description |
|--------|------|-------------|
| Managed | `~/.claude/plugins/marketplaces/.../.claude/skills/` | Enterprise management |
| User | `~/.claude/skills/` | User global |
| Project | `.claude/skills/` | Project level |
| Bundled | Built-in skills | CLI bundled |
| Plugin | `~/.claude/plugins/*/skills/` | Provided by plugins |
| MCP | `mcpServers` config | MCP tools exported as skills |
| Commands (legacy) | `commands/` directory | Legacy command skills |

> Note: Skill names come from the directory name, not the frontmatter `name` field.

---

## SKILL.md Frontmatter Complete Specification

Based on `src/utils/frontmatterParser.ts` complete field definitions:

```yaml
---
# Note: Skill name comes from directory name, not frontmatter field
# === Core Fields ===
description: Short description           # Recommended, skill purpose
when_to_use: Usage scenario description  # Recommended, model reference

# === Tool Configuration ===
allowed-tools:                  # Optional, allowed tools
  - Read
  - Write
  - Edit
  - Bash(git *)

# === Parameter Definitions ===
arguments:                      # Optional, parameter list
  - name
  - description
argument-hint: "Parameter hint" # Optional, parameter examples

# === Agent Configuration ===
agent: agent-name              # Optional, agent name to use
skills: skill-name              # Optional, agent preloaded skill list
model: sonnet                   # Optional, specify model
effort: medium                  # Optional, low/medium/high/max or positive integer
context: inline                 # Optional, inline (default) or fork (sub-agent execution)

# === Conditional Activation ===
paths:                         # Optional, path patterns
  - "*.sql"
  - "migrations/*.sql"
  - "{frontend,backend}/**/*.ts"

# === Behavior Control ===
user-invocable: true          # Default true, false=hidden
disable-model-invocation: false # Default false
hide-from-slash-command-tool: false  # Default false
version: "1.0.0"             # Optional, version number

# === Shell Configuration ===
shell: bash                   # Optional, bash or powershell

# === Hooks ===
hooks:                        # Optional, built-in Hooks
  PreToolUse:
    - matcher: "Bash"
      hooks:
        - type: command
          command: "python3 validate.py"
          timeout: 5

# === Skill Content ===
---

# Skill Content (Markdown)

Specific description and usage instructions...

Supports `!` blocks for command execution (note: `!` is followed directly by a newline, not a language name — any language name would be executed as part of the command):
```!
echo "Execute shell command"
```
```

---

## Frontmatter Field Details

### Core Fields

| Field | Type | Description |
|-------|------|-------------|
| `name` | string | Display name (defaults to directory name) |
| `description` | string | Skill description, shown in skills list |
| `when_to_use` | string | Usage suggestions (model reference) |
| `user-invocable` | boolean | Whether callable via `/` command |
| `hide-from-slash-command-tool` | boolean | Whether hidden from SlashCommand tool |

### Tool Configuration

| Field | Type | Description |
|-------|------|-------------|
| `allowed-tools` | string/string[] | List of allowed tools |

**Examples**:
```yaml
allowed-tools: "Read|Edit|Write"
allowed-tools:
  - Read
  - Write
  - Bash(git *)
```

### Model and Execution

| Field | Type | Description |
|-------|------|-------------|
| `model` | string | Specify model |
| `effort` | 'low' \| 'medium' \| 'high' \| 'max' \| number | Effort level |
| `context` | 'inline' \| 'fork' | Execution mode; `fork`=sub-agent execution |
| `agent` | string | Agent name to use |
| `skills` | string | Agent preloaded skill list |
| `shell` | 'bash' \| 'powershell' | Default shell |

### Conditional Activation

| Field | Type | Description |
|-------|------|-------------|
| `paths` | string/string[] | Activates only when path pattern matches |
| `arguments` | string/string[] | Accepted parameter list |
| `argument-hint` | string | Parameter usage hint/examples |

**Paths Syntax**:
```yaml
paths: "*.sql"                    # Single
paths: "*.sql, migrations/*.sql"  # Comma separated
paths:                             # Array
  - "*.sql"
  - "migrations/*.sql"
  - "{frontend,backend}/**/*.ts"  # Supports brace expansion
```

### Shell Configuration

| Field | Type | Description |
|-------|------|-------------|
| `shell` | string | `bash` or `powershell` |

### Version and Metadata

| Field | Type | Description |
|-------|------|-------------|
| `version` | string | Skill version |

---

## Skill Loading Process

```
┌──────────────────────────────────────────────────────────────┐
│                    Skill Loading Process                      │
├──────────────────────────────────────────────────────────────┤
│                                                              │
│  1. Scan and Load Sources                                    │
│     ├── userSettings: ~/.claude/skills/                      │
│     ├── projectSettings: .claude/skills/                     │
│     ├── policySettings: managed directories                │
│     ├── bundled: Built-in skills                            │
│     └── plugin: Plugin skills/ directories                   │
│                                                              │
│  2. Parse Frontmatter                                        │
│     └── parseSkillFrontmatterFields()                       │
│                                                              │
│  3. Deduplication Check                                       │
│     └── getFileIdentity() - Resolve symlinks                │
│                                                              │
│  4. Classification                                           │
│     ├── No paths → Unconditional skills list                │
│     └── With paths → Conditional skills pool                │
│                                                              │
│  5. Conditional Activation                                   │
│     └── Match paths patterns when files are accessed        │
│                                                              │
└──────────────────────────────────────────────────────────────┘
```

---

## Built-in Bundled Skills

Based on `src/skills/bundled/index.ts`:

### Registration Mechanism

Built-in skills are registered via `registerBundledSkill()`, supporting these fields:

| Field | Type | Description |
|-------|------|-------------|
| `name` | string | Skill name (command name) |
| `aliases` | string[] | Command aliases |
| `description` | string | Skill description |
| `whenToUse` | string | Usage scenario description |
| `allowedTools` | string[] | List of allowed tools |
| `userInvocable` | boolean | Whether callable via `/` command |
| `isEnabled` | () => boolean | Enable condition function |
| `disableModelInvocation` | boolean | Whether to disable model invocation |
| `context` | 'inline' \| 'fork' | Execution mode |
| `agent` | string | Agent name to use |
| `files` | Record\<string, string\> | Related files (path → content mapping) |
| `hooks` | HooksSettings | Built-in Hooks |

### Skills List

| Skill | Command | Function | Feature Flag / Trigger | Notes |
|-------|---------|----------|------------------------|-------|
| update-config | `/update-config` | Update config | Enabled by default | |
| keybindings-help | `/keybindings-help` | Keybindings | `isKeybindingCustomizationEnabled()` | ⚠️ userInvocable: false - Model only |
| verify | `/verify` | Verify | `USER_TYPE === 'ant'` | ANT-only |
| debug | `/debug` | Debug | Enabled by default | ⚠️ disableModelInvocation: true - User only |
| lorem-ipsum | `/lorem-ipsum` | Generate placeholder text | `USER_TYPE === 'ant'` | ANT-only |
| skillify | `/skillify` | Convert to skill | `USER_TYPE === 'ant'` | ANT-only, ⚠️ disableModelInvocation: true |
| remember | `/remember` | Memory | `USER_TYPE === 'ant'` + `isAutoMemoryEnabled()` | ANT-only |
| simplify | `/simplify` | Simplify text | Enabled by default | |
| batch | `/batch` | Batch processing | Enabled by default | ⚠️ disableModelInvocation: true - User only |
| stuck | `/stuck` | Stuck help | `USER_TYPE === 'ant'` | ANT-only |
| loop | `/loop` | Loop task | `AGENT_TRIGGERS` | ⚠️ Also requires `isKairosCronEnabled()` at runtime |
| schedule | `/schedule` | Remote scheduling | `AGENT_TRIGGERS_REMOTE` registered + runtime `tengu_surreal_dali` + `allow_remote_sessions` | Requires claude.ai OAuth |
| claude-api | `/claude-api` | Claude API | `BUILDING_CLAUDE_APPS` | |
| dream | `/dream` | Dream Mode | `KAIROS` or `KAIROS_DREAM` | |
| hunter | `/hunter` | Code Hunter | `REVIEW_ARTIFACT` | |
| claude-in-chrome | `/claude-in-chrome` | Chrome extension | `auto (shouldAutoEnableClaudeInChrome)` | |
| run-skill-generator | `/run-skill-generator` | Skill generator | `RUN_SKILL_GENERATOR` | |

> **Note**: Source files for `dream`, `hunter`, and `runSkillGenerator` do not exist in the open-source repository. They are loaded via dynamic `require('./xxx.js')` and injected at build time, only available when their respective feature flags are enabled.

---

## Directory Structure Specification

### Standard Format

```
skills/
├── skill-name/
│   └── SKILL.md        # Required
├── another-skill/
│   ├── SKILL.md        # Required
│   ├── schemas/        # Optional
│   ├── templates/      # Optional
│   └── examples/       # Optional
└── ...
```

**Important**: The `skills/` directory only supports directory format, not single files.

---

## Execution Modes

### Inline (Default)

Skill content is expanded directly into the current conversation:

```yaml
context: inline  # Default
---
# Skill Content
```

### Fork (Sub-Agent)

Skill executes in an independent context:

```yaml
context: fork
agent: general-purpose
---
# Skill Content
```

---

## Variable Substitution

### Available Variables

| Variable | Description |
|----------|-------------|
| `$ARGUMENTS` | Full arguments string passed |
| `$ARGUMENTS[0]`, `$ARGUMENTS[1]`, ... | Reference arguments by index |
| `$0`, `$1`, `$2`, ... | Reference arguments by position (shorthand) |
| `$arg_name` | Reference arguments by name (requires `arguments` definition) |

### Shell Blocks

```markdown
Skill content...

```!
echo "Execute shell"
```
```

---

## Conditional Activation

### Path Patterns

```yaml
# SQL optimization skill
paths:
  - "*.sql"
  - "migrations/*.sql"
  - "**/database/**/*.sql"
```

**Pattern Syntax**:
- `*.sql` - Single file
- `dir/*` - All in directory
- `dir/**` - Recursive all
- `{a,b}` - Brace expansion
- Comma-separated multiple patterns

### Conditional Trigger Logic

```typescript
// From loadSkillsDir.ts
function parseSkillPaths(frontmatter: FrontmatterData): string[] | undefined {
  const patterns = splitPathInFrontmatter(frontmatter.paths)
  // Remove /** suffix
  // If all are **, return undefined
}
```

---

## Hooks Integration

Skills can include built-in Hooks:

```yaml
hooks:
  PreToolUse:
    - matcher: "Bash"
      hooks:
        - type: command
          command: "python3 validate.py"
          timeout: 5
          if: "Bash(git *)"
  PostToolUse:
    - hooks:
        - type: command
          command: "log.py"
```

---

## FAQ

### Q: Why isn't my skill showing up?

Checklist:
- [ ] Is SKILL.md in `skills/{name}/` directory?
- [ ] Does frontmatter have a description?
- [ ] Is it hidden by `user-invocable: false`?
- [ ] Is it hidden by `hide-from-slash-command-tool: true`?

### Q: Why isn't the conditional skill activating?

Checklist:
- [ ] Is the `paths` pattern correct?
- [ ] Is the matching file being accessed?
- [ ] Is the pattern using comma separation or YAML list?

### Q: Insufficient tool permissions?

```yaml
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash(git *)
  - Bash(npm *)
```

---

## Testing and Verification

Run test script to verify Skills configuration:
```bash
bash tests/01-skills-test.sh
```
