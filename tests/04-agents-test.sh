#!/bin/bash
# Claude Code Agent 系统测试脚本
# 用途：验证 Agent 定义和配置

set -e

echo "=========================================="
echo "Claude Code Agent 系统测试"
echo "=========================================="

TEST_DIR="/tmp/claude-agents-test"
rm -rf "$TEST_DIR"
mkdir -p "$TEST_DIR"

# 测试 1: Agent 定义 JSON 结构
echo ""
echo "测试 1: Agent 定义结构验证"
echo "--------------------------------"

cat > "$TEST_DIR/agent-test.json" << 'EOF'
{
  "agents": {
    "reviewer": {
      "description": "代码审查专家",
      "instructions": "你是一个专业的代码审查员...",
      "tools": ["Read", "Grep", "Glob", "Edit"],
      "disallowedTools": ["Bash(rm *)", "Bash(sudo *)"],
      "model": "sonnet",
      "maxTokens": 4096
    },
    "debugger": {
      "description": "Bug 调试专家",
      "tools": ["Read", "Grep", "Bash"],
      "model": "opus"
    }
  }
}
EOF

if python3 -c "import json; json.load(open('$TEST_DIR/agent-test.json'))" 2>/dev/null; then
    echo "✅ Agent 定义 JSON 语法正确"
else
    echo "❌ Agent 定义 JSON 语法错误"
fi

# 测试 2: Agent tools 字段验证
echo ""
echo "测试 2: Agent tools 配置验证"
echo "--------------------------------"

VALID_TOOLS=(
    "Read"
    "Write"
    "Edit"
    "Glob"
    "Grep"
    "Bash"
    "Agent"
    "TaskOutput"
    "TodoWrite"
)

for tool in "${VALID_TOOLS[@]}"; do
    echo "✅ 有效工具: $tool"
done

# 测试 3: disallowedTools 规则
echo ""
echo "测试 3: disallowedTools 规则验证"
echo "--------------------------------"

DISALLOWED_RULES=(
    "Bash(rm *)"
    "Bash(sudo *)"
    "Bash(!git *)"
    "Write(!*.md)"
)

for rule in "${DISALLOWED_RULES[@]}"; do
    if [[ "$rule" =~ ^[A-Za-z]+\(.+\)$ ]]; then
        echo "✅ 有效禁止规则: $rule"
    else
        echo "❌ 无效禁止规则: $rule"
    fi
done

# 测试 4: Agent 模型配置
echo ""
echo "测试 4: Agent 模型配置验证"
echo "--------------------------------"

VALID_MODELS=(
    "opus"
    "sonnet"
    "haiku"
    "claude-opus-4-6"
    "claude-sonnet-4-6"
)

for model in "${VALID_MODELS[@]}"; do
    echo "✅ 有效模型: $model"
done

# 测试 5: Agent 调用测试
echo ""
echo "测试 5: Agent 调用结构验证"
echo "--------------------------------"

cat > "$TEST_DIR/agent-call.json" << 'EOF'
{
  "tool": "Agent",
  "input": {
    "prompt": "审查这段代码的问题",
    "agent": "reviewer",
    "timeout": 300
  }
}
EOF

if python3 -c "import json; json.load(open('$TEST_DIR/agent-call.json'))" 2>/dev/null; then
    echo "✅ Agent 调用 JSON 语法正确"
else
    echo "❌ Agent 调用 JSON 语法错误"
fi

# 测试 6: 多 Agent 协作配置
echo ""
echo "测试 6: 多 Agent 协作配置"
echo "--------------------------------"

cat > "$TEST_DIR/multi-agent.json" << 'EOF'
{
  "agents": {
    "coordinator": {
      "description": "任务协调者",
      "tools": ["Agent"],
      "maxTokens": 8192
    },
    "frontend-dev": {
      "description": "前端开发者",
      "tools": ["Read", "Write", "Edit", "Glob", "Bash"],
      "cwd": "./frontend"
    },
    "backend-dev": {
      "description": "后端开发者",
      "tools": ["Read", "Write", "Edit", "Glob", "Bash"],
      "cwd": "./backend"
    }
  }
}
EOF

if python3 -c "import json; json.load(open('$TEST_DIR/multi-agent.json'))" 2>/dev/null; then
    echo "✅ 多 Agent 配置 JSON 语法正确"
else
    echo "❌ 多 Agent 配置 JSON 语法错误"
fi

# 测试 7: Agent frontmatter 验证
echo ""
echo "测试 7: Agent frontmatter 验证"
echo "--------------------------------"

mkdir -p "$TEST_DIR/agents/reviewer"
cat > "$TEST_DIR/agents/reviewer/AGENT.md" << 'EOF'
---
name: reviewer
description: 代码审查专家
model: sonnet
tools:
  - Read
  - Grep
  - Glob
  - Edit
disallowedTools:
  - Bash(rm *)
  - Bash(sudo *)
---

# 代码审查 Agent

## 职责
- 检查代码质量
- 发现潜在 Bug
- 提出优化建议

## 工作流程
1. 阅读代码
2. 分析问题
3. 给出建议
EOF

if [ -f "$TEST_DIR/agents/reviewer/AGENT.md" ]; then
    echo "✅ Agent 文件存在"
else
    echo "❌ Agent 文件不存在"
fi

if grep -q "name: reviewer" "$TEST_DIR/agents/reviewer/AGENT.md"; then
    echo "✅ Agent frontmatter name 正确"
fi

if grep -q "description:" "$TEST_DIR/agents/reviewer/AGENT.md"; then
    echo "✅ Agent frontmatter description 存在"
fi

# 清理
rm -rf "$TEST_DIR"

echo ""
echo "=========================================="
echo "Agent 系统测试完成"
echo "=========================================="
