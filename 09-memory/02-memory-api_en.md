# 9.2 Memory API

> Based on deep analysis of source code `src/memdir/memdir.ts`, `src/memdir/memoryScan.ts`, `src/memdir/paths.ts`

## Export Functions Overview

```typescript
// src/memdir/memdir.ts
export { buildMemoryPrompt, buildMemoryLines, loadMemoryPrompt }
export { truncateEntrypointContent, ensureMemoryDirExists }
export { findRelevantMemories, type RelevantMemory }
export { buildSearchingPastContextSection }
export { DIR_EXISTS_GUIDANCE, DIRS_EXIST_GUIDANCE }
export { ENTRYPOINT_NAME, MAX_ENTRYPOINT_LINES, MAX_ENTRYPOINT_BYTES }

// src/memdir/paths.ts
export { isAutoMemoryEnabled, getAutoMemPath, getAutoMemDailyLogPath }
export { getAutoMemEntrypoint, getMemoryBaseDir }
export { isAutoMemPath, hasAutoMemPathOverride, isExtractModeActive }

// src/memdir/memoryScan.ts
export { scanMemoryFiles, formatMemoryManifest, type MemoryHeader }

// src/memdir/memoryTypes.ts
export { MEMORY_TYPES, parseMemoryType, type MemoryType }
export { TYPES_SECTION_INDIVIDUAL, TYPES_SECTION_COMBINED }
export { WHAT_NOT_TO_SAVE_SECTION, WHEN_TO_ACCESS_SECTION }
export { TRUSTING_RECALL_SECTION, MEMORY_FRONTMATTER_EXAMPLE }
export { MEMORY_DRIFT_CAVEAT }

// src/memdir/memoryAge.ts
export { memoryAge, memoryAgeDays, memoryFreshnessText, memoryFreshnessNote }

// src/memdir/teamMemPrompts.ts (TEAMMEM feature)
export { buildCombinedMemoryPrompt }
```

---

## Core API

### loadMemoryPrompt()

```typescript
async function loadMemoryPrompt(): Promise<string | null>
```

**Function**: Load unified memory prompt for inclusion in system prompts.

**Return Value**:
- When enabled: Returns complete memory instruction string
- When disabled: Returns `null` and sends `tengu_memdir_disabled` event

**Internal Logic**:
```typescript
// Priority resolution
if (feature('KAIROS') && autoEnabled && getKairosActive()) {
  return buildAssistantDailyLogPrompt()  // KAIROS daily log mode
}

if (feature('TEAMMEM') && isTeamMemoryEnabled()) {
  return buildCombinedMemoryPrompt()  // Team + personal combined mode
}

if (autoEnabled) {
  return buildMemoryLines().join('\n')  // Personal only mode
}

return null  // Disabled
```

---

### buildMemoryPrompt()

```typescript
function buildMemoryPrompt(params: {
  displayName: string
  memoryDir: string
  extraGuidelines?: string[]
}): string
```

**Function**: Build complete memory prompt containing MEMORY.md content.

**Parameters**:
- `displayName`: Display name (e.g., "auto memory")
- `memoryDir`: Memory directory path
- `extraGuidelines`: Additional guidance text

**Return Value**: Complete memory instruction string containing MEMORY.md content.

**Processing Flow**:
1. Read MEMORY.md content (synchronous)
2. Call `truncateEntrypointContent()` to truncate
3. Record `tengu_memdir_loaded` event
4. Return combined prompt

---

### buildMemoryLines()

```typescript
function buildMemoryLines(
  displayName: string,
  memoryDir: string,
  extraGuidelines?: string[],
  skipIndex?: boolean
): string[]
```

**Function**: Build memory behavior instructions (without MEMORY.md content).

**Parameters**:
- `skipIndex`: Skip index writing instructions (for Agent memory)

**Return Content**:
1. Memory system introduction
2. 4 memory type definitions (`TYPES_SECTION_INDIVIDUAL`)
3. What not to save (`WHAT_NOT_TO_SAVE_SECTION`)
4. How to save memories
5. When to access memories (`WHEN_TO_ACCESS_SECTION`)
6. Trusting recall (`TRUSTING_RECALL_SECTION`)
7. Difference between memory and other persistence mechanisms
8. Searching past context (`buildSearchingPastContextSection`)

---

### truncateEntrypointContent()

