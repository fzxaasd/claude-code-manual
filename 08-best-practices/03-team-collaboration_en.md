# 8.3 Team Collaboration Guidelines

> Best practices and guidelines for using Claude Code in a team setting

---

## Team Configuration Strategy

### 1. Layered Configuration Files

```
Project Root/
├── .claude/
│   ├── settings.json         # ✅ Commit - Unified standards (permissions in settings.json's permissions field)
├── .claudeignore             # ✅ Commit - Ignore rules
└── settings.local.json      # ❌ Don't commit - Local overrides
```

### 2. Permission Levels

| Level | Config | Applicable Users |
|-------|--------|------------------|
| Strict | `dontAsk` + detailed whitelist | All members |
| Medium | `default` + limited allow | Developers |
| Relaxed | `acceptEdits` | Admins |

### 3. Unified Configuration Example

```json
// .claude/settings.json
{
  "permissions": {
    "defaultMode": "dontAsk",
    "allow": [
      "Read",
      "Write(src/**)",
      "Edit",
      "Glob",
      "Grep",
      "Bash(npm *)",
      "Bash(git *)",
      "Bash(pytest *)",
      "Bash(node *)"
    ],
    "deny": [
      "Bash(rm -rf .)",
      "Bash(rm -rf node_modules)",
      "Bash(sudo *)",
      "Write(*.env)",
      "Write(*.pem)",
      "Write(*.key)",
      "Write(/etc/**)"
    ]
  }
}
```

---

## Hooks Guidelines

### 1. Project-level Hooks

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "hooks/pre-command.sh",
            "if": "git commit"
          }
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "hooks/post-command.sh"
          }
        ]
      }
    ]
  }
}
```

### 2. Hook Types

4 types are supported (documentation only shows `command`):

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",   // Command type: Execute local script
            "command": "hooks/pre-command.sh"
          }
        ]
      },
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "prompt",   // Prompt type: Modify user input
            "prompt": "Ensure command is safe"
          }
        ]
      },
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "agent",    // Agent type: LLM decides whether to execute
            "agent": "security-reviewer"
          }
        ]
      },
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "http",     // HTTP type: Send request to external service
            "url": "https://hooks.example.com/check",
            "method": "POST"
          }
        ]
      }
    ]
  }
}
```

### Hook Additional Fields

```json
{
  "type": "command",
  "command": "hooks/check.sh",
  "async": true,           // Async execution, does not block tool
  "once": true,           // Remove after executing once
  "asyncRewake": true,     // Wake model on async hook error
  "if": "Bash(git *)"     // Conditional execution (permission rule syntax)
}
```

### 3. Hooks Directory Structure

```
.claude/
├── hooks/
│   ├── pre-command.sh        # Pre-execution validation
│   ├── post-command.sh       # Post-execution logging
│   ├── commit-msg.sh         # Git commit message validation
│   └── code-style.sh         # Code style checking
└── settings.json
```

### 3. Team Shared Hooks

```bash
#!/bin/bash
# hooks/pre-command.sh
# Team-unified pre-command checks

COMMAND=$1

# Check dangerous commands
if echo "$COMMAND" | grep -qE "^rm\s+-rf"; then
  echo "❌ Dangerous command blocked"
  exit 2
fi

# Check if in correct directory
if [[ "$COMMAND" == *"git push"* ]]; then
  if ! git diff-index --quiet HEAD -- 2>/dev/null; then
    echo "⚠️ Uncommitted changes exist"
  fi
fi

exit 0
```

---

## Skills Guidelines

### 1. Team Skill Directories

```
~/.claude/skills/
├── team/
│   ├── code-review/         # Team code review
│   ├── deploy/              # Deployment workflow
│   └── docs/                # Documentation generation
└── personal/                # Personal Skills
```

### 2. Team Skill Template

```markdown
---
name: team-code-review
description: Team unified code review workflow
author: team
version: 1.0.0
---

# Team Code Review

## Review Checklist

- [ ] Code style check passed
- [ ] Unit test coverage
- [ ] No security vulnerabilities
- [ ] Documentation updated

## Review Standards

1. **Readability**: Code is clear and readable
2. **Maintainability**: Modular design
3. **Performance**: No obvious performance issues
4. **Security**: No security vulnerabilities
```

### 3. Skill Version Management

```markdown
---
name: team-deploy
version: 1.0.0
updated: 2026-04-01
changelog:
  - "1.0.0: Initial version"
  - "1.1.0: Added pre-check"
---

# Deployment Workflow
```

---

## Naming Conventions

### 1. Project Naming

```json
// Note: project.slug and project.language do not exist in source code
{
  "project": {
    "name": "my-app"
  }
}
```

### 2. Agent Naming

```json
{
  "agents": {
    "frontend-reviewer": {...},
    "backend-reviewer": {...},
    "security-auditor": {...}
  }
}
```

### 3. Hook Naming

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash(deploy*)"
      }
    ]
  }
}
```

---

## Documentation Guidelines

### 1. Project README

```markdown
# Project Name

