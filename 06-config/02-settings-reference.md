# settings.json 完整字段参考

> 基于源码 `src/utils/settings/types.ts` 的完整字段清单

## 配置来源

Claude Code 有 5 种配置来源，按优先级从高到低：

```
policySettings (managed) > flagSettings > localSettings > projectSettings > userSettings
```

---

## 完整字段列表

```json
{
  "$schema": "https://json.schemastore.org/claude-code-settings.json",

  // === 认证与凭证 ===
  "apiKeyHelper": "path/to/script",
  "env": { "KEY": "value" },
  "awsCredentialExport": "path/to/script",
  "awsAuthRefresh": "path/to/script",
  "gcpAuthRefresh": "command",
  "otelHeadersHelper": "path/to/script",

  // === 会话管理 ===
  "cleanupPeriodDays": 30,
  "autoMemoryEnabled": true,
  "autoMemoryDirectory": "path",
  "autoDreamEnabled": true,

  // === 模型配置 ===
  "model": "claude-sonnet-4-6",
  "availableModels": ["opus", "sonnet"],
  "modelOverrides": { "claude-opus-4-6": "bedrock/..." },
  "advisorModel": "sonnet",

  // === 行为控制 ===
  "alwaysThinkingEnabled": true,
  "effortLevel": "medium",
  "fastMode": false,
  "fastModePerSessionOptIn": false,
  "promptSuggestionEnabled": true,
  "showClearContextOnPlanAccept": false,
  "skipDangerousModePermissionPrompt": false, // 已接受过 bypass 权限模式确认（状态标记）

  // === 输出与显示 ===
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

  // === 权限配置 ===
  "permissions": {
    "allow": ["Read", "Bash(git *)"],
    "deny": ["Bash(rm -rf *)"],
    "ask": [],
    "defaultMode": "default",
    "disableBypassPermissionsMode": "disable",
    "additionalDirectories": ["path"]
  },

  // === 自动模式 (TRANSCRIPT_CLASSIFIER feature-gated) ===
  "disableAutoMode": "disable",  // 禁用自动模式（ANT 用户）

  // === Hooks ===
  "hooks": {
    "PreToolUse": [...],
    "PostToolUse": [...],
    "UserPromptSubmit": [...]
  },
  "disableAllHooks": false,
  "allowManagedHooksOnly": false,
  "allowedHttpHookUrls": ["https://..."],
  "httpHookAllowedEnvVars": ["AUTH_TOKEN"],

  // === MCP 服务器 ===
  "enableAllProjectMcpServers": true,
  "enabledMcpjsonServers": ["server1"],
  "disabledMcpjsonServers": ["server2"],
  "allowedMcpServers": [{ "serverName": "name" }],
  "deniedMcpServers": [{ "serverName": "name" }],
  "allowManagedMcpServersOnly": false,

  // === 插件 ===
  "enabledPlugins": { "plugin@marketplace": true },
  "extraKnownMarketplaces": { "name": {...} },
  "strictKnownMarketplaces": [...],
  "blockedMarketplaces": [...],
  "pluginConfigs": { "pluginId": { "options": {...} } },
  "pluginTrustMessage": "message",
  "strictPluginOnlyCustomization": ["skills", "agents", "hooks", "mcp"],

  // === Skills ===
  "skills": { ... },

  // === Agent 选择 ===
  "agent": "agent-name",

  // === Worktree ===
  "worktree": {
    "symlinkDirectories": ["node_modules"],
    "sparsePaths": ["src/**"]
  },

  // === SSH 配置 ===
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

  // === Auto Mode（⚠️ TRANSCRIPT_CLASSIFIER feature-gated，仅 ANT 用户）===
  "autoMode": {
    "allow": ["Bash(git *)"],
    "soft_deny": ["Bash(rm *)"],
    "environment": []
  },
  "useAutoModeDuringPlan": true,  // ⚠️ TRANSCRIPT_CLASSIFIER feature-gated
  "skipAutoPermissionPrompt": false,  // ⚠️ TRANSCRIPT_CLASSIFIER feature-gated
  "disableAutoMode": "disable",  // ⚠️ 顶层字段，不是 permissions 子字段

  // === 安全 ===
  "skipWebFetchPreflight": false,
  "skipDangerousModePermissionPrompt": false,
  "allowManagedPermissionRulesOnly": false,

  // === Sandbox ===
  "sandbox": {
    "filesystem": { ... },
    "network": { ... }
  },

  // === 更新 ===
  "autoUpdatesChannel": "latest",
  "minimumVersion": "2.0.0",

  // === 文件建议 ===
  "fileSuggestion": {
    "type": "command",
    "command": "path/to/script"
  },
  "respectGitignore": true,

  // === 其他 ===
  "defaultShell": "bash",
  "companyAnnouncements": ["message"],
  "feedbackSurveyRate": 0.05,
  "plansDirectory": "~/.claude/plans/",
  "claudeMdExcludes": ["**/sensitive/**"],

  // === 远程与状态栏 ===
  "statusLine": {
    "type": "command",
    "command": "my-status",
    "padding": 1
  }
}
```

