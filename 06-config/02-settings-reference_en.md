# settings.json Complete Field Reference

> Complete field list based on source code `src/utils/settings/types.ts`

## Configuration Sources

Claude Code has 5 configuration sources, ordered by priority (highest to lowest):

```
policySettings (managed) > flagSettings > localSettings > projectSettings > userSettings
```

---

## Complete Field List

```json
{
  "$schema": "https://json.schemastore.org/claude-code-settings.json",

  // === Authentication & Credentials ===
  "apiKeyHelper": "path/to/script",
  "env": { "KEY": "value" },
  "awsCredentialExport": "path/to/script",
  "awsAuthRefresh": "path/to/script",
  "gcpAuthRefresh": "command",
  "otelHeadersHelper": "path/to/script",

  // === Session Management ===
  "cleanupPeriodDays": 30,
  "autoMemoryEnabled": true,
  "autoMemoryDirectory": "path",
  "autoDreamEnabled": true,

  // === Model Configuration ===
  "model": "claude-sonnet-4-6",
  "availableModels": ["opus", "sonnet"],
  "modelOverrides": { "claude-opus-4-6": "bedrock/..." },
  "advisorModel": "sonnet",

  // === Behavior Control ===
  "alwaysThinkingEnabled": true,
  "effortLevel": "medium",
  "fastMode": false,
  "fastModePerSessionOptIn": false,
  "promptSuggestionEnabled": true,
  "showClearContextOnPlanAccept": false,
  "skipDangerousModePermissionPrompt": false,

  // === Output & Display ===
  "outputStyle": "default",
  "language": "chinese",
  "syntaxHighlightingDisabled": false,
  "showThinkingSummaries": false,
  "terminalTitleFromRename": true,
  "prefersReducedMotion": false,

  // === Spinner ===
  "spinnerTipsEnabled": true,
  "spinnerVerbs": {
    "mode": "append",
    "verbs": ["thinking", "analyzing"]
  },
  "spinnerTipsOverride": {
    "excludeDefault": false,
    "tips": ["tip1", "tip2"]
  },

  // === Permission Configuration ===
  "permissions": {
    "allow": ["Read", "Bash(git *)"],
    "deny": ["Bash(rm -rf *)"],
    "ask": [],
    "defaultMode": "default",
    "disableBypassPermissionsMode": "disable",
    "additionalDirectories": ["path"]
  },

  // === Auto Mode (TRANSCRIPT_CLASSIFIER feature-gated) ===
  "disableAutoMode": "disable",

  // === Hooks ===
  "hooks": {
    "PreToolUse": [...],
    "PostToolUse": [...],
    "PostToolUseFailure": [...],
    "Notification": [...],
    "UserPromptSubmit": [...],
    "SessionStart": [...],
    "SessionEnd": [...],
    "Stop": [...],
    "StopFailure": [...],
    "SubagentStart": [...],
    "SubagentStop": [...],
    "PreCompact": [...],
    "PostCompact": [...],
    "PermissionRequest": [...],
    "PermissionDenied": [...],
    "Setup": [...],
    "TeammateIdle": [...],
    "TaskCreated": [...],
    "TaskCompleted": [...],
    "Elicitation": [...],
    "ElicitationResult": [...],
    "ConfigChange": [...],
    "WorktreeCreate": [...],
    "WorktreeRemove": [...],
    "InstructionsLoaded": [...],
    "CwdChanged": [...],
    "FileChanged": [...]
  },
  "disableAllHooks": false,
  "allowManagedHooksOnly": false,
  "allowedHttpHookUrls": ["https://..."],
  "httpHookAllowedEnvVars": ["AUTH_TOKEN"],

  // === MCP Servers ===
  "enableAllProjectMcpServers": true,
  "enabledMcpjsonServers": ["server1"],
  "disabledMcpjsonServers": ["server2"],
  "allowedMcpServers": [{ "serverName": "name" }],
  "deniedMcpServers": [{ "serverName": "name" }],
  "allowManagedMcpServersOnly": false,

  // === Plugins ===
  "enabledPlugins": { "plugin@marketplace": true },
  "extraKnownMarketplaces": { "name": {...} },
  "strictKnownMarketplaces": [...],
  "blockedMarketplaces": [...],
  "pluginConfigs": { "pluginId": { "options": {...} } },
  "pluginTrustMessage": "message",
  "strictPluginOnlyCustomization": ["skills", "agents", "hooks", "mcp"],

  // === Skills ===
  "skills": { ... },

  // === Agent Selection ===
  "agent": "agent-name",

  // === Worktree ===
  "worktree": {
    "symlinkDirectories": ["node_modules"],
    "sparsePaths": ["src/**"]
  },

  // === SSH Configuration ===
  "sshConfigs": [{
    "id": "unique-id",
    "name": "Display Name",
    "sshHost": "user@hostname",
    "sshPort": 22,
    "sshIdentityFile": "path",
    "startDirectory": "~/projects"
  }],

  // === Remote ===
  "remote": {
    "defaultEnvironmentId": "env-id"
  },

  // === Attribution ===
  "attribution": {
    "commit": "Co-authored-by: ...",
    "pr": "Co-authored-by: ..."
  },
  "includeCoAuthoredBy": false,
  "includeGitInstructions": true,

  // === Auto Mode (TRANSCRIPT_CLASSIFIER feature-gated, ANT users only) ===
  "autoMode": {
    "allow": ["Bash(git *)"],
    "soft_deny": ["Bash(rm *)"],
    "environment": []
  },
  "useAutoModeDuringPlan": true,
  "skipAutoPermissionPrompt": false,
  "disableAutoMode": "disable",

  // === Security ===
  "skipWebFetchPreflight": false,
  "skipDangerousModePermissionPrompt": false,
  "allowManagedPermissionRulesOnly": false,

  // === Sandbox ===
  "sandbox": {
    "filesystem": { ... },
    "network": { ... }
  },

  // === Updates ===
  "autoUpdatesChannel": "latest",
  "minimumVersion": "2.0.0",

  // === File Suggestions ===
  "fileSuggestion": {
    "type": "command",
    "command": "path/to/script"
  },
  "respectGitignore": true,

  // === Other ===
  "defaultShell": "bash",
  "companyAnnouncements": ["message"],
  "feedbackSurveyRate": 0.05,
  "plansDirectory": "~/.claude/plans/",
  "claudeMdExcludes": ["**/sensitive/**"],

  // === Remote & Status Bar ===
  "statusLine": {
    "type": "command",
    "command": "my-status",
    "padding": 1
  }
}
```

