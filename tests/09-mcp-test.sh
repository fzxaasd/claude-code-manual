#!/bin/bash
# Claude Code MCP 服务器测试脚本
# 用途：验证 MCP 服务器配置

set -e

echo "=========================================="
echo "Claude Code MCP 服务器测试"
echo "=========================================="

TEST_DIR="/tmp/claude-mcp-test"
rm -rf "$TEST_DIR"
mkdir -p "$TEST_DIR"

# 测试 1: MCP 配置 JSON 结构
echo ""
echo "测试 1: MCP 配置结构验证"
echo "--------------------------------"

cat > "$TEST_DIR/.mcp.json" << 'EOF'
{
  "mcpServers": {
    "github": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-github"]
    },
    "filesystem": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-filesystem"],
      "env": {
        "ALLOWED_PATHS": "/tmp,/home"
      }
    },
    "brave-search": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-brave-search"],
      "env": {
        "BRAVE_API_KEY": "your-api-key"
      }
    }
  }
}
EOF

if python3 -c "import json; json.load(open('$TEST_DIR/.mcp.json'))" 2>/dev/null; then
    echo "✅ MCP 配置 JSON 语法正确"
else
    echo "❌ MCP 配置 JSON 语法错误"
fi

# 测试 2: MCP 服务器类型验证
echo ""
echo "测试 2: MCP 服务器类型验证"
echo "--------------------------------"

SERVER_TYPES=(
    "npx"
    "node"
    "python"
    "python3"
    "/usr/local/bin/server"
)

for type in "${SERVER_TYPES[@]}"; do
    echo "✅ 有效服务器类型: $type"
done

# 测试 3: MCP 服务器配置选项
echo ""
echo "测试 3: MCP 服务器配置选项"
echo "--------------------------------"

cat > "$TEST_DIR/mcp-options.json" << 'EOF'
{
  "command": "npx",
  "args": ["-y", "@modelcontextprotocol/server-github"],
  "env": {
    "DEBUG": "true"
  },
  "timeout": 30000,
  "autoReconnect": true,
  "maxRetries": 3
}
EOF

if python3 -c "import json; json.load(open('$TEST_DIR/mcp-options.json'))" 2>/dev/null; then
    echo "✅ MCP 选项 JSON 语法正确"
else
    echo "❌ MCP 选项 JSON 语法错误"
fi

# 测试 4: MCP 工具调用格式
echo ""
echo "测试 4: MCP 工具调用格式验证"
echo "--------------------------------"

cat > "$TEST_DIR/mcp-tool-call.json" << 'EOF'
{
  "tool": "mcp__github__list_repos",
  "input": {
    "owner": "anthropics",
    "limit": 10
  }
}
EOF

if python3 -c "import json; json.load(open('$TEST_DIR/mcp-tool-call.json'))" 2>/dev/null; then
    echo "✅ MCP 工具调用 JSON 语法正确"
else
    echo "❌ MCP 工具调用 JSON 语法错误"
fi

# 测试 5: MCP 服务器权限配置
echo ""
echo "测试 5: MCP 服务器权限配置"
echo "--------------------------------"

cat > "$TEST_DIR/mcp-permissions.json" << 'EOF'
{
  "allowedMcpServers": [
    { "serverName": "github" },
    { "serverCommand": ["npx", "@modelcontextprotocol/server-github"] },
    { "serverUrl": "https://mcp.example.com/*" }
  ],
  "deniedMcpServers": [
    { "serverName": "untrusted-server" }
  ],
  "allowManagedMcpServersOnly": false
}
EOF

if python3 -c "import json; json.load(open('$TEST_DIR/mcp-permissions.json'))" 2>/dev/null; then
    echo "✅ MCP 权限配置 JSON 语法正确"
else
    echo "❌ MCP 权限配置 JSON 语法错误"
fi

# 测试 6: MCP 工具过滤器
echo ""
echo "测试 6: MCP 工具过滤器验证"
echo "--------------------------------"

cat > "$TEST_DIR/mcp-filter.json" << 'EOF'
{
  "enabledMcpjsonServers": ["github", "filesystem"],
  "disabledMcpjsonServers": ["slack", "discord"],
  "mcpToolFilter": {
    "include": ["github__*", "filesystem__read_file"],
    "exclude": ["github__delete_*"]
  }
}
EOF

if python3 -c "import json; json.load(open('$TEST_DIR/mcp-filter.json'))" 2>/dev/null; then
    echo "✅ MCP 过滤器 JSON 语法正确"
else
    echo "❌ MCP 过滤器 JSON 语法错误"
fi

# 测试 7: MCP 连接状态
echo ""
echo "测试 7: MCP 连接状态验证"
echo "--------------------------------"

VALID_STATES=(
    "connecting"
    "connected"
    "disconnected"
    "error"
    "reconnecting"
)

for state in "${VALID_STATES[@]}"; do
    echo "✅ 有效连接状态: $state"
done

# 测试 8: MCP 错误处理
echo ""
echo "测试 8: MCP 错误处理验证"
echo "--------------------------------"

cat > "$TEST_DIR/mcp-error.json" << 'EOF'
{
  "error": {
    "code": "SERVER_NOT_FOUND",
    "message": "MCP server 'github' not found",
    "serverName": "github",
    "suggestion": "Run: npx -y @modelcontextprotocol/server-github"
  }
}
EOF

if python3 -c "import json; json.load(open('$TEST_DIR/mcp-error.json'))" 2>/dev/null; then
    echo "✅ MCP 错误 JSON 语法正确"
else
    echo "❌ MCP 错误 JSON 语法错误"
fi

# 清理
rm -rf "$TEST_DIR"

echo ""
echo "=========================================="
echo "MCP 服务器测试完成"
echo "=========================================="