---

## 字段分类详解

### 1. 认证与凭证

| 字段 | 类型 | 说明 |
|------|------|------|
| `apiKeyHelper` | string | API Key 辅助脚本路径 |
| `awsCredentialExport` | string | AWS 凭证导出脚本 |
| `awsAuthRefresh` | string | AWS 认证刷新脚本 |
| `gcpAuthRefresh` | string | GCP 认证刷新命令 |
| `otelHeadersHelper` | string | OpenTelemetry 头部辅助脚本 |
| `env` | object | 环境变量映射 |

### 2. 会话管理

| 字段 | 类型 | 默认 | 说明 |
|------|------|------|------|
| `cleanupPeriodDays` | number | 30 | 会话保留天数，0=禁用 |
| `autoMemoryEnabled` | boolean | - | 启用自动记忆 |
| `autoMemoryDirectory` | string | - | 自动记忆目录 |
| `autoDreamEnabled` | boolean | - | 背景记忆整合 |

### 3. 模型配置

| 字段 | 类型 | 说明 |
|------|------|------|
| `model` | string | 默认模型 |
| `availableModels` | string[] | 可用模型白名单 |
| `modelOverrides` | object | 模型 ID 映射（Bedrock 等） |
| `advisorModel` | string | 顾问模型 |

### 4. 行为控制

| 字段 | 类型 | 默认 | 说明 |
|------|------|------|------|
| `alwaysThinkingEnabled` | boolean | true | 启用思考 |
| `effortLevel` | enum | medium | low/medium/high |
| `fastMode` | boolean | false | 快速模式 |
| `promptSuggestionEnabled` | boolean | true | 提示建议 |

### 5. 权限配置

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

| 权限字段 | 类型 | 说明 |
|----------|------|------|
| `allow` | string[] | 允许的操作 |
| `deny` | string[] | 禁止的操作 |
| `ask` | string[] | 始终询问的操作 |
| `defaultMode` | enum | 默认权限模式 (default/acceptEdits/bypassPermissions/dontAsk/plan/auto) |
| `disableBypassPermissionsMode` | "disable" | 禁用绕过权限模式 |
| `additionalDirectories` | string[] | 额外允许访问的目录 |

> **注意**: `disableAutoMode` 是**顶层字段**，不是 `permissions` 的子字段。 |

> **注意**: `defaultMode: "auto"` 是 TRANSCRIPT_CLASSIFIER feature-gated，仅 ANT 用户可用。

> **数组合并语义**: 权限数组（allow/deny/ask）在多级配置中采用"拼接去重"合并策略。

### 6. Hooks 配置

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

### 7. MCP 服务器配置

```json
"allowedMcpServers": [
  { "serverName": "github" },
  { "serverCommand": ["npx", "@modelcontextprotocol/server-github"] },
  { "serverUrl": "https://*.example.com/*" }
]
```

> **MCP 服务器来源**:
> - `.mcp.json` 文件定义 MCP 服务器
> - `enabledMcpjsonServers` / `disabledMcpjsonServers` 控制启用/禁用
> - `allowedMcpServers` / `deniedMcpServers` 是企业白名单/黑名单
> - `allowManagedMcpServersOnly` 控制是否仅使用托管 MCP

### 8. 插件配置

```json
"enabledPlugins": {
  "formatter@anthropic-tools": true
},
"strictPluginOnlyCustomization": ["skills", "hooks"]
```

### 9. Worktree 配置

```json
"worktree": {
  "symlinkDirectories": ["node_modules", ".cache"],
  "sparsePaths": ["src/**", "docs/**"]
}
```

### 10. SSH 配置

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

### 11. Auto Mode 配置（⚠️ TRANSCRIPT_CLASSIFIER feature-gated，仅 ANT 用户）

```json
"autoMode": {
  "allow": ["Bash(git status)", "Bash(git diff)"],
  "soft_deny": ["Bash(rm *)"],
  "environment": ["SAFE_MODE=true"]
}
```

| 字段 | 说明 |
|------|------|
| `autoMode` | 自动权限模式配置 |
| `useAutoModeDuringPlan` | 规划阶段启用自动模式 |
| `skipAutoPermissionPrompt` | 跳过自动模式权限确认 |
| `disableAutoMode` | 设置为 `"disable"` 可完全禁用自动模式（**顶层字段**） |

### 12. 企业管理配置