## Claude Code Configuration

### Installation
```bash
npm install
claude init
```

### Permission Configuration
This project uses `dontAsk` permission mode.

### Team Hooks
- pre-command: Pre-command execution checks
- post-command: Post-command execution logging
```

### 2. Contribution Guide

```markdown
## Claude Code Usage Guidelines

### First-time Use
1. Run `claude init`
2. Read `.claude/settings.json`
3. Understand permission configuration

### Development Workflow
1. Use `claude` to start a session
2. Follow code review workflow
3. Run tests before commit
```

### 3. Team Documentation Structure

```
docs/
├── claude-code/
│   ├── getting-started.md
│   ├── configuration.md
│   ├── hooks.md
│   └── skills.md
└── contributing.md
```

---

## Collaboration Workflow

### 1. New Member Onboarding

```bash
# 1. Clone project
git clone git@github.com:team/project.git
cd project

# 2. Install Claude Code
brew install anthropic/formulae/claude-code

# 3. Initialize
claude init

# 4. View team configuration
# View .claude/settings.json directly or use /config command
cat .claude/settings.json

# 5. Understand permissions
# Claude Code will automatically prompt for permission requests when needed
```

### 2. Daily Development

```bash
# 1. Daily start
claude
> pull latest changes
> review my tasks

# 2. Complete tasks
> implement feature
> run tests
> commit with message

# 3. Code review
> use team-code-review skill
```

### 3. Issue Handling

```bash
# 1. Diagnose issue
claude "debug: user cannot login"

# 2. Record issue
> save diagnostic to /docs/issues/login-bug.md

# 3. Fix issue
> fix the bug
> run regression tests
```

---

## Permission Management

### 1. Permission Levels

**Note**: `permissionMode` does not exist, the correct field is `permissions.defaultMode`. `"ask"` is not a valid value, use `"default"`.

```json
// Developer permissions
{
  "permissions": {
    "defaultMode": "dontAsk",
    "allow": [
      "Read",
      "Write(src/**)",
      "Bash(npm *)",
      "Bash(git *)"
    ]
  }
}

// Advanced permissions (requires application)
{
  "permissions": {
    "defaultMode": "default",
    "allow": ["Bash(*)"]
  }
}
```

### 2. Permission Request Process

```
1. Fill out permission request form
2. Explain use case
3. Team lead approval
4. Update configuration file
```

### 3. Audit Logs

**Note**: `permission_audit.log` does not exist in the source code. Permission usage records need to be viewed through session Transcript.

```bash
# View permission usage records through Transcript
claude "Generate monthly permission usage report"
```

---

## Security Guidelines

### 1. Sensitive Operations

```bash
# Dangerous commands require manual confirmation
> rm -rf node_modules

# Sensitive file protection
# .env, *.pem, *.key files are prohibited from modification
```

### 2. API Keys

```bash
# Never expose keys in conversations
# Use environment variables
export ANTHROPIC_API_KEY=xxx
```

### 3. Audit Trail

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "audit.sh"
          }
        ]
      }
    ]
  }
}
```

---

## Team Mailbox System

### 1. Location and Structure

```
~/.claude/teams/{team_name}/inboxes/{agent_name}.json
```

Each agent has an individual mailbox file for inter-team member communication.

### 2. Message Types

| Message Type | Purpose | Direction |
|--------------|---------|------------|
| `idle_notification` | Agent idle notification | Worker -> Leader |
| `task_assignment` | Task assignment | Leader -> Worker |
| `permission_request` | Permission request | Worker -> Leader |
| `sandbox_permission_request` | Sandbox network permission | Worker -> Leader |
| `permission_response` | Permission response | Leader -> Worker |
| `sandbox_permission_response` | Sandbox permission response | Leader -> Worker |
| `shutdown_request` | Shutdown request | Leader -> Worker |
| `shutdown_approved` | Shutdown confirmed | Worker -> Leader |
| `shutdown_rejected` | Shutdown rejected | Worker -> Leader |
| `plan_approval_request` | Plan approval request | Worker -> Leader |
| `plan_approval_response` | Plan approval response | Leader -> Worker |
| `mode_set_request` | Permission mode change | Leader -> Worker |
| `team_permission_update` | Team permission broadcast | Leader -> Workers |

### 3. Message Format

```typescript
// Standard message structure
interface TeammateMessage {
  from: string           // Sender agent ID
  text: string           // Message content (JSON string)
  timestamp: string      // ISO timestamp
  read: boolean          // Whether read
  color?: string         // Sender's color tag
  summary?: string       // 5-10 word summary for UI preview
}
```

### 4. Peer DM Visibility

When an agent sends a direct message to another member, the message summary is included in idle notifications:

```typescript
// Extract peer DM summary from the last assistant message
"[to {agent_name}] {summary}"
```

This allows the Leader to track communication status between team members.

---

## Execution Backends

### 1. Backend Types

