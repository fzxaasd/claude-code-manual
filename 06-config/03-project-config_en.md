# 6.3 Project-Level Configuration

> Configure Claude Code in team projects

---

## Project Configuration Structure

### Directory Structure

```
project/
├── .claude/
│   ├── settings.json        # Project settings (must be committed to Git)
│   └── settings.local.json   # Local overrides (not committed)
└── .claudeignore             # Ignore rules
```

### Create Project Configuration

```bash
# Interactive creation
claude init

# Specify configuration
claude init --project-name my-app
```

---

## settings.json Complete Example

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

> **Note**: Agent configuration is not in settings.json. Agents should be placed in the `.claude/agents/` directory (Markdown files). settings.json does not support a top-level `agents` field.

---

## Permission Configuration

### Team Permission Policy

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

### Common Restrictions

| Restriction Type | Configuration |
|------------------|---------------|
| Disable file deletion | `deny: ["Bash(rm -rf *)"]` |
| Disable system commands | `deny: ["Bash(sudo *)", "Bash(chmod *)"]` |
| Protect sensitive files | `deny: ["Write(*.pem)", "Write(*.key)", "Write(.env)"]` |
| npm only | `allow: ["Bash(npm *)"]` |
| Protect config directories | `deny: ["Write(/etc/**)"]` |

---

## Hooks Configuration

### Project-Level Hooks

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

### Hook Script Example

```bash
#!/bin/bash
# hooks/pre_command.sh
# Purpose: Validate command safety

COMMAND=$(echo "$1" | jq -r '.command')

# Check for dangerous commands
if echo "$COMMAND" | grep -qE "rm -rf|sudo|chmod 777"; then
  echo '{"exit": 2, "error": "Dangerous command blocked"}'
  exit 2
fi

exit 0
```

---

## Sandbox Configuration

> Sandbox configuration controls the security isolation level for Claude Code command execution

### Basic Structure

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

### Network Sandbox Configuration

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

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `allowedDomains` | string[] | - | List of allowed domains |
| `allowManagedDomainsOnly` | boolean | false | Use only managed settings domains (enterprise config) |
| `allowUnixSockets` | string[] | - | macOS only: Allowed Unix socket paths |
| `allowAllUnixSockets` | boolean | false | Allow all Unix sockets (disable platform blocking) |
| `allowLocalBinding` | boolean | false | Allow local binding connections |
| `httpProxyPort` | number | - | HTTP proxy port |
| `socksProxyPort` | number | - | SOCKS proxy port |

### Filesystem Sandbox Configuration

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

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `allowWrite` | string[] | - | Additional allowed write paths (merged from Edit permission rules) |
| `denyWrite` | string[] | - | Denied write paths (merged from Edit deny permission rules) |
| `denyRead` | string[] | - | Denied read paths (merged from Read deny permission rules) |
| `allowRead` | string[] | - | Paths to re-allow read within denyRead regions |
| `allowManagedReadPathsOnly` | boolean | false | Use only managed settings read paths (enterprise config) |

### Complete Configuration Example

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

### Configuration Reference

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `enabled` | boolean | - | Enable sandbox |
| `failIfUnavailable` | boolean | false | Exit with error when sandbox unavailable (for mandatory sandbox deployment) |
| `autoAllowBashIfSandboxed` | boolean | false | Auto-allow Bash commands when sandbox is enabled |
| `allowUnsandboxedCommands` | boolean | true | Allow bypassing sandbox via dangerouslyDisableSandbox parameter |
| `ignoreViolations` | Record<string, string[]> | - | Ignore sandbox violations for specific tools/commands |
| `enableWeakerNestedSandbox` | boolean | false | Enable weaker nested sandbox |
| `enableWeakerNetworkIsolation` | boolean | false | macOS only: Allow access to trustd (for MITM proxy certificate validation, **reduces security**) |
| `excludedCommands` | string[] | - | Commands excluded from sandbox |
| `ripgrep.command` | string | - | Custom ripgrep command path |
| `ripgrep.args` | string[] | - | ripgrep extra arguments |

> **Platform Notes**:
> - `allowUnixSockets` only works on macOS (Linux seccomp cannot filter by path)
> - `enableWeakerNetworkIsolation` only works on macOS
> - Enterprise deployments should set `failIfUnavailable: true` to ensure sandbox enforcement

---

## .claudeignore

### Syntax

```
# Comments
pattern
!pattern    # Negation
*.log       # Wildcards
```

### Example

```
# Claude Code ignore file
.claude/
.claude/settings.local.json
*.local.*
node_modules/
dist/
build/
.git/
```

---

## Local Overrides

### .claude/settings.local.json

This file should be added to `.gitignore` for local special configuration:

```json
{
  "permissions": {
    "defaultMode": "ask"
  }
}
```

> **Path Note**: `settings.local.json` is fixed at `.claude/settings.local.json`, not the project root directory.

### Local Configuration Merge

| Field | Merge Method |
|-------|-------------|
| String | Override |
| Array | Concat-dedupe |
| Object | Deep merge |

---

## Agent Configuration

### Project-Specific Agents

Agent configurations are placed in the `.claude/agents/` directory, using Markdown file format:

```markdown
# .claude/agents/frontend-reviewer.md

## Description
Frontend code review assistant

## Tool Restrictions
- Read
- Glob(src/**/*.tsx)
- Glob(src/**/*.ts)
- Grep
- Bash(npm *)
```

> **Important**: Agents are not configured in settings.json. Agents are standalone Markdown files placed in `~/.claude/agents/` or `.claude/agents/` directories.

---

## MCP Server Configuration

### .mcp.json

MCP servers are configured in the `.mcp.json` file in the project root:

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

> **Note**: `mcpServers` is not a top-level field of settings.json. MCP server configuration is in `.mcp.json`, controlled via `enabledMcpjsonServers` and `disabledMcpjsonServers` in settings.json.

---

## Multi-Environment Configuration

### Environment Variable Override

```bash
# Development environment
export CLAUDE_PERMISSIONS_DEFAULT_MODE=ask

# Production environment
export CLAUDE_PERMISSIONS_DEFAULT_MODE=dontAsk
```

### Conditional Configuration

Use environment variables in `settings.json`:

```json
{
  "permissions": {
    "defaultMode": "${CLAUDE_ENV:-ask}"
  }
}
```

---

## Version Control Best Practices

### Must Commit

- `.claude/settings.json`
- `.claudeignore`

### Must NOT Commit

- `.claude/settings.local.json`
- Configurations containing API keys
- Local debugging configurations

### .gitignore Example

```gitignore
# Claude Code
.claude/
!.claude/settings.json
.claude/settings.local.json
```

---

## Team Collaboration Workflow

### 1. Project Initialization

```bash
# Initialize after cloning
git clone git@github.com:team/project.git
cd project
claude init
```

### 2. Configuration Sync

```bash
# View project configuration
claude config show --scope project

# Validate configuration
claude settings validate
```

### 3. Local Override

```bash
# Create local configuration
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

## Troubleshooting

### Configuration Not Taking Effect

```bash
# Check configuration file path
claude settings path

# Validate JSON format
claude settings validate

# View effective configuration
claude config show
```

### Permission Issues

```bash
# Test permissions
claude permissions test "Bash(rm -rf /)"

# View current permission status
claude permissions show
```

### Hook Not Executing

```bash
# Validate hook configuration
claude hooks validate

# Debug hook
claude hooks debug --event PreToolUse
```

---

## Configuration Templates

### Basic Project Template

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

### Strict Project Template

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
