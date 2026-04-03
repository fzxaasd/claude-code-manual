# 3.3 MCP 工具集成

> Model Context Protocol 工具集成指南

---

## MCP 概述

MCP (Model Context Protocol) 是一种标准化协议，用于将外部工具和数据源集成到 Claude Code 中。

```
Claude Code ←→ MCP Server ←→ External Service
                ↓
         文件系统、API、数据库等
```

---

## MCP 服务器配置

### 基本配置

在 `settings.json` 中配置 MCP 服务器：

```json
{
  "mcpServers": {
    "github": {
      "command": "npx",
      "args": ["@modelcontextprotocol/server-github"],
      "env": {
        "GITHUB_TOKEN": "ghp_xxxxx"
      }
    }
  }
}
```

**注意**: MCP 服务器配置支持 **6 种传输类型**，不仅仅是 stdio。

---

### 传输类型 (Transport Types)

源码: `src/services/mcp/types.ts`

```typescript
export const TransportSchema = z.enum(['stdio', 'sse', 'sse-ide', 'http', 'ws', 'sdk'])
```

#### 1. stdio (本地进程)

本地进程通信，通过 stdin/stdout：

```json
{
  "mcpServers": {
    "github": {
      "type": "stdio",
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-github"],
      "env": {
        "GITHUB_TOKEN": "${GITHUB_TOKEN}"
      }
    }
  }
}
```

**字段**:
- `command` (必填): 可执行命令
- `args` (可选): 命令参数数组
- `env` (可选): 环境变量
- `type` (可选): 默认 `stdio`，可省略

#### 2. sse (Server-Sent Events)

通过 HTTP SSE 连接到远程 MCP 服务器：

```json
{
  "mcpServers": {
    "remote-server": {
      "type": "sse",
      "url": "https://mcp.example.com/sse",
      "headers": {
        "Authorization": "Bearer ${MCP_TOKEN}"
      },
      "oauth": {
        "clientId": "your-client-id",
        "clientSecret": "${MCP_CLIENT_SECRET}",
        "authServerMetadataUrl": "https://auth.example.com/.well-known/openid-configuration",
        "callbackPort": 3000
      }
    }
  }
}
```

**字段**:
- `url` (必填): SSE 端点 URL
- `headers` (可选): HTTP 请求头
- `headersHelper` (可选): 辅助请求头文件路径
- `oauth` (可选): OAuth 2.0 配置
  - `clientId`: OAuth 客户端 ID
  - `clientSecret`: OAuth 客户端密钥
  - `authServerMetadataUrl`: OIDC 发现 URL
  - `callbackPort`: 回调端口
  - `xaa` (可选): 启用 XAA (SEP-990) 跨应用访问

#### 3. sse-ide (IDE 专用)

IDE extension 专用 SSE 连接：

```json
{
  "mcpServers": {
    "ide-connection": {
      "type": "sse-ide",
      "url": "http://localhost:3100/sse",
      "ideName": "Cursor",
      "ideRunningInWindows": false
    }
  }
}
```

**字段**:
- `url` (必填): IDE SSE 端点
- `ideName` (必填): IDE 名称
- `ideRunningInWindows` (可选): Windows 标识

#### 4. http (HTTP POST)

通过 HTTP POST 轮询连接：

```json
{
  "mcpServers": {
    "http-server": {
      "type": "http",
      "url": "https://mcp.example.com/mcp",
      "headers": {
        "X-API-Key": "${MCP_API_KEY}"
      }
    }
  }
}
```

#### 5. ws (WebSocket)

通过 WebSocket 连接：

```json
{
  "mcpServers": {
    "ws-server": {
      "type": "ws",
      "url": "wss://mcp.example.com/ws",
      "headers": {
        "Authorization": "Bearer ${WS_TOKEN}"
      }
    }
  }
}
```

#### 6. sdk (SDK 模式)

使用 Claude Code SDK 实现的 MCP 服务器：

```json
{
  "mcpServers": {
    "my-sdk-server": {
      "type": "sdk",
      "name": "my-sdk-server"
    }
  }
}
```

### MCP CLI 命令

```bash
# 添加服务器 (stdio)
claude mcp add <name> <command> [args...]

# 添加服务器 (HTTP/WebSocket)
claude mcp add <name> <url>

# 添加服务器 (带环境变量和请求头)
claude mcp add <name> <command> --env KEY=value --header "Authorization: Bearer xxx"

# 添加服务器 (OAuth/XAA)
claude mcp add <name> <url> --xaa --client-id <id> --client-secret <secret>

# JSON 方式添加
claude mcp add-json

# 从 Claude Desktop 导入
claude mcp add-from-claude-desktop

# 列出服务器
claude mcp list

# 获取服务器详情
claude mcp get <name>

# 删除服务器
claude mcp remove <name> [--scope <scope>]

# 启动 MCP 服务器模式
claude mcp serve [--debug] [--verbose]

# 重置项目选择
claude mcp reset-project-choices
```

