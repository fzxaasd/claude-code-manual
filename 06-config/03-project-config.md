# 6.3 项目级配置

> 在团队项目中配置 Claude Code

---

## 项目配置结构

### 目录结构

```
project/
├── .claude/
│   ├── settings.json        # 项目设置（必须提交到 Git）
│   └── settings.local.json   # 本地覆盖（不提交）
└── .claudeignore             # 忽略规则
```

### 创建项目配置

```bash
# 交互式创建
claude init

# 指定配置
claude init --project-name my-app
```

---

## settings.json 完整示例

```json
{
  "permissions": {
    "defaultMode": "ask",
    "allow": [
      "Read",
      "Write",
      "Edit",
      "Glob",
      "Grep",
      "Bash(npm *)",
      "Bash(git *)"
    ],
    "deny": [
      "Bash(rm -rf /)",
      "Bash(rm -rf node_modules)",
      "Bash(sudo *)",
      "Write(*.env)",
      "Write(*.pem)",
      "Write(*.key)"
    ]
  },
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "hooks/check_command.sh"
          }
        ]
      }
    ]
  }
}
```

> **注意**: Agent 配置不在 settings.json 中。Agent 应放在 `.claude/agents/` 目录（Markdown 文件），settings.json 不支持顶层 `agents` 字段。

---

## 权限配置

### 团队权限策略

```json
{
  "permissions": {
    "allow": [
      "Read",
      "Write(src/**)",
      "Edit",
      "Glob",
      "Grep",
      "Bash(npm run *)",
      "Bash(npm test)",
      "Bash(git *)"
    ],
    "deny": [
      "Bash(rm -rf *)",
      "Bash(sudo *)",
      "Write(*.pem)",
      "Write(*.key)",
      "Write(.env)",
      "Write(config/*.local.*)"
    ]
  }
}
```

### 常见限制

| 限制类型 | 配置 |
|----------|------|
| 禁止删除文件 | `deny: ["Bash(rm -rf *)"]` |
| 禁止系统命令 | `deny: ["Bash(sudo *)", "Bash(chmod *)"]` |
| 保护敏感文件 | `deny: ["Write(*.pem)", "Write(*.key)", "Write(.env)"]` |
| 仅允许 npm | `allow: ["Bash(npm *)"]` |
| 保护配置目录 | `deny: ["Write(/etc/**)"]` |

---

## Hooks 配置

### 项目级 Hooks

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "hooks/pre_command.sh"
          }
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "hooks/post_command.sh"
          }
        ]
      }
    ],
    "UserPromptSubmit": [
      {
        "matcher": "*",
        "hooks": [
          {
            "type": "command",
            "command": "hooks/validate_prompt.sh"
          }
        ]
      }
    ]
  }
}
```

### Hook 脚本示例

```bash
#!/bin/bash
# hooks/pre_command.sh
# 用途: 验证命令安全性

COMMAND=$(echo "$1" | jq -r '.command')

# 检查危险命令
if echo "$COMMAND" | grep -qE "rm -rf|sudo|chmod 777"; then
  echo '{"exit": 2, "error": "危险命令被阻止"}'
  exit 2
fi

