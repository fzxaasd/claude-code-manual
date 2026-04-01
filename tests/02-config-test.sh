#!/bin/bash
# Claude Code 配置系统测试脚本

set -e

echo "=========================================="
echo "Claude Code 配置系统测试"
echo "=========================================="

TEST_DIR="/tmp/claude-config-test"
rm -rf "$TEST_DIR"
mkdir -p "$TEST_DIR"
cd "$TEST_DIR"

# 测试 1: 基础 settings.json
echo ""
echo "测试 1: 基础 settings.json"
echo "--------------------------------"
cat > "$TEST_DIR/settings.json" << 'EOF'
{
  "$schema": "https://json.schemastore.org/claude-code-settings.json",
  "permissions": {
    "allow": ["Bash(git *)", "Read", "Edit"],
    "deny": ["Bash(rm -rf /*)"]
  }
}
EOF

if [ -f "$TEST_DIR/settings.json" ]; then
    echo "✅ settings.json 创建成功"
else
    echo "❌ settings.json 创建失败"
fi

# 验证 JSON 语法
if python3 -c "import json; json.load(open('$TEST_DIR/settings.json'))" 2>/dev/null; then
    echo "✅ JSON 语法正确"
else
    echo "❌ JSON 语法错误"
fi

# 测试 2: Hooks 配置
echo ""
echo "测试 2: Hooks 配置"
echo "--------------------------------"
cat > "$TEST_DIR/hooks-test.json" << 'EOF'
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "python3 security.py",
            "if": "Bash(git *)",
            "timeout": 5
          }
        ]
      }
    ],
    "UserPromptSubmit": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "python3 validate.py",
            "timeout": 10
          }
        ]
      }
    ]
  }
}
EOF

if python3 -c "import json; json.load(open('$TEST_DIR/hooks-test.json'))" 2>/dev/null; then
    echo "✅ Hooks 配置 JSON 语法正确"
else
    echo "❌ Hooks 配置 JSON 语法错误"
fi

# 测试 3: Agent 配置
echo ""
echo "测试 3: Agent 配置"
echo "--------------------------------"
cat > "$TEST_DIR/agents-test.json" << 'EOF'
{
  "agents": {
    "reviewer": {
      "description": "代码审查专家",
      "tools": ["Read", "Grep", "Glob"],
      "disallowedTools": ["Bash(rm *)", "Bash(sudo *)"],
      "model": "sonnet"
    }
  }
}
EOF

if python3 -c "import json; json.load(open('$TEST_DIR/agents-test.json'))" 2>/dev/null; then
    echo "✅ Agent 配置 JSON 语法正确"
else
    echo "❌ Agent 配置 JSON 语法错误"
fi

# 测试 4: MCP 配置
echo ""
echo "测试 4: MCP 配置"
echo "--------------------------------"
cat > "$TEST_DIR/.mcp.json" << 'EOF'
{
  "mcpServers": {
    "github": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-github"]
    }
  }
}
EOF

if python3 -c "import json; json.load(open('$TEST_DIR/.mcp.json'))" 2>/dev/null; then
    echo "✅ MCP 配置 JSON 语法正确"
else
    echo "❌ MCP 配置 JSON 语法错误"
fi

# 测试 5: 权限规则语法
echo ""
echo "测试 5: 权限规则语法验证"
echo "--------------------------------"

# 有效规则
VALID_RULES=(
    'Bash(git *)'
    'Bash(!rm *)'
    'Read(*.md)'
    'Edit(!*.json)'
)

# 无效规则
INVALID_RULES=(
    'Bash()'           # 空操作
    'Read'              # 缺少括号
)

for rule in "${VALID_RULES[@]}"; do
    echo "测试规则: $rule"
    # 基本格式检查
    if [[ "$rule" =~ ^[A-Za-z]+\(.*\)$ ]]; then
        echo "  ✅ 格式正确"
    else
        echo "  ❌ 格式错误"
    fi
done

# 清理
cd /
rm -rf "$TEST_DIR"

echo ""
echo "=========================================="
echo "配置测试完成"
echo "=========================================="
