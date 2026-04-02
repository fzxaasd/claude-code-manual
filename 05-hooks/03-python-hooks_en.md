# Python Hooks Practice

> Complete Python Hooks development templates and best practices

## Basic Templates

### PreToolUse Hook

```python
#!/usr/bin/env python3
"""Claude Code PreToolUse Hook - Security Check"""
import json
import sys
import os

DANGEROUS_PATTERNS = [
    'rm -rf /',
    'rm -rf /*',
    'sudo rm -rf',
    'chmod 777',
    ':(){:|:&};:',
]

SENSITIVE_PATHS = [
    '.env',
    'credentials',
    'secrets',
    '.pem',
    '.key',
]

def main():
    try:
        data = json.loads(sys.stdin.read())
        tool_name = data.get('tool_name', '')
        tool_input = data.get('tool_input', {})

        if tool_name == 'Bash':
            command = tool_input.get('command', '')
            for pattern in DANGEROUS_PATTERNS:
                if pattern in command:
                    print(f"BLOCKED: dangerous pattern '{pattern}'", file=sys.stderr)
                    sys.exit(2)  # Exit 2 = block execution

        elif tool_name == 'Read':
            path = tool_input.get('file_path', '')
            for pattern in SENSITIVE_PATHS:
                if pattern in path:
                    print(f"WARNING: sensitive file access '{path}'", file=sys.stderr)

        sys.exit(0)  # Exit 0 = allow execution

    except json.JSONDecodeError:
        print("ERROR: invalid JSON input", file=sys.stderr)
        sys.exit(1)

if __name__ == '__main__':
    main()
```

### UserPromptSubmit Hook

```python
#!/usr/bin/env python3
"""Claude Code UserPromptSubmit Hook - Input Validation"""
import json
import sys

BLOCKED_KEYWORDS = [
    'drop table',
    'delete all',
    'rm -rf',
]

def main():
    try:
        data = json.loads(sys.stdin.read())
        prompt = data.get('prompt', '')

        for keyword in BLOCKED_KEYWORDS:
            if keyword.lower() in prompt.lower():
                print(f"BLOCKED: contains '{keyword}'", file=sys.stderr)
                sys.exit(2)  # Block submission

        sys.exit(0)

    except json.JSONDecodeError:
        sys.exit(1)

if __name__ == '__main__':
    main()
```

### PostToolUse Hook

```python
#!/usr/bin/env python3
"""Claude Code PostToolUse Hook - Result Verification"""
import json
import sys

def main():
    try:
        data = json.loads(sys.stdin.read())
        tool_name = data.get('tool_name', '')
        tool_input = data.get('tool_input', {})
        tool_response = data.get('tool_response', {})

        exit_code = tool_response.get('exit_code', 0)
        output = tool_response.get('output', '')

        # Check for failures
        if exit_code != 0:
            print(f"WARNING: {tool_name} failed with code {exit_code}", file=sys.stderr)
            sys.exit(0)  # Non-blocking, just a warning

        sys.exit(0)

    except json.JSONDecodeError:
        sys.exit(1)

if __name__ == '__main__':
    main()
```

---

## Advanced Templates

### Configurable Hook

