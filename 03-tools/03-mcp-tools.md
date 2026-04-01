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

MCP 工具权限通过 Claude Code 的 `permissions` 配置控制，不在 server config 中设置。

**McpStdioServerConfig 实际支持的字段**：
```json
{
  "command": "npx",
  "args": ["@modelcontextprotocol/server-github"],
  "env": { "GITHUB_TOKEN": "${GITHUB_TOKEN}" }
}
```

**注意**: `allowedTools`/`deniedTools`/`allowedPaths`/`deniedPaths` 等字段 **不存在**于 MCP server config schema 中。这些是各 MCP server 自身实现的限制，不是 Claude Code 层面的配置。

### 工具限制

MCP server 的路径限制由各个 server 自己实现（如 filesystem server），不是 Claude Code 配置的一部分。

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

# 重连 server
claude mcp reconnect <server-name>

# 注意: claude mcp status 和 claude mcp debug 命令不存在
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