```typescript
function truncateEntrypointContent(raw: string): EntrypointTruncation

interface EntrypointTruncation {
  content: string        // Truncated content
  lineCount: number      // Original line count
  byteCount: number      // Original byte count
  wasLineTruncated: boolean   // Whether truncated by line count
  wasByteTruncated: boolean   // Whether truncated by byte count
}
```

**Limits**:
- Maximum 200 lines (`MAX_ENTRYPOINT_LINES`)
- Maximum 25,000 bytes (`MAX_ENTRYPOINT_BYTES`)

**Truncation Logic**:
1. First truncate by lines
2. Then truncate by bytes (ensuring not to cut mid-line)
3. Append warning message

---

### findRelevantMemories()

```typescript
async function findRelevantMemories(
  query: string,
  memoryDir: string,
  signal: AbortSignal,
  recentTools?: readonly string[],
  alreadySurfaced?: ReadonlySet<string>
): Promise<RelevantMemory[]>

interface RelevantMemory {
  path: string    // Absolute path
  mtimeMs: number // Modification time
}
```

**Function**: Find relevant memory files based on query.

**Workflow**:
```
┌────────────────────────────────────────────────────────────┐
│              findRelevantMemories Workflow                   │
├────────────────────────────────────────────────────────────┤
│                                                            │
│  1. scanMemoryFiles(memoryDir)                             │
│     └── Scan directory, read frontmatter, return MemoryHeader[]
│                                                            │
│  2. Filter already displayed files                         │
│     └── Exclude files in alreadySurfaced                   │
│                                                            │
│  3. selectRelevantMemories()                               │
│     └── Call Sonnet model to select up to 5 relevant files │
│                                                            │
│  4. Return RelevantMemory[]                                │
│     └── { path, mtimeMs }                                  │
│                                                            │
└────────────────────────────────────────────────────────────┘
```

**Selection Prompt** (SELECT_MEMORIES_SYSTEM_PROMPT):
```
You are selecting memories that will be useful to Claude Code as it processes a user's query.
Return a list of filenames for the memories that will clearly be useful (up to 5).
- If you are unsure if a memory will be useful, do not include it.
- If there are no useful memories, return an empty list.
- Do not select memories that are usage reference or API documentation for recently used tools.
```

---

### scanMemoryFiles()

```typescript
async function scanMemoryFiles(
  memoryDir: string,
  signal: AbortSignal
): Promise<MemoryHeader[]>

interface MemoryHeader {
  filename: string           // Filename
  filePath: string           // Absolute path
  mtimeMs: number           // Modification time
  description: string | null  // frontmatter.description
  type: MemoryType | undefined  // frontmatter.type
}
```

**Limits**:
- Maximum 200 .md files scanned (`MAX_MEMORY_FILES`)
- Frontmatter reads maximum first 30 lines (`FRONTMATTER_MAX_LINES`)

**Sorting**: Descending by mtimeMs (newest first)

---

### formatMemoryManifest()

```typescript
function formatMemoryManifest(memories: MemoryHeader[]): string
```

**Output Format**:
```markdown
- [user] user_role.md (2026-04-01T10:30:00.000Z): User role and expertise
- [feedback] testing_policy.md (2026-03-28T14:20:00.000Z)
- [project] v2_release.md (2026-03-25T09:00:00.000Z): Release on April 15th
```

---

## Path API

### isAutoMemoryEnabled()

```typescript
function isAutoMemoryEnabled(): boolean
```

**Enable Priority** (first match wins):
1. `CLAUDE_CODE_DISABLE_AUTO_MEMORY=1/true` → Disabled
2. `CLAUDE_CODE_SIMPLE` (`--bare`) → Disabled
3. CCR without persistent storage → Disabled
4. `settings.autoMemoryEnabled` → Explicit setting
5. Default → Enabled

### getAutoMemPath()

```typescript
const getAutoMemPath = memoize((): string => { ... }, () => getProjectRoot())
```

**Path Resolution**:
1. `CLAUDE_COWORK_MEMORY_PATH_OVERRIDE` environment variable
2. `settings.autoMemoryDirectory`
3. `{memoryBase}/projects/{sanitized-git-root}/memory/`

**Note**: Internally cached, invalidated by `getProjectRoot()`

### getAutoMemDailyLogPath()

```typescript
function getAutoMemDailyLogPath(date: Date = new Date()): string
```

**KAIROS Mode Only**: Returns daily log file path

