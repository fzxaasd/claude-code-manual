# Plugin System

> Claude Code plugin installation, configuration, and management

## Core Concepts

### Plugin Architecture

```
┌─────────────────────────────────────────────┐
│ Claude Code                                 │
│  ┌─────────────┐  ┌─────────────────────┐ │
│  │ Built-in    │  │ Plugin System       │ │
│  │ Features    │  │  ┌───────────────┐  │ │
│  └─────────────┘  │  │ Plugin A      │  │ │
│                    │  │ - Skills     │  │ │
│                    │  │ - Hooks      │  │ │
│                    │  │ - Agents     │  │ │
│                    │  └───────────────┘  │ │
│                    │  ┌───────────────┐  │ │
│                    │  │ Plugin B     │  │ │
│                    │  │ - Skills     │  │ │
│                    │  │ - Tools      │  │ │
│                    │  └───────────────┘  │ │
│                    └─────────────────────┘ │
└─────────────────────────────────────────────┘
```

---

## Plugin Management CLI

### Basic Commands

| Command | Description |
|---------|-------------|
| `claude plugin list` | List installed plugins |
| `claude plugin install <name>` | Install plugin |
| `claude plugin uninstall <name>` | Uninstall plugin |
| `claude plugin enable <name>` | Enable plugin |
| `claude plugin disable <name>` | Disable plugin |
| `claude plugin update <name>` | Update plugin |
| `claude plugin validate <path>` | Validate plugin manifest |

### Marketplace Management

```bash
# List available marketplaces
claude plugin marketplace list

# Add marketplace
claude plugin marketplace add <source>

# Import from Claude Desktop
claude mcp add-from-claude-desktop
```

---

## Plugin Structure

### Directory Structure

```
plugin-name/
├── .claude-plugin/
│   └── plugin.json      # Plugin manifest (required, in .claude-plugin/ subdirectory)
├── skills/
│   └── my-skill/
│       └── SKILL.md
├── agents/
│   └── my-agent.md
├── hooks/
│   └── hooks.json
└── README.md
```

> Note: Plugin manifest must be located at `.claude-plugin/plugin.json`, not `plugin.json` in root directory.

### plugin.json

```json
{
  "name": "my-plugin@marketplace",
  "version": "1.0.0",
  "description": "Plugin description",
  "author": {
    "name": "Author Name",
    "email": "author@example.com"
  },
  "homepage": "https://github.com/author/plugin",
  "repository": "https://github.com/author/plugin",
  "license": "MIT",
  "keywords": ["testing", "mcp"],
  "strict": true,
  "skills": "./skills",
  "agents": "./agents",
  "commands": {
    "build": { "source": "commands/build.md", "description": "Build project" },
    "deploy": { "source": "commands/deploy.md", "description": "Deploy", "argumentHint": "<env>", "model": "sonnet", "tools": ["Read", "Bash(npm *)", "Write"] }
  },
  "hooks": "./hooks/hooks.json",
  "dependencies": ["formatter@marketplace", "linter"],
  "mcpServers": {
    "github-server": { "command": "npx", "args": ["@modelcontextprotocol/server-github"] }
  },
  "userConfig": {
    "api_key": { "type": "string", "description": "API Key", "sensitive": true, "required": true },
    "project_dir": { "type": "directory", "description": "Project directory" },
    "config_file": { "type": "file", "description": "Config file path" }
  },
  "outputStyles": "./output-styles",
  "channels": [
    { "name": "telegram", "displayName": "Telegram", "server": "telegram-bot" }
  ]
}
```

**Important Notes**:
- The `id` field does **not** exist in plugin.json. Plugin ID is automatically derived from `name@marketplace`.
- The field name in `channels` is `server`, not `mcpServer`.

**Field Reference**:

| Field | Type | Description |
|-------|------|-------------|
| `name` | string | Plugin ID in kebab-case with `@marketplace` suffix (required) |
| `version` | string | Semantic version (semver) |
| `description` | string | Brief description |
| `author` | object | Author info (name required) |
| `homepage` | string | Homepage URL |
| `repository` | string | Source repository URL (metadata) |
| `license` | string | SPDX license identifier (metadata) |
| `keywords` | string[] | Discovery and categorization tags |
| `strict` | boolean | Require plugin.json (marketplace entries only) |
| `dependencies` | string[] | Plugin dependencies, auto-resolved at install |
| `skills` | path\\|path[] | Skills directory paths (not object format) |
| `agents` | path\\|path[] | Agent definition file paths (not object format) |
| `commands` | path\\|path[]\\|object | Command file paths or inline definitions; supports object format `{source, description, argumentHint, model, allowedTools}` |
| `hooks` | path\\|object | Hook configuration path or inline config |
| `mcpServers` | object\\|path\\|MCPB | MCP server configs; supports .mcpb/.dxt files |
| `userConfig` | object | User-configurable options; supports string/number/boolean/directory/file types; `sensitive` values are stored in keychain |
| `outputStyles` | path\\|path[] | Output styles directory |
| `channels` | array | MCP message channels (Telegram/Slack/Discord), injected via `notifications/claude/channel` |
| `lspServers` | object\\|path | LSP server configurations |
| `settings` | object | Settings to merge into settings cascade |

