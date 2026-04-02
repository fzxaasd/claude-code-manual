# 7.4 MCP 服务器

> 基于源码 `src/services/mcp/types.ts` 深度分析

## 核心概念

MCP (Model Context Protocol) 是一种标准化协议，允许 Claude Code 与外部工具和服务集成。

```
┌────────────────────────────────────────────────────────────┐
│                    MCP 架构                                  │
├────────────────────────────────────────────────────────────┤
│                                                            │
│  Claude Code                                               │
│       │                                                    │
│       ├── ListMcpResourcesTool                            │
│       ├── ReadMcpResourceTool                             │
│       └── mcp__server__tool                             │
│              │                                           │
│              ▼                                           │
│       MCP Client (@modelcontextprotocol/sdk)              │
│              │                                           │
│              ▼                                           │
│       MCP Server (stdio/sse/http/ws)                     │
│              │                                           │
│              ▼                                           │
│       External Services (GitHub, Database, etc.)          │
│                                                            │
└────────────────────────────────────────────────────────────┘
```

---

## Transport 类型

基于 `src/services/mcp/types.ts`：

```typescript
const TransportSchema = z.enum([
  'stdio',        // 标准输入/输出 (本地进程)
  'sse',          // Server-Sent Events
  'sse-ide',      // IDE 扩展专用 SSE
  'http',         // HTTP 请求
  'ws',           // WebSocket
  'ws-ide',       // IDE 扩展专用 WebSocket
  'sdk',          // SDK 内部传输 (IDE 集成)
  'claudeai-proxy' // Claude.ai Proxy 服务器
])
```

### 1. stdio 服务器

```typescript
// 最常用的本地进程模式
interface McpStdioServerConfig {
  type: 'stdio'
  command: string          // 必须，命令
  args: string[]          // 默认 []
  env?: Record<string, string>  // 环境变量
}

// 示例
{
  "mcpServers": {
    "github": {
      "type": "stdio",
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-github"]
    }
  }
}
```

### 2. HTTP 服务器

```typescript
interface McpHTTPServerConfig {
  type: 'http'
  url: string
  headers?: Record<string, string>
  headersHelper?: string       // 从环境变量获取 headers
  oauth?: McpOAuthConfig      // OAuth 配置
}

// OAuth 配置
interface McpOAuthConfig {
  clientId?: string
  callbackPort?: number
  authServerMetadataUrl?: string  // 必须 https://
  xaa?: boolean                   // Cross-App Access
}

// 示例
{
  "mcpServers": {
    "remote-api": {
      "type": "http",
      "url": "https://api.example.com/mcp",
      "headers": {
        "Authorization": "Bearer token"
      },
      "oauth": {
        "clientId": "xxx",
        "callbackPort": 8080,
        "authServerMetadataUrl": "https://auth.example.com/.well-known/openid-configuration"
      }
    }
  }
}
```

### 3. SSE 服务器

```typescript
interface McpSSEServerConfig {
  type: 'sse'
  url: string
  headers?: Record<string, string>
  headersHelper?: string
  oauth?: McpOAuthConfig
}

// 示例
{
  "mcpServers": {
    "sse-server": {
      "type": "sse",
      "url": "https://api.example.com/events",
      "headers": {
        "Authorization": "Bearer xxx"
      }
    }
  }
}
```

### 4. WebSocket 服务器

```typescript
interface McpWebSocketServerConfig {
  type: 'ws'
  url: string
  headers?: Record<string, string>
  headersHelper?: string
}

// 示例
{
  "mcpServers": {
    "ws-server": {
      "type": "ws",
      "url": "wss://api.example.com/mcp"
    }
  }
}
```

### 5. SDK 服务器 (IDE 集成)

```typescript
interface McpSdkServerConfig {
  type: 'sdk'
  name: string  // SDK 服务器名称
}

// 用于 IDE 扩展（如 VS Code, JetBrains）与 Claude Code 的内部通信
// 不通过标准网络传输，在同一进程内直接调用
```

### 6. Claude.ai 代理

```typescript
interface McpClaudeAIProxyServerConfig {
  type: 'claudeai-proxy'
  url: string
  id: string
}
```

---

## McpSdkServerConfig 用途

`McpSdkServerConfig` 用于 IDE 扩展集成场景：
- VS Code Claude 扩展
- JetBrains Claude 插件