**mcp add 选项**:

| 选项 | 类型 | 说明 |
|------|------|------|
| `--scope/-s` | string | 作用域 (user/project/local) |
| `--transport/-t` | string | 传输类型 (stdio/sse/http/ws) |
| `--env/-e` | string | 环境变量 (KEY=value 格式) |
| `--header/-H` | string | HTTP 请求头 |
| `--client-id` | string | OAuth 客户端 ID |
| `--client-secret` | string | OAuth 客户端密钥 |
| `--callback-port` | number | OAuth 回调端口 |
| `--xaa` | boolean | 启用 XAA (SEP-990) 认证 |

**注意**:
- `--client-id`, `--client-secret`, `--callback-port`, `--xaa` 仅对 HTTP/SSE 传输有效，对 stdio 会忽略
- `--xaa` 需要先运行 `claude mcp xaa setup` 配置 XAA (SEP-990) 认证
- XAA 由 `CLAUDE_CODE_ENABLE_XAA=1` 环境变量启用，非企业独占

### 项目级配置 (.mcp.json)

MCP 服务器也可以通过项目根目录的 `.mcp.json` 文件配置：

```json
{
  "mcpServers": {
    "local-tool": {
      "type": "stdio",
      "command": "node",
      "args": ["./mcp-server.js"]
    }
  }
}
```

**作用域优先级**: `--scope local` (项目) > `--scope project` > `--scope user`

---

### 本地服务器

```json
{
  "mcpServers": {
    "local-python": {
      "command": "python",
      "args": ["/path/to/mcp_server.py"]
    }
  }
}
```

---

## 常用 MCP 服务器

### GitHub

```bash
# 安装
npm install @modelcontextprotocol/server-github

# 配置
npx @modelcontextprotocol/server-github
```

**功能**:
- 查看仓库
- 管理 Issues
- 创建 PR
- 查看代码

### 文件系统

```bash
# 安装
npm install @modelcontextprotocol/server-filesystem

# 配置
{
  "mcpServers": {
    "filesystem": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-filesystem", "/path/to/allowed/directory"]
    }
  }
}
```

**功能**:
- 安全的文件读取
- 目录浏览
- 文件搜索

### Slack

```bash
# 安装
npm install @modelcontextprotocol/server-slack

# 配置
{
  "mcpServers": {
    "slack": {
      "command": "npx",
      "args": ["@modelcontextprotocol/server-slack"],
      "env": {
        "SLACK_BOT_TOKEN": "xoxb-xxxxx",
        "SLACK_TEAM_ID": "Txxxxx"
      }
    }
  }
}
```

### PostgreSQL

```bash
# 安装
npm install @modelcontextprotocol/server-postgres

# 配置
{
  "mcpServers": {
    "postgres": {
      "command": "npx",
      "args": ["@modelcontextprotocol/server-postgres"],
      "env": {
        "DATABASE_URL": "postgresql://user:pass@localhost:5432/db"
      }
    }
  }
}
```

---

## MCP 工具使用

### 查看可用工具

```bash
claude mcp list
```

输出示例:
```
MCP Servers:
├── github
│   ├── list_repositories
│   ├── get_file_contents
│   ├── create_or_update_file
│   └── search_code
└── filesystem
    ├── read_file
    ├── list_directory
    └── glob
```

### 调用 MCP 工具

```
> 使用 GitHub MCP 列出我的仓库

> 使用文件系统 MCP 读取 config.yaml
```

---

## MCP 工具类型

### 资源型 (Resources)

提供数据访问：

```json
{
  "resources": {
    "github://repos": "仓库列表",
    "github://user": "当前用户信息"
  }
}
```

### 工具型 (Tools)

可执行的操作：

```json
{
  "tools": {
    "github_create_issue": {
      "description": "创建 GitHub Issue",
      "inputSchema": {
        "type": "object",
        "properties": {
          "title": {"type": "string"},
          "body": {"type": "string"}
        }
      }
    }
  }
}
```

### 提示型 (Prompts)

预定义提示模板：

```json
{
  "prompts": {
    "review-pr": {
      "description": "审查 Pull Request",
      "arguments": [
        {"name": "pr_number", "required": true}
      ]
    }
  }
}
```

---

## 自定义 MCP 服务器

### Python 实现

```python
from mcp.server.fastmcp import FastMCP

mcp = FastMCP("my-server")

@mcp.tool()
def calculate(expression: str) -> str:
    """执行数学计算"""
    return str(eval(expression))

@mcp.resource("config://app")
def get_config() -> str:
    """返回应用配置"""
    return '{"version": "1.0"}'

if __name__ == "__main__":
    mcp.run()
```

### 启动服务器

```bash
python my_mcp_server.py
```

### 配置使用

