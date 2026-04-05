# 3.2 工具权限管理

> 详细说明 Claude Code 的权限控制机制

---

## 权限模式

### 权限模式类型

| 模式 | 说明 | 适用场景 |
|------|------|----------|
| `default` | 使用默认权限规则 | 标准使用 |
| `acceptEdits` | 允许编辑文件 | 需要修改代码 |
| `bypassPermissions` | 跳过权限检查 | CI/自动化环境 |
| `dontAsk` | 不询问，静默拒绝未授权操作 | 无交互环境 |
| `plan` | 规划模式，只分析不执行 | 预览操作 |
| `auto` | 自动模式（实验性，需要 TRANSCRIPT_CLASSIFIER 功能开启） | 智能权限判断 |

### 设置权限模式

```bash
# 命令行
claude --permission-mode acceptEdits

# 环境变量
# CLAUDE_PERMISSION_MODE 环境变量不存在，应使用 CLI 参数或 settings.json

# CLI 参数
claude --permission-mode acceptEdits

# 配置文件
{
  "permissions": {
    "defaultMode": "acceptEdits"
  }
}
```

---

## 权限规则配置

### 规则结构

权限规则包含以下属性：

| 属性 | 类型 | 说明 |
|------|------|------|
| `source` | string | 规则来源 |
| `ruleBehavior` | `allow` \| `deny` \| `ask` | 规则行为 |
| `ruleValue.toolName` | string | 工具名称 |
| `ruleValue.ruleContent` | string | 可选的匹配模式 |

### 规则语法

#### 工具匹配
```
ToolName          # 允许/拒绝该工具
ToolName(pattern) # 匹配特定调用模式
```

#### 支持的模式

| 模式示例 | 匹配内容 |
|----------|----------|
| `Bash` | 所有 Bash 调用 |
| `Bash(npm *)` | npm 开头的命令 |
| `Bash(*.sh)` | 所有 shell 脚本 |
| `Bash(git push)` | git push 命令 |
| `Write(*.env)` | 所有 .env 文件 |
| `Read(/etc/*)` | /etc 目录文件 |

### 规则来源

规则按来源分组管理：

| 来源 | 说明 |
|------|------|
| `userSettings` | 用户级配置 (~/.claude/settings.json) |
| `projectSettings` | 项目级配置 (.claude.json) |
| `localSettings` | 本地覆盖配置 |
| `flagSettings` | 命令行标志设置 |
| `policySettings` | 企业策略配置 |
| `cliArg` | CLI 参数指定 |
| `command` | 命令注入 |
| `session` | 会话内动态设置 |

---

## 权限优先级

### 规则优先级

1. **明确拒绝 (deny)** > **允许 (allow)** > **询问 (ask)**
2. 模式越具体优先级越高
3. 正则匹配优先于通配符

### 来源优先级

```
policySettings (最高) > flagSettings > localSettings > projectSettings > userSettings > pluginSettings (最低)
```

**注意**：从**低优先级到高优先级**遍历配置，后面的覆盖前面的。

### 执行顺序

```
请求工具
    ↓
检查规则 (从高优先级来源开始)
    ↓ [命中 deny]
    ↓
拒绝执行
    ↓ [命中 allow]
    ↓
允许执行
    ↓ [命中 ask]
    ↓
询问用户
    ↓ [未命中任何规则]
    ↓
检查默认权限模式
```

---

## 动态权限请求

### Hook 系统

Claude Code 使用 Hook 系统处理动态权限请求。

### PreToolUse Hook

在工具执行前触发：

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "check_permission.sh"
          }
        ]
      }
    ]
  }
}
```

### Hook 返回格式

Hook 返回 JSON 格式的决策：

```json
{
  "continue": true,
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "allow",
    "permissionDecisionReason": "Trusted command"
  }
}
```

支持 `permissionDecision` 值：
- `allow` - 允许执行
- `deny` - 拒绝执行
- `ask` - 询问用户

---

## PermissionDenied Hook

工具被拒绝后触发：

```json
{
  "hooks": {
    "PermissionDenied": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "log_denial.sh"
          }
        ]
      }
    ]
  }
}
```

### 返回格式

```json
{
  "continue": true,
  "hookSpecificOutput": {
    "hookEventName": "PermissionDenied",
    "retry": false
  }
}
```

---

## 临时权限

### 会话级别

```bash
# 使用 acceptEdits 模式
claude --permission-mode acceptEdits

# 绕过所有权限检查（不推荐）
claude --permission-mode bypassPermissions
```

### 工具级别

用户可以在运行时批准单个调用：

```
⚠️ 工具请求: Bash(rm -rf node_modules)
是否允许? [y/N/a]
```

| 选项 | 含义 |
|------|------|
| `y` | 仅允许本次 |
| `n` | 拒绝 |
| `a` | 允许所有后续类似调用 |

---

## 权限配置示例

### 开发环境

```json
{
  "permissions": {
    "defaultMode": "acceptEdits"
  }
}
```

### 审阅环境

```json
{
  "permissions": {
    "defaultMode": "default",
    "allow": ["Read", "Glob", "Grep"],
    "deny": ["Bash(rm -rf *)", "Write(/etc/**)"]
  }
}
```

### 生产环境

```json
{
  "permissions": {
    "defaultMode": "dontAsk",
    "allow": ["Read", "Glob", "Grep", "Bash(npm run build)", "Bash(npm test)"],
    "deny": ["Bash(sudo *)", "Bash(chmod *)", "Write(/etc/**)", "Write(*.pem)", "Write(*.key)"]
  }
}
```

### 规划模式

```json
{
  "permissions": {
    "defaultMode": "plan"
  }
}
```

---

## 权限审计

### 权限日志

通过 Hook 记录权限决策：

```json
{
  "hooks": {
    "PermissionDenied": [
      {
        "matcher": "*",
        "hooks": [
          {
            "type": "command",
            "command": "audit_permission.sh"
          }
        ]
      }
    ]
  }
}
```

### 审计脚本示例

```bash
#!/bin/bash
# audit_permission.sh
read input
echo "$input" >> ~/.claude/permission_audit.log
```

---

## 故障排除

### 常见问题

**Q: 所有命令都被拒绝**
```json
// 检查 permissions 配置
{
  "permissions": {
    "allow": ["Bash"]
  }
}
```

**Q: Hook 返回后权限仍不生效**
```json
// 确保返回正确的 hookSpecificOutput
{
  "continue": true,
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "allow"
  }
}
```

**Q: 规则不生效**
```json
// 检查优先级顺序
// policySettings > flagSettings > localSettings > projectSettings > userSettings
// 确保高优先级来源的规则正确配置
```

---

## 最佳实践

1. **最小权限原则**: 仅授予必要权限
2. **分层配置**: userSettings < projectSettings < localSettings < flagSettings < policySettings
3. **定期审计**: 记录权限请求
4. **危险命令黑名单**: rm -rf, sudo 等
5. **模式具体化**: 避免使用 `*` 通配符