```typescript
// Output: <autoMemPath>/logs/YYYY/MM/YYYY-MM-DD.md
// Example: ~/.claude/projects/my-project/memory/logs/2026/04/2026-04-01.md
```

### isAutoMemPath()

```typescript
function isAutoMemPath(absolutePath: string): boolean
```

**Function**: Check if path is within memory directory

**Security**: Internally normalizes to prevent path traversal attacks

### getAutoMemEntrypoint()

```typescript
function getAutoMemEntrypoint(): string
```

**Function**: Return full path to MEMORY.md index file

**Path**: `<autoMemPath>/MEMORY.md`

**Note**: Follows same resolution order as `getAutoMemPath()`

### getMemoryBaseDir()

```typescript
function getMemoryBaseDir(): string
```

**Function**: Return base directory for persistent memory storage

**Resolution Order**:
1. `CLAUDE_CODE_REMOTE_MEMORY_DIR` environment variable (CCR settings)
2. `~/.claude` (default config directory)

### hasAutoMemPathOverride()

```typescript
function hasAutoMemPathOverride(): boolean
```

**Function**: Check if Cowork memory path override is set

**Usage**: SDK callers can explicitly enable auto memory mechanism by setting `CLAUDE_COWORK_MEMORY_PATH_OVERRIDE` environment variable, to decide whether to inject memory prompts

### buildSearchingPastContextSection()

```typescript
function buildSearchingPastContextSection(autoMemDir: string): string[]
```

**Function**: Build "searching past context" prompt section

**Feature Flag**: `tengu_coral_fern`

**Return Content**:
- Search topic files in memory directory
- Search session transcript logs (`.jsonl` files)

**Note**: Only returns content when `tengu_coral_fern` feature is enabled, otherwise returns empty array

---

## Type Definitions

### MemoryType

```typescript
const MEMORY_TYPES = ['user', 'feedback', 'project', 'reference'] as const
type MemoryType = 'user' | 'feedback' | 'project' | 'reference'

function parseMemoryType(raw: unknown): MemoryType | undefined
```

**Parsing Rules**:
- String and in MEMORY_TYPES → Return that type
- Otherwise → Return undefined

---

## Memory Freshness System (memoryAge.ts)

### memoryAge()

```typescript
function memoryAge(mtimeMs: number): string
```

**Function**: Return human-readable memory age string

**Return Value**: `'today'` | `'yesterday'` | `'N days ago'`

### memoryAgeDays()

```typescript
function memoryAgeDays(mtimeMs: number): number
```

**Function**: Return days since file modification (floor)

**Note**: Future times or clock skews are clamped to 0

### memoryFreshnessText()

```typescript
function memoryFreshnessText(mtimeMs: number): string
```

**Function**: Return staleness warning text for memories older than 1 day

**Return Value**:
- Within 1 day: Returns empty string
- Older than 1 day: Returns warning text

### memoryFreshnessNote()

```typescript
function memoryFreshnessNote(mtimeMs: number): string
```

**Function**: Return staleness note wrapped in `<system-reminder>` tag

---

## Team Memory (TEAMMEM feature)

### buildCombinedMemoryPrompt()

```typescript
function buildCombinedMemoryPrompt(
  extraGuidelines?: string[],
  skipIndex = false,
): string
```

**Function**: Build combined prompt when both personal and team memories are enabled

**Team Memory Structure**:
- Personal memory: `~/.claude/memory/projects/{project}/memory/`
- Team memory: `~/.claude/memory/projects/{project}/memory/team/`

**Return Content**:
- Dual-directory memory system introduction
- Memory scope explanation (private/team)
- 4 memory type definitions (`TYPES_SECTION_COMBINED`)
- What not to save
- How to save memories
- When to access memories
- Trusting recall
- Extra guidelines (`extraGuidelines`)
- Searching past context (`buildSearchingPastContextSection`)

### Cowork Extra Guidelines

Cowork injects extra memory policy guidance via environment variables:

```typescript
const coworkExtraGuidelines = process.env.CLAUDE_COWORK_MEMORY_EXTRA_GUIDELINES
```

These guidelines are added to memory prompts via the `extraGuidelines` parameter passed to `buildMemoryLines()` and `buildCombinedMemoryPrompt()`.

---

## Prompt Fragments

### TYPES_SECTION_INDIVIDUAL

