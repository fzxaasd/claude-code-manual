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

MCP tool permissions are controlled through Claude Code's `permissions` configuration, not set in the server config.

**Fields actually supported by McpStdioServerConfig**:
```json
{
  "command": "npx",
  "args": ["@modelcontextprotocol/server-github"],
  "env": { "GITHUB_TOKEN": "${GITHUB_TOKEN}" }
}
```

**Note**: Fields like `allowedTools`/`deniedTools`/`allowedPaths`/`deniedPaths` do **NOT** exist in the MCP server config schema. These are limitations implemented by individual MCP servers themselves, not Claude Code-level configuration.

### Tool Restrictions

Path restrictions for MCP servers are implemented by each server (e.g., filesystem server), not part of Claude Code configuration.

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

# Reconnect server
claude mcp reconnect <server-name>

# Note: claude mcp status and claude mcp debug commands do not exist
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