**特点**：
- 不启动独立进程
- 通过 SDK 内部传输直接通信
- 适用于 `sse-ide` 和 `sdk` 类型的组合

```typescript
// IDE 扩展配置示例
{
  "mcpServers": {
    "ide-integration": {
      "type": "sdk",
      "name": "claude-ide"
    }
  }
}
```

### McpOAuthConfig XAA 配置

`xaa` (Cross-App Access) 字段用于 SEP-990 跨应用访问：

```typescript
interface McpOAuthConfig {
  clientId?: string
  callbackPort?: number
  authServerMetadataUrl?: string  // 必须 https://
  xaa?: boolean                   // Cross-App Access (SEP-990)
}

// XAA 配置说明：
// - xaaIdp 连接详情 (issuer, clientId, callbackPort) 来自 settings.xaaIdp
// - 配置一次，所有启用 XAA 的服务器共享
// - clientId/clientSecret (parent oauth config + keychain slot) 用于 MCP server 的 AS
```

---

## ConfigScope 类型

```typescript
const ConfigScopeSchema = z.enum([
  'local',      // 本地配置
  'user',       // 用户级配置
  'project',    // 项目级配置
  'dynamic',    // 动态配置
  'enterprise', // 企业配置
  'claudeai',  // Claude.ai 配置
  'managed',    // 托管配置
])

type ConfigScope = 'local' | 'user' | 'project' | 'dynamic' | 'enterprise' | 'claudeai' | 'managed'
```

---

## 服务器连接状态

### MCPServerConnection

```typescript
type MCPServerConnection =
  | ConnectedMCPServer
  | FailedMCPServer
  | NeedsAuthMCPServer
  | PendingMCPServer
  | DisabledMCPServer

// 已连接
interface ConnectedMCPServer {
  client: Client
  name: string
  type: 'connected'
  capabilities: ServerCapabilities
  serverInfo?: {
    name: string
    version: string
  }
  instructions?: string
  config: ScopedMcpServerConfig
  cleanup: () => Promise<void>
}

// 连接失败
interface FailedMCPServer {
  name: string
  type: 'failed'
  config: ScopedMcpServerConfig
  error?: string
}

// 需要认证
interface NeedsAuthMCPServer {
  name: string
  type: 'needs-auth'
  config: ScopedMcpServerConfig
}

// 连接中/重连中
interface PendingMCPServer {
  name: string
  type: 'pending'
  config: ScopedMcpServerConfig
  reconnectAttempt?: number
  maxReconnectAttempts?: number
}

// 已禁用
interface DisabledMCPServer {
  name: string
  type: 'disabled'
  config: ScopedMcpServerConfig
}
```

---

## ScopedMcpServerConfig

```typescript
interface ScopedMcpServerConfig extends McpServerConfig {
  scope: ConfigScope
  pluginSource?: string  // 插件提供的服务器来源
}

// McpServerConfig = union of all transport configs
type McpServerConfig =
  | McpStdioServerConfig
  | McpSSEServerConfig
  | McpHTTPServerConfig
  | McpWebSocketServerConfig
  | McpSSEIDEServerConfig
  | McpWebSocketIDEServerConfig
  | McpSdkServerConfig
  | McpClaudeAIProxyServerConfig
```

---

## MCP CLI State

```typescript
interface SerializedTool {
  name: string
  description: string
  inputJSONSchema?: {
    type: 'object'
    properties?: Record<string, unknown>
  }
  isMcp?: boolean
  originalToolName?: string  // 原始未规范化的工具名
}

interface SerializedClient {
  name: string
  type: 'connected' | 'failed' | 'needs-auth' | 'pending' | 'disabled'
  capabilities?: ServerCapabilities
}

interface MCPCliState {
  clients: SerializedClient[]
  configs: Record<string, ScopedMcpServerConfig>
  tools: SerializedTool[]
  resources: Record<string, ServerResource[]>
  normalizedNames?: Record<string, string>  // 规范化名称映射
}
```

---

## 配置示例

### 1. GitHub 服务器

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

### 2. 文件系统服务器

```json
{
  "mcpServers": {
    "filesystem": {
      "type": "stdio",
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-filesystem", "/home/user/projects"],
      "env": {}
    }
  }
}
```

### 3. PostgreSQL 服务器

