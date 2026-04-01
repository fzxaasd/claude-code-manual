# Hook 配置与调试

## 测试 Hook 实际行为

### 测试 PreToolUse

```bash
# 创建测试目录
mkdir -p /tmp/hook-test
cd /tmp/hook-test

# 创建 hook 脚本
cat > test-hook.sh << 'SCRIPT'
#!/bin/bash
echo "Hook triggered!"
echo "Input: $1"  # JSON input from Claude Code
echo "Args count: $#"
SCRIPT
chmod +x test-hook.sh

# 测试运行
./test-hook.sh '{"tool_name":"Bash","tool_input":{"command":"echo hi"}}'
```

### Hook 调试技巧

1. **启用调试模式**
   ```bash
   claude --debug hooks
   ```

2. **日志输出**
   ```bash
   claude --debug-file /tmp/claude-debug.log
   ```

3. **查看已注册的 Hooks**
   ```bash
   claude /hooks
   ```

---

## 常见问题排查

### 问题 1: Hook 不触发

检查清单：
- [ ] settings.json 语法正确？
- [ ] Hook 类型拼写正确？（区分大小写）
- [ ] matcher 模式匹配？
- [ ] 脚本有执行权限？

### 问题 2: Hook 超时

```json
{
  "type": "command",
  "command": "python3 slow-script.py",
  "timeout": 30  // 增加超时时间
}
```

### 问题 3: Hook 输出不正确显示

```
Exit 0  → 正常输出
Exit 2  → stderr 显示给模型（阻塞）
其他   → stderr 仅显示给用户
```

---

## Python Hooks 最佳实践

### 1. 基础模板

```python
#!/usr/bin/env python3
"""PreToolUse 安全检查 Hook"""
import json
import sys
import os

def main():
    try:
        # 从 stdin 读取 JSON 输入
        input_data = json.loads(sys.stdin.read())
        
        tool_name = input_data.get('tool_name', '')
        tool_input = input_data.get('tool_input', {})
        
        # 安全检查逻辑
        if tool_name == 'Bash':
            command = tool_input.get('command', '')
            dangerous_patterns = ['rm -rf', 'sudo rm', 'chmod 777']
            
            for pattern in dangerous_patterns:
                if pattern in command:
                    # Exit 2 = 阻止执行
                    print(f"Blocked: 危险命令模式 '{pattern}'", file=sys.stderr)
                    sys.exit(2)
        
        # Exit 0 = 允许执行
        print(f"Allowed: {tool_name}")
        sys.exit(0)
        
    except json.JSONDecodeError:
        print("Invalid JSON input", file=sys.stderr)
        sys.exit(1)

if __name__ == '__main__':
    main()
```

### 2. 支持 Env 文件的 Hook

```python
#!/usr/bin/env python3
"""CwdChanged Hook - 更新环境变量"""
import json
import sys
import os

def main():
    input_data = json.loads(sys.stdin.read())
    old_cwd = input_data.get('old_cwd', '')
    new_cwd = input_data.get('new_cwd', '')
    
    # 写入 CLAUDE_ENV_FILE
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

## Hooks 配置适配

### 常见配置问题

示例问题配置：
```json
{
  "hooks": {
    "PreToolUse": [{ "matcher": "Bash|Edit|Write", ... }],
    "PostToolUse": [{ "matcher": "Edit|Write", ... }],
    "PreCommit": [...]  // ❌ Claude Code 不支持！
  }
}
```

### 正确配置

Claude Code 使用以下 Hook 组合替代 PreCommit：

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

### 建议修正

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
            "if": "Bash(git *)"  // 条件过滤
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
