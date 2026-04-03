# Hook System Details

> In-depth analysis based on source code `src/entrypoints/sdk/coreSchemas.ts`

## Overview

The Claude Code Hook system provides 27 lifecycle hooks, allowing custom logic to be executed at key event points.

---

## Complete Hook Types (27 Types)

### 1. Tool Execution (4 Types)

#### PreToolUse ⭐ Most Common
**Trigger**: Before tool execution

**Input Parameters**:
```typescript
{
  hook_event_name: "PreToolUse",
  tool_name: string,           // Tool name, e.g., "Bash", "Read"
  tool_input: unknown,          // Tool input parameters
  tool_use_id: string,          // Unique tool call ID
  session_id: string,
  transcript_path: string,
  cwd: string,
  agent_id?: string,            // Subagent ID (only in subagents)
  agent_type?: string           // Subagent type
}
```

**Response Options**:
```json
{
  "continue": true,             // Whether to continue (default true)
  "decision": "approve",        // approve | block
  "updatedInput": {...},        // Modified tool input
  "permissionDecision": "allow", // Permission decision
  "additionalContext": "..."    // Additional context
}
```

**Exit Code**:
- `0`: Continue execution, stdout can be passed to model as context
- `2`: Block execution, stderr displayed to model

---

#### PostToolUse
**Trigger**: After tool execution succeeds

**Input Parameters**:
```typescript
{
  hook_event_name: "PostToolUse",
  tool_name: string,
  tool_input: unknown,
  tool_response: unknown,       // Tool execution result
  tool_use_id: string,
  session_id: string,
  transcript_path: string,
  cwd: string
}
```

**Use Cases**: Result verification, logging, output modification (MCP tools)

---

#### PostToolUseFailure
**Trigger**: When tool execution fails

**Input Parameters**:
```typescript
{
  hook_event_name: "PostToolUseFailure",
  tool_name: string,
  tool_input: unknown,
  tool_use_id: string,
  error: string,                // Error message
  is_interrupt: boolean,        // Whether it's an interrupt error
  session_id: string,
  transcript_path: string,
  cwd: string
}
```

**Use Cases**: Error handling, automatic retry attempts, error logging

---

#### PermissionDenied
**Trigger**: When auto mode denies tool execution

**Input Parameters**:
```typescript
{
  hook_event_name: "PermissionDenied",
  tool_name: string,
  tool_input: unknown,
  tool_use_id: string,
  reason: string,               // Denial reason
  session_id: string,
  transcript_path: string,
  cwd: string
}
```

**Use Cases**: Permission appeal handling, alternative solution suggestions

---

### 2. Session Lifecycle (4 Types)

#### SessionStart
**Trigger**: Session startup

**Input Parameters**:
```typescript
{
  hook_event_name: "SessionStart",
  source: "startup" | "resume" | "clear" | "compact",
  agent_type?: string,
  model?: string,
  session_id: string,
  transcript_path: string,
  cwd: string
}
```

**Use Cases**: Initialization checks, resource preloading, environment preparation

---

#### Setup
**Trigger**: When Claude Code initializes or runs maintenance tasks

**Input Parameters**:
```typescript
{
  hook_event_name: "Setup",
  trigger: "init" | "maintenance",  // init=at startup, maintenance=during maintenance tasks
  session_id: string,
  transcript_path: string,
  cwd: string
}
```

**Use Cases**: Environment initialization, dependency checks, configuration validation

**Note**: HTTP Hook does not support Setup event

---

#### SessionEnd
**Trigger**: Session end

**Input Parameters**:
```typescript
{
  hook_event_name: "SessionEnd",
  session_id: string,
  transcript_path: string,
  cwd: string,
  reason: "clear" | "resume" | "logout" | "prompt_input_exit" | "other" | "bypass_permissions_disabled"
}
```

**reason values**:
| Value | Description |
|-------|-------------|
| `clear` | Session was cleared by user |
| `resume` | Session replaced after resume |
| `logout` | User logged out |
| `prompt_input_exit` | User exited via input exit |
| `other` | Other reason |
| `bypass_permissions_disabled` | bypassPermissions mode was disabled |

**Use Cases**: Cleanup, state saving, final reporting

---

#### Stop
**Trigger**: Before Claude response ends

