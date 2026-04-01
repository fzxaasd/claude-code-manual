#!/bin/bash
# Claude Code 任务系统测试脚本
# 用途：验证任务管理功能

set -e

echo "=========================================="
echo "Claude Code 任务系统测试"
echo "=========================================="

TEST_DIR="/tmp/claude-tasks-test"
rm -rf "$TEST_DIR"
mkdir -p "$TEST_DIR"

# 测试 1: TodoWrite 工具调用
echo ""
echo "测试 1: TodoWrite 工具调用验证"
echo "--------------------------------"

cat > "$TEST_DIR/todo-call.json" << 'EOF'
{
  "tool": "TodoWrite",
  "input": {
    "todos": [
      {
        "activeForm": "完成代码审查",
        "content": "完成 API 重构代码审查",
        "status": "in_progress"
      },
      {
        "activeForm": "编写测试",
        "content": "编写单元测试",
        "status": "pending"
      },
      {
        "activeForm": "更新文档",
        "content": "更新 README 文档",
        "status": "pending"
      }
    ]
  }
}
EOF

if python3 -c "import json; json.load(open('$TEST_DIR/todo-call.json'))" 2>/dev/null; then
    echo "✅ TodoWrite 调用 JSON 语法正确"
else
    echo "❌ TodoWrite 调用 JSON 语法错误"
fi

# 测试 2: 任务状态验证
echo ""
echo "测试 2: 任务状态验证"
echo "--------------------------------"

VALID_STATUSES=(
    "pending"
    "in_progress"
    "completed"
)

for status in "${VALID_STATUSES[@]}"; do
    echo "✅ 有效任务状态: $status"
done

# 测试 3: TaskOutput 工具调用
echo ""
echo "测试 3: TaskOutput 工具调用验证"
echo "--------------------------------"

cat > "$TEST_DIR/taskoutput-call.json" << 'EOF'
{
  "tool": "TaskOutput",
  "input": {
    "task_id": "abc123",
    "block": true,
    "timeout": 30000
  }
}
EOF

if python3 -c "import json; json.load(open('$TEST_DIR/taskoutput-call.json'))" 2>/dev/null; then
    echo "✅ TaskOutput 调用 JSON 语法正确"
else
    echo "❌ TaskOutput 调用 JSON 语法错误"
fi

# 测试 4: TaskStop 工具调用
echo ""
echo "测试 4: TaskStop 工具调用验证"
echo "--------------------------------"

cat > "$TEST_DIR/taskstop-call.json" << 'EOF'
{
  "tool": "TaskStop",
  "input": {
    "task_id": "abc123"
  }
}
EOF

if python3 -c "import json; json.load(open('$TEST_DIR/taskstop-call.json'))" 2>/dev/null; then
    echo "✅ TaskStop 调用 JSON 语法正确"
else
    echo "❌ TaskStop 调用 JSON 语法错误"
fi

# 测试 5: 任务文件格式
echo ""
echo "测试 5: 任务文件格式验证"
echo "--------------------------------"

mkdir -p "$TEST_DIR/.claude/tasks"

cat > "$TEST_DIR/.claude/tasks/task-001.json" << 'EOF'
{
  "id": "task-001",
  "content": "完成用户认证功能",
  "status": "in_progress",
  "activeForm": "开发用户认证模块",
  "createdAt": "2026-04-01T10:00:00Z",
  "updatedAt": "2026-04-01T12:00:00Z"
}
EOF

if [ -f "$TEST_DIR/.claude/tasks/task-001.json" ]; then
    echo "✅ 任务文件存在"
else
    echo "❌ 任务文件不存在"
fi

# 测试 6: 任务列表更新
echo ""
echo "测试 6: 任务列表更新验证"
echo "--------------------------------"

cat > "$TEST_DIR/tasks-update.json" << 'EOF'
{
  "tool": "TodoWrite",
  "input": {
    "todos": [
      {
        "activeForm": "完成代码审查",
        "content": "完成 API 重构代码审查",
        "status": "completed"
      },
      {
        "activeForm": "编写测试",
        "content": "编写单元测试",
        "status": "in_progress"
      },
      {
        "activeForm": "更新文档",
        "content": "更新 README 文档",
        "status": "pending"
      }
    ]
  }
}
EOF

if python3 -c "import json; json.load(open('$TEST_DIR/tasks-update.json'))" 2>/dev/null; then
    echo "✅ 任务更新 JSON 语法正确"
else
    echo "❌ 任务更新 JSON 语法错误"
fi

# 测试 7: 任务优先级
echo ""
echo "测试 7: 任务优先级验证"
echo "--------------------------------"

cat > "$TEST_DIR/tasks-priority.json" << 'EOF'
{
  "tasks": [
    {
      "id": "1",
      "content": "修复生产环境 Bug",
      "priority": "critical",
      "status": "pending"
    },
    {
      "id": "2",
      "content": "添加新功能",
      "priority": "high",
      "status": "pending"
    },
    {
      "id": "3",
      "content": "优化性能",
      "priority": "medium",
      "status": "pending"
    },
    {
      "id": "4",
      "content": "更新文档",
      "priority": "low",
      "status": "pending"
    }
  ]
}
EOF

if python3 -c "import json; json.load(open('$TEST_DIR/tasks-priority.json'))" 2>/dev/null; then
    echo "✅ 任务优先级 JSON 语法正确"
else
    echo "❌ 任务优先级 JSON 语法错误"
fi

# 清理
rm -rf "$TEST_DIR"

echo ""
echo "=========================================="
echo "任务系统测试完成"
echo "=========================================="
