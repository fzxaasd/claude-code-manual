#!/bin/bash
# Claude Code Sandbox 沙箱测试脚本
# 用途：验证沙箱配置和安全设置
# 注意：沙箱配置仅支持有限字段，详见 src/entrypoints/sandboxTypes.ts

set -e

echo "=========================================="
echo "Claude Code Sandbox 沙箱测试"
echo "=========================================="

TEST_DIR="/tmp/claude-sandbox-test"
rm -rf "$TEST_DIR"
mkdir -p "$TEST_DIR"

# 测试 1: Sandbox 基础配置
echo ""
echo "测试 1: Sandbox 基础配置验证"
echo "--------------------------------"

# 正确的沙箱配置结构 (基于 src/entrypoints/sandboxTypes.ts)
cat > "$TEST_DIR/sandbox-config.json" << 'EOF'
{
  "sandbox": {
    "enabled": true,
    "failIfUnavailable": true,
    "excludedCommands": ["rm -rf /", "dd if=/dev/zero"],
    "autoAllowBashIfSandboxed": false,
    "allowUnsandboxedCommands": false
  }
}
EOF

if python3 -c "import json; json.load(open('$TEST_DIR/sandbox-config.json'))" 2>/dev/null; then
    echo "✅ Sandbox 基础配置 JSON 语法正确"
else
    echo "❌ Sandbox 基础配置 JSON 语法错误"
fi

# 测试 2: 文件系统配置
echo ""
echo "测试 2: 文件系统配置验证"
echo "--------------------------------"

# filesystem 子配置: allowWrite / denyWrite
cat > "$TEST_DIR/filesystem-config.json" << 'EOF'
{
  "sandbox": {
    "enabled": true,
    "filesystem": {
      "allowWrite": ["/tmp/work", "/project/src"],
      "denyWrite": ["/etc", "/root", "/.dockerenv"]
    }
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

# network 子配置: allowedDomains / deniedDomains / allowUnixSockets / allowLocalBinding
cat > "$TEST_DIR/network-config.json" << 'EOF'
{
  "sandbox": {
    "enabled": true,
    "network": {
      "allowedDomains": ["api.github.com", "registry.npmjs.org"],
      "allowUnixSockets": ["/var/run/docker.sock"],
      "allowLocalBinding": true
    }
  }
}
EOF

if python3 -c "import json; json.load(open('$TEST_DIR/network-config.json'))" 2>/dev/null; then
    echo "✅ 网络配置 JSON 语法正确"
else
    echo "❌ 网络配置 JSON 语法错误"
fi

# 测试 4: 完整沙箱配置示例
echo ""
echo "测试 4: 完整沙箱配置验证"
echo "--------------------------------"

cat > "$TEST_DIR/full-sandbox-config.json" << 'EOF'
{
  "sandbox": {
    "enabled": true,
    "failIfUnavailable": true,
    "excludedCommands": ["sudo", "su"],
    "autoAllowBashIfSandboxed": false,
    "allowUnsandboxedCommands": false,
    "filesystem": {
      "allowWrite": ["/project/src", "/tmp/work"],
      "denyWrite": ["/etc", "/root", "/var"]
    },
    "network": {
      "allowedDomains": ["api.github.com"],
      "allowUnixSockets": ["/var/run/docker.sock"],
      "allowLocalBinding": false
    }
  }
}
EOF

if python3 -c "import json; json.load(open('$TEST_DIR/full-sandbox-config.json'))" 2>/dev/null; then
    echo "✅ 完整沙箱配置 JSON 语法正确"
else
    echo "❌ 完整沙箱配置 JSON 语法错误"
fi

# 测试 5: Bare Repo 安全保护
echo ""
echo "测试 5: Bare Repo 安全保护验证"
echo "--------------------------------"

# 测试 .git 目录保护配置
cat > "$TEST_DIR/bare-repo-config.json" << 'EOF'
{
  "sandbox": {
    "enabled": true,
    "filesystem": {
      "denyWrite": ["/etc", "/root", "/.dockerenv"]
    }
  }
}
EOF

if python3 -c "import json; json.load(open('$TEST_DIR/bare-repo-config.json'))" 2>/dev/null; then
    echo "✅ Bare Repo 安全配置 JSON 语法正确"
else
    echo "❌ Bare Repo 安全配置 JSON 语法错误"
fi

# 测试 6: 网络隔离配置
echo ""
echo "测试 6: 网络隔离配置验证"
echo "--------------------------------"

cat > "$TEST_DIR/network-isolation-config.json" << 'EOF'
{
  "sandbox": {
    "enabled": true,
    "network": {
      "allowManagedDomainsOnly": true,
      "allowAllUnixSockets": true,
      "allowedDomains": ["api.example.com"]
    }
  }
}
EOF

if python3 -c "import json; json.load(open('$TEST_DIR/network-isolation-config.json'))" 2>/dev/null; then
    echo "✅ 网络隔离配置 JSON 语法正确"
else
    echo "❌ 网络隔离配置 JSON 语法错误"
fi

# 测试 7: 沙箱与 MCP 集成
echo ""
echo "测试 7: 沙箱与 MCP 集成验证"
echo "--------------------------------"

cat > "$TEST_DIR/mcp-sandbox.json" << 'EOF'
{
  "mcpServers": {
    "custom-server": {
      "command": "node",
      "args": ["./server.js"]
    }
  }
}
EOF

if python3 -c "import json; json.load(open('$TEST_DIR/mcp-sandbox.json'))" 2>/dev/null; then
    echo "✅ MCP 配置 JSON 语法正确"
else
    echo "❌ MCP 配置 JSON 语法错误"
fi

# 测试 8: 沙箱 Hook 配置
echo ""
echo "测试 8: 沙箱 Hook 配置验证"
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
    ]
  }
}
EOF