Memory type description for single-user mode, containing:
- user: User memories
- feedback: Feedback memories
- project: Project memories
- reference: Reference memories

### TYPES_SECTION_COMBINED

Memory type description for team mode, containing `<scope>` tags:
- `<scope>always private</scope>`
- `<scope>default to private</scope>`
- `<scope>private or team, but strongly bias toward team</scope>`
- `<scope>usually team</scope>`

### WHAT_NOT_TO_SAVE_SECTION

What not to save:
- Code patterns (can be derived from code)
- Git history (can be derived from git)
- Debugging solutions (in code)
- Content already in CLAUDE.md
- Ongoing task details

### WHEN_TO_ACCESS_SECTION

When to access memories:
- Memories appear relevant
- User explicitly asks to check/recall
- User says "ignore" → Ignore memories
- Memories may be stale → Verify before use

### TRUSTING_RECALL_SECTION

Verification before using memories:
- Memory names file path → Check if file exists
- Memory names function/flag → grep search
- User will act based on memory → Verify first

---

## Event Tracking

### telemetry Events

| Event | Timing | Fields |
|------|--------|--------|
| `tengu_memdir_loaded` | Memory directory loaded | content_length, line_count, was_truncated, memory_type |
| `tengu_memdir_disabled` | Memory disabled | disabled_by_env_var, disabled_by_setting |
| `tengu_team_memdir_disabled` | Team memory disabled | - |

### Feature Flags

| Flag | Function |
|------|----------|
| `TEAMMEM` | Team memory feature |
| `KAIROS` | Daily log mode |
| `EXTRACT_MEMORIES` | Extract memories background agent |
| `tengu_coral_fern` | Search past context (`buildSearchingPastContextSection`) |
| `tengu_moth_copse` | Skip MEMORY.md index writing instructions |
| `tengu_passport_quail` | Extract memories background agent activation |
| `tengu_slate_thimble` | Force activation of extract for non-interactive sessions |
| `tengu_herring_clock` | Team memory disable telemetry |

---

## Usage Examples

### Build Memory Prompt

```typescript
import { buildMemoryPrompt, getAutoMemPath } from './memdir/memdir.ts'

const memoryDir = getAutoMemPath()
const prompt = buildMemoryPrompt({
  displayName: 'auto memory',
  memoryDir,
  extraGuidelines: ['Prefer using TypeScript']
})

// prompt contains:
// - Memory system introduction
// - 4 type definitions
// - Save/access guidelines
// - MEMORY.md content (truncated)
```

### Find Relevant Memories

```typescript
import { findRelevantMemories } from './memdir/memdir.ts'

const memories = await findRelevantMemories(
  'How does the user handle database testing?',
  memoryDir,
  abortSignal,
  ['Bash', 'Edit'],  // Recently used tools
  new Set(['already-loaded-memory.md'])  // Already displayed
)

// Return top 5 relevant memories
for (const m of memories) {
  console.log(`${m.path} (mtime: ${m.mtimeMs})`)
}
```

### Scan Memory Directory

```typescript
import { scanMemoryFiles, formatMemoryManifest } from './memdir/memoryScan.ts'

const headers = await scanMemoryFiles(memoryDir, abortSignal)
const manifest = formatMemoryManifest(headers)
console.log(manifest)
```

### Check Path

```typescript
import { isAutoMemPath, isAutoMemoryEnabled } from './memdir/paths.ts'

if (isAutoMemoryEnabled()) {
  const file = '/home/user/.claude/projects/my-repo/memory/user/test.md'
  console.log(isAutoMemPath(file)) // true
}
```

---

## Relationship with Other Modules

```
┌────────────────────────────────────────────────────────────┐
│                    Memory API Dependencies                  │
├────────────────────────────────────────────────────────────┤
│                                                            │
│  memdir.ts                                                 │
│      ├── memoryTypes.ts  (Type definitions)               │
│      ├── memoryScan.ts   (Scanning)                        │
│      ├── paths.ts        (Paths)                           │
│      └── Dependencies:                                       │
│            ├── utils/frontmatterParser.ts                  │
│            ├── utils/fsOperations.js                       │
│            ├── utils/sideQuery.js                          │
│            └── bootstrap/state.js                         │
│                                                            │
│  teamMemPaths.ts (TEAMMEM feature)                        │
│  teamMemPrompts.ts (TEAMMEM feature)                     │
│                                                            │
└────────────────────────────────────────────────────────────┘
```
