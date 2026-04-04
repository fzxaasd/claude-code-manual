# 11.1 Plugin System Overview

> Core guide for Claude Code plugin extension mechanism

---

## Overview

Claude Code plugins are an extension mechanism that allows developers to package Skills, Agents, Hooks, MCP Servers, and other features through configuration files.

Plugin manifest files must be located in `.claude-plugin/plugin.json` (i.e., in a `.claude-plugin/` subdirectory under the plugin root directory).

```
Plugin Directory
├── .claude-plugin/
│   └── plugin.json      # Plugin manifest (required)
├── skills/              # Skills directory
├── agents/              # Agent definitions directory
├── hooks/               # Hook configuration directory
├── commands/            # Command files directory
├── output-styles/       # Output styles directory
└── ...
```

---

## Plugin Manifest Fields

Complete field definitions based on `src/utils/plugins/schemas.ts`:

```json
{
  "name": "my-plugin",
  "version": "1.0.0",
  "description": "My plugin",
  "author": {
    "name": "Author Name",
    "email": "author@example.com",
    "url": "https://github.com/author"
  },
  "homepage": "https://github.com/user/my-plugin",
  "repository": "https://github.com/user/my-plugin",
  "license": "MIT",
  "keywords": ["productivity", "development"],
  "dependencies": ["helper-plugin@marketplace"],
  "commands": "./commands",
  "agents": "./agents",
  "hooks": "./hooks",
  "skills": "./skills",
  "outputStyles": "./styles",
  "mcpServers": {},
  "lspServers": {},
  "userConfig": {},
  "channels": []
}
```

### Field Details

| Field | Type | Description |
|------|------|-------------|
| `name` | string | Plugin name (kebab-case, required) |
| `version` | string | Semantic version (semver) |
| `description` | string | Brief description |
| `author` | object | Author info (name required, email/url optional) |
| `homepage` | string | Homepage URL |
| `repository` | string | Source repository URL |
| `license` | string | SPDX license (MIT, Apache-2.0) |
| `keywords` | string[] | Search tags |
| `dependencies` | string[] | Plugin dependencies |
| `commands` | path/array/object | Command file paths |
| `agents` | path/array | Agent definition file paths |
| `hooks` | path/hooks | Hook configuration |
| `skills` | path/array | Skills directory paths |
| `outputStyles` | path/array | Output styles directory |
| `mcpServers` | object/path/MCPB | MCP server configuration |
| `lspServers` | object/path | LSP server configuration |
| `userConfig` | object | User-configurable options |
| `channels` | array | Message channels (Telegram/Slack/Discord) |
| `settings` | object | Merged into settings (whitelist only) |

### Skills/Agents/Hooks Configuration Format

These three fields only support two formats:

1. **Single path**: `"./skills"`
2. **Path array**: `["./skills", "./extra-skills"]`

Does not support `{ directory, autoLoad }` object format.

### Agent File Format

Agent definitions use **markdown format** with frontmatter for metadata:

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
color: blue
background: true
memory: project
isolation: worktree
effort: medium
maxTurns: 10
skills:
  - code-review
---

# Code Review Agent

Agent markdown body content. This content will be used as the system prompt.
```

### AgentDefinition Fields

| Field | Type | Description |
|-------|------|-------------|
| `name` | string | Agent name (required) |
| `description` | string | Agent description (required) |
| `model` | string | Model to use (sonnet/opus/haiku) |
| `tools` | string[] | Allowed tools (use `tools`, not `allowedTools`) |
| `disallowedTools` | string[] | Explicitly denied tools |
| `color` | 'red'\\|'blue'\\|'green'\\|'yellow'\\|'purple'\\|'orange'\\|'pink'\\|'cyan' | UI display color |
| `background` | boolean | Always run as background task |
| `memory` | 'user'\\|'project'\\|'local' | Persistent memory scope |
| `isolation` | 'worktree' | Git worktree isolation mode |
| `effort` | string\\|number | Effort level |
| `maxTurns` | number | Maximum agentic turns |
| `skills` | string[] | Preloaded skill list |
| `permissionMode` | string | Permission mode (default/acceptEdits/bypassPermissions/dontAsk/plan) |
| `mcpServers` | AgentMcpServerSpec[] | Agent-specific MCP servers |
| `hooks` | HooksSettings | Session-scoped hooks |
| `initialPrompt` | string | Prepended to the first user turn |
| `requiredMcpServers` | string[] | MCP server name patterns required for agent availability |
| `omitClaudeMd` | boolean | Omit CLAUDE.md hierarchy from agent's userContext |
| `criticalSystemReminder_EXPERIMENTAL` | string | Short message re-injected at every user turn |

> **Note**: `system_prompt` is NOT a frontmatter field. The system prompt comes from the markdown body content.

### outputStyles Configuration

The `outputStyles` field specifies additional output style files or directories:

```json
{
  "outputStyles": "./custom-styles"
}
```

### mcpServers Configuration Format

`mcpServers` supports multiple formats:

1. **Inline object**: `{ "server-name": { command: "npx", args: [...] } }`
2. **Path string**: `"./.mcp.json"` or `"./mcp-config.json"`
3. **MCPB file**: `"./servers.mcpb"` or URL `https://example.com/servers.mcpb`
4. **Array**: Array mixing above types