if python3 -c "import json; json.load(open('$TEST_DIR/sandbox-hooks.json'))" 2>/dev/null; then
    echo "✅ 沙箱 Hook 配置 JSON 语法正确"
else
    echo "❌ 沙箱 Hook 配置 JSON 语法错误"
fi

# 测试 9: 沙箱权限验证函数
echo ""
echo "测试 9: 沙箱权限验证"
echo "--------------------------------"

validate_sandbox_config() {
    local config_file="$1"
    local errors=0

    # 检查 sandbox.enabled 字段类型
    if python3 -c "
import json
config = json.load(open('$config_file'))
sandbox = config.get('sandbox', {})
if 'enabled' in sandbox and not isinstance(sandbox['enabled'], bool):
    exit(1)
if 'failIfUnavailable' in sandbox and not isinstance(sandbox['failIfUnavailable'], bool):
    exit(1)
if 'excludedCommands' in sandbox and not isinstance(sandbox['excludedCommands'], list):
    exit(1)
" 2>/dev/null; then
        echo "✅ $config_file: 字段类型验证通过"
    else
        echo "❌ $config_file: 字段类型验证失败"
        ((errors++))
    fi
}

validate_sandbox_config "$TEST_DIR/sandbox-config.json"
validate_sandbox_config "$TEST_DIR/full-sandbox-config.json"

# 测试 10: sandboxed bash 命令行为
echo ""
echo "测试 10: sandboxed bash 配置验证"
echo "--------------------------------"

cat > "$TEST_DIR/sandboxed-bash.json" << 'EOF'
{
  "sandbox": {
    "enabled": true,
    "autoAllowBashIfSandboxed": false,
    "allowUnsandboxedCommands": false,
    "excludedCommands": ["sudo", "su", "chmod 777"]
  }
}
EOF

if python3 -c "import json; json.load(open('$TEST_DIR/sandboxed-bash.json'))" 2>/dev/null; then
    echo "✅ sandboxed bash 配置 JSON 语法正确"
else
    echo "❌ sandboxed bash 配置 JSON 语法错误"
fi

# 清理
rm -rf "$TEST_DIR"

echo ""
echo "=========================================="
echo "Sandbox 沙箱测试完成"
echo "=========================================="
echo ""
echo "注意: sandbox 配置支持以下字段 (src/entrypoints/sandboxTypes.ts):"
echo "  - enabled: boolean"
echo "  - failIfUnavailable: boolean"
echo "  - excludedCommands: string[]"
echo "  - autoAllowBashIfSandboxed: boolean"
echo "  - allowUnsandboxedCommands: boolean"
echo "  - filesystem.allowWrite: string[]"
echo "  - filesystem.denyWrite: string[]"
echo "  - network.allowedDomains: string[]"
echo "  - network.allowManagedDomainsOnly: boolean"
echo "  - network.allowUnixSockets: string[]"
echo "  - network.allowAllUnixSockets: boolean"
echo "  - network.allowLocalBinding: boolean"
echo "  - network.httpProxyPort: number"
echo "  - network.socksProxyPort: number"