```json
{
  "mcpServers": {
    "database": {
      "type": "stdio",
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-postgres"],
      "env": {
        "DATABASE_URL": "postgresql://localhost/mydb"
      }
    }
  }
}
```

### 4. 远程 HTTP 服务器

```json
{
  "mcpServers": {
    "remote-api": {
      "type": "http",
      "url": "https://api.example.com/mcp",
      "headers": {
        "Authorization": "Bearer ${API_TOKEN}"
      },
      "oauth": {
        "clientId": "my-client-id",
        "callbackPort": 8080,
        "authServerMetadataUrl": "https://auth.example.com/.well-known/openid-configuration"
      }
    }
  }
}
```

### 5. WebSocket 服务器

```json
{
  "mcpServers": {
    "ws-api": {
      "type": "ws",
      "url": "wss://api.example.com/mcp",
      "headers": {
        "X-API-Key": "${API_KEY}"
      }
    }
  }
}
```

---

## 安全配置

### 允许/禁止列表

```json
{
  "allowedMcpServers": [
    { "serverName": "github" },
    { "serverName": "filesystem" },
    { "serverCommand": ["npx", "@approved/server"] }
  ],
  "deniedMcpServers": [
    { "serverName": "untrusted-plugin" }
  ]
}
```

### 企业策略

```json
{
  "allowManagedMcpServersOnly": true,
  "allowedMcpServers": [
    { "serverName": "internal-tool-1" },
    { "serverName": "internal-tool-2" }
  ]
}
```

---

## MCP 工具调用

### 工具命名格式

```
mcp__serverName__toolName
```

### 调用示例

```json
{
  "tool": "mcp__github__list_issues",
  "input": {
    "owner": "anthropic",
    "repo": "claude-code",
    "per_page": 10
  }
}
```

### 内置 MCP 工具

| 工具 | 说明 |
|------|------|
| ListMcpResources | 列出 MCP 资源 |
| ReadMcpResource | 读取 MCP 资源 |

---

## MCP 资源类型

```typescript
type ServerResource = Resource & {
  server: string  // 服务器名称
}

// Resource 来自 @modelcontextprotocol/sdk/types
```

---

## CLI 命令

```bash
# 打开 MCP 设置界面
/mcp

# 启用/禁用 MCP 服务器
/mcp enable [server-name]     # 启用指定服务器或所有服务器
/mcp disable [server-name]   # 禁用指定服务器或所有服务器

# 重新连接服务器
/mcp reconnect <server-name>
```

**注意**：`claude mcp test` 和 `claude mcp get` 命令不存在。MCP 管理通过交互式界面 (`/mcp`) 进行。

---

## MCPB 文件格式

MCPB (MCP Bundle) 用于打包 MCP 服务器配置：

```typescript
// 支持的路径类型
type McpbPath = RelativePath.endsWith('.mcpb' | '.dxt')
              | URL.endsWith('.mcpb' | '.dxt')

// 示例
{
  "mcpServers": {
    "server": "./config.mcpb"
  }
}
```

---

## 常见问题

### 服务器启动失败

```bash
# 检查配置是否正确
/mcp list

# 检查环境变量
echo $VAR_NAME
```

### 连接超时

```json
{
  "mcpServers": {
    "slow-server": {
      "type": "http",
      "url": "https://api.example.com/mcp",
      "timeout": 30000
    }
  }
}
```

### OAuth 配置错误

```json
{
  "oauth": {
    "clientId": "xxx",
    "callbackPort": 8080,
    "authServerMetadataUrl": "https://auth.example.com/.well-known/openid-configuration"
  }
}
```

---

## 最佳实践

### 1. 使用环境变量

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

### 2. 最小权限

```bash
# 只授权需要的目录
claude mcp add filesystem -- npx @server/filesystem /project/src

# 避免
# ❌ npx @server/filesystem /home/user
# ✅ npx @server/filesystem /home/user/projects
```

### 3. 使用 headersHelper

```json
{
  "mcpServers": {
    "api": {
      "type": "http",
      "url": "https://api.example.com/mcp",
      "headersHelper": "API_HEADERS"
    }
  }
}
```

---

## 测试验证

```bash
# 检查 MCP 配置
cat ~/.claude/mcp.json

# 列出可用服务器（通过 UI）
/mcp

# 查看 MCP 状态
claude --debug mcp
```
