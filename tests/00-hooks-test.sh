#!/bin/bash
# Claude Code Hook 系统测试脚本
# 用途：验证 Hook 配置是否正确生效

set -o pipefail

echo "=========================================="
echo "Claude Code Hook 系统测试"
echo "=========================================="

# 测试目录
TEST_DIR="/tmp/claude-hook-test"
rm -rf "$TEST_DIR"
mkdir -p "$TEST_DIR"

# 创建测试 Hook 脚本
cat > "$TEST_DIR/security-hook.py" << 'PYTHON'
#!/usr/bin/env python3
"""PreToolUse 安全检查 Hook 测试"""
import json
import sys

def main():
    try:
        data = json.loads(sys.stdin.read())
        tool_name = data.get('tool_name', '')
        tool_input = data.get('tool_input', {})
        
        print(f"Hook triggered: {tool_name}", file=sys.stderr)
        
        if tool_name == 'Bash':
            command = tool_input.get('command', '')
            if 'rm -rf /' in command:
                print("Blocked: dangerous command", file=sys.stderr)
                sys.exit(2)  # 阻止执行
            if ':(){:|:&};:' in command:
                print("Blocked: fork bomb", file=sys.stderr)
                sys.exit(2)
        
        print("Allowed", file=sys.stderr)
        sys.exit(0)
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)

if __name__ == '__main__':
    main()
PYTHON

chmod +x "$TEST_DIR/security-hook.py"

# 测试 1: 安全命令
echo ""
echo "测试 1: 安全命令 (echo hello)"
echo "--------------------------------"
INPUT='{"tool_name":"Bash","tool_input":{"command":"echo hello"}}'
RESULT=$(echo "$INPUT" | python3 "$TEST_DIR/security-hook.py" 2>&1)
EXIT_CODE=${PIPESTATUS[0]}
echo "Exit Code: $EXIT_CODE"
echo "Output: $RESULT"
if [ $EXIT_CODE -eq 0 ]; then
    echo "✅ 测试 1 通过"
else
    echo "❌ 测试 1 失败"
fi

# 测试 2: 危险命令 (rm -rf /)
echo ""
echo "测试 2: 危险命令 (rm -rf /)"
echo "--------------------------------"
INPUT='{"tool_name":"Bash","tool_input":{"command":"rm -rf /"}}'
RESULT=$(echo "$INPUT" | python3 "$TEST_DIR/security-hook.py" 2>&1)
EXIT_CODE=${PIPESTATUS[0]}
echo "Exit Code: $EXIT_CODE"
echo "Output: $RESULT"
if [ $EXIT_CODE -eq 2 ]; then
    echo "✅ 测试 2 通过 (正确阻止)"
else
    echo "❌ 测试 2 失败 (应该返回 Exit 2)"
fi

# 测试 3: Fork bomb
echo ""
echo "测试 3: Fork bomb 检测"
echo "--------------------------------"
INPUT='{"tool_name":"Bash","tool_input":{"command":":(){:|:&};:"}}'
RESULT=$(echo "$INPUT" | python3 "$TEST_DIR/security-hook.py" 2>&1)
EXIT_CODE=${PIPESTATUS[0]}
echo "Exit Code: $EXIT_CODE"
echo "Output: $RESULT"
if [ $EXIT_CODE -eq 2 ]; then
    echo "✅ 测试 3 通过 (正确阻止)"
else
    echo "❌ 测试 3 失败 (应该返回 Exit 2)"
fi

# 测试 4: 读取操作
echo ""
echo "测试 4: 读取操作"
echo "--------------------------------"
INPUT='{"tool_name":"Read","tool_input":{"file_path":"/etc/passwd"}}'
RESULT=$(echo "$INPUT" | python3 "$TEST_DIR/security-hook.py" 2>&1)
EXIT_CODE=${PIPESTATUS[0]}
echo "Exit Code: $EXIT_CODE"
echo "Output: $RESULT"
if [ $EXIT_CODE -eq 0 ]; then
    echo "✅ 测试 4 通过"
else
    echo "❌ 测试 4 失败"
fi

# 清理
rm -rf "$TEST_DIR"

echo ""
echo "=========================================="
echo "测试完成"
echo "=========================================="