**Input Parameters**:
```typescript
{
  hook_event_name: "Stop",
  stop_hook_active: boolean,   // Whether Stop Hook is enabled
  last_assistant_message?: string, // Last assistant message
  session_id: string,
  transcript_path: string,
  cwd: string
}
```

**Exit Code**:
- `0`: Normal stop
- `2`: Continue conversation, do not stop

---

#### StopFailure
**Trigger**: When API error causes stop

**Input Parameters**:
```typescript
{
  hook_event_name: "StopFailure",
  error: { ... },              // SDKAssistantMessageError
  error_details?: string,
  last_assistant_message?: string,
  session_id: string,
  transcript_path: string,
  cwd: string
}
```

**Use Cases**: Error logging, alert notifications

---

### 3. User Interaction (4 Types)

#### UserPromptSubmit ⭐ Common
**Trigger**: When user submits prompt

**Input Parameters**:
```typescript
{
  hook_event_name: "UserPromptSubmit",
  prompt: string,              // User input content
  session_id: string,
  transcript_path: string,
  cwd: string
}
```

**Exit Code**:
- `0`: Normal submission
- `2`: Block submission and clear input

**Use Cases**: Input validation, content filtering, security checks

---

#### Notification
**Trigger**: When sending notifications

**Input Parameters**:
```typescript
{
  hook_event_name: "Notification",
  message: string,
  title?: string,
  notification_type: string,
  session_id: string,
  transcript_path: string,
  cwd: string
}
```

**Use Cases**: Notification forwarding, third-party integrations

---

#### Elicitation
**Trigger**: When MCP server requests user input

**Input Parameters**:
```typescript
{
  hook_event_name: "Elicitation",
  mcp_server_name: string,
  message: string,
  mode?: "form" | "url",
  url?: string,
  elicitation_id?: string,
  requested_schema?: Record<string, unknown>,
  session_id: string,
  transcript_path: string,
  cwd: string
}
```

**Response Options**:
```json
{
  "action": "accept" | "decline" | "cancel",
  "content": { ... }
}
```

**Use Cases**: Automated form filling

---

#### ElicitationResult
**Trigger**: After user responds to elicitation

**Input Parameters**:
```typescript
{
  hook_event_name: "ElicitationResult",
  mcp_server_name: string,
  elicitation_id?: string,
  mode?: "form" | "url",
  action: "accept" | "decline" | "cancel",
  content?: Record<string, unknown>,  // Form data submitted by user
  session_id: string,
  transcript_path: string,
  cwd: string
}
```

**Use Cases**: Response processing, override modifications

---

### 4. Subagent (2 Types)

#### SubagentStart
**Trigger**: When subagent starts

**Input Parameters**:
```typescript
{
  hook_event_name: "SubagentStart",
  agent_id: string,
  agent_type: string,
  session_id: string,
  transcript_path: string,
  cwd: string
}
```

**Use Cases**: Initialize context, resource allocation

---

#### SubagentStop
**Trigger**: Before subagent ends

**Input Parameters**:
```typescript
{
  hook_event_name: "SubagentStop",
  stop_hook_active: boolean,
  agent_id: string,
  agent_transcript_path: string,
  agent_type: string,
  last_assistant_message?: string,
  session_id: string,
  transcript_path: string,
  cwd: string
}
```

**Exit Code**:
- `0`: Normal stop
- `2`: Continue running

---

### 5. Context Compression (2 Types)

#### PreCompact
**Trigger**: Before compression

**Input Parameters**:
```typescript
{
  hook_event_name: "PreCompact",
  trigger: "manual" | "auto",
  custom_instructions: string | null,
  session_id: string,
  transcript_path: string,
  cwd: string
}
```

**Exit Code**:
- `0`: stdout appended as custom compaction instructions
- `2`: Block compression

---

#### PostCompact
**Trigger**: After compression

**Input Parameters**:
```typescript
{
  hook_event_name: "PostCompact",
  trigger: "manual" | "auto",
  compact_summary: string,      // Summary generated by compression
  session_id: string,
  transcript_path: string,
  cwd: string
}
```

**Use Cases**: Verify compression quality, record summary

---

### 6. Permissions and Configuration (2 Types)

#### PermissionRequest
**Trigger**: When permission dialog displays

**Input Parameters**:
```typescript
{
  hook_event_name: "PermissionRequest",
  tool_name: string,
  tool_input: unknown,
  permission_suggestions?: PermissionUpdate[],
  session_id: string,
  transcript_path: string,
  cwd: string
}
```