---

## Field Categories Detail

### 1. Authentication & Credentials

| Field | Type | Description |
|-------|------|-------------|
| `apiKeyHelper` | string | API Key helper script path |
| `awsCredentialExport` | string | AWS credential export script |
| `awsAuthRefresh` | string | AWS auth refresh script |
| `gcpAuthRefresh` | string | GCP auth refresh command |
| `otelHeadersHelper` | string | OpenTelemetry headers helper script |
| `env` | object | Environment variable mapping |

### 2. Session Management

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `cleanupPeriodDays` | number | 30 | Session retention days, 0=disabled |
| `autoMemoryEnabled` | boolean | - | Enable automatic memory |
| `autoMemoryDirectory` | string | - | Automatic memory directory |
| `autoDreamEnabled` | boolean | - | Background memory integration |

### 3. Model Configuration

| Field | Type | Description |
|-------|------|-------------|
| `model` | string | Default model |
| `availableModels` | string[] | Available model whitelist |
| `modelOverrides` | object | Model ID mapping (Bedrock, etc.) |
| `advisorModel` | string | Advisor model |

### 4. Behavior Control

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `alwaysThinkingEnabled` | boolean | true | Enable thinking |
| `effortLevel` | enum | medium | low/medium/high |
| `fastMode` | boolean | false | Fast mode |
| `promptSuggestionEnabled` | boolean | true | Prompt suggestions |

### 5. Permission Configuration

```json
"permissions": {
  "allow": ["Bash(git *)"],
  "deny": ["Bash(rm -rf /*)"],
  "ask": ["Bash(curl *)"],
  "defaultMode": "default",
  "disableBypassPermissionsMode": "disable",
  "additionalDirectories": ["/tmp/work"]
}
```

| Permission Field | Type | Description |
|------------------|------|-------------|
| `allow` | string[] | Allowed operations |
| `deny` | string[] | Denied operations |
| `ask` | string[] | Operations that always prompt |
| `defaultMode` | enum | Default permission mode (default/acceptEdits/bypassPermissions/dontAsk/plan/auto) |
| `disableBypassPermissionsMode` | "disable" | Disable bypass permissions mode |
| `additionalDirectories` | string[] | Additional allowed directories |