| Backend | Description | Use Case |
|---------|-------------|----------|
| `tmux` | Traditional tmux pane management | Standard terminal |
| `iterm2` | iTerm2 native split panes | iTerm2 users |
| `in-process` | Isolated context in same Node.js process | Lightweight/testing |

### 2. tmux Backend

- Uses tmux pane for agent visualization
- Supports pane layout rebalancing
- Supports pane hide/show
- Configurable external session socket

### 3. iTerm2 Backend

- Uses iTerm2 native split panes
- Requires `it2` CLI tool installation
- Provides pane border color and title settings

### 4. In-Process Backend

- Runs in the same Node.js process
- Uses isolated context (AsyncLocalStorage)
- Suitable for testing and lightweight scenarios
- Supports AbortController for lifecycle management

### 5. Backend Configuration

```json
// Configure execution backend in settings.json
{
  "swarm": {
    "backend": "tmux"  // or "iterm2", "in-process"
  }
}
```

---

## Agent Mailbox Settings

### 1. Mailbox Location

```
~/.claude/teams/{team}/inboxes/{agent_name}.json
```

### 2. Environment Variables

Agents identify themselves through these environment variables:

| Environment Variable | Description |
|---------------------|-------------|
| `CLAUDE_CODE_TEAM_NAME` | Team name |
| `CLAUDE_CODE_AGENT_ID` | Agent unique ID (format: agentName@teamName) |
| `CLAUDE_CODE_AGENT_NAME` | Agent name |
| `CLAUDE_CODE_AGENT_COLOR` | UI display color |

### 3. Team Lead Identification

The Team Lead does not have the `CLAUDE_CODE_AGENT_ID` environment variable set, or its value is `team-lead`. Other members identify the Leader by this characteristic.

---

## Permission Sync System

### 1. Permission Request Flow

```
Worker encounters permission prompt
    ↓
Worker sends permission_request to Leader mailbox
    ↓
Leader polls mailbox and detects request
    ↓
User approves/rejects via Leader UI
    ↓
Leader sends permission_response to Worker mailbox
    ↓
Worker continues execution
```

### 2. File System Structure

```
~/.claude/teams/{team_name}/
├── permissions/
│   ├── pending/           # Pending requests
│   │   └── {request_id}.json
│   └── resolved/          # Resolved requests (auto-cleanup)
│       └── {request_id}.json
└── inboxes/
    └── {agent_name}.json
```

### 3. Permission Request Message Format

```typescript
interface PermissionRequestMessage {
  type: 'permission_request'
  request_id: string
  agent_id: string        // Worker's agent_id
  tool_name: string       // Tool name requiring permission
  tool_use_id: string     // Original toolUseID
  description: string    // Human-readable description
  input: Record<string, unknown>
  permission_suggestions: unknown[]
}
```

### 4. Permission Response Message Format

```typescript
// Success response
{
  type: 'permission_response',
  request_id: string,
  subtype: 'success',
  response: {
    updated_input?: Record<string, unknown>
    permission_updates?: unknown[]
  }
}

// Error response
{
  type: 'permission_response',
  request_id: string,
  subtype: 'error',
  error: string
}
```

### 5. Sandbox Permissions

When sandbox runtime detects network access to a non-allowed host:

```typescript
interface SandboxPermissionRequestMessage {
  type: 'sandbox_permission_request'
  requestId: string
  workerId: string
  workerName: string
  workerColor?: string
  hostPattern: { host: string }
  createdAt: number
}
```

### 6. Team Permission Update Broadcast

Leader can broadcast permission updates to all members:

```typescript
interface TeamPermissionUpdateMessage {
  type: 'team_permission_update'
  permissionUpdate: {
    type: 'addRules'
    rules: Array<{ toolName: string; ruleContent?: string }>
    behavior: 'allow' | 'deny' | 'ask'
    destination: 'session'
  }
  directoryPath: string
  toolName: string
}
```

---

## Quality Assurance

### 1. Code Quality

```bash
# Pre-commit checks
> lint && test && build

# Code review
> use team-code-review skill
```

### 2. Test Coverage

```bash
# Unit tests
claude "run unit tests"

# Integration tests
claude "run integration tests"

# E2E tests
claude "run e2e tests"
```

### 3. Performance Monitoring

```bash
# Regular checks
claude "check build performance"
claude "analyze bundle size"
```

---

## Issue Feedback

### 1. Issue Template

```markdown
## Issue Description
[Detailed description of the issue]

## Reproduction Steps
1.
2.
3.

## Expected Behavior
[Expected result]

## Actual Behavior
[Actual result]

## Claude Code Version
[version]

## Configuration Info
[Related configuration]
```

### 2. Feedback Channels

| Type | Channel |
|------|---------|
| Configuration issues | GitHub Issue |
| Feature suggestions | Team discussion |
| Security issues | Private communication |
| Documentation improvements | PR |

### 3. Continuous Improvement

```bash
# Regular retrospectives
> review Claude Code usage last month
> identify improvements
> update team guidelines
```
