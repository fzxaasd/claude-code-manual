# 7.4 MCP Servers

> Deep analysis based on source code `src/services/mcp/types.ts`

## Core Concepts

MCP (Model Context Protocol) is a standardized protocol that allows Claude Code to integrate with external tools and services.

```
┌────────────────────────────────────────────────────────────┐
│                    MCP Architecture                          │
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

## Transport Types

Based on `src/services/mcp/types.ts`:

```typescript
const TransportSchema = z.enum([
  'stdio',     // Standard input/output (local process)
  'sse',      // Server-Sent Events
  'sse-ide',  // IDE extension-specific SSE
  'http',     // HTTP requests
  'ws',       // WebSocket
  'sdk',      // SDK internal transport (IDE integration)
])
```

**Note**: `ws-ide` Transport no longer exists in `TransportSchema`. IDE extensions should use `sdk` type.

### 1. stdio Server

```typescript
// Most commonly used local process mode
interface McpStdioServerConfig {
  type: 'stdio'
  command: string          // Required, command
  args: string[]          // Default []
  env?: Record<string, string>  // Environment variables
}

// Example
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

### 2. HTTP Server

```typescript
interface McpHTTPServerConfig {
  type: 'http'
  url: string
  headers?: Record<string, string>
  headersHelper?: string       // Get headers from env variable
  oauth?: McpOAuthConfig      // OAuth configuration
}

// OAuth configuration
interface McpOAuthConfig {
  clientId?: string
  callbackPort?: number
  authServerMetadataUrl?: string  // Must be https://
  xaa?: boolean                   // Cross-App Access
}

// Example
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

### 3. SSE Server

```typescript
interface McpSSEServerConfig {
  type: 'sse'
  url: string
  headers?: Record<string, string>
  headersHelper?: string
  oauth?: McpOAuthConfig
}

// Example
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

### 4. WebSocket Server

```typescript
interface McpWebSocketServerConfig {
  type: 'ws'
  url: string
  headers?: Record<string, string>
  headersHelper?: string
}

// Example
{
  "mcpServers": {
    "ws-server": {
      "type": "ws",
      "url": "wss://api.example.com/mcp"
    }
  }
}
```

### 5. SDK Server (IDE Integration)

```typescript
interface McpSdkServerConfig {
  type: 'sdk'
  name: string  // SDK server name
}

// Used for IDE extensions (VS Code, JetBrains) to communicate with Claude Code internally
// Does not use standard network transport, directly calls within the same process
```

### 6. Claude.ai Proxy

```typescript
interface McpClaudeAIProxyServerConfig {
  type: 'claudeai-proxy'
  url: string
  id: string
}
```

---

## McpSdkServerConfig Usage

`McpSdkServerConfig` is used for IDE extension integration scenarios:
- VS Code Claude extension
- JetBrains Claude plugin

**Characteristics**:
- Does not start a separate process
- Communicates directly via SDK internal transport
- Suitable for combination of `sse-ide` and `sdk` transport types

```typescript
// IDE extension configuration example
{
  "mcpServers": {
    "ide-integration": {
      "type": "sdk",
      "name": "claude-ide"
    }
  }
}
```

### McpOAuthConfig XAA Configuration

The `xaa` (Cross-App Access) field is used for SEP-990 cross-app access:

```typescript
interface McpOAuthConfig {
  clientId?: string
  callbackPort?: number
  authServerMetadataUrl?: string  // Must be https://
  xaa?: boolean                   // Cross-App Access (SEP-990)
}

// XAA configuration notes:
// - xaaIdp connection details (issuer, clientId, callbackPort) come from settings.xaaIdp
// - Configure once, shared by all XAA-enabled servers
// - clientId/clientSecret (parent oauth config + keychain slot) used for AS of MCP server
```

---

## ConfigScope Type

```typescript
const ConfigScopeSchema = z.enum([
  'local',      // Local configuration
  'user',       // User-level configuration
  'project',    // Project-level configuration
  'dynamic',    // Dynamic configuration
  'enterprise', // Enterprise configuration
  'claudeai',  // Claude.ai configuration
  'managed',    // Managed configuration
])

type ConfigScope = 'local' | 'user' | 'project' | 'dynamic' | 'enterprise' | 'claudeai' | 'managed'
```

---

## Server Connection States

### MCPServerConnection

```typescript
type MCPServerConnection =
  | ConnectedMCPServer
  | FailedMCPServer
  | NeedsAuthMCPServer
  | PendingMCPServer
  | DisabledMCPServer

// Connected
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

// Connection failed
interface FailedMCPServer {
  name: string
  type: 'failed'
  config: ScopedMcpServerConfig
  error?: string
}

// Needs authentication
interface NeedsAuthMCPServer {
  name: string
  type: 'needs-auth'
  config: ScopedMcpServerConfig
}

// Connecting/reconnecting
interface PendingMCPServer {
  name: string
  type: 'pending'
  config: ScopedMcpServerConfig
  reconnectAttempt?: number
  maxReconnectAttempts?: number
}

// Disabled
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
  pluginSource?: string  // Plugin-provided server source
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
  originalToolName?: string  // Original non-normalized tool name
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
  normalizedNames?: Record<string, string>  // Normalized name mapping
}
```

---

## Configuration Examples

### 1. GitHub Server

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

### 2. Filesystem Server

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

### 3. PostgreSQL Server

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

### 4. Remote HTTP Server

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

### 5. WebSocket Server

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

## Security Configuration

### Allow/Deny Lists

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

### Enterprise Policy

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

## MCP Tool Invocation

### Tool Naming Format

```
mcp__serverName__toolName
```

### Invocation Example

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

### Built-in MCP Tools

| Tool | Description |
|------|-------------|
| ListMcpResources | List MCP resources |
| ReadMcpResource | Read MCP resource |

---

## MCP Resource Types

```typescript
type ServerResource = Resource & {
  server: string  // Server name
}

// Resource comes from @modelcontextprotocol/sdk/types
```

---

## CLI Commands

```bash
# Open MCP settings interface
/mcp

# Enable/disable MCP server
/mcp enable [server-name]     # Enable specified server or all servers
/mcp disable [server-name]   # Disable specified server or all servers

# Reconnect server
/mcp reconnect <server-name>
```

**Note**: `claude mcp test` and `claude mcp get` commands do not exist. MCP management is done via the interactive interface (`/mcp`).

---

## MCPB File Format

MCPB (MCP Bundle) is used to package MCP server configurations:

```typescript
// Supported path types
type McpbPath = RelativePath.endsWith('.mcpb' | '.dxt')
              | URL.endsWith('.mcpb' | '.dxt')

// Example
{
  "mcpServers": {
    "server": "./config.mcpb"
  }
}
```

---

## Common Issues

### Server Startup Failure

```bash
# Check if configuration is correct
/mcp list

# Check environment variables
echo $VAR_NAME
```

### Connection Timeout

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

### OAuth Configuration Error

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

## Best Practices

### 1. Use Environment Variables

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

### 2. Least Privilege

```bash
# Only authorize needed directories
claude mcp add filesystem -- npx @server/filesystem /project/src

# Avoid
# ❌ npx @server/filesystem /home/user
# ✅ npx @server/filesystem /home/user/projects
```

### 3. Use headersHelper

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

## Testing Verification

```bash
# Check MCP configuration
cat ~/.claude/mcp.json

# List available servers (via UI)
/mcp

# View MCP status
claude --debug mcp
```