> **Note**: `disableAutoMode` is a **top-level field**, not a subfield of `permissions`.

> **Note**: `defaultMode: "auto"` is TRANSCRIPT_CLASSIFIER feature-gated, available only to ANT users.

> **Array Merge Semantics**: Permission arrays (allow/deny/ask) use "concat-dedupe" merge strategy across multiple config levels.

### 6. Hooks Configuration

```json
"hooks": {
  "PreToolUse": [
    {
      "matcher": "Bash",
      "hooks": [
        {
          "type": "command",
          "command": "python3 security.py",
          "if": "Bash(git *)",
          "timeout": 5
        }
      ]
    }
  ]
}
```

### 7. MCP Server Configuration

```json
"allowedMcpServers": [
  { "serverName": "github" },
  { "serverCommand": ["npx", "@modelcontextprotocol/server-github"] },
  { "serverUrl": "https://*.example.com/*" }
]
```

> **MCP Server Sources**:
> - `.mcp.json` files define MCP servers
> - `enabledMcpjsonServers` / `disabledMcpjsonServers` control enable/disable
> - `allowedMcpServers` / `deniedMcpServers` are enterprise whitelist/blacklist
> - `allowManagedMcpServersOnly` controls whether to use managed MCP only

### 8. Plugin Configuration

```json
"enabledPlugins": {
  "formatter@anthropic-tools": true
},
"strictPluginOnlyCustomization": ["skills", "agents", "hooks", "mcp"]
```

### 9. Worktree Configuration

```json
"worktree": {
  "symlinkDirectories": ["node_modules", ".cache"],
  "sparsePaths": ["src/**", "docs/**"]
}
```

### 10. SSH Configuration

```json
"sshConfigs": [
  {
    "id": "prod",
    "name": "Production",
    "sshHost": "admin@prod.example.com",
    "sshIdentityFile": "~/.ssh/prod_key",
    "startDirectory": "~/projects"
  }
]
```

### 11. Auto Mode Configuration (TRANSCRIPT_CLASSIFIER feature-gated, ANT users only)

```json
"autoMode": {
  "allow": ["Bash(git status)", "Bash(git diff)"],
  "soft_deny": ["Bash(rm *)"],
  "environment": ["SAFE_MODE=true"]
}
```

| Field | Description |
|-------|-------------|
| `autoMode` | Auto permission mode configuration |
| `useAutoModeDuringPlan` | Enable auto mode during planning |
| `skipAutoPermissionPrompt` | Skip auto mode permission confirmation |
| `disableAutoMode` | Set to `"disable"` to completely disable auto mode (**top-level field**) |

### 12. Enterprise Management Configuration

| Field | Type | Description |
|-------|------|-------------|
| `allowManagedHooksOnly` | boolean | Use managed hooks only |
| `allowManagedPermissionRulesOnly` | boolean | Use managed permissions only |
| `allowManagedMcpServersOnly` | boolean | Use managed MCP only |
| `strictKnownMarketplaces` | array | Allowed marketplaces |
| `blockedMarketplaces` | array | Blocked marketplaces |
| `pluginTrustMessage` | string | Plugin trust message |

### 13. Other Settings

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `defaultShell` | string | - | Default shell |
| `claudeMdExcludes` | string[] | - | CLAUDE.md paths to exclude from loading (glob patterns) |
| `fastModePerSessionOptIn` | boolean | false | Fast mode does not persist across sessions |
| `classifierPermissionsEnabled` | boolean | - | Bash(prompt:...) AI classification permissions (TRANSCRIPT_CLASSIFIER feature-gated, ANT users) |
| `voiceEnabled` | boolean | - | Voice mode (requires VOICE_MODE feature) |
| `channelsEnabled` | boolean | - | Team/Enterprise channel notifications (requires KAIROS_CHANNELS feature) |
| `forceLoginMethod` | 'claudeai' \| 'console' | - | Force login method |
| `companyAnnouncements` | string[] | - | Company announcements |
| `feedbackSurveyRate` | number | - | Feedback survey frequency |
| `plansDirectory` | string | ~/.claude/plans/ | Plan files directory |