exit 0
```

---

## Sandbox 配置

> 沙箱配置用于控制 Claude Code 命令执行的安全隔离级别

### 基础结构

```json
{
  "sandbox": {
    "enabled": true,
    "failIfUnavailable": false,
    "autoAllowBashIfSandboxed": false,
    "allowUnsandboxedCommands": true,
    "network": { ... },
    "filesystem": { ... },
    "ignoreViolations": {},
    "enableWeakerNestedSandbox": false,
    "enableWeakerNetworkIsolation": false,
    "excludedCommands": [],
    "ripgrep": { "command": "rg" }
  }
}
```

### 网络沙箱配置

```json
{
  "sandbox": {
    "network": {
      "allowedDomains": ["github.com", "api.example.com"],
      "allowManagedDomainsOnly": false,
      "allowUnixSockets": ["/var/run/docker.sock"],
      "allowAllUnixSockets": false,
      "allowLocalBinding": false,
      "httpProxyPort": 8080,
      "socksProxyPort": 1080
    }
  }
}
```

| 字段 | 类型 | 默认 | 说明 |
|------|------|------|------|
| `allowedDomains` | string[] | - | 允许访问的域名列表 |
| `allowManagedDomainsOnly` | boolean | false | 仅使用托管设置中的域名（企业配置） |
| `allowUnixSockets` | string[] | - | macOS 专用：允许的 Unix 套接字路径 |
| `allowAllUnixSockets` | boolean | false | 允许所有 Unix 套接字（禁用平台阻塞） |
| `allowLocalBinding` | boolean | false | 允许本地绑定连接 |
| `httpProxyPort` | number | - | HTTP 代理端口 |
| `socksProxyPort` | number | - | SOCKS 代理端口 |

### 文件系统沙箱配置

```json
{
  "sandbox": {
    "filesystem": {
      "allowWrite": ["/tmp/cache"],
      "denyWrite": ["/etc/**", "/root/**"],
      "denyRead": ["/private/**", "/.ssh/**"],
      "allowRead": ["/tmp/public/**"],
      "allowManagedReadPathsOnly": false
    }
  }
}
```

| 字段 | 类型 | 默认 | 说明 |
|------|------|------|------|
| `allowWrite` | string[] | - | 允许写入的额外路径（合并自 Edit 权限规则） |
| `denyWrite` | string[] | - | 禁止写入的路径（合并自 Edit deny 权限规则） |
| `denyRead` | string[] | - | 禁止读取的路径（合并自 Read deny 权限规则） |
| `allowRead` | string[] | - | 在 denyRead 区域中重新允许读取的路径 |
| `allowManagedReadPathsOnly` | boolean | false | 仅使用托管设置中的读取路径（企业配置） |

### 完整配置示例

```json
{
  "sandbox": {
    "enabled": true,
    "failIfUnavailable": true,
    "autoAllowBashIfSandboxed": true,
    "allowUnsandboxedCommands": false,
    "network": {
      "allowedDomains": ["github.com", "*.anthropic.com"],
      "allowManagedDomainsOnly": true,
      "allowUnixSockets": ["/var/run/docker.sock"],
      "allowLocalBinding": false
    },
    "filesystem": {
      "allowWrite": ["/tmp/project-cache"],
      "denyWrite": ["*.pem", "*.key", ".env"],
      "denyRead": ["/private/**", "/.ssh/**"]
    },
    "ignoreViolations": {
      "Bash": ["timeout"]
    },
    "enableWeakerNestedSandbox": false,
    "enableWeakerNetworkIsolation": false,
    "excludedCommands": ["dangerous-tool"],
    "ripgrep": {
      "command": "/usr/local/bin/rg",
      "args": ["--smart-case"]
    }
  }
}
```

### 配置说明

| 字段 | 类型 | 默认 | 说明 |
|------|------|------|------|
| `enabled` | boolean | - | 启用沙箱 |
| `failIfUnavailable` | boolean | false | 沙箱不可用时退出错误（用于强制沙箱部署） |
| `autoAllowBashIfSandboxed` | boolean | false | 沙箱启用时自动允许 Bash 命令 |
| `allowUnsandboxedCommands` | boolean | true | 允许通过 dangerouslyDisableSandbox 参数绕过沙箱 |
| `ignoreViolations` | Record<string, string[]> | - | 忽略特定工具/命令的沙箱违规 |
| `enableWeakerNestedSandbox` | boolean | false | 启用弱化嵌套沙箱 |
| `enableWeakerNetworkIsolation` | boolean | false | macOS 专用：允许访问 trustd（用于 MITM 代理证书验证，**降低安全性**） |
| `excludedCommands` | string[] | - | 从沙箱排除的命令 |
| `ripgrep.command` | string | - | 自定义 ripgrep 命令路径 |
| `ripgrep.args` | string[] | - | ripgrep 额外参数 |

> **平台说明**:
> - `allowUnixSockets` 仅在 macOS 上生效（Linux seccomp 无法按路径过滤）
> - `enableWeakerNetworkIsolation` 仅在 macOS 上生效
> - 企业部署建议设置 `failIfUnavailable: true` 以确保沙箱强制执行

---

## .claudeignore

### 语法

```
# 注释
pattern
!pattern    # 否定
*.log       # 通配符
```

### 示例

```
# Claude Code 忽略文件
.claude/
.claude/settings.local.json
*.local.*
node_modules/
dist/
build/
.git/
```

---

## 本地覆盖

### .claude/settings.local.json

此文件应添加到 `.gitignore`，用于本地特殊配置：

```json
{
  "permissions": {
    "defaultMode": "ask"
  }
}
```

> **路径说明**: `settings.local.json` 固定在 `.claude/settings.local.json`，不是项目根目录。

### 本地配置合并

| 字段 | 合并方式 |
|------|----------|
| 字符串 | 覆盖 |
| 数组 | 拼接去重 |
| 对象 | 深度合并 |

---

## Agent 配置

### 项目专用 Agent

Agent 配置放在 `.claude/agents/` 目录，使用 Markdown 文件格式：

```markdown
# .claude/agents/frontend-reviewer.md

