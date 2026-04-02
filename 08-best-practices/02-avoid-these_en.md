# 8.2 Features to Avoid

> Based on source code research and practical testing, features that should be used with caution or avoided in Claude Code

## Dangerous Operations

### 1. Dangerous Command Interception

While Claude Code has security mechanisms, you should still avoid:

```bash
# ⚠️ High-risk commands
rm -rf /              # Absolutely avoid
sudo rm -rf /         # Absolutely avoid
chmod 777             # Dangerous permissions
curl | sh             # Pipe to shell
:wq! /etc/passwd     # Edit system files
```

**Recommendation**: Explicitly deny in permissions:
```json
{
  "permissions": {
    "deny": [
      "Bash(rm -rf *)",
      "Bash(sudo rm *)",
      "Bash(chmod 777 *)"
    ]
  }
}
```

### 2. Sensitive Information Handling

```bash
# ⚠️ Avoid exposing keys in commands
curl -H "Authorization: Bearer $API_KEY"      # ✅ Safe
curl -H "Authorization: Bearer sk-xxx"       # ❌ Exposes key
```

**Best Practices**:
- Use environment variables
- Use `.env` files (already added to .gitignore)
- Use `--settings` to inject sensitive configuration

---

## Not Recommended Features

### 1. `--dangerously-skip-permissions`

```bash
# ❌ Dangerous! Skips all permission checks
claude --dangerously-skip-permissions

# ✅ Alternative: Use fine-grained whitelist or plan mode
claude --permission-mode plan
```

**Risks**:
- Cannot block dangerous operations
- Cannot audit operation history
- Violates security principles

**Note**: `--permission-mode acceptEdits` only auto-approves file write operations (Edit, Write), and does not skip permission checks for Bash and other commands. It is not a safe alternative to `--dangerously-skip-permissions`.

### 2. `--permission-mode bypassPermissions`

```bash
# Correct syntax: --permission-mode is a CLI argument, bypassPermissions is the value
claude --permission-mode bypassPermissions

# ❌ --bypassPermissions alone as a CLI flag does not exist!
```

**Note**: `--bypassPermissions` alone as a flag does not exist in the source code. The correct usage is `claude --permission-mode bypassPermissions`.

`--dangerously-skip-permissions` is a completely different flag, only available in sandboxed containers without network access.

### 3. Over-reliance on Auto Mode

```json
{
  "autoMode": {
    "allow": ["Bash(*)"]  # ⚠️ Too permissive
  }
}
```

**Recommendations**:
```json
{
  "autoMode": {
    "allow": [
      "Bash(git *)",
      "Bash(npm test)",
      "Read",
      "Glob"
    ],
    "soft_deny": [
      "Bash(rm -rf *)",
      "Bash(sudo *)"
    ]
  }
}
```

---

## Performance Issues

### 1. Large File Operations

```bash
# ⚠️ Avoid using Read/Write on large files
Read 100MB_file.log    # May cause context bloat
Write large_binary.bin  # May timeout
```

**Alternatives**:
- Use `grep -n "pattern" file` instead of full read
- Use `head -n 100 file` to read partial content
- Use streaming processing

### 2. Deep Nested Directories

```bash
# ⚠️ Avoid operating in deeply nested directories
cd /very/deep/nested/directory/structure/project  # Performance degradation
```

**Recommendations**:
- Use `--add-dir` to specify working directory
- Avoid searching in node_modules

### 3. Frequent Context Compaction

```bash
# ⚠️ Avoid triggering frequent automatic compaction
# Processing too many tasks in a single session
```

**Recommendations**:
- Split long tasks into multiple sessions
- Use `/compact` to manually trigger
- Set reasonable `cleanupPeriodDays`

---

## Configuration Pitfalls

### 1. Circular Hooks

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "git status"
          }
        ]
      }
    ]
  }
}
```

**Problem**: The `git status` Hook will trigger itself!

**Fix**: Use `if` condition
```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "security-check.sh",
            "if": "Bash(git commit)"
          }
        ]
      }
    ]
  }
}
```

### 2. Improper Timeout Settings

```json
{
  "hooks": [
    {
      "type": "command",
      "command": "slow-script.sh",
      "timeout": 5  # ⚠️ Too short
    }
  ]
}
```

**Recommendations**:
- Analyze actual execution time of scripts
- Set reasonable buffer (e.g., 1.5x expected time)
- Use `async: true` for long-running tasks

### 3. Hook Deadlock

```python
# ⚠️ PostToolUse Hook tries to modify the same file
def hook(input, response):
    if response['file'] == 'hooks.json':
        write_to_file(...)  # May cause deadlock
```

**Fix**: Use async Hook
```json
{
  "type": "command",
  "command": "async-handler.sh",
  "async": true
}
```

---

## Permission Configuration Errors

### 1. Overly Permissive Whitelist

```json
{
  "permissions": {
    "allow": ["Bash(*)"]  # ❌ Allows all commands
  }
}
```

### 2. Overly Strict Rules

```json
{
  "permissions": {
    "allow": [],
    "deny": ["Bash(*)"]  # ⚠️ Blocks all commands including git
    "defaultMode": "dontAsk"
  }
}
```

**Correct Example**:
```json
{
  "permissions": {
    "allow": [
      "Bash(git *)",
      "Bash(npm:*)",
      "Bash(npx:*)",
      "Bash(node:*)",
      "Bash(pnpm:*)",
      "Bash(yarn:*)",
      "Read",
      "Edit",
      "Write",
      "Glob",
      "Grep"
    ],
    "deny": [
      "Bash(rm -rf /*)",
      "Bash(sudo rm *)",
      "Bash(:(){:|:&};:)"
    ],
    "defaultMode": "default"
  }
}
```

---

## Session Management Issues

### 1. Session Persistence Disabled

```bash
# ⚠️ Disable session persistence
claude --no-session-persistence -p "task"
```

**Problem**: Cannot use `/resume`, cannot trace history

### 2. Fork Session ID Conflicts

```bash
# ⚠️ Frequent forks may cause ID chaos
claude --fork-session -c "task1"
claude --fork-session -c "task2"
claude --fork-session -c "task3"
```

**Recommendation**: Use meaningful session names
```bash
claude -n "feature-auth" -c
```

---

## Best Practices Summary

### ✅ Recommended

| Scenario | Recommended Approach |
|----------|----------------------|
| Permission control | Use fine-grained whitelist |
| Sensitive information | Use environment variables |
| Long tasks | Use `context: fork` |
| Security checks | Use PreToolUse Hook |
| Session management | Keep persistence enabled |

### ❌ Avoid

| Scenario | Avoid |
|----------|-------|
| Permissions | `--dangerously-skip-permissions` |
| Permissions | `allow: ["Bash(*)"]` |
| Hooks | Circular triggers |
| Files | Full read of large files |
| Sessions | `--no-session-persistence` |