MCPB file format (`.mcpb` or `.dxt`) is used to package MCP server configurations.

---

## Plugin Loading Mechanism

### Loading Sources

| Source | Path | Description |
|--------|------|-------------|
| User-level | `~/.claude/plugins/` | User-installed plugins |
| Project-level | `.claude/plugins/` | In-project plugins |
| Built-in | `builtin@` | Built-in plugins, use `@builtin` suffix |

### Loading Flow

```
1. Scan plugin directories
    ↓
2. Read .claude-plugin/plugin.json
    ↓
3. Validate plugin manifest
    ↓
4. Load Skills/Agents/Hooks
    ↓
5. Initialize MCP/LSP Servers
    ↓
6. Register to system
```

---

## Built-in Plugins Mechanism

Built-in plugins use plugin ID format with `@builtin` suffix:

```
plugin-name@builtin
```

Built-in plugin characteristics:
- Released with CLI, users can enable/disable in `/plugin` UI
- Displayed under "Built-in" category in `/plugin` UI
- Can provide various components like skills, hooks, MCP servers
- User disable state persists to user settings

---

## Plugin Marketplace

### Marketplace Source Types

| Source | Description |
|--------|-------------|
| `url:https://...` | Direct URL |
| `github:owner/repo` | GitHub repository |
| `git:https://...` | Any Git |
| `npm:package` | NPM package |
| `file:path` | Local file |
| `directory:path` | Local directory |
| `hostPattern:regex` | Match hostname |
| `pathPattern:regex` | Match path |
| `settings` | Inline definition |

### strict Field (Marketplace Entries)

The `strict` field only exists in marketplace.json entries, controlling whether plugin.json is required:

```json
{
  "plugins": [
    {
      "id": "my-plugin",
      "source": "github:owner/repo",
      "strict": true
    }
  ]
}
```

| Value | Description |
|-------|-------------|
| `true` | Must exist, otherwise install fails (default) |
| `false` | plugin.json is optional |

### sparsePaths (Sparse Clone)

For github and git type marketplaces, `sparsePaths` field supports sparse clone:

```json
{
  "source": "github",
  "repo": "owner/monorepo",
  "sparsePaths": [".claude-plugin", "plugins"]
}
```

### forceRemoveDeletedPlugins

Set in marketplace.json, deleted plugins are automatically uninstalled:

```json
{
  "forceRemoveDeletedPlugins": true
}
```

### autoUpdate Mechanism

Marketplace supports auto-update mechanism. Configure in `known_marketplaces.json`:

```json
{
  "marketplace-name": {
    "source": { "source": "github", "repo": "owner/plugins" },
    "autoUpdate": true
  }
}
```

Official Anthropic marketplace has autoUpdate enabled by default (except `knowledge-work-plugins`).

---

## Plugin Type Definitions

### PluginManifest (Complete Structure)

```typescript
interface PluginManifest {
  // === Metadata ===
  name: string
  version?: string
  description?: string
  author?: PluginAuthor
  homepage?: string
  repository?: string
  license?: string
  keywords?: string[]
  dependencies?: DependencyRef[]

  // === Content paths (only supports path strings or arrays) ===
  commands?: CommandPath | CommandPath[] | Record<string, CommandMetadata>
  agents?: AgentPath | AgentPath[]     // markdown file paths
  hooks?: HooksConfig
  skills?: SkillPath | SkillPath[]       // directory paths
  outputStyles?: StylePath | StylePath[]
  // strict is NOT in PluginManifest, only in MarketplaceManifest entries

  // === Service configuration ===
  mcpServers?: McpConfig | McpBPath | RelativeJsonPath
  lspServers?: LspConfig | RelativeJsonPath

  // === User configuration ===
  userConfig?: Record<string, UserConfigOption>
  channels?: ChannelConfig[]

  // === Plugin-level settings ===
  settings?: Record<string, unknown>
}
```

### DependencyRef (Plugin Dependencies)

```typescript
// Three forms, unified to "name" or "name@marketplace"
type DependencyRef =
  | "plugin"                       // Bare name
  | "plugin@marketplace"           // Marketplace-qualified
  | "plugin@marketplace@^1.2"     // With version constraint (silently ignored)
  | { name: string, marketplace?: string }  // Object form (other fields ignored)
```