---

## Undocumented Configuration Options

> The following options exist in source code but are not officially documented

### Feature-Gated Configuration

| Field | Type | Feature Gate | Description |
|-------|------|--------------|-------------|
| `xaaIdp` | object | CLAUDE_CODE_ENABLE_XAA | XAA (SEP-990) IdP connection config |
| `disableDeepLinkRegistration` | "disable" | LODESTONE | Prevent OS from registering claude-cli:// protocol handler |
| `classifierPermissionsEnabled` | boolean | ANT users | Enable AI classification for Bash(prompt:...) permission rules |
| `minSleepDurationMs` | number | PROACTIVE/KAIROS | Minimum sleep duration in milliseconds for Sleep tool |
| `maxSleepDurationMs` | number | PROACTIVE/KAIROS | Maximum sleep duration in milliseconds, -1=indefinite |
| `voiceEnabled` | boolean | VOICE_MODE | Enable voice mode (hold-to-talk) |
| `assistant` | boolean | KAIROS | Start Claude in assistant mode |
| `assistantName` | string | KAIROS | Assistant display name |
| `defaultView` | "chat" \| "transcript" | KAIROS/KAIROS_BRIEF | Default transcript view |

### SSH Configuration

| Field | Type | Description |
|-------|------|-------------|
| `sshConfigs` | array | SSH connection configuration array |

**sshConfigs structure**:
```typescript
{
  id: string,                   // Unique identifier
  name: string,                 // Configuration name
  sshHost: string,              // SSH host
  sshPort?: number,             // SSH port, default 22
  sshIdentityFile?: string,      // SSH private key path
  startDirectory?: string,       // Start directory
}
```

### XAA IdP Configuration

```typescript
{
  issuer: string,           // IdP issuer URL (required)
  clientId: string,         // OAuth client ID (required)
  callbackPort?: number,     // Fixed callback port (optional)
}
```

### Channel Plugin Allowlist

| Field | Type | Description |
|-------|------|-------------|
| `allowedChannelPlugins` | array | Teams/Enterprise channel plugin allowlist |

```typescript
{
  marketplace: string,  // Marketplace name
  plugin: string,       // Plugin name
}
```

### PROACTIVE/KAIROS Sleep Configuration

```json
{
  "minSleepDurationMs": 1000,      // Minimum sleep duration
  "maxSleepDurationMs": 60000     // Maximum sleep duration, -1=wait indefinitely
}
```

---

## Enterprise Configuration Examples

### Minimum Permission Team

```json
{
  "$schema": "https://json.schemastore.org/claude-code-settings.json",
  "permissions": {
    "allow": [
      "Bash(git status)",
      "Bash(git diff)",
      "Bash(git log *)",
      "Read",
      "Glob",
      "Grep"
    ],
    "deny": [
      "Bash(sudo *)",
      "Bash(rm *)",
      "Write",
      "Edit"
    ],
    "defaultMode": "default"
  },
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          { "type": "command", "command": "security-check.sh", "timeout": 5 }
        ]
      }
    ]
  }
}
```

### Developer-Friendly Configuration

```json
{
  "permissions": {
    "allow": [
      "Bash(git *)",
      "Bash(npm *)",
      "Bash(node *)",
      "Bash(pnpm *)",
      "Bash(yarn *)",
      "Bash(bun *)",
      "Read",
      "Write",
      "Edit",
      "Glob",
      "Grep"
    ],
    "deny": [
      "Bash(sudo *)",
      "Bash(:(){:|:&};:)"
    ]
  },
  "autoUpdatesChannel": "latest",
  "alwaysThinkingEnabled": true
}
```

---

## Permission Rule Syntax

| Format | Example | Description |
|--------|---------|-------------|
| `ToolName` | `Bash` | Entire tool |
| `ToolName(operation)` | `Bash(git *)` | Match operation |
| `ToolName(!operation)` | `Read(!*.json)` | Exclude operation |
| `mcp__server__tool` | `mcp__github__*` | MCP tool |

---

## Configuration Schema

Official JSON Schema: https://json.schemastore.org/claude-code-settings.json

```json
{
  "$schema": "https://json.schemastore.org/claude-code-settings.json"
}
```

---

## Testing & Validation

Run the test script to validate configuration:
```bash
bash tests/02-config-test.sh
```