| 字段 | 类型 | 说明 |
|------|------|------|
| `allowManagedHooksOnly` | boolean | 仅使用管理 Hooks |
| `allowManagedPermissionRulesOnly` | boolean | 仅使用管理权限 |
| `allowManagedMcpServersOnly` | boolean | 仅使用管理 MCP |
| `strictKnownMarketplaces` | array | 允许的市场 |
| `blockedMarketplaces` | array | 禁止的市场 |
| `pluginTrustMessage` | string | 插件信任消息 |

### 13. 其他设置

| 字段 | 类型 | 默认 | 说明 |
|------|------|------|------|
| `defaultShell` | string | - | 默认 shell |
| `claudeMdExcludes` | string[] | - | 排除加载的 CLAUDE.md 路径（glob 模式） |
| `fastModePerSessionOptIn` | boolean | false | Fast mode 不跨会话持久化 |
| `classifierPermissionsEnabled` | boolean | - | ⚠️ Bash(prompt:...) AI 分类权限（TRANSCRIPT_CLASSIFIER feature-gated，ANT 用户） |
| `voiceEnabled` | boolean | - | ⚠️ 语音模式（需 VOICE_MODE feature） |
| `channelsEnabled` | boolean | - | ⚠️ 团队/企业渠道通知（需 KAIROS_CHANNELS feature） |
| `forceLoginMethod` | 'claudeai' \\| 'console' | - | 强制登录方式 |
| `companyAnnouncements` | string[] | - | 公司公告 |
| `feedbackSurveyRate` | number | - | 反馈调查频率 |
| `plansDirectory` | string | ~/.claude/plans/ | 计划文件目录 |

---

## 未文档化的配置选项

> 以下选项存在于源码中但未在官方文档中记录

### Feature-Gated 配置

| 字段 | 类型 | Feature Gate | 说明 |
|------|------|--------------|------|
| `xaaIdp` | object | CLAUDE_CODE_ENABLE_XAA | XAA (SEP-990) IdP 连接配置 |
| `disableDeepLinkRegistration` | "disable" | LODESTONE | 防止向 OS 注册 claude-cli:// 协议处理器 |
| `classifierPermissionsEnabled` | boolean | ANT 用户 | 为 Bash(prompt:...) 启用 AI 分类权限 |
| `minSleepDurationMs` | number | PROACTIVE/KAIROS | Sleep 工具最小睡眠时长(毫秒) |
| `maxSleepDurationMs` | number | PROACTIVE/KAIROS | Sleep 工具最大睡眠时长(毫秒)，-1=无限 |
| `voiceEnabled` | boolean | VOICE_MODE | 启用语音模式（按住说话） |
| `assistant` | boolean | KAIROS | 以助手模式启动 Claude |
| `assistantName` | string | KAIROS | 助手显示名称 |
| `defaultView` | "chat" \| "transcript" | KAIROS/KAIROS_BRIEF | 默认转录视图 |

### SSH 配置

| 字段 | 类型 | 说明 |
|------|------|------|
| `sshConfigs` | array | SSH 连接配置数组 |

**sshConfigs 结构**:
```typescript
{
  id: string,                   // 唯一标识符
  name: string,                 // 配置名称
  sshHost: string,              // SSH 主机
  sshPort?: number,             // SSH 端口，默认 22
  sshIdentityFile?: string,     // SSH 私钥路径
  startDirectory?: string,     // 启动目录
}
```

### XAA IdP 配置

```typescript
{
  issuer: string,           // IdP issuer URL (必需)
  clientId: string,         // OAuth client ID (必需)
  callbackPort?: number,     // 固定回调端口 (可选)
}
```

### 渠道插件白名单

| 字段 | 类型 | 说明 |
|------|------|------|
| `allowedChannelPlugins` | array | 团队/企业渠道插件白名单 |

```typescript
{
  marketplace: string,  // 市场名称
  plugin: string,      // 插件名称
}
```

### PROACTIVE/KAIROS Sleep 配置

```json
{
  "minSleepDurationMs": 1000,      // 最小睡眠时长
  "maxSleepDurationMs": 60000      // 最大睡眠时长，-1=无限等待
}
```

---

## 企业配置示例

### 最小权限团队

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

### 开发者友好配置

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

## 权限规则语法

| 格式 | 示例 | 说明 |
|------|------|------|
| `ToolName` | `Bash` | 整个工具 |
| `ToolName(operation)` | `Bash(git *)` | 匹配操作 |
| `ToolName(!operation)` | `Read(!*.json)` | 排除操作 |
| `mcp__server__tool` | `mcp__github__*` | MCP 工具 |

---

## 配置 Schema

官方 JSON Schema: https://json.schemastore.org/claude-code-settings.json

```json
{
  "$schema": "https://json.schemastore.org/claude-code-settings.json"
}
```

---

## 测试验证

运行测试脚本验证配置：
```bash
bash tests/02-config-test.sh
```
