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
