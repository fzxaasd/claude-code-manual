#!/bin/bash
# Claude Code Skills 系统测试脚本

set -e

echo "=========================================="
echo "Claude Code Skills 系统测试"
echo "=========================================="

TEST_DIR="/tmp/claude-skills-test"
rm -rf "$TEST_DIR"
mkdir -p "$TEST_DIR"

# 创建测试技能
mkdir -p "$TEST_DIR/skills/hello"
cat > "$TEST_DIR/skills/hello/SKILL.md" << 'EOF'
---
name: hello
description: 简单的问候技能
when_to_use: 当你需要测试 Claude Code 时使用
---

# 打招呼技能

这是一个简单的示例技能。

## 用法

直接说"你好"即可。
EOF

# 创建带条件的技能
mkdir -p "$TEST_DIR/skills/sql-optimizer"
cat > "$TEST_DIR/skills/sql-optimizer/SKILL.md" << 'EOF'
---
name: sql-optimizer
description: SQL 优化专家
paths:
  - "*.sql"
  - "migrations/*.sql"
when_to_use: 当你需要优化 SQL 查询时使用
allowed-tools:
  Bash(psql:*)
  Read
  Grep
---

# SQL 优化助手

帮助你优化 SQL 查询性能。

## 输入
- `$query`: 要优化的 SQL 查询

## 检查项
1. 索引使用情况
2. 查询计划分析
3. 建议的优化方案
EOF

echo ""
echo "测试 1: 技能文件结构"
echo "--------------------------------"
if [ -f "$TEST_DIR/skills/hello/SKILL.md" ]; then
    echo "✅ hello 技能文件存在"
else
    echo "❌ hello 技能文件不存在"
fi

if [ -f "$TEST_DIR/skills/sql-optimizer/SKILL.md" ]; then
    echo "✅ sql-optimizer 技能文件存在"
else
    echo "❌ sql-optimizer 技能文件不存在"
fi

echo ""
echo "测试 2: 验证 frontmatter"
echo "--------------------------------"
# 检查 hello 技能
if grep -q "name: hello" "$TEST_DIR/skills/hello/SKILL.md"; then
    echo "✅ hello 技能 frontmatter 正确"
else
    echo "❌ hello 技能 frontmatter 缺少 name"
fi

if grep -q "description:" "$TEST_DIR/skills/hello/SKILL.md"; then
    echo "✅ hello 技能有 description"
else
    echo "❌ hello 技能缺少 description"
fi

# 检查 sql-optimizer 技能
if grep -q 'paths:' "$TEST_DIR/skills/sql-optimizer/SKILL.md"; then
    echo "✅ sql-optimizer 技能有 paths 配置"
else
    echo "❌ sql-optimizer 技能缺少 paths"
fi

echo ""
echo "测试 3: 条件激活配置"
echo "--------------------------------"
if grep -q '"*.sql"' "$TEST_DIR/skills/sql-optimizer/SKILL.md"; then
    echo "✅ SQL 文件模式匹配"
else
    echo "❌ SQL 文件模式匹配缺失"
fi

if grep -q "migrations/" "$TEST_DIR/skills/sql-optimizer/SKILL.md"; then
    echo "✅ migrations 路径模式"
else
    echo "❌ migrations 路径模式缺失"
fi

# 清理
rm -rf "$TEST_DIR"

echo ""
echo "=========================================="
echo "测试完成"
echo "=========================================="