### Plugin ID Format

```
plugin-name@marketplace-name
```

Regex: `/^[a-z0-9][-a-z0-9._]*@[a-z0-9][-a-z0-9._]*$/i`

### InstalledPluginsFile (V1/V2)

V1 format: `plugins` is `Record<PluginId, PluginInstallationEntry>`
V2 format: `plugins` is `Record<PluginId, PluginInstallationEntry[]>`, supporting multi-scope installation

Scope types: `'managed' | 'user' | 'project' | 'local'`

---

## userConfig (User Configuration)

Plugins can declare user-configurable options:

```json
{
  "userConfig": {
    "apiKey": {
      "type": "string",
      "title": "API Key",
      "description": "Your API key for the service",
      "required": true,
      "sensitive": true,
      "default": null
    },
    "maxResults": {
      "type": "number",
      "title": "Max Results",
      "description": "Maximum number of results to return",
      "min": 1,
      "max": 100,
      "default": 10
    }
  }
}
```

### Configuration Field Types

| Field | Type | Description |
|------|------|-------------|
| `type` | enum | string/number/boolean/directory/file |
| `title` | string | Display name (required) |
| `description` | string | Help text (required) |
| `required` | boolean | Whether required |
| `default` | any | Default value |
| `multiple` | boolean | Allow multiple values (string type) |
| `sensitive` | boolean | Sensitive data, stored in Keychain |
| `min/max` | number | Value range (number type) |

### Configuration Storage

| Type | Storage Location |
|------|------------------|
| Non-sensitive | `settings.json` → `pluginConfigs[id].options` |
| Sensitive | macOS Keychain / `.credentials.json` |

### Template Variables

Configuration values can be referenced via `${user_config.KEY}` template variables, used in MCP/LSP server config environment variables, Hook command parameters, etc.

---

## channels Configuration (Message Channels)

Plugins can declare message channels (injected via MCP server):

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

Supported channel types: Telegram, Slack, Discord, etc. The `server` field value must match a key in `mcpServers`.

---

## PluginError Type System

The plugin system defines 20+ error types (`src/types/plugin.ts`):

| Error Type | Description |
|------------|-------------|
| `path-not-found` | Component path does not exist |
| `git-auth-failed` | Git authentication failed (ssh/https) |
| `git-timeout` | Git operation timeout |
| `network-error` | Network error |
| `manifest-parse-error` | Manifest file parse failed |
| `manifest-validation-error` | Manifest field validation failed |
| `plugin-not-found` | Plugin not found in marketplace |
| `marketplace-not-found` | Marketplace not found |
| `marketplace-load-failed` | Marketplace load failed |
| `mcp-config-invalid` | MCP configuration invalid |
| `mcp-server-suppressed-duplicate` | MCP server duplicate suppressed |
| `hook-load-failed` | Hook load failed |
| `component-load-failed` | Component load failed |
| `mcpb-download-failed` | MCPB file download failed |
| `mcpb-extract-failed` | MCPB file extraction failed |
| `mcpb-invalid-manifest` | MCPB manifest invalid |
| `marketplace-blocked-by-policy` | Marketplace blocked by enterprise policy |
| `dependency-unsatisfied` | Dependency unsatisfied |
| `lsp-config-invalid` | LSP configuration invalid |
| `lsp-server-start-failed` | LSP server start failed |
| `lsp-server-crashed` | LSP server crashed |
| `lsp-request-timeout` | LSP request timeout |
| `lsp-request-failed` | LSP request failed |
| `plugin-cache-miss` | Plugin cache miss |
| `generic-error` | Generic error |

---

## Development Workflow

### 1. Create Project

```bash
mkdir my-plugin && cd my-plugin
mkdir -p .claude-plugin skills agents hooks
```

### 2. Write plugin.json

```json
{
  "name": "my-plugin",
  "version": "1.0.0",
  "description": "My plugin",
  "author": { "name": "Author" },
  "skills": "./skills",
  "agents": "./agents"
}
```

### 3. Implement Features

```
my-plugin/
├── .claude-plugin/
│   └── plugin.json
├── skills/
│   └── hello/SKILL.md
└── agents/
    └── assistant.md
```

### 4. Test

```bash
# Local testing
claude plugin install ./my-plugin

# Validate plugin
claude plugin validate ./my-plugin
```

---

## Next Steps

- [11.2 Plugin Structure](./02-structure.md) - Detailed directory structure
- [11.3 Plugin API](./03-api.md) - Type reference
- [11.4 Development Examples](./04-examples.md) - Complete examples