```python
#!/usr/bin/env python3
"""Configurable PreToolUse Hook"""
import json
import sys
import os
from pathlib import Path

class HookConfig:
    def __init__(self):
        self.dangerous_patterns = [
            'rm -rf /',
            'sudo rm -rf',
        ]
        self.allowed_users = os.environ.get('ALLOWED_USERS', '').split(',')
        self.log_file = os.environ.get('HOOK_LOG_FILE', '/tmp/hook.log')

    def load_from_file(self, path):
        """Load additional configuration from file"""
        if Path(path).exists():
            with open(path) as f:
                extra = json.load(f)
                self.dangerous_patterns.extend(extra.get('patterns', []))

    def log(self, message):
        """Log message"""
        with open(self.log_file, 'a') as f:
            f.write(f"{message}\n")

class SecurityHook:
    def __init__(self):
        self.config = HookConfig()
        self.config.load_from_file('.claude/hook-config.json')

    def check_bash_command(self, command):
        """Check Bash command"""
        for pattern in self.config.dangerous_patterns:
            if pattern in command:
                return False, f"Dangerous pattern: {pattern}"
        return True, "OK"

    def run(self, input_data):
        """Execute check"""
        tool_name = input_data.get('tool_name', '')
        tool_input = input_data.get('tool_input', {})

        if tool_name == 'Bash':
            command = tool_input.get('command', '')
            allowed, msg = self.check_bash_command(command)
            if not allowed:
                return 2, msg

        return 0, "Allowed"

def main():
    config = HookConfig()
    hook = SecurityHook()

    try:
        data = json.loads(sys.stdin.read())
        exit_code, message = hook.run(data)

        print(message, file=sys.stderr if exit_code != 0 else sys.stdout)
        sys.exit(exit_code)

    except json.JSONDecodeError as e:
        print(f"JSON error: {e}", file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        print(f"Hook error: {e}", file=sys.stderr)
        sys.exit(1)

if __name__ == '__main__':
    main()
```

### Async Hook

```python
#!/usr/bin/env python3
"""Async PostToolUse Hook - Notifications"""
import json
import sys
import subprocess
import threading

def async_notify(message):
    """Send notification asynchronously"""
    def _send():
        subprocess.run([
            'notify-send',
            'Claude Code',
            message
        ], capture_output=True)

    thread = threading.Thread(target=_send)
    thread.start()

def main():
    try:
        data = json.loads(sys.stdin.read())
        tool_name = data.get('tool_name', '')
        tool_response = data.get('tool_response', {})

        exit_code = tool_response.get('exit_code', 0)

        if tool_name == 'Bash' and exit_code == 0:
            async_notify(f"Bash command completed: {exit_code}")

        sys.exit(0)

    except json.JSONDecodeError:
        sys.exit(1)

if __name__ == '__main__':
    main()
```

---

## CwdChanged Hook

```python
#!/usr/bin/env python3
"""CwdChanged Hook - Environment Variable Management"""
import json
import sys
import os

def main():
    data = json.loads(sys.stdin.read())
    old_cwd = data.get('old_cwd', '')
    new_cwd = data.get('new_cwd', '')

    env_file = os.environ.get('CLAUDE_ENV_FILE')
    if env_file:
        with open(env_file, 'w') as f:
            f.write(f'export OLD_DIR="{old_cwd}"\n')
            f.write(f'export CURRENT_DIR="{new_cwd}"\n')

            # Load environment variables based on new directory
            env_path = f"{new_cwd}/.env"
            if os.path.exists(env_path):
                f.write(f'# Load .env from {new_cwd}\n')
                f.write(f'source "{env_path}"\n')

    sys.exit(0)

if __name__ == '__main__':
    main()
```

---

## Best Practices

### 1. Error Handling

```python
try:
    # Main logic
except json.JSONDecodeError:
    print("Invalid JSON", file=sys.stderr)
    sys.exit(1)  # Non-blocking error
except Exception as e:
    print(f"Error: {e}", file=sys.stderr)
    sys.exit(1)
```

### 2. Logging

```python
import logging

logging.basicConfig(
    filename='/tmp/claude-hooks.log',
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)

def log(msg):
    logging.info(msg)
```

### 3. Performance Optimization

```python
# Use caching
import functools

@functools.lru_cache(maxsize=128)
def check_pattern(pattern, text):
    return pattern in text
```

### 4. Testing

```python
import unittest

class TestSecurityHook(unittest.TestCase):
    def test_dangerous_command_blocked(self):
        hook = SecurityHook()
        allowed, _ = hook.check_bash_command('rm -rf /')
        self.assertFalse(allowed)

    def test_safe_command_allowed(self):
        hook = SecurityHook()
        allowed, _ = hook.check_bash_command('echo hello')
        self.assertTrue(allowed)
```