## 描述
前端代码审查助手

## 工具限制
- Read
- Glob(src/**/*.tsx)
- Glob(src/**/*.ts)
- Grep
- Bash(npm *)
```

> **重要**: Agent 不在 settings.json 中配置。Agent 是独立的 Markdown 文件，放在 `~/.claude/agents/` 或 `.claude/agents/` 目录。

---

## MCP 服务器配置

### .mcp.json

MCP 服务器在项目根目录的 `.mcp.json` 文件中配置：

```json
{
  "mcpServers": {
    "github": {
      "command": "npx",
      "args": ["@modelcontextprotocol/server-github"]
    }
  }
}
```

> **注意**: `mcpServers` 不是 settings.json 的顶层字段。MCP 服务器配置在 `.mcp.json` 中，通过 `enabledMcpjsonServers` 和 `disabledMcpjsonServers` 在 settings.json 中控制。

---

## 多环境配置

### 环境变量覆盖

```bash
# 开发环境
export CLAUDE_PERMISSIONS_DEFAULT_MODE=ask

# 生产环境
export CLAUDE_PERMISSIONS_DEFAULT_MODE=dontAsk
```

### 条件配置

在 `settings.json` 中使用环境变量：

```json
{
  "permissions": {
    "defaultMode": "${CLAUDE_ENV:-ask}"
  }
}
```

---

## 版本控制最佳实践

### 必须提交

- `.claude/settings.json`
- `.claudeignore`

### 禁止提交

- `.claude/settings.local.json`
- 包含 API key 的配置
- 本地调试配置

### .gitignore 示例

```gitignore
# Claude Code
.claude/
!.claude/settings.json
.claude/settings.local.json
```

---

## 团队协作流程

### 1. 项目初始化

```bash
# 克隆仓库后初始化
git clone git@github.com:team/project.git
cd project
claude init
```

### 2. 配置同步

```bash
# 查看项目配置
claude config show --scope project

# 验证配置
claude settings validate
```

### 3. 本地覆盖

```bash
# 创建本地配置
mkdir -p .claude
cat > .claude/settings.local.json << 'EOF'
{
  "permissions": {
    "defaultMode": "ask"
  }
}
EOF
```

---

## 故障排除

### 配置不生效

```bash
# 检查配置文件路径
claude settings path

# 验证 JSON 格式
claude settings validate

# 查看生效的配置
claude config show
```

### 权限问题

```bash
# 测试权限
claude permissions test "Bash(rm -rf /)"

# 查看当前权限状态
claude permissions show
```

### Hook 不执行

```bash
# 验证 Hook 配置
claude hooks validate

# 调试 Hook
claude hooks debug --event PreToolUse
```

---

## 配置模板

### 基础项目模板

```json
{
  "permissions": {
    "defaultMode": "ask",
    "allow": ["Read", "Write(src/**)", "Edit", "Glob", "Grep"],
    "deny": [
      "Bash(rm -rf *)",
      "Write(*.env)",
      "Write(*.pem)"
    ]
  }
}
```

### 严格项目模板

```json
{
  "permissions": {
    "defaultMode": "dontAsk",
    "allow": [
      "Read",
      "Glob",
      "Grep",
      "Bash(npm run *)",
      "Bash(npm test)",
      "Bash(git status)",
      "Bash(git log)"
    ],
    "deny": [
      "Bash(rm *)",
      "Bash(sudo *)",
      "Write",
      "Edit"
    ]
  }
}
```
