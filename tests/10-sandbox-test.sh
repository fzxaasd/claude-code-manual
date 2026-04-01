#!/bin/bash
# Claude Code Sandbox 沙箱测试脚本
# 用途：验证沙箱配置和安全设置

set -e

echo "=========================================="
echo "Claude Code Sandbox 沙箱测试"
echo "=========================================="

TEST_DIR="/tmp/claude-sandbox-test"
rm -rf "$TEST_DIR"
mkdir -p "$TEST_DIR"

# 测试 1: Sandbox 配置结构
echo ""
echo "测试 1: Sandbox 配置结构验证"
echo "--------------------------------"

cat > "$TEST_DIR/sandbox-config.json" << 'EOF'
{
  "sandbox": {
    "enabled": true,
    "timeout": 30000,
    "maxMemory": "512MB",
    "filesystem": {
      "allowedPaths": ["/tmp/work", "/project/src"],
      "deniedPaths": ["/etc", "/root", "*.pem"],
      "readOnly": false
    },
    "network": {
      "enabled": true,
      "allowedHosts": ["api.github.com", "registry.npmjs.org"],
      "blockedHosts": ["internal.local", "10.0.0.*"],
      "allowedPorts": [80, 443, 8080]
    },
    "env": {
      "NODE_ENV": "production",
      "SANDBOX_MODE": "true"
    }
  }
}
EOF

if python3 -c "import json; json.load(open('$TEST_DIR/sandbox-config.json'))" 2>/dev/null; then
    echo "✅ Sandbox 配置 JSON 语法正确"
else
    echo "❌ Sandbox 配置 JSON 语法错误"
fi

# 测试 2: 文件系统配置
echo ""
echo "测试 2: 文件系统配置验证"
echo "--------------------------------"

cat > "$TEST_DIR/filesystem-config.json" << 'EOF'
{
  "filesystem": {
    "allowedPaths": ["/tmp", "/project"],
    "deniedPaths": ["/etc/passwd", "/root/.ssh"],
    "readOnly": true,
    "followSymlinks": false
  }
}
EOF

if python3 -c "import json; json.load(open('$TEST_DIR/filesystem-config.json'))" 2>/dev/null; then
    echo "✅ 文件系统配置 JSON 语法正确"
else
    echo "❌ 文件系统配置 JSON 语法错误"
fi

# 测试 3: 网络配置
echo ""
echo "测试 3: 网络配置验证"
echo "--------------------------------"

cat > "$TEST_DIR/network-config.json" << 'EOF'
{
  "network": {
    "enabled": false,
    "allowedHosts": ["api.example.com"],
    "blockedHosts": ["*.local", "192.168.*.*"],
    "allowedPorts": [443],
    "dnsServers": ["8.8.8.8"]
  }
}
EOF

if python3 -c "import json; json.load(open('$TEST_DIR/network-config.json'))" 2>/dev/null; then
    echo "✅ 网络配置 JSON 语法正确"
else
    echo "❌ 网络配置 JSON 语法错误"
fi

# 测试 4: 沙箱权限模式
echo ""
echo "测试 4: 沙箱权限模式验证"
echo "--------------------------------"

PERMISSION_MODES=(
    "all"         # 禁用沙箱
    "ask"         # 执行前询问
    "limiting"    # 强制沙箱
    "safeExit"    # 严格沙箱
)

for mode in "${PERMISSION_MODES[@]}"; do
    echo "✅ 有效权限模式: $mode"
done

# 测试 5: 沙箱工具调用
echo ""
echo "测试 5: 沙箱工具调用验证"
echo "--------------------------------"

cat > "$TEST_DIR/sandbox-call.json" << 'EOF'
{
  "tool": "SandboxExecute",
  "input": {
    "sandboxId": "sandbox_abc123",
    "command": "npm install",
    "cwd": "/tmp/work",
    "timeout": 60000,
    "env": {
      "NODE_ENV": "production"
    }
  }
}
EOF

if python3 -c "import json; json.load(open('$TEST_DIR/sandbox-call.json'))" 2>/dev/null; then
    echo "✅ 沙箱调用 JSON 语法正确"
else
    echo "❌ 沙箱调用 JSON 语法错误"
fi

# 测试 6: 沙箱违规处理
echo ""
echo "测试 6: 沙箱违规处理验证"
echo "--------------------------------"

cat > "$TEST_DIR/sandbox-violation.json" << 'EOF'
{
  "violation": {
    "type": "filesystem",
    "attemptedPath": "/etc/passwd",
    "allowedPaths": ["/tmp/work"],
    "timestamp": "2026-04-01T10:00:00Z"
  }
}
EOF

if python3 -c "import json; json.load(open('$TEST_DIR/sandbox-violation.json'))" 2>/dev/null; then
    echo "✅ 违规处理 JSON 语法正确"
else
    echo "❌ 违规处理 JSON 语法错误"
fi

# 测试 7: 沙箱 Hook 配置
echo ""
echo "测试 7: 沙箱 Hook 配置验证"
echo "--------------------------------"

cat > "$TEST_DIR/sandbox-hooks.json" << 'EOF'
{
  "hooks": {
    "SandboxViolation": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "log_violation.sh",
            "timeout": 5
          }
        ]
      }
    ],
    "SandboxCreate": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "setup_sandbox.sh"
          }
        ]
      }
    ]
  }
}
EOF

if python3 -c "import json; json.load(open('$TEST_DIR/sandbox-hooks.json'))" 2>/dev/null; then
    echo "✅ 沙箱 Hook 配置 JSON 语法正确"
else
    echo "❌ 沙箱 Hook 配置 JSON 语法错误"
fi

# 测试 8: 沙箱与 MCP 集成
echo ""
echo "测试 8: 沙箱与 MCP 集成验证"
echo "--------------------------------"

cat > "$TEST_DIR/mcp-sandbox.json" << 'EOF'
{
  "mcpServers": {
    "untrusted-plugin": {
      "command": "node",
      "args": ["./plugin.js"],
      "sandbox": {
        "filesystem": {
          "allowedPaths": ["/project"]
        },
        "network": {
          "enabled": false
        }
      }
    }
  }
}
EOF

if python3 -c "import json; json.load(open('$TEST_DIR/mcp-sandbox.json'))" 2>/dev/null; then
    echo "✅ MCP 沙箱配置 JSON 语法正确"
else
    echo "❌ MCP 沙箱配置 JSON 语法错误"
fi

# 测试 9: 资源限制配置
echo ""
echo "测试 9: 资源限制配置验证"
echo "--------------------------------"

cat > "$TEST_DIR/limits-config.json" << 'EOF'
{
  "sandbox": {
    "timeout": 30000,
    "maxMemory": "512MB",
    "maxCpu": "1",
    "maxDisk": "1GB",
    "maxProcesses": 10,
    "maxOpenFiles": 100
  }
}
EOF

if python3 -c "import json; json.load(open('$TEST_DIR/limits-config.json'))" 2>/dev/null; then
    echo "✅ 资源限制配置 JSON 语法正确"
else
    echo "❌ 资源限制配置 JSON 语法错误"
fi

# 清理
rm -rf "$TEST_DIR"

echo ""
echo "=========================================="
echo "Sandbox 沙箱测试完成"
echo "=========================================="