> **Note**: MCP server config uses `command`/`args`/`env`, not `type`. Skills/agents/hooks paths support string or array only, not object format.

---

## Plugin Skills

### Create Plugin Skill

```
my-plugin/
├── .claude-plugin/
│   └── plugin.json
└── skills/
    └── custom-skill/
        └── SKILL.md
```

### SKILL.md Example

```markdown
---
name: custom-skill
description: Custom skill description
when_to_use: Use this when you need...
---

# Custom Skill

This is a skill provided by the plugin.
```

---

## Plugin Hooks

### hooks.json Format

```json
{
  "PreToolUse": [
    {
      "matcher": "Bash",
      "hooks": [
        {
          "type": "command",
          "command": "python3 security-check.py"
        }
      ]
    }
  ],
  "SessionStart": [
    {
      "hooks": [
        {
          "type": "prompt",
          "prompt": "Welcome to the project!"
        }
      ]
    }
  ]
}
```

---

## Enterprise Configuration

### Plugin-Only Customization

```json
{
  "strictPluginOnlyCustomization": ["skills", "agents", "hooks"]
}
```

This prevents users from directly editing these configurations, only allowing additions via plugins.

### Marketplace Whitelist

```json
{
  "strictKnownMarketplaces": [
    {
      "type": "github",
      "repo": "my-org/approved-plugins"
    }
  ]
}
```

---

## Plugin Marketplace

### Official Marketplace

```
anthropic-tools (official)
├── claude-code-snippets
├── git-helpers
└── productivity-tools
```

### Third-party Marketplace

```json
{
  "extraKnownMarketplaces": {
    "internal": {
      "source": {
        "type": "github",
        "repo": "my-org/claude-plugins"
      },
      "autoUpdate": true
    }
  }
}
```

### Add Custom Marketplace

```bash
# Via CLI
claude plugin marketplace add --type github --repo my-org/plugins

# Via settings.json
{
  "extraKnownMarketplaces": {
    "my-marketplace": {
      "source": {
        "type": "github",
        "repo": "my-org/marketplace"
      }
    }
  }
}
```

---

## Security Considerations

### Plugin Trust

Trust warning displayed before plugin installation:

```
⚠️ This plugin will be able to:
- Read/write project files
- Execute shell commands
- Access configured MCP servers

Confirm installation?
```

### Trust Message

Enterprises can customize trust message:

```json
{
  "pluginTrustMessage": "All internal marketplace plugins have passed security review."
}
```

### Plugin Read-Only

```json
{
  "strictPluginOnlyCustomization": true
}
```

This locks all custom configurations, only allowing modifications via plugins.

---

## Troubleshooting

### Plugin Not Loading

1. Check plugin directory exists
2. Validate plugin.json format
3. Check error logs

```bash
# Validate plugin
claude plugin validate ./my-plugin

# Debug mode
claude --debug plugin
```

### Skill Not Showing

1. Check SKILL.md location
2. Validate frontmatter
3. Confirm plugin is enabled

```bash
# List all skills
claude /skills

# View skill details
claude /skill-name --help
```

---

## Recommended Plugins

### 1. Official Plugins

| Plugin | Features |
|--------|----------|
| claude-code-snippets | Code snippets |
| git-helpers | Git helper tools |
| productivity-tools | Productivity tools |

### 2. Common MCP Servers

```bash
# GitHub integration
claude mcp add github -- npx -y @modelcontextprotocol/server-github

# Filesystem
claude mcp add filesystem -- npx -y @modelcontextprotocol/server-filesystem

# Slack
claude mcp add slack -- npx -y @modelcontextprotocol/server-slack
```

---

## Developing Plugins

### Create New Plugin

1. Create directory structure
2. Write plugin.json
3. Add skills/agents/hooks
4. Test and verify
5. Publish to marketplace

### Local Testing

```bash
# Test with --plugin-dir
claude --plugin-dir ./my-plugin

# Validate manifest
claude plugin validate ./my-plugin
```
