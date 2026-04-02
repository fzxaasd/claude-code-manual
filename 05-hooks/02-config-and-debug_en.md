# Hook Configuration and Debugging

## Testing Hook Behavior

### Testing PreToolUse

```bash
# Create test directory
mkdir -p /tmp/hook-test
cd /tmp/hook-test

# Create hook script
cat > test-hook.sh << 'SCRIPT'
#!/bin/bash
echo "Hook triggered!"
echo "Input: $1"  # JSON input from Claude Code
echo "Args count: $#"
SCRIPT
chmod +x test-hook.sh

# Test run
./test-hook.sh '{"tool_name":"Bash","tool_input":{"command":"echo hi"}}'
```

### Hook Debugging Tips

1. **Enable debug mode**
   ```bash
   claude --debug hooks
   ```

2. **Log output**
   ```bash
   claude --debug-file /tmp/claude-debug.log
   ```

3. **View registered hooks**
   ```bash
   claude /hooks
   ```

---

## Common Troubleshooting

### Issue 1: Hook Not Triggering

Checklist:
- [ ] Is settings.json syntax correct?
- [ ] Is hook type spelled correctly? (case-sensitive)
- [ ] Does matcher pattern match?
- [ ] Does script have execute permission?

### Issue 2: Hook Timeout

```json
{
  "type": "command",
  "command": "python3 slow-script.py",
  "timeout": 30  // Increase timeout
}
```

### Issue 3: Hook Output Not Displaying Correctly

```
Exit 0  --> Normal output
Exit 2  --> stderr shown to model (blocking)
Other   --> stderr only shown to user
```

---

## Python Hooks Best Practices

### 1. Basic Template

```python
#!/usr/bin/env python3
"""PreToolUse Security Check Hook"""
import json
import sys
import os

def main():
    try:
        # Read JSON input from stdin
        input_data = json.loads(sys.stdin.read())

        tool_name = input_data.get('tool_name', '')
        tool_input = input_data.get('tool_input', {})

        # Security check logic
        if tool_name == 'Bash':
            command = tool_input.get('command', '')
            dangerous_patterns = ['rm -rf', 'sudo rm', 'chmod 777']

            for pattern in dangerous_patterns:
                if pattern in command:
                    # Exit 2 = block execution
                    print(f"Blocked: dangerous command pattern '{pattern}'", file=sys.stderr)
                    sys.exit(2)

        # Exit 0 = allow execution
        print(f"Allowed: {tool_name}")
        sys.exit(0)

    except json.JSONDecodeError:
        print("Invalid JSON input", file=sys.stderr)
        sys.exit(1)

if __name__ == '__main__':
    main()
```

### 2. Hook with Env File Support

```python
#!/usr/bin/env python3
"""CwdChanged Hook - Update Environment Variables"""
import json
import sys
import os

def main():
    input_data = json.loads(sys.stdin.read())
    old_cwd = input_data.get('old_cwd', '')
    new_cwd = input_data.get('new_cwd', '')

    # Write to CLAUDE_ENV_FILE
    env_file = os.environ.get('CLAUDE_ENV_FILE')
    if env_file:
        with open(env_file, 'w') as f:
            f.write(f'export OLD_DIR="{old_cwd}"\n')
            f.write(f'export CURRENT_DIR="{new_cwd}"\n')

    sys.exit(0)

if __name__ == '__main__':
    main()
```

---

## Hook Configuration Adaptation

### Common Configuration Issues

Example problematic configuration:
```json
{
  "hooks": {
    "PreToolUse": [{ "matcher": "Bash|Edit|Write", ... }],
    "PostToolUse": [{ "matcher": "Edit|Write", ... }],
    "PreCommit": [...]  // Claude Code does not support this!
  }
}
```

### Correct Configuration

Claude Code uses the following hook combination instead of PreCommit:

```json
{
  "hooks": {
    "UserPromptSubmit": [
      {
        "matcher": "commit",
        "hooks": [
          {
            "type": "command",
            "command": "pre-commit-check.sh",
            "timeout": 30000
          }
        ]
      }
    ],
    "PreToolUse": [
      {
        "matcher": "Bash(git commit*)",
        "hooks": [
          {
            "type": "command",
            "command": "validate.sh"
          }
        ]
      }
    ]
  }
}
```

### Recommended Configuration

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "python3 .claude/hooks/security.py",
            "if": "Bash(git *)"  // Conditional filter
          }
        ]
      },
      {
        "matcher": "Edit|Write",
        "hooks": [
          {
            "type": "command",
            "command": "python3 .claude/hooks/testing.py"
          }
        ]
      }
    ],
    "UserPromptSubmit": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "python3 .claude/hooks/workflow.py",
            "timeout": 5
          }
        ]
      }
    ],
    "PreCompact": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "python3 .claude/hooks/context-management.py"
          }
        ]
      }
    ]
  }
}
```
