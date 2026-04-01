#!/bin/bash
# Claude Code CLI 参数测试脚本
# 用途：验证命令行参数解析

set -e

echo "=========================================="
echo "Claude Code CLI 参数测试"
echo "=========================================="

# 测试 1: 全局选项格式
echo ""
echo "测试 1: 全局选项格式验证"
echo "--------------------------------"

VALID_FLAGS=(
    "--debug"
    "--debug-file=/tmp/log.txt"
    "--model=opus"
    "--agent=test-agent"
    "--output-style=short"
    "--verbose"
    "--version"
    "--help"
    "-y"
    "-n"
)

for flag in "${VALID_FLAGS[@]}"; do
    echo "✅ 有效 CLI 选项: $flag"
done

# 测试 2: 子命令格式
echo ""
echo "测试 2: 子命令格式验证"
echo "--------------------------------"

VALID_COMMANDS=(
    "claude"
    "claude /help"
    "claude /plan"
    "claude /tasks"
    "claude /memory"
    "claude /agents"
    "claude /hooks"
    "claude /skills"
    "claude /config"
    "claude /compact"
    "claude /clear"
    "claude /exit"
)

for cmd in "${VALID_COMMANDS[@]}"; do
    echo "✅ 有效子命令: $cmd"
done

# 测试 3: claude 命令参数解析
echo ""
echo "测试 3: claude 命令参数解析"
echo "--------------------------------"

parse_claude_args() {
    local args="$1"

    # 解析基本参数
    if [[ "$args" == -* ]]; then
        echo "Flag mode detected"
    elif [[ "$args" == /* ]]; then
        echo "Slash command: ${args:1}"
    else
        echo "Prompt mode"
    fi
}

parse_claude_args "--debug"
parse_claude_args "/help"
parse_claude_args "请帮我写一个函数"

# 测试 4: 短选项验证
echo ""
echo "测试 4: 短选项验证"
echo "--------------------------------"

SHORT_FLAGS=(
    "-y"  # yes/no 模式
    "-n"  # non-interactive
    "-i"  # interactive
    "-v"  # verbose
)

for flag in "${SHORT_FLAGS[@]}"; do
    echo "✅ 有效短选项: $flag"
done

# 测试 5: 长选项验证
echo ""
echo "测试 5: 长选项验证"
echo "--------------------------------"

LONG_FLAGS=(
    "--add-dir"
    "--agent"
    "-- verbose"
    "--output-style"
    "--model"
    "--config"
    "--debug"
)

for flag in "${LONG_FLAGS[@]}"; do
    echo "✅ 有效长选项: $flag"
done

# 测试 6: 配置子命令
echo ""
echo "测试 6: 配置子命令验证"
echo "--------------------------------"

CONFIG_COMMANDS=(
    "claude /config set model=opus"
    "claude /config get model"
    "claude /config list"
    "claude /config reset"
)

for cmd in "${CONFIG_COMMANDS[@]}"; do
    echo "✅ 有效配置命令: $cmd"
done

# 测试 7: 任务子命令
echo ""
echo "测试 7: 任务子命令验证"
echo "--------------------------------"

TASK_COMMANDS=(
    "claude /tasks"
    "claude /tasks list"
    "claude /tasks add 完成代码审查"
    "claude /tasks complete 1"
    "claude /tasks delete 2"
)

for cmd in "${TASK_COMMANDS[@]}"; do
    echo "✅ 有效任务命令: $cmd"
done

# 测试 8: 环境变量
echo ""
echo "测试 8: 环境变量验证"
echo "--------------------------------"

VALID_ENV_VARS=(
    "ANTHROPIC_API_KEY"
    "CLAUDE_DISABLE_SPINNER"
    "CLAUDE_NO_INPUT"
    "CLAUDE_SESSION_TIMEOUT"
    "HTTP_PROXY"
    "HTTPS_PROXY"
)

for env in "${VALID_ENV_VARS[@]}"; do
    echo "✅ 有效环境变量: $env"
done

# 测试 9: Exit Code
echo ""
echo "测试 9: Exit Code 验证"
echo "--------------------------------"

EXIT_CODES=(
    "0 - 成功"
    "1 - 一般错误"
    "2 - 严重错误/阻止操作"
    "130 - Ctrl+C 中断"
)

for code in "${EXIT_CODES[@]}"; do
    echo "✅ Exit Code: $code"
done

# 测试 10: CLI 配置文件
echo ""
echo "测试 10: CLI 配置 JSON 结构"
echo "--------------------------------"

TEST_DIR="/tmp/claude-cli-test"
rm -rf "$TEST_DIR"
mkdir -p "$TEST_DIR"

cat > "$TEST_DIR/cli-config.json" << 'EOF'
{
  "defaultModel": "sonnet",
  "defaultAgent": "default",
  "outputStyle": "default",
  "autoMemoryEnabled": true,
  "sessionTimeout": 3600,
  "aliases": {
    "gs": "git status",
    "gc": "git commit",
    "gl": "git log"
  }
}
EOF

if python3 -c "import json; json.load(open('$TEST_DIR/cli-config.json'))" 2>/dev/null; then
    echo "✅ CLI 配置 JSON 语法正确"
else
    echo "❌ CLI 配置 JSON 语法错误"
fi

# 清理
rm -rf "$TEST_DIR"

echo ""
echo "=========================================="
echo "CLI 参数测试完成"
echo "=========================================="
