# 11.2 Plugin Structure

> Plugin directory structure and configuration file details

---

## Complete Directory Structure

```
my-plugin/
├── .claude-plugin/
│   └── plugin.json      # Plugin manifest (required, in .claude-plugin/ subdirectory)
├── package.json         # npm package config (optional)
├── skills/             # Skills directory
│   ├── hello/
│   │   └── SKILL.md
│   └── sql-optimizer/
│       └── SKILL.md
├── agents/             # Agent definitions directory
│   ├── reviewer.md
│   └── coder.md
├── hooks/              # Hook configuration
│   └── hooks.json
├── commands/           # Command files directory
│   └── README.md
├── output-styles/      # Output styles directory
│   └── custom.css
└── tests/              # Testing
    └── plugin.test.ts
```

> Note: Plugin manifest files must be located in `.claude-plugin/plugin.json`, not `manifest.json` in the root directory.

---

## .claude-plugin/plugin.json

### Basic Configuration

```json
{
  "name": "my-plugin",
  "version": "1.0.0",
  "description": "Plugin description",
  "author": {
    "name": "Author Name",
    "email": "author@example.com"
  },
  "repository": "https://github.com/user/my-plugin",
  "license": "MIT"
}
```

### Skills Configuration

```json
{
  "skills": "./skills"
}
```

Or multiple paths:

```json
{
  "skills": ["./skills", "./extra-skills"]
}
```

Only supports path strings or string arrays, **does not support** `{ directory, autoLoad }` object format.

### Agents Configuration

```json
{
  "agents": "./agents"
}
```

Agent files are in markdown format, see Agent directory structure below.

### Hooks Configuration

```json
{
  "hooks": "./hooks"
}
```

### MCP Servers

```json
{
  "mcpServers": {
    "db-server": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-postgres"],
      "env": {
        "DATABASE_URL": "${user_config.DATABASE_URL}"
      }
    }
  }
}
```

MCP Servers also support:
- Path reference: `"./.mcp.json"`
- MCPB files: `"./servers.mcpb"` or URL

### outputStyles Configuration

```json
{
  "outputStyles": "./output-styles"
}
```

### userConfig Configuration

```json
{
  "userConfig": {
    "apiKey": {
      "type": "string",
      "description": "API Key for external service",
      "sensitive": true,
      "required": false
    },
    "maxResults": {
      "type": "number",
      "description": "Maximum results to return",
      "default": 10,
      "min": 1,
      "max": 100
    }
  }
}
```

### channels Configuration

```json
{
  "channels": [
    {
      "server": "telegram-bot",
      "displayName": "Telegram",
      "userConfig": {
        "botToken": {
          "type": "string",
          "title": "Bot Token",
          "description": "Your Telegram bot token",
          "sensitive": true
        }
      }
    }
  ]
}
```

---

## Skills Directory Structure

### Single Skill Directory

```
skills/
└── hello/
    ├── SKILL.md           # Required
    ├── assets/            # Optional
    │   └── icon.png
    └── scripts/           # Optional
        └── helper.sh
```

### SKILL.md Structure

```markdown
---
name: hello
description: Greeting skill
when_to_use: Use when you need to greet
paths:
  - "*.ts"
  - "*.js"
tools:
  - Bash
  - Read
version: "1.0.0"
---

# Greeting Skill

This is a sample skill.

## Usage

Simply say "hello".
```

---

## Agents Directory Structure

```
agents/
├── reviewer.md
└── coder.md
```

### Agent Definition (markdown + frontmatter)

```markdown
---
name: reviewer
description: Code review Agent
model: sonnet
tools:
  - Read
  - Glob
  - Grep
  - Bash(git *)
disallowedTools:
  - Bash(rm *)
  - Write(/etc/**)
---

# Code Review Agent

Agent detailed description and usage guide.

System prompt comes from markdown body content, not frontmatter.

## Features

1. Security checks
2. Code quality assessment
3. Performance analysis
```

Agent frontmatter field descriptions:

| Field | Type | Description |
|------|------|-------------|
| `name` | string | Agent name |
| `description` | string | Description |
| `model` | string | Default model |
| `tools` | string[] | Allowed tools |
| `disallowedTools` | string[] | Disallowed tools |
| System prompt | - | From markdown body content, not a frontmatter field |

---

## Hooks Directory Structure

```
hooks/
├── hooks.json
├── pre-check.sh
└── post-check.sh
```

### hooks.json

```json
{
  "description": "Security check hooks",
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "${HOOK_DIR}/pre-check.sh",
            "timeout": 5,
            "if": "Bash(git commit)"
          }
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "*",
        "hooks": [
          {
            "type": "command",
            "command": "${HOOK_DIR}/post-check.sh",
            "async": true
          }
        ]
      }
    ],
    "SessionStart": [
      {
        "hooks": [
          {
            "type": "prompt",
            "prompt": "Remember to follow security best practices"
          }
        ]
      }
    ],
    "Notification": [
      {
        "hooks": [
          {
            "type": "http",
            "url": "https://webhook.example.com/notify",
            "method": "POST",
            "allowedEnvVars": ["USER"]
          }
        ]
      }
    ]
  }
}
```

---

## Environment Variables

Template variables available to plugins:

| Variable | Description |
|------|-------------|
| `${PLUGIN_DIR}` | Plugin root directory |
| `${CLAUDE_PLUGIN_ROOT}` | Plugin installation root directory (versioned) |
| `${CLAUDE_PLUGIN_DATA}` | Plugin data directory (persistent storage) |
| `${SKILL_DIR}` | Skills directory |
| `${HOOK_DIR}` | Hooks directory |
| `${AGENT_DIR}` | Agents directory |
| `${COMMAND_DIR}` | Commands directory |
| `${user_config.KEY}` | Variables defined in userConfig |

---

## Next Steps

- [11.3 Plugin API](./03-api.md) - Type reference
- [11.4 Development Examples](./04-examples.md) - Complete examples