```json
{
  "mcpServers": {
    "my-server": {
      "command": "python",
      "args": ["/path/to/my_mcp_server.py"]
    }
  }
}
```

---

## MCP 工具权限

### 基础权限控制

MCP 工具通过 `permissions.allow`/`permissions.deny` 配置控制：

```json
{
  "permissions": {
    "allow": ["mcp__github__*"],
    "deny": ["mcp__*__admin_*"]
  }
}
```

### 企业白名单/黑名单

源码: `src/settings/types.ts`

```json
{
  // 允许的 MCP 服务器列表
  "allowedMcpServers": [
    { "serverName": "github" },
    { "serverName": "filesystem" }
  ],

  // 拒绝的 MCP 服务器列表 (优先于 allowlist)
  "deniedMcpServers": [
    { "serverName": "dangerous-server" },
    { "serverCommand": ["python", "/path/to/script.py"] },
    { "serverUrl": "https://*.blocked-domain.com/*" }
  ]
}
```

**匹配方式**:
- `serverName`: 按服务器名称
- `serverCommand`: 按命令数组 (stdio 服务器精确匹配)
- `serverUrl`: 按 URL 模式 (支持通配符如 `https://*.example.com/*`)

**注意**: Denylist 优先于 allowlist。

### 企业策略控制

```json
{
  // 仅允许托管 MCP 服务器
  "allowManagedMcpServersOnly": true,

  // 项目级服务器管理
  "enabledMcpjsonServers": ["server-a", "server-b"],
  "disabledMcpjsonServers": ["server-c"],
  "enableAllProjectMcpServers": false
}
```

### 工具限制

MCP server 的路径限制由各个 server 自己实现（如 filesystem server），不是 Claude Code 配置的一部分。

**McpStdioServerConfig 实际支持的字段**：
```json
{
  "command": "npx",
  "args": ["@modelcontextprotocol/server-github"],
  "env": { "GITHUB_TOKEN": "${GITHUB_TOKEN}" }
}
```

**注意**: `allowedTools`/`deniedTools`/`allowedPaths`/`deniedPaths` 等字段 **不存在**于 MCP server config schema 中。这些是各 MCP server 自身实现的限制，不是 Claude Code 层面的配置。

---

## MCP 与原生工具对比

| 特性 | MCP 工具 | 原生工具 |
|------|----------|----------|
| 来源 | 外部服务 | Claude Code 内置 |
| 安装 | 需要配置 | 开箱即用 |
| 功能 | 依赖服务器 | 固定集合 |
| 权限 | 可单独配置 | 全局配置 |
| 延迟 | 网络延迟 | 无延迟 |

---

## 故障排除

### MCP 服务器不响应

```bash
# 列出所有 MCP server 状态
claude mcp list

# 获取特定 server 详情
claude mcp get <server-name>

# 删除并重新添加服务器
claude mcp remove <server-name>
claude mcp add <server-name> <command>

# 重新连接特定服务器
claude mcp reconnect <server-name>
```

### 工具不可用

```json
// 确保工具名称正确
{
  "mcpServers": {
    "github": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-github"],
      "env": {
        "GITHUB_TOKEN": "xxx"
      }
    }
  }
}
```

### 连接超时

```bash
# 增加超时时间
export MCP_SERVER_TIMEOUT=60000
```

---

## 最佳实践

### 1. 安全配置

```json
{
  "mcpServers": {
    "production-api": {
      "command": "npx",
      "args": ["mcp-server"],
      "env": {
        // 使用环境变量而非硬编码
        "API_KEY": "${PROD_API_KEY}"
      }
    }
  }
}
```

### 2. 权限隔离

MCP server 的工具限制由 server 自身实现。Claude Code 通过 `permissions.allow`/`permissions.deny` 控制用户可调用的工具。

### 3. 性能优化

MCP server 的缓存行为由各 server 自己实现。Claude Code 不提供 `cacheEnabled`/`cacheTTL` 配置。

---

## 常用 MCP 服务器列表

| 服务器 | 功能 | 安装命令 |
|--------|------|----------|
| github | GitHub API | `npx -y @modelcontextprotocol/server-github` |
| filesystem | 文件操作 | `npx -y @modelcontextprotocol/server-filesystem` |
| slack | Slack 集成 | `npx -y @modelcontextprotocol/server-slack` |
| postgres | PostgreSQL | `npx -y @modelcontextprotocol/server-postgres` |
| sqlite | SQLite | `npx -y @modelcontextprotocol/server-sqlite` |
| s3 | AWS S3 | `npx -y @modelcontextprotocol/server-s3` |
| google-maps | Google Maps | `npx -y @modelcontextprotocol/server-google-maps` |

---

## 进阶使用

### MCP 组合

```
> 使用 GitHub MCP 查看代码，然后使用文件系统 MCP 保存修改
```

### MCP 上下文

MCP server 的上下文包含功能由各 server 自己实现。Claude Code 不提供 `includeContext` 配置。
