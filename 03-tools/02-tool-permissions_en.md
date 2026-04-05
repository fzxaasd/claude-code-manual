# 3.2 Tool Permission Management

> Detailed explanation of Claude Code's permission control mechanism

---

## Permission Modes

### Permission Mode Types

| Mode | Description | Use Case |
|------|-------------|----------|
| `default` | Use default permission rules | Standard usage |
| `acceptEdits` | Allow file edits | Code modification needed |
| `bypassPermissions` | Skip permission checks | CI/automation environments |
| `dontAsk` | Don't ask, silently deny unauthorized operations | Non-interactive environments |
| `plan` | Plan mode, only analyze without executing | Preview operations |
| `auto` | Auto mode (experimental, requires TRANSCRIPT_CLASSIFIER feature) | Intelligent permission decisions |

### Setting Permission Mode

```bash
# Command line
claude --permission-mode acceptEdits

# Environment variable
# CLAUDE_PERMISSION_MODE does not exist, use CLI flag or settings.json instead

# CLI argument
claude --permission-mode acceptEdits

# Configuration file
{
  "permissions": {
    "defaultMode": "acceptEdits"
  }
}
```

---

## Permission Rules Configuration

### Rule Structure

Permission rules contain the following properties:

| Property | Type | Description |
|----------|------|-------------|
| `source` | string | Rule source |
| `ruleBehavior` | `allow` \| `deny` \| `ask` | Rule behavior |
| `ruleValue.toolName` | string | Tool name |
| `ruleValue.ruleContent` | string | Optional matching pattern |

### Rule Syntax

#### Tool Matching
```
ToolName          # Allow/deny this tool
ToolName(pattern) # Match specific call patterns
```

#### Supported Patterns

| Pattern Example | Matches |
|-----------------|---------|
| `Bash` | All Bash calls |
| `Bash(npm *)` | Commands starting with npm |
| `Bash(*.sh)` | All shell scripts |
| `Bash(git push)` | git push command |
| `Write(*.env)` | All .env files |
| `Read(/etc/*)` | Files in /etc directory |

### Rule Sources

Rules are grouped and managed by source:

| Source | Description |
|--------|-------------|
| `userSettings` | User-level configuration (~/.claude/settings.json) |
| `projectSettings` | Project-level configuration (.claude.json) |
| `localSettings` | Local override configuration |
| `flagSettings` | Command line flag settings |
| `policySettings` | Enterprise policy configuration |
| `cliArg` | CLI argument specification |
| `command` | Command injection |
| `session` | In-session dynamic settings |

---

## Permission Priority

### Rule Priority

1. **Explicit deny (deny)** > **allow** > **ask**
2. More specific patterns have higher priority
3. Regex matches take priority over wildcards

### Source Priority

```
policySettings (highest) > flagSettings > localSettings > projectSettings > userSettings > pluginSettings (lowest)
```

**Note**: Configurations are traversed from **lowest to highest priority**, later items override earlier ones.

### Execution Order

```
Tool request
    ↓
Check rules (starting from highest priority source)
    ↓ [deny matches]
    ↓
Deny execution
    ↓ [allow matches]
    ↓
Allow execution
    ↓ [ask matches]
    ↓
Ask user
    ↓ [no rule matches]
    ↓
Check default permission mode
```

---

## Dynamic Permission Requests

### Hook System

Claude Code uses the Hook system to handle dynamic permission requests.

### PreToolUse Hook

Triggers before tool execution:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "check_permission.sh"
          }
        ]
      }
    ]
  }
}
```

### Hook Return Format

Hooks return JSON-formatted decisions:

```json
{
  "continue": true,
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "allow",
    "permissionDecisionReason": "Trusted command"
  }
}
```

Supported `permissionDecision` values:
- `allow` - Allow execution
- `deny` - Deny execution
- `ask` - Ask user

---

## PermissionDenied Hook

Triggers after a tool is denied:

```json
{
  "hooks": {
    "PermissionDenied": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "log_denial.sh"
          }
        ]
      }
    ]
  }
}
```

### Return Format

```json
{
  "continue": true,
  "hookSpecificOutput": {
    "hookEventName": "PermissionDenied",
    "retry": false
  }
}
```

---

## Temporary Permissions

### Session Level

```bash
# Use acceptEdits mode
claude --permission-mode acceptEdits

# Bypass all permission checks (not recommended)
claude --permission-mode bypassPermissions
```

### Tool Level

Users can approve individual calls at runtime:

```
Tool request: Bash(rm -rf node_modules)
Allow? [y/N/a]
```

| Option | Meaning |
|--------|---------|
| `y` | Allow this time only |
| `n` | Deny |
| `a` | Allow all subsequent similar calls |

---

## Permission Configuration Examples

### Development Environment

```json
{
  "permissions": {
    "defaultMode": "acceptEdits"
  }
}
```

### Review Environment

```json
{
  "permissions": {
    "defaultMode": "default",
    "allow": ["Read", "Glob", "Grep"],
    "deny": ["Bash(rm -rf *)", "Write(/etc/**)"]
  }
}
```

### Production Environment

```json
{
  "permissions": {
    "defaultMode": "dontAsk",
    "allow": ["Read", "Glob", "Grep", "Bash(npm run build)", "Bash(npm test)"],
    "deny": ["Bash(sudo *)", "Bash(chmod *)", "Write(/etc/**)", "Write(*.pem)", "Write(*.key)"]
  }
}
```

### Plan Mode

```json
{
  "permissions": {
    "defaultMode": "plan"
  }
}
```

---

## Permission Auditing

### Permission Logging

Record permission decisions via Hooks:

```json
{
  "hooks": {
    "PermissionDenied": [
      {
        "matcher": "*",
        "hooks": [
          {
            "type": "command",
            "command": "audit_permission.sh"
          }
        ]
      }
    ]
  }
}
```

### Audit Script Example

```bash
#!/bin/bash
# audit_permission.sh
read input
echo "$input" >> ~/.claude/permission_audit.log
```

---

## Troubleshooting

### Common Issues

**Q: All commands are denied**
```json
// Check permissions configuration
{
  "permissions": {
    "allow": ["Bash"]
  }
}
```

**Q: Permissions still not taking effect after hook returns**
```json
// Ensure correct hookSpecificOutput is returned
{
  "continue": true,
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "allow"
  }
}
```

**Q: Rules not taking effect**
```json
// Check priority order
// policySettings > flagSettings > localSettings > projectSettings > userSettings
// Ensure rules in higher priority sources are correctly configured
```

---

## Best Practices

1. **Principle of Least Privilege**: Only grant necessary permissions
2. **Layered Configuration**: userSettings < projectSettings < localSettings < flagSettings < policySettings
3. **Regular Auditing**: Log permission requests
4. **Dangerous Command Blacklist**: rm -rf, sudo, etc.
5. **Specific Patterns**: Avoid using `*` wildcards
