# 配置层次结构

> Claude Code 配置系统深度解析

## 重要说明：不同配置类型有不同的优先级

**Claude Code 的不同配置类型有不同的优先级规则，不能用单一的 6 层优先级描述。**

---

## 配置来源

Claude Code 有 6 种配置来源：

| 来源 | 文件路径 | 说明 |
|------|----------|------|
| User | `~/.claude/settings.json` | 全局配置，所有项目共享 |
| Project | `.claude/settings.json` | 项目级配置，提交到 git |
| Local | `.claude/settings.local.json` | 本地配置，gitignored |
| Flag | CLI `--settings` 参数 | 临时配置 |
| Policy | `managed-settings.json` | 企业管理配置（只读） |
| Plugin | 插件内置配置 | 来自插件的默认配置 |

---

## 不同配置类型的优先级规则

**注意**: 源码 `SETTING_SOURCES` 数组定义了 5 个配置来源（从低到高）：`user` / `project` / `local` / `flag` / `policy`。`pluginSettings` 是特殊的基础层，由 `getPluginSettingsBase()` 返回，在 `loadSettingsFromDisk()` 中先加载作为最低优先级基础。

所有配置类型（Hooks、Permissions、General Settings）使用相同的优先级顺序：

```
pluginSettings (最低基础层) → userSettings → projectSettings → localSettings → flagSettings → policySettings (最高)
```

### SETTING_SOURCES 常量

```typescript
// src/utils/settings/constants.ts
export const SETTING_SOURCES = ['userSettings', 'projectSettings', 'localSettings', 'flagSettings', 'policySettings'] as const
```

> **注意**：pluginSettings 不是 SETTING_SOURCES 的一部分，而是通过 `getPluginSettingsBase()` 单独加载。

### 特殊说明

1. **Permissions 权限配置**
   - `projectSettings` 出于安全原因被排除在 `autoMode` 配置之外（防止恶意项目注入）
   - 当 `allowManagedPermissionRulesOnly` 开启时，仅使用 policySettings

2. **Hooks 配置**
   - 数组使用"concat-dedupe"合并策略（拼接后去重）

3. **autoMode 配置**
   - 仅使用 `userSettings`、`localSettings`、`flagSettings`、`policySettings`
   - 排除 `projectSettings`（安全原因）

### 4. General Settings 优先级

```
pluginSettings (最低基础层) → userSettings → projectSettings → localSettings → flagSettings → policySettings (最高)
```

---

## 配置路径解析

```typescript
// 从源码 src/utils/settings/constants.ts

// 用户设置
~/.claude/settings.json

// 项目设置
<CWD>/.claude/settings.json

// 本地设置（gitignored）
<CWD>/.claude/settings.local.json

// 管理设置 (平台相关)
macOS:    /Library/Application Support/ClaudeCode/managed-settings.json
Windows:  C:\Program Files\ClaudeCode\managed-settings.json
Linux:    /etc/claude-code/managed-settings.json

// 可选的 drop-in 目录 (按字母顺序合并)
macOS:    /Library/Application Support/ClaudeCode/managed-settings.d/*.json
Windows:  C:\Program Files\ClaudeCode\managed-settings.d\*.json
Linux:    /etc/claude-code/managed-settings.d/*.json
```

---

## CLI 参数与配置覆盖

### --setting-sources 参数

```bash
# 只加载 user 和 project 设置
claude --setting-sources user,project

# 只加载 project 设置
claude --setting-sources project

# 默认：加载所有来源 (user, project, local, flag, policy)
claude
```

**注意**: `--setting-sources` 只控制 user/project/local，flag 和 policy 始终加载。

### --settings 参数

```bash
# 从文件加载
claude --settings /path/to/settings.json

# 从 JSON 字符串加载
claude --settings '{"hooks":{"PreToolUse":[]}}'
```

### 环境变量

```bash
# 代理配置
export ANTHROPIC_BASE_URL="http://127.0.0.1:5000"
export ANTHROPIC_API_KEY="sk-..."

# 调试模式
export CLAUDE_DEBUG=1
```

---

## 合并规则

### 1. 顶层字段覆盖

高层配置覆盖低层配置的同名字段：

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

// 最终结果
{
  "effortLevel": "high",        // project 覆盖 user
  "alwaysThinkingEnabled": true // 保留 user
}
```

### 2. 数组字段合并

Hooks、allowedMcpServers 等数组字段会合并：

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

// 最终结果
{
  "hooks": {
    "PreToolUse": [...userSettings..., ...projectSettings...]
  }
}
```

### 3. 特殊覆盖字段

部分字段使用特殊合并策略：

| 字段 | 行为 |
|------|------|
| `permissions.deny` | 拼接去重（所有 deny 规则合并） |
| `permissions.allow` | 拼接去重（所有 allow 规则合并） |
| `hooks` | 拼接去重（所有 hooks 合并） |
| `env` | 深度合并（环境变量追加） |

> **注意**: 所有数组字段（包括 permissions.allow/deny/ask、hooks 等）在配置合并时使用相同的"拼接去重"策略（源码 `settingsMergeCustomizer`），即 `uniq([...targetArray, ...sourceArray])`。不存在交集/差集合并。运行时 deny 规则总是优先于 allow 规则。

---

## 权限规则执行优先级

权限规则的**执行**优先级（deny 总是优先于 allow）：

```
deny > allow  // deny 规则总是优先
```

### 权限配置的加载优先级

所有配置使用相同的优先级顺序：

```
pluginSettings → userSettings → projectSettings → localSettings → flagSettings → policySettings
```

**注意**：
- `projectSettings` 被排除在 `autoMode` 配置之外（安全原因）
- 当 `allowManagedPermissionRulesOnly` 开启时，仅使用 policySettings

### 示例

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

// 最终权限结果
允许: Bash(git *), Bash(npm *)
拒绝: Bash(rm *), Bash(rm -rf *)  // deny 规则优先
```

---

## 配置验证

### Schema URL

Claude Code 使用 JSON Schema：

```json
{
  "$schema": "https://json.schemastore.org/claude-code-settings.json"
}
```

### 验证提示

```bash
# 打开配置编辑器
claude /config

# 查看配置问题
# 在 Claude Code 中输入 /doctor
```

---

## 团队协作建议

### 1. 项目级配置 (.claude/settings.json)

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

### 2. 本地忽略配置 (.gitignore)

```
.claude/settings.local.json
.claude/sessions/
```

### 3. 不应提交的字段

```json
{
  // ✅ 应提交
  "permissions": {...},
  "hooks": {...},
  "extraKnownMarketplaces": {...},
  
  // ❌ 不应提交
  "env": {
    "API_KEY": "..."
  },
  "pluginConfigs": {...}
}
```

---

## 调试配置

### 查看加载的配置

```bash
# 调试模式
claude --debug settings

# 查看解析的配置
claude -p --debug
```

### 常见问题

1. **配置不生效**
   - 检查文件路径是否正确
   - 检查 JSON 语法
   - 确认配置来源优先级

2. **配置冲突**
   - 使用 `--debug settings` 查看合并结果
   - 确认是否有更高优先级覆盖

3. **权限问题**
   - 检查是否在 policySettings 中被锁定
   - 使用 `--setting-sources` 限制加载来源
