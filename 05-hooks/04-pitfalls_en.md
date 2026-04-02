# Common Issues and Pitfalls

> Troubleshooting guide for Claude Code Hooks system

## Issue Classification

### 1. Hook Not Triggering

#### Symptoms
Hook is configured but never executes.

#### Possible Causes

| Cause | How to Check | Solution |
|-------|--------------|----------|
| JSON syntax error | `python3 -m json.tool settings.json` | Fix JSON |
| Hook type misspelling | Compare with `hooksConfigManager.ts` | Use correct type name |
| Matcher not matching | Check if tool name matches | Modify matcher |
| File path error | Check config file location | Move to correct location |

#### Troubleshooting Steps

```bash
# 1. Verify JSON syntax
python3 -m json.tool ~/.claude/settings.json > /dev/null

# 2. View registered hooks
claude /hooks

# 3. Enable debugging
claude --debug hooks

# 4. Check config file
cat ~/.claude/settings.json | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('hooks', {}))"
```

### 2. Hook Timeout

#### Symptoms
Hook takes too long to execute or times out.

#### Causes
- Script execution time exceeds `timeout`
- Network request blocking
- Infinite loop

#### Solution

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "long-running-script.sh",
            "timeout": 30,
            "async": true
          }
        ]
      }
    ]
  }
}
```

### 3. Recursive Triggering

#### Symptoms
Hook triggers itself, causing infinite loop.

#### Problem Example

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

`git status` will trigger PreToolUse Hook again!

#### Solution

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

### 4. Exit Code Behavior Errors

#### Common Misconceptions

| Exit Code | Expected | Actual |
|-----------|----------|--------|
| 0 | Failure | Success (no output) |
| 2 | Error | Blocking (shown to model) |
| Other | Error | Non-blocking (only shown to user) |

#### Correct Understanding

```
Exit 0  --> Success, stdout optionally passed to model
Exit 2  --> Blocking error, stderr shown to model
Other   --> Non-blocking error, stderr only shown to user
```

### 5. Permission Issues

#### Symptoms
Hook script lacks execute permission.

#### Solution

```bash
chmod +x .claude/hooks/*.sh
chmod +x .claude/hooks/*.py
```

### 6. Missing Environment Variables

#### Symptoms
Script depends on environment variables that don't exist.

#### Solution

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "script.sh",
            "env": {
              "MY_VAR": "value"
            }
          }
        ]
      }
    ]
  }
}
```

### 7. Working Directory Errors

#### Symptoms
Script can't find files, but files exist.

#### Solution

```bash
# Use absolute path
python3 /absolute/path/to/script.py

# Or change directory at script start
cd "$(dirname "$0")"
```

### 8. Multiple Hook Execution Order

#### Problem
Execution order is undefined when multiple hooks match.

#### Solution
Use a single hook to call a script, handle logic inside the script:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash|Edit|Write",
        "hooks": [
          {
            "type": "command",
            "command": "python3 combined-hook.py"
          }
        ]
      }
    ]
  }
}
```

---

## Debugging Tips

### 1. Simple Debugging

```python
#!/usr/bin/env python3
import sys
import json

data = json.loads(sys.stdin.read())
print(f"DEBUG: {json.dumps(data, indent=2)}", file=sys.stderr)
sys.exit(0)
```

### 2. Conditional Debugging

```python
import os

if os.environ.get('DEBUG_HOOKS'):
    print(f"DEBUG: {data}", file=sys.stderr)
```

### 3. Log Files

```python
import logging

logging.basicConfig(
    filename='/tmp/claude-hooks.log',
    level=logging.DEBUG
)

logging.debug(f"Hook input: {data}")
```

---

## Common Error Reference

| Error | Cause | Solution |
|-------|-------|----------|
| Hook not executing | JSON syntax error | Validate JSON |
| Hook timeout | Timeout too short | Increase timeout |
| Recursive trigger | Hook triggers itself | Use `if` condition |
| No permission | chmod issue | Add execute permission |
| File not found | Path error | Use absolute path |
| Exit 0 but not working | Logic error | Check script logic |
| Exit 2 not working | Tool not supported | Confirm tool type |
