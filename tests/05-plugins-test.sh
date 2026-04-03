#!/bin/bash
# Claude Code 插件系统测试脚本
# 用途：验证插件结构和 .claude-plugin/plugin.json
# 注意：skills/agents/hooks 在 plugin.json 中使用路径字符串数组

set -e

echo "=========================================="
echo "Claude Code 插件系统测试"
echo "=========================================="

TEST_DIR="/tmp/claude-plugins-test"
rm -rf "$TEST_DIR"
mkdir -p "$TEST_DIR"

# 测试 1: 插件目录结构
echo ""
echo "测试 1: 插件目录结构验证"
echo "--------------------------------"

mkdir -p "$TEST_DIR/my-plugin/.claude-plugin"
mkdir -p "$TEST_DIR/my-plugin/skills/greeting"
mkdir -p "$TEST_DIR/my-plugin/agents/helper"
mkdir -p "$TEST_DIR/my-plugin/hooks"

echo "插件目录结构:"
find "$TEST_DIR/my-plugin" -type d

# 测试 2: .claude-plugin/plugin.json 结构
# 注意：清单文件必须在 .claude-plugin/ 子目录中
echo ""
echo "测试 2: .claude-plugin/plugin.json 结构验证"
echo "--------------------------------"

cat > "$TEST_DIR/my-plugin/.claude-plugin/plugin.json" << 'EOF'
{
  "name": "my-plugin",
  "version": "1.0.0",
  "description": "我的第一个 Claude Code 插件",
  "author": {
    "name": "Developer",
    "email": "developer@example.com"
  },
  "skills": ["./skills/greeting/SKILL.md"],
  "agents": ["./agents/helper/AGENT.md"],
  "hooks": ["./hooks"]
}
EOF

if python3 -c "import json; json.load(open('$TEST_DIR/my-plugin/.claude-plugin/plugin.json'))" 2>/dev/null; then
    echo "✅ .claude-plugin/plugin.json JSON 语法正确"
else
    echo "❌ .claude-plugin/plugin.json JSON 语法错误"
fi

# 测试 3: 插件技能定义
echo ""
echo "测试 3: 插件技能定义验证"
echo "--------------------------------"

cat > "$TEST_DIR/my-plugin/skills/greeting/SKILL.md" << 'EOF'
---
name: greeting
description: 打招呼技能
version: "1.0"
when_to_use: 当需要打招呼时使用
---

# 打招呼技能

提供友好的问候服务。

## 使用方法

直接说"你好"或"hello"
EOF

if [ -f "$TEST_DIR/my-plugin/skills/greeting/SKILL.md" ]; then
    echo "✅ 插件技能文件存在"
else
    echo "❌ 插件技能文件不存在"
fi

# 测试 4: 插件 Agent 定义
echo ""
echo "测试 4: 插件 Agent 定义验证"
echo "--------------------------------"

mkdir -p "$TEST_DIR/my-plugin/agents/helper"
cat > "$TEST_DIR/my-plugin/agents/helper/AGENT.md" << 'EOF'
---
name: helper
description: 帮助助手
model: sonnet
tools:
  - Read
  - Write
  - Grep
---

# 帮助助手

提供各种帮助信息。
EOF

if [ -f "$TEST_DIR/my-plugin/agents/helper/AGENT.md" ]; then
    echo "✅ 插件 Agent 文件存在"
else
    echo "❌ 插件 Agent 文件不存在"
fi

# 测试 5: 插件配置
echo ""
echo "测试 5: 插件配置验证"
echo "--------------------------------"

cat > "$TEST_DIR/plugin-config.json" << 'EOF'
{
  "plugins": {
    "enabled": {
      "formatter@anthropic-tools": true,
      "linter@custom-marketplace": true
    }
  }
}
EOF

if python3 -c "import json; json.load(open('$TEST_DIR/plugin-config.json'))" 2>/dev/null; then
    echo "✅ 插件配置 JSON 语法正确"
else
    echo "❌ 插件配置 JSON 语法错误"
fi

# 测试 6: 插件安装验证
echo ""
echo "测试 6: 插件结构完整性检查"
echo "--------------------------------"

check_plugin_structure() {
    local plugin_dir="$1"
    local errors=0

    # 检查必需文件：必须在 .claude-plugin/ 子目录中
    if [ ! -f "$plugin_dir/.claude-plugin/plugin.json" ]; then
        echo "❌ 缺少 .claude-plugin/plugin.json"
        ((errors++))
    fi

    # 检查 skills 目录（可选）
    if [ ! -d "$plugin_dir/skills" ]; then
        echo "⚠️  缺少 skills 目录（可选）"
    fi

    # 检查 agents 目录（可选）
    if [ ! -d "$plugin_dir/agents" ]; then
        echo "⚠️  缺少 agents 目录（可选）"
    fi

    if [ $errors -eq 0 ]; then
        echo "✅ 插件结构完整"
    fi
}

check_plugin_structure "$TEST_DIR/my-plugin"

# 测试 7: 插件市场配置
echo ""
echo "测试 7: 插件市场配置验证"
echo "--------------------------------"

cat > "$TEST_DIR/marketplace-config.json" << 'EOF'
{
  "extraKnownMarketplaces": {
    "internal": {
      "source": {
        "type": "github",
        "repo": "my-org/claude-plugins"
      }
    }
  },
  "blockedMarketplaces": [
    "untrusted-marketplace"
  ]
}
EOF

if python3 -c "import json; json.load(open('$TEST_DIR/marketplace-config.json'))" 2>/dev/null; then
    echo "✅ 市场配置 JSON 语法正确"
else
    echo "❌ 市场配置 JSON 语法错误"
fi

# 清理
rm -rf "$TEST_DIR"

echo ""
echo "=========================================="
echo "插件系统测试完成"
echo "=========================================="
