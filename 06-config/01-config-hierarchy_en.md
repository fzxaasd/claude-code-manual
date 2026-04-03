# Configuration Hierarchy

> In-depth analysis of Claude Code's configuration system

## Important: Different Configuration Types Have Different Priority Rules

**Claude Code's different configuration types have different priority rules and cannot be described with a single 6-layer priority system.**

---

## Configuration Sources

Claude Code has 6 configuration sources:

| Source | File Path | Description |
|--------|-----------|-------------|
| User | `~/.claude/settings.json` | Global configuration, shared across all projects |
| Project | `.claude/settings.json` | Project-level configuration, committed to git |
| Local | `.claude/settings.local.json` | Local configuration, gitignored |
| Flag | CLI `--settings` parameter | Temporary configuration |
| Policy | `managed-settings.json` | Enterprise managed configuration (read-only) |
| Plugin | Built-in plugin configuration | Default configuration from plugins |

---

## Priority Rules for Different Configuration Types

**Note**: Source `SETTING_SOURCES` array iterates from **lowest to highest priority**, later items override earlier ones.

All configuration types (Hooks, Permissions, General Settings) use the same priority order:

```
pluginSettings (lowest) → userSettings → projectSettings → localSettings → flagSettings → policySettings (highest)
```

### Special Notes

1. **Permissions Configuration**
   - `projectSettings` is intentionally excluded from `autoMode` config (malicious project injection prevention)
   - When `allowManagedPermissionRulesOnly` is enabled, only policySettings is used

2. **Hooks Configuration**
   - Arrays use "concat-dedupe" merge strategy (concatenate then deduplicate)

3. **autoMode Configuration**
   - Only uses `userSettings`, `localSettings`, `flagSettings`, `policySettings`
   - Excludes `projectSettings` (security reason)

### 4. General Settings Priority

```
pluginSettings (lowest base) → userSettings → projectSettings → localSettings → flagSettings → policySettings (highest)
```

---

## Configuration Path Resolution

```typescript
// From source code src/utils/settings/constants.ts

// User settings
~/.claude/settings.json

// Project settings
<CWD>/.claude/settings.json

// Local settings (gitignored)
<CWD>/.claude/settings.local.json

// Managed settings (platform-dependent)
macOS:    /Library/Application Support/ClaudeCode/managed-settings.json
Windows:  C:\Program Files\ClaudeCode\managed-settings.json
Linux:    /etc/claude-code/managed-settings.json

// Optional drop-in directories (merged alphabetically)
macOS:    /Library/Application Support/ClaudeCode/managed-settings.d/*.json
Windows:  C:\Program Files\ClaudeCode\managed-settings.d\*.json
Linux:    /etc/claude-code/managed-settings.d/*.json
```

---

## CLI Parameters and Configuration Overrides

### --setting-sources Parameter

```bash
# Load only user and project settings
claude --setting-sources user,project

# Load only project settings
claude --setting-sources project

# Default: Load all sources (user, project, local, flag, policy)
claude
```

**Note**: `--setting-sources` only controls user/project/local; flag and policy are always loaded.

### --settings Parameter

```bash
# Load from file
claude --settings /path/to/settings.json

# Load from JSON string
claude --settings '{"hooks":{"PreToolUse":[]}}'
```

### Environment Variables

```bash
# Proxy configuration
export ANTHROPIC_BASE_URL="http://127.0.0.1:5000"
export ANTHROPIC_API_KEY="sk-..."

# Debug mode
export CLAUDE_DEBUG=1
```

---

## Merge Rules

### 1. Top-level Field Override

Higher-level configurations override same-named fields in lower-level configurations:

```json
// userSettings
{
  "effortLevel": "medium",
  "alwaysThinkingEnabled": true
}

// projectSettings
{
  "effortLevel": "high"
}

// Final result
{
  "effortLevel": "high",        // project overrides user
  "alwaysThinkingEnabled": true // user value retained
}
```

### 2. Array Field Merge

Array fields like Hooks and allowedMcpServers are merged:

```json
// userSettings
{
  "hooks": {
    "PreToolUse": [...]
  }
}

// projectSettings
{
  "hooks": {
    "PreToolUse": [...]
  }
}

// Final result
{
  "hooks": {
    "PreToolUse": [...userSettings..., ...projectSettings...]
  }
}
```

### 3. Special Override Fields

Some fields do not merge but override directly:

| Field | Behavior |
|-------|----------|
| `permissions.deny` | Merge (intersection is more restrictive) |
| `permissions.allow` | Merge (union is more permissive) |
| `hooks` | Merge |
| `env` | Merge (environment variables appended) |

---

## Permission Rule Execution Priority

The **execution** priority of permission rules (deny always takes precedence over allow):

```
deny > allow  // deny rules always take precedence
```

### Permission Configuration Load Priority

All configurations use the same priority order:

```
pluginSettings → userSettings → projectSettings → localSettings → flagSettings → policySettings
```

**Note**:
- `projectSettings` is excluded from `autoMode` config (security reason)
- When `allowManagedPermissionRulesOnly` is enabled, only policySettings is used

### Example

```json
// userSettings
{
  "permissions": {
    "allow": ["Bash(git *)"],
    "deny": ["Bash(rm *)"]
  }
}

// projectSettings
{
  "permissions": {
    "allow": ["Bash(git *)", "Bash(npm *)"]
  }
}

// localSettings
{
  "permissions": {
    "deny": ["Bash(rm -rf *)"]
  }
}

// Final permission result
Allowed: Bash(git *), Bash(npm *)
Denied: Bash(rm *), Bash(rm -rf *)  // deny rules take precedence
```

---

## Configuration Validation

### Schema URL

Claude Code uses JSON Schema:

```json
{
  "$schema": "https://json.schemastore.org/claude-code-settings.json"
}
```

### Validation Tips

```bash
# Open configuration editor
claude /config

# View configuration issues
# In Claude Code, type /doctor
```

---

## Team Collaboration Recommendations

### 1. Project-level Configuration (.claude/settings.json)

```json
{
  "$schema": "https://json.schemastore.org/claude-code-settings.json",
  "permissions": {
    "allow": ["Bash(git *)", "Bash(npm:*)", "Bash(npx:*)"],
    "deny": ["Bash(rm -rf /)"]
  },
  "hooks": {
    "PreToolUse": [...]
  },
  "extraKnownMarketplaces": {
    "internal": {
      "source": {
        "type": "github",
        "repo": "your-org/claude-plugins"
      }
    }
  }
}
```

### 2. Local Ignore Configuration (.gitignore)

```
.claude/settings.local.json
.claude/sessions/
```

### 3. Fields That Should Not Be Committed

```json
{
  // Should be committed
  "permissions": {...},
  "hooks": {...},
  "extraKnownMarketplaces": {...},

  // Should NOT be committed
  "env": {
    "API_KEY": "..."
  },
  "pluginConfigs": {...}
}
```

---

## Debugging Configuration

### View Loaded Configuration

```bash
# Debug mode
claude --debug settings

# View parsed configuration
claude -p --debug
```

### Common Issues

1. **Configuration Not Taking Effect**
   - Check if file path is correct
   - Check JSON syntax
   - Confirm configuration source priority

2. **Configuration Conflict**
   - Use `--debug settings` to view merge results
   - Confirm if higher priority is overriding

3. **Permission Issues**
   - Check if locked in policySettings
   - Use `--setting-sources` to limit loaded sources
