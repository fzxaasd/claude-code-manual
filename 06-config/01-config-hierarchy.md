# 配置层次结构

> Claude Code 配置系统深度解析

## 配置来源优先级

Claude Code 有 5 种配置来源，按优先级从低到高排列：

```
┌─────────────────────────────────────────────────────────────────┐
│  1. userSettings          (~/.claude/settings.json)           │
├─────────────────────────────────────────────────────────────────┤
│  2. projectSettings       (.claude/settings.json)              │
├─────────────────────────────────────────────────────────────────┤
│  3. localSettings         (.claude/settings.local.json)       │
├─────────────────────────────────────────────────────────────────┤
│  4. flagSettings          (--settings CLI 参数)               │
├─────────────────────────────────────────────────────────────────┤
│  5. policySettings        (managed-settings.json / API)        │
│                          ← 最高优先级                         │
└─────────────────────────────────────────────────────────────────┘
```

**注意**：权限规则（allow/deny/ask）的保存位置有单独的优先级：

```
localSettings > projectSettings > userSettings
```

---

## 配置文件位置

| 来源 | 文件路径 | 说明 |
|------|----------|------|
| User | `~/.claude/settings.json` | 全局配置，所有项目共享 |
| Project | `.claude/settings.json` | 项目级配置，提交到 git |
| Local | `.claude/settings.local.json` | 本地配置，gitignored |
| Flag | CLI `--settings` 参数 | 临时配置 |
| Policy | `managed-settings.json` | 企业管理配置（只读） |

---

## 配置文件路径解析

```typescript
// 从源码 src/utils/settings/constants.ts

// 用户设置
~/.claude/settings.json

// 项目设置
<CWD>/.claude/settings.json

// 本地设置（gitignored）
<CWD>/.claude/settings.local.json

// 管理设置
~/.claude/managed-settings.json
// 或从远程 API 获取
```

---

## CLI 参数与配置覆盖

### --setting-sources 参数

```bash
# 只加载 user 和 project 设置
claude --setting-sources user,project

# 只加载 project 设置
claude --setting-sources project

# 默认：加载所有来源
claude
```

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

部分字段不合并，直接覆盖：

| 字段 | 行为 |
|------|------|
| `permissions.deny` | 合并（交集更严格） |
| `permissions.allow` | 合并（并集更宽松） |
| `hooks` | 合并 |
| `env` | 合并（环境变量追加） |

---

## 权限规则优先级

权限规则（allow/deny）有自己的保存优先级：

```
localSettings > projectSettings > userSettings
```

**但执行优先级相反**：

```
deny > allow  // deny 总是优先
```

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
拒绝: Bash(rm *), Bash(rm -rf *)  // 最终拒绝更严格
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