**Response Options**:
```json
{
  "decision": {
    "behavior": "allow",
    "updatedInput": {...},
    "updatedPermissions": [...]
  } | {
    "behavior": "deny",
    "message": "...",
    "interrupt": true
  }
}
```

**Use Cases**: Automatic authorization decisions

---

#### ConfigChange
**Trigger**: When configuration file changes

**Input Parameters**:
```typescript
{
  hook_event_name: "ConfigChange",
  source: "user_settings" | "project_settings" | "local_settings" | "policy_settings" | "skills",
  file_path?: string,
  session_id: string,
  transcript_path: string,
  cwd: string
}
```

**Exit Code**:
- `0`: Accept changes
- `2`: Block changes

---

### 7. Git Worktree (2 Types)

#### WorktreeCreate
**Trigger**: When creating worktree

**Input Parameters**:
```typescript
{
  hook_event_name: "WorktreeCreate",
  name: string,
  session_id: string,
  transcript_path: string,
  cwd: string
}
```

---

#### WorktreeRemove
**Trigger**: When removing worktree

**Input Parameters**:
```typescript
{
  hook_event_name: "WorktreeRemove",
  worktree_path: string,
  session_id: string,
  transcript_path: string,
  cwd: string
}
```

---

### 8. Instructions Loading (1 Type)

#### InstructionsLoaded
**Trigger**: When loading CLAUDE.md or other instruction files

**Input Parameters**:
```typescript
{
  hook_event_name: "InstructionsLoaded",
  file_path: string,
  memory_type: "User" | "Project" | "Local" | "Managed",
  load_reason: "session_start" | "nested_traversal" | "path_glob_match" | "include" | "compact",
  globs?: string[],
  trigger_file_path?: string,
  parent_file_path?: string,
  session_id: string,
  transcript_path: string,
  cwd: string
}
```

**Use Cases**: Audit tracking, instruction change detection

---

### 9. File and Directory Monitoring (2 Types)

#### CwdChanged
**Trigger**: When working directory changes

**Input Parameters**:
```typescript
{
  hook_event_name: "CwdChanged",
  old_cwd: string,
  new_cwd: string,
  session_id: string,
  transcript_path: string,
  cwd: string
}
```

**Response Options**:
```typescript
{
  watchPaths?: string[]  // Dynamic watch path configuration
}
```

**Use Cases**: Environment variable injection, path updates

---

#### FileChanged
**Trigger**: When monitored file changes

**Input Parameters**:
```typescript
{
  hook_event_name: "FileChanged",
  file_path: string,
  event: "change" | "add" | "unlink",
  session_id: string,
  transcript_path: string,
  cwd: string
}
```

**Response Options**:
```typescript
{
  watchPaths?: string[]  // Dynamic watch path configuration
}
```

**Use Cases**: Hot reload configuration, dependency monitoring

---

### 10. Team Collaboration (3 Types)

#### TeammateIdle
**Trigger**: When teammate is idle

**Input Parameters**:
```typescript
{
  hook_event_name: "TeammateIdle",
  teammate_name: string,
  team_name: string,
  session_id: string,
  transcript_path: string,
  cwd: string
}
```

---

#### TaskCreated
**Trigger**: When task is created

**Input Parameters**:
```typescript
{
  hook_event_name: "TaskCreated",
  task_id: string,
  task_subject: string,
  task_description?: string,
  teammate_name?: string,
  team_name?: string,
  session_id: string,
  transcript_path: string,
  cwd: string
}
```

---

#### TaskCompleted
**Trigger**: When task completes

**Input Parameters**:
```typescript
{
  hook_event_name: "TaskCompleted",
  task_id: string,
  task_subject: string,
  task_description?: string,
  teammate_name?: string,
  team_name?: string,
  session_id: string,
  transcript_path: string,
  cwd: string
}
```

---

## Hook Execution Specification

### Exit Code Semantics

| Exit Code | Semantic | Applicable Hooks |
|-----------|----------|------------------|
| 0 | Success/Continue | All Hooks |
| 1 | Non-blocking error | All Hooks |
| 2 | Blocking error | PreToolUse, Stop, SubagentStop, PreCompact, ConfigChange, TeammateIdle, TaskCreated, TaskCompleted |

