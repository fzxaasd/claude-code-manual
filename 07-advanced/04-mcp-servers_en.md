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
  'stdio',           // Standard input/output (local process)
  'sse',             // Server-Sent Events
  'sse-ide',         // IDE extension-specific SSE
  'http',            // HTTP requests
  'ws',              // WebSocket
  'sdk'              // SDK internal transport (IDE integration)
])

// Note: 'ws-ide' and 'claudeai-proxy' are NOT part of TransportSchema;
// they have their own separate config schemas (see dedicated sections below)
```

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

### 6. IDE SSE Server (sse-ide)

```typescript
interface McpSSEIDEServerConfig {
  type: 'sse-ide'
  url: string
  ideName: string
  ideRunningInWindows?: boolean  // Windows environment flag (undocumented)
}
```

### 7. IDE WebSocket Server (ws-ide)

```typescript
interface McpWebSocketIDEServerConfig {
  type: 'ws-ide'
  url: string
  ideName: string
  authToken?: string              // IDE WebSocket auth token (undocumented)
  ideRunningInWindows?: boolean   // Windows environment flag (undocumented)
}
```

### 8. Claude.ai Proxy

```typescript
interface McpClaudeAIProxyServerConfig {
  type: 'claudeai-proxy'
  url: string
  id: string
}

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

**Note**: `claude mcp test` command does not exist (use interactive `/mcp` interface). `claude mcp get` is used to get server details.

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

MCP server config has no `timeout` field. Timeout is controlled via environment variables:

| Environment Variable | Default | Description |
|----------------------|---------|-------------|
| `MCP_TIMEOUT` | 30000ms | Connection timeout |
| `MCP_TOOL_TIMEOUT` | 100000000ms (~27.8 hours) | Tool invocation timeout |
| `MCP_REQUEST_TIMEOUT_MS` | 60000ms | Internal request timeout |

```bash
# Example: Set 60 second connection timeout
export MCP_TIMEOUT=60000
```

> **Note**: The `timeout` field does not exist in MCP server configuration schema.

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

---

## Undocumented Features

### MCP-Related Environment Variables

| Environment Variable | Default | Description |
|---------------------|---------|-------------|
| `MCP_TIMEOUT` | 30000ms | MCP server connection timeout |
| `MCP_TOOL_TIMEOUT` | 100000000ms (~27.8 hours) | MCP tool invocation timeout |
| `MCP_REQUEST_TIMEOUT_MS` | 60000ms | Internal request timeout |
| `MCP_CLIENT_SECRET` | - | OAuth client secret (secure storage) |
| `MCP_OAUTH_CLIENT_METADATA_URL` | - | OAuth client metadata URL (FedStart support) |
| `CLAUDE_CODE_ENABLE_XAA` | - | Enable XAA (SEP-990) cross-app access |
| `ENABLE_CLAUDEAI_MCP_SERVERS` | - | Enable/disable claude.ai MCP server fetching |

### OAuth Sensitive Parameter Sanitization

OAuth sensitive parameters are automatically removed from logs:

```typescript
const SENSITIVE_OAUTH_PARAMS = [
  'state', 'nonce', 'code_challenge', 'code_verifier', 'code',
]
```

### Slack Non-Standard Error Codes

Automatically normalizes Slack and other services' non-standard `invalid_grant` error codes:

```typescript
const NONSTANDARD_INVALID_GRANT_ALIASES = new Set([
  'invalid_refresh_token',
  'expired_refresh_token',
  'token_expired',
])
```

### Token Revocation (RFC 7009)

Supports OAuth token revocation, including `refresh_token` and `access_token`.

### Built-in MCP Servers Default Disabled

Built-in MCP servers (like Computer Use MCP) are default disabled and must be explicitly enabled via `enabledMcpServers`.

### ${VAR:-default} Syntax

Environment variables support default values:

```json
{
  "env": {
    "DATABASE_URL": "${DB_URL:-postgresql://localhost:5432/db}"
  }
}
```

### headersHelper Security Features

`headersHelper` scripts are blocked when:
- Project/local MCP servers
- Non-CI/CD mode
- Workspace trust not established

Passed environment variables:
- `CLAUDE_CODE_MCP_SERVER_NAME`
- `CLAUDE_CODE_MCP_SERVER_URL`

### Server Configuration Priority

MCP server configuration priority (highest to lowest):
1. `local` (highest)
2. `project` (approved servers only)
3. `user`
4. `plugin` (lowest)
5. `claude.ai` connectors

### Channel Permissions System

Enabled via `tengu_harbor_permissions` GrowthBook feature:

```typescript
// Permission response format
/^\s*(y|yes|n|no)\s+([a-km-z]{5})\s*$/i
// Example: "yes tbxkq" - 5-letter ID system
```

### Dynamic MCP Configuration

MCP servers can be configured dynamically via:
- `--mcp-config` CLI flag (JSON file)
- `mcp_set_servers` control message
- SDK V2 `Query.setMcpServers()`

### Built-in Default-Disabled Servers

Some MCP servers are built-in and default disabled:
- Requires explicit opt-in via `enabledMcpServers`
- Controlled by `CHICAGO_MCP` feature flag

### URL Pattern Matching

Enterprise policy URL pattern matching rules:
- Only `*` is treated as wildcard
- `.*` in pattern becomes literal `.*`
- `\*` escape not supported
