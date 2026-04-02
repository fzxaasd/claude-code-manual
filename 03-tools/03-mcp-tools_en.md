# 3.3 MCP Tool Integration

> Model Context Protocol tool integration guide

---

## MCP Overview

MCP (Model Context Protocol) is a standardized protocol for integrating external tools and data sources into Claude Code.

```
Claude Code ←→ MCP Server ←→ External Service
                ↓
         File System, APIs, Databases, etc.
```

---

## MCP Server Configuration

### Basic Configuration

Configure MCP servers in `settings.json`:

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

**Note**: MCP server configuration supports **6 transport types**, not just stdio.

---

### Transport Types

Source: `src/services/mcp/types.ts`

```typescript
export const TransportSchema = z.enum(['stdio', 'sse', 'sse-ide', 'http', 'ws', 'sdk'])
```

#### 1. stdio (Local Process)

Local process communication via stdin/stdout:

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

**Fields**:
- `command` (required): Executable command
- `args` (optional): Command argument array
- `env` (optional): Environment variables
- `type` (optional): Defaults to `stdio`

#### 2. sse (Server-Sent Events)

Connect to remote MCP server via HTTP SSE:

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

**Fields**:
- `url` (required): SSE endpoint URL
- `headers` (optional): HTTP request headers
- `headersHelper` (optional): Helper request header file path
- `oauth` (optional): OAuth 2.0 configuration
  - `clientId`: OAuth client ID
  - `clientSecret`: OAuth client secret
  - `authServerMetadataUrl`: OIDC discovery URL
  - `callbackPort`: Callback port
  - `xaa` (optional): Enable XAA (SEP-990) cross-app access

#### 3. sse-ide (IDE-Only)

IDE extension SSE connection:

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

**Fields**:
- `url` (required): IDE SSE endpoint
- `ideName` (required): IDE name
- `ideRunningInWindows` (optional): Windows identifier

#### 4. http (HTTP POST)

HTTP POST polling connection:

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

WebSocket connection:

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

#### 6. sdk (SDK Mode)

MCP server implemented using Claude Code SDK:

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

### MCP CLI Commands

```bash
# Add server
claude mcp add <name> <commandOrUrl> [args...]

# Add server with OAuth/XAA
claude mcp add <name> <url> --xaa --client-id <id> --client-secret <secret>

# Add via JSON
claude mcp add-json

# Import from Claude Desktop
claude mcp add-from-claude-desktop

# List servers
claude mcp list

# Get server details
claude mcp get <name>

# Remove server
claude mcp remove <name> [--scope <scope>]

# Start MCP server mode
claude mcp serve [--debug] [--verbose]

# Reset project choices
claude mcp reset-project-choices
```

**Note**:
- `--client-id`, `--client-secret`, `--callback-port`, `--xaa` only work for HTTP/SSE transports, ignored for stdio
- `--xaa` requires running `claude mcp xaa setup` first
- XAA is enabled via `CLAUDE_CODE_ENABLE_XAA=1` env var, not enterprise-only

### Project-Level Configuration (.mcp.json)

MCP servers can also be configured via `.mcp.json` in project root:

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

**Scope priority**: `--scope local` (project) > `--scope project` > `--scope user`

---

### Local Servers

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

## Common MCP Servers

### GitHub

```bash
# Install
npm install @modelcontextprotocol/server-github

# Configure
npx @modelcontextprotocol/server-github
```

**Features**:
- View repositories
- Manage Issues
- Create PRs
- View code

### File System

```bash
# Install
npm install @modelcontextprotocol/server-filesystem

# Configure
{
  "mcpServers": {
    "filesystem": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-filesystem", "/path/to/allowed/directory"]
    }
  }
}
```

**Features**:
- Secure file reading
- Directory browsing
- File search

### Slack

```bash
# Install
npm install @modelcontextprotocol/server-slack

# Configure
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
# Install
npm install @modelcontextprotocol/server-postgres

# Configure
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

## Using MCP Tools

### View Available Tools

```bash
claude mcp list
```

Example output:
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

### Invoking MCP Tools

```
> Use GitHub MCP to list my repositories

