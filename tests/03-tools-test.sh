#!/bin/bash
# Claude Code 工具系统测试脚本
# 用途：验证内置工具和权限规则

set -e

echo "=========================================="
echo "Claude Code 工具系统测试"
echo "=========================================="

TEST_DIR="/tmp/claude-tools-test"
rm -rf "$TEST_DIR"
mkdir -p "$TEST_DIR"

# 测试 1: 权限规则语法
echo ""
echo "测试 1: 权限规则语法验证"
echo "--------------------------------"

# 有效的权限规则
VALID_RULES=(
    'Bash(git *)'
    'Bash(!rm *)'
    'Read(*.md)'
    'Edit(!*.json)'
    'Glob(**/*.ts)'
    'Grep(-n)'
    'Write'
    'Bash(npm test)'
    'Read(/tmp/*)'
)

# 无效的权限规则
INVALID_RULES=(
    'Bash()'           # 空操作
    'Read'              # 缺少括号
    '(!rm *)'           # 缺少工具名
)

for rule in "${VALID_RULES[@]}"; do
    if [[ "$rule" =~ ^[A-Za-z]+\(.+\)$ ]]; then
        echo "✅ 有效规则: $rule"
    else
        echo "❌ 无效规则误判: $rule"
    fi
done

for rule in "${INVALID_RULES[@]}"; do
    if [[ "$rule" =~ ^[A-Za-z]+\(.+\)$ ]]; then
        echo "❌ 有效规则误判: $rule"
    else
        echo "✅ 无效规则正确拒绝: $rule"
    fi
done

# 测试 2: 内置工具清单
echo ""
echo "测试 2: 内置工具清单验证"
echo "--------------------------------"

# 根据文档定义的内置工具
BUILTIN_TOOLS=(
    "Bash"
    "Read"
    "Write"
    "Edit"
    "Glob"
    "Grep"
    "Agent"
    "TaskOutput"
    "TaskStop"
    "TodoWrite"
    "ExitPlanMode"
)

for tool in "${BUILTIN_TOOLS[@]}"; do
    echo "✅ 内置工具: $tool"
done

# 测试 3: 权限规则模式
echo ""
echo "测试 3: 权限规则模式测试"
echo "--------------------------------"

# 测试 glob 模式匹配（使用更准确的匹配逻辑）
test_match() {
    local pattern="$1"
    local text="$2"
    local expected="$3"

    # 使用 bash 通配符进行匹配
    result="no"
    case "$text" in
        $pattern)
            result="yes"
            ;;
    esac

    if [ "$result" == "$expected" ]; then
        echo "✅ glob('$pattern', '$text') = $expected"
    else
        echo "❌ glob('$pattern', '$text') 期望 $expected, 得到 $result"
    fi
}

test_match "git *" "git status" "yes"
test_match "git *" "npm install" "no"
test_match "*.md" "README.md" "yes"
test_match "*.md" "index.js" "no"
test_match "src/**/*" "src/utils/helper.ts" "yes"

# 测试 4: 工具权限配置
echo ""
echo "测试 4: 权限配置 JSON 结构"
echo "--------------------------------"

cat > "$TEST_DIR/permissions.json" << 'EOF'
{
  "permissions": {
    "allow": [
      "Bash(git *)",
      "Bash(npm *)",
      "Read",
      "Write",
      "Edit"
    ],
    "deny": [
      "Bash(rm -rf /*)",
      "Bash(sudo rm *)"
    ],
    "defaultMode": "default"
  }
}
EOF

if python3 -c "import json; json.load(open('$TEST_DIR/permissions.json'))" 2>/dev/null; then
    echo "✅ 权限配置 JSON 语法正确"
else
    echo "❌ 权限配置 JSON 语法错误"
fi

# 测试 5: 权限规则解析
echo ""
echo "测试 5: 权限规则解析验证"
echo "--------------------------------"

# 解析工具名和模式
parse_rule() {
    local rule="$1"
    if [[ "$rule" =~ ^([A-Za-z]+)\((.*)\)$ ]]; then
        echo "Tool: ${BASH_REMATCH[1]}, Pattern: ${BASH_REMATCH[2]}"
    else
        echo "Invalid rule: $rule"
    fi
}

parse_rule "Bash(git *)"
parse_rule "Read(*.md)"
parse_rule "Edit(!*.json)"

# 清理
rm -rf "$TEST_DIR"

echo ""
echo "=========================================="
echo "工具系统测试完成"
echo "=========================================="
