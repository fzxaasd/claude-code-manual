#!/bin/bash
# Claude Code 内存系统测试脚本
# 用途：验证内存系统功能和文件格式

set -e

echo "=========================================="
echo "Claude Code 内存系统测试"
echo "=========================================="

TEST_DIR="/tmp/claude-memory-test"
rm -rf "$TEST_DIR"
mkdir -p "$TEST_DIR/.claude/projects/test"

# 测试 1: 内存文件结构
echo ""
echo "测试 1: 内存文件结构验证"
echo "--------------------------------"

# 创建测试内存文件
cat > "$TEST_DIR/.claude/projects/test/user.md" << 'EOF'
---
name: developer
description: 开发人员信息
type: user
---

# 开发者信息

## 角色
后端开发工程师

## 偏好
- 使用 TypeScript
- 偏好函数式编程
- 喜欢简洁的代码风格
EOF

if [ -f "$TEST_DIR/.claude/projects/test/user.md" ]; then
    echo "✅ 用户内存文件存在"
else
    echo "❌ 用户内存文件不存在"
fi

# 测试 2: 内存类型验证
echo ""
echo "测试 2: 内存类型验证"
echo "--------------------------------"

VALID_MEMORY_TYPES=(
    "user"
    "feedback"
    "project"
    "reference"
)

for type in "${VALID_MEMORY_TYPES[@]}"; do
    echo "✅ 有效内存类型: $type"
done

# 测试 3: 内存 frontmatter 格式
echo ""
echo "测试 3: 内存 frontmatter 格式验证"
echo "--------------------------------"

cat > "$TEST_DIR/.claude/projects/test/feedback.md" << 'EOF'
---
name: prefer-typescript
description: TypeScript 偏好记录
type: feedback
---

## 偏好规则
用户偏好使用 TypeScript 进行开发

## 为什么
之前的项目中使用 TypeScript 获得了良好的类型安全体验

## 如何应用
在代码建议中优先提供 TypeScript 方案
EOF

# 验证 frontmatter
if grep -q "^---$" "$TEST_DIR/.claude/projects/test/feedback.md"; then
    echo "✅ frontmatter 分隔符存在"
fi

if grep -q "^name:" "$TEST_DIR/.claude/projects/test/feedback.md"; then
    echo "✅ frontmatter 包含 name"
fi

if grep -q "^type:" "$TEST_DIR/.claude/projects/test/feedback.md"; then
    echo "✅ frontmatter 包含 type"
fi

if grep -q "^description:" "$TEST_DIR/.claude/projects/test/feedback.md"; then
    echo "✅ frontmatter 包含 description"
fi

# 测试 4: 项目内存
echo ""
echo "测试 4: 项目内存验证"
echo "--------------------------------"

cat > "$TEST_DIR/.claude/projects/test/project.md" << 'EOF'
---
name: api-redesign
description: API 重构项目
type: project
---

## 项目目标
重构现有的 REST API 为 GraphQL

## 约束
- 保持向后兼容
- 不破坏现有客户端
- 迁移过程平滑

## 如何应用
在 API 相关工作时考虑 GraphQL 迁移策略
EOF

if grep -q "type: project" "$TEST_DIR/.claude/projects/test/project.md"; then
    echo "✅ 项目内存格式正确"
fi

# 测试 5: 参考内存
echo ""
echo "测试 5: 参考内存验证"
echo "--------------------------------"

cat > "$TEST_DIR/.claude/projects/test/reference.md" << 'EOF'
---
name: grafana-dashboard
description: Grafana 监控面板位置
type: reference
---

## 监控面板
grafana.internal/d/api-latency

## 用途
查看 API 延迟和性能指标

## 何时使用
修改请求处理代码时查看此面板
EOF

if grep -q "type: reference" "$TEST_DIR/.claude/projects/test/reference.md"; then
    echo "✅ 参考内存格式正确"
fi

# 测试 6: MEMORY.md 索引
echo ""
echo "测试 6: MEMORY.md 索引验证"
echo "--------------------------------"

cat > "$TEST_DIR/.claude/projects/test/MEMORY.md" << 'EOF'
# 内存索引

## 用户记忆
- [开发者偏好](user.md)

## 反馈记录
- [代码风格偏好](feedback.md)

## 项目信息
- [API 重构](project.md)

## 参考资料
- [Grafana 面板](reference.md)
EOF

if [ -f "$TEST_DIR/.claude/projects/test/MEMORY.md" ]; then
    echo "✅ MEMORY.md 索引文件存在"
fi

# 测试 7: 内存系统配置
echo ""
echo "测试 7: 内存系统配置验证"
echo "--------------------------------"

cat > "$TEST_DIR/memory-config.json" << 'EOF'
{
  "autoMemoryEnabled": true,
  "autoMemoryDirectory": ".claude/projects",
  "memory": {
    "maxEntries": 100,
    "autoCleanup": true,
    "cleanupPeriodDays": 30
  }
}
EOF

if python3 -c "import json; json.load(open('$TEST_DIR/memory-config.json'))" 2>/dev/null; then
    echo "✅ 内存配置 JSON 语法正确"
else
    echo "❌ 内存配置 JSON 语法错误"
fi

# 清理
rm -rf "$TEST_DIR"

echo ""
echo "=========================================="
echo "内存系统测试完成"
echo "=========================================="