> Use filesystem MCP to read config.yaml
```

---

## MCP Tool Types

### Resources

Provide data access:

```json
{
  "resources": {
    "github://repos": "Repository list",
    "github://user": "Current user information"
  }
}
```

### Tools

Executable operations:

```json
{
  "tools": {
    "github_create_issue": {
      "description": "Create GitHub Issue",
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

### Prompts

Pre-defined prompt templates:

```json
{
  "prompts": {
    "review-pr": {
      "description": "Review Pull Request",
      "arguments": [
        {"name": "pr_number", "required": true}
      ]
    }
  }
}
```

---

## Custom MCP Servers

### Python Implementation

```python
from mcp.server.fastmcp import FastMCP

mcp = FastMCP("my-server")

@mcp.tool()
def calculate(expression: str) -> str:
    """Perform mathematical calculations"""
    return str(eval(expression))

@mcp.resource("config://app")
def get_config() -> str:
    """Return application configuration"""
    return '{"version": "1.0"}'

if __name__ == "__main__":
    mcp.run()
```

### Starting the Server

```bash
python my_mcp_server.py
```

### Configuration Usage

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

## MCP Tool Permissions

### Basic Permission Control

MCP tools are controlled via `permissions.allow`/`permissions.deny`:

```json
{
  "permissions": {
    "allow": ["mcp__github__*"],
    "deny": ["mcp__*__admin_*"]
  }
}
```

### Enterprise Allowlist/Denylist

Source: `src/settings/types.ts`

```json
{
  // Allowed MCP server list
  "allowedMcpServers": [
    { "serverName": "github" },
    { "serverName": "filesystem" }
  ],

  // Denied MCP server list (takes precedence over allowlist)
  "deniedMcpServers": [
    { "serverName": "dangerous-server" },
    { "serverCommand": ["python", "/path/to/script.py"] },
    { "serverUrl": "https://*.blocked-domain.com/*" }
  ]
}
```

**Matching modes**:
- `serverName`: Match by server name
- `serverCommand`: Exact match by command array (stdio servers)
- `serverUrl`: URL pattern matching with wildcard support (e.g., `https://*.example.com/*`)

**Note**: Denylist takes precedence over allowlist.

### Enterprise Policy Control

```json
{
  // Only allow managed MCP servers
  "allowManagedMcpServersOnly": true,

  // Project-level server management
  "enabledMcpjsonServers": ["server-a", "server-b"],
  "disabledMcpjsonServers": ["server-c"],
  "enableAllProjectMcpServers": false
}
```

### Tool Restrictions

Path restrictions for MCP servers are implemented by each server (e.g., filesystem server), not part of Claude Code configuration.

**Fields actually supported by McpStdioServerConfig**:
```json
{
  "command": "npx",
  "args": ["@modelcontextprotocol/server-github"],
  "env": { "GITHUB_TOKEN": "${GITHUB_TOKEN}" }
}
```

**Note**: Fields like `allowedTools`/`deniedTools`/`allowedPaths`/`deniedPaths` do **NOT** exist in the MCP server config schema. These are limitations implemented by individual MCP servers themselves, not Claude Code-level configuration.

---

## MCP vs Native Tools Comparison

| Feature | MCP Tools | Native Tools |
|---------|-----------|--------------|
| Source | External services | Built into Claude Code |
| Installation | Requires configuration | Ready to use |
| Capabilities | Server-dependent | Fixed set |
| Permissions | Configurable individually | Global configuration |
| Latency | Network latency | No latency |

---

## Troubleshooting

### MCP Server Not Responding

```bash
# List all MCP server status
claude mcp list

# Get specific server details
claude mcp get <server-name>

# Remove and re-add server
claude mcp remove <server-name>
claude mcp add <server-name> <command>

# Note: claude mcp status, mcp debug, mcp reconnect commands do not exist
```

### Tool Not Available

```json
// Ensure tool name is correct
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

### Connection Timeout

```bash
# Increase timeout
export MCP_SERVER_TIMEOUT=60000
```

---

## Best Practices

### 1. Secure Configuration

```json
{
  "mcpServers": {
    "production-api": {
      "command": "npx",
      "args": ["mcp-server"],
      "env": {
        // Use environment variables instead of hardcoding
        "API_KEY": "${PROD_API_KEY}"
      }
    }
  }
}
```

### 2. Permission Isolation

Tool restrictions for MCP servers are implemented by the servers themselves. Claude Code controls user-callable tools through `permissions.allow`/`permissions.deny`.

### 3. Performance Optimization

Caching behavior for MCP servers is implemented by each server. Claude Code does not provide `cacheEnabled`/`cacheTTL` configuration.

---

## Common MCP Servers List

| Server | Features | Install Command |
|--------|----------|-----------------|
| github | GitHub API | `npx -y @modelcontextprotocol/server-github` |
| filesystem | File operations | `npx -y @modelcontextprotocol/server-filesystem` |
| slack | Slack integration | `npx -y @modelcontextprotocol/server-slack` |
| postgres | PostgreSQL | `npx -y @modelcontextprotocol/server-postgres` |
| sqlite | SQLite | `npx -y @modelcontextprotocol/server-sqlite` |
| s3 | AWS S3 | `npx -y @modelcontextprotocol/server-s3` |
| google-maps | Google Maps | `npx -y @modelcontextprotocol/server-google-maps` |

---

## Advanced Usage

### MCP Composition

```
> Use GitHub MCP to view code, then use filesystem MCP to save changes
```

### MCP Context

Context inclusion capabilities for MCP servers are implemented by each server. Claude Code does not provide `includeContext` configuration.
