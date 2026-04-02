# 8.1 Recommended Patterns

> Verified best practices and usage patterns

---

## Workflow Patterns

### 1. Incremental Development Pattern

```
Requirements → Breakdown → Implementation → Testing → Review → Merge
```

**Use Case**: Large feature development
**Advantages**: Controllable risk, easy to review

```bash
# Best practices
> Break this feature into 3-4 smaller tasks
> Complete only one small task at a time
> Perform code review after completion
> Then move to the next task
```

### 2. Exploration and Verification Pattern

```
Hypothesis → Verification → Conclusion → Implementation
```

**Use Case**: Technology selection, problem diagnosis
**Advantages**: Reduces trial and error costs

```bash
# Best practices
> First analyze existing code using Read and Grep
> Confirm technical feasibility
> Then start implementation
```

### 3. Progressive Enhancement Pattern

```
Existing Code → Understanding → Small Changes → Testing → Large Changes
```

**Use Case**: Refactoring, optimization
**Advantages**: Maintains functional stability

---

## Project Organization Patterns

### 1. Single Responsibility Directory

```
src/
├── features/
│   ├── auth/
│   │   ├── components/
│   │   ├── hooks/
│   │   └── services/
│   └── dashboard/
├── shared/
│   ├── components/
│   └── utils/
└── tests/
```

### 2. Organized by Domain

```
domain/
├── users/
├── orders/
├── products/
└── shared/
```

### 3. Layered Architecture

```
layers/
├── presentation/
├── application/
├── domain/
└── infrastructure/
```

---

## Configuration Patterns

### 1. Layered Configuration

**Note**: `permissionMode` does not exist! The correct field is `permissions.defaultMode`.

```json
// ~/.claude/settings.json (user-level)
{
  "permissions": {
    "defaultMode": "default"
  },
  "model": "sonnet"
}

// .claude/settings.json (project-level)
{
  "permissions": {
    "defaultMode": "dontAsk",
    ...
  }
}

// .claude/settings.local.json (local)
{
  "permissions": {
    "defaultMode": "acceptEdits"
  }
}
```

### 2. Permission Configuration Pattern

```json
{
  "permissions": {
    "allow": [
      "Read",
      "Write(src/**)",
      "Edit",
      "Glob",
      "Grep",
      "Bash(npm run *)",
      "Bash(npm test)",
      "Bash(git *)"
    ],
    "deny": [
      "Bash(rm -rf *)",
      "Bash(sudo *)",
      "Write(*.env)",
      "Write(*.pem)"
    ]
  }
}
```

### 3. Hook Configuration Pattern

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "hooks/validate.sh"
          }
        ]
      }
    ]
  }
}
```

---

## Skill Design Patterns

### 1. Atomic Skill

Each Skill does one thing:

```markdown
---
name: eslint-fix
description: Run ESLint and auto-fix
---

# ESLint Fix

Run eslint --fix and report results.
```

### 2. Composed Skill

Multiple atomic Skills combined:

```markdown
---
name: code-review
description: Complete code review workflow
---

# Code Review Workflow

1. Run eslint-fix
2. Run prettier-format
3. Run unit-tests
4. Generate review report
```

### 3. Conditional Skill Activation

```markdown
---
name: python-lint
paths:
  - "**/*.py"
---

# Python Linting
```

---

## Collaboration Patterns

### 1. Master-Assistant Pattern

```
User (Decision Maker)
    ↓ Instructions
Claude (Executor)
    ↓ Suggestions
User (Approval)
```

### 2. Pair Programming Pattern

```
User ←→ Claude
  ↕        ↕
 Keyboard  Code
```

### 3. Code Review Pattern

```
Claude (Implementer)
    ↓ PR
Claude (Reviewer)
    ↓ Feedback
Claude (Fixer)
```

---

## Debugging Patterns

### 1. Step-by-Step Debugging

```bash
> Execute this function step by step
> Add breakpoint at line 5
> Check the value of variable x
> Continue to line 10
```

### 2. Incremental Changes

```bash
> First modify the function signature
> Verify compilation passes
> Then modify the function body
> Verify tests pass
```

### 3. Rollback Strategy

```bash
# Test after each major change
> git commit -m "WIP: step 1"

# Rollback when problems occur
> git reset --soft HEAD~1
```

---

## Security Patterns

### 1. Principle of Least Privilege

**Note**: `permissionMode` does not exist! The correct field is `permissions.defaultMode`.

```json
{
  "permissions": {
    "defaultMode": "dontAsk",
    "allow": ["Read", "Glob", "Grep"],
    "deny": ["Write", "Bash"]
  }
}
```

### 2. Command Whitelist

```json
{
  "permissions": {
    "allow": [
      "Bash(npm run *)",
      "Bash(npm test)",
      "Bash(git status)",
      "Bash(git log)"
    ]
  }
}
```

### 3. Sensitive Operation Confirmation

```bash
> Confirm you want to execute this command?
> This is an irreversible operation
> Recommended to backup data first
```

---

## Performance Patterns

### 1. Context Management

```bash
# Periodically compact session
> compact

# Start new session instead of continuing
> start new session
```

### 2. Batch Operations

```bash
# Instead of processing one by one
> Batch rename all test files to *.spec

# Instead of searching one by one
> Search all TODOs and generate report
```

### 3. Incremental Updates

```bash
# Instead of full rebuild
> npm run build -- --watch

# Instead of testing everything
> npm test -- --grep "auth"
```

---

## Version Control Patterns

### 1. Atomic Commits

```bash
# One commit does one thing
> commit: add user authentication feature
> commit: fix login page styles
> commit: add unit tests
```

### 2. Pre-commit Checks

```bash
# Auto-check before commit
> git add .
> npm test
> git commit -m "feat: add feature"
```

### 3. Branch Strategy

```
main (production)
  ↑
develop (development)
  ↑
feature/xxx (feature branches)
```

---

## Documentation Patterns

### 1. Code as Documentation

```typescript
// Use clear naming
const isUserAuthenticated = true;

// Add necessary comments
/**
 * Calculate order total
 * @param items - Order item list
 * @returns Total price (in cents)
 */
function calculateTotal(items: Item[]): number
```

### 2. Changelog

```markdown
## 2026-04-01

### Added
- User authentication feature

### Changed
- Optimized login page performance

### Fixed
- Fixed Token expiration issue
```

### 3. README Structure

```markdown
# Project Name

## Quick Start
## Features
## Configuration
## Development Guide
## API Documentation
```

---

## Error Handling Patterns

### 1. Defensive Programming

```bash
# Check preconditions
> Backup before making changes
> Confirm file exists
> Validate input parameters
```

### 2. Graceful Degradation

```bash
> Try the simplest solution first
> If it fails, try the more complex solution
> Finally fall back to manual handling
```

### 3. Error Logging

```bash
# Log error information
> Save error log to /tmp/error.log
> Analyze error cause
> Propose solution
```

---

## Template Files

### Project Initialization Template

**Note**: `permissionMode` does not exist! The correct field is `permissions.defaultMode`.

```bash
mkdir -p .claude
cat > .claude/settings.json << 'EOF'
{
  "permissions": {
    "defaultMode": "default",
    "allow": ["Read", "Write", "Edit", "Glob", "Grep"],
    "deny": ["Bash(rm -rf *)"]
  }
}
EOF
```

### Pre-commit Hook Template

```bash
#!/bin/bash
# .git/hooks/pre-commit
claude --command "run lint && run tests"
```