### Basic Hook Input

All hooks include the following base fields:

```typescript
{
  session_id: string,          // Session ID
  transcript_path: string,      // Transcript file path
  cwd: string,                  // Current working directory
  permission_mode?: string,     // Permission mode
  agent_id?: string,            // Subagent ID (only in subagents)
  agent_type?: string           // Subagent type
}
```

### Hook Response Fields

All synchronous hook responses support these common fields:

```typescript
{
  continue?: boolean,           // Whether to continue (default true)
  suppressOutput?: boolean,     // Suppress output
  stopReason?: string,          // Stop reason
  decision?: "approve" | "block", // Decision
  systemMessage?: string,       // System message, inserted into context
  reason?: string,              // Reason description
  hookSpecificOutput?: {...}    // Hook-specific output
}
```

### HTTP Hook Limitations

HTTP Hook does not support the following events:
- `Setup`
- `SessionStart`

Using HTTP Hooks for these events will be ignored.

---

## Configuration Examples

### Complete Configuration Structure

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash|Edit|Write",
        "hooks": [
          {
            "type": "command",
            "command": "python3 security-check.py",
            "timeout": 5,
            "if": "Bash(git *)"
          }
        ]
      }
    ],
    "PostToolUse": [...],
    "UserPromptSubmit": [...],
    "SessionStart": [...],
    "PreCompact": [...],
    "FileChanged": [...]
  }
}
```

### Hook Type Support

| type | Description |
|------|-------------|
| command | Execute shell command |
| prompt | Call LLM to process |
| agent | Call Agent to process |
| http | Send HTTP request |

### Hook Fields

| Field | Type | Description |
|-------|------|-------------|
| `type` | string | Hook type: command/prompt/agent/http |
| `command` | string | Command to execute (command type) |
| `prompt` | string | LLM prompt (prompt type) |
| `agent` | string | Agent name (agent type) |
| `url` | string | HTTP URL (http type) |
| `method` | string | HTTP method (http type, default POST) |
| `async` | boolean | Async execution, non-blocking tool |
| `once` | boolean | Remove after single execution |
| `asyncRewake` | boolean | Wake model when async hook errors (implies async) |
| `if` | string | Permission rule syntax condition |
| `timeout` | number | Timeout in seconds |

---

## Undocumented Features

### PostToolUse updatedMCPToolOutput

PostToolUse Hook can return `updatedMCPToolOutput` to modify MCP tool output:

```typescript
{
  hookEventName: "PostToolUse",
  updatedMCPToolOutput: unknown  // Replace tool's original output
}
```

### WorktreeCreate worktreePath

WorktreeCreate Hook can return `worktreePath` to specify the worktree directory path:

```typescript
{
  hookEventName: "WorktreeCreate",
  worktreePath: string  // Absolute path to the worktree
}
```

### PermissionDenied retry

PermissionDenied Hook can return `retry: true` to retry the denied operation:

```typescript
{
  hookEventName: "PermissionDenied",
  retry: boolean  // Retry the denied operation
}
```

### ConfigChange source Values

ConfigChange Hook's `source` field supports these values:

```typescript
source: "user_settings" | "project_settings" | "local_settings" | "policy_settings" | "skills"
```

**Note**: When `source` is `policy_settings`, even if the Hook returns a blocking result, it will be ignored (enterprise policies cannot be blocked).

**Note**: `cli_args` and `env` are NOT valid ConfigChange source values.

### InstructionsLoaded Cannot Block

InstructionsLoaded Hook is a read-only hook that does not support blocking operations:

```typescript
/**
 * Fire-and-forget — this hook is for observability/audit only
 * and does not support blocking.
 */
```

---

## Important Findings

1. **Claude Code Does Not Support PreCommit Hook**
   - PreCommit does not exist!
   - Use `PreToolUse` + `UserPromptSubmit` combination instead

2. **Hook Source Priority**
   ```
   policySettings > flagSettings > localSettings > projectSettings > userSettings
   ```

3. **Configuration Locations**
   - User level: `~/.claude/settings.json`
   - Project level: `.claude/settings.json`
   - Local level: `.claude/settings.local.json`
   - Plugin level: `~/.claude/plugins/*/hooks/hooks.json`

---

## Testing and Verification

Run test script to verify hook configuration:
```bash
bash tests/00-hooks-test.sh
```
