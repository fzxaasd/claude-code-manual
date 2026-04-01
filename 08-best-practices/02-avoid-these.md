# ⚠️ 避免使用的功能

> 基于源码研究和实际测试，总结 Claude Code 中应谨慎使用或避免的功能

## 危险操作

### 1. 危险命令拦截

虽然 Claude Code 有安全机制，但仍应避免：

```bash
# ⚠️ 高风险命令
rm -rf /              # 绝对避免
sudo rm -rf /         # 绝对避免
chmod 777             # 危险权限
curl | sh             # 管道到 shell
:wq! /etc/passwd     # 编辑系统文件
```

**建议**：在 permissions 中明确拒绝：
```json
{
  "permissions": {
    "deny": [
      "Bash(rm -rf *)",
      "Bash(sudo rm *)",
      "Bash(chmod 777 *)"
    ]
  }
}
```

### 2. 敏感信息处理

```bash
# ⚠️ 避免在命令中暴露密钥
curl -H "Authorization: Bearer $API_KEY"      # ✅ 安全
curl -H "Authorization: Bearer sk-xxx"       # ❌ 暴露密钥
```

**最佳实践**：
- 使用环境变量
- 使用 `.env` 文件（已添加到 .gitignore）
- 使用 `--settings` 注入敏感配置

---

## 不推荐使用的功能

### 1. `--dangerously-skip-permissions`

```bash
# ❌ 危险！跳过所有权限检查
claude --dangerously-skip-permissions

# ✅ 替代方案：使用白名单模式
claude --permission-mode acceptEdits
```

**风险**：
- 无法阻止危险操作
- 无法审计操作历史
- 违背安全原则

### 2. `--bypassPermissions`

```bash
# ❌ 危险！--bypassPermissions 是 --permission-mode bypassPermissions 的简写
# 不同于 --dangerously-skip-permissions（完全跳过权限检查）
claude --bypassPermissions
```

### 3. 过度依赖 auto mode

```json
{
  "autoMode": {
    "allow": ["Bash(*)"]  # ⚠️ 过于宽松
  }
}
```

**建议**：
```json
{
  "autoMode": {
    "allow": [
      "Bash(git *)",
      "Bash(npm test)",
      "Read",
      "Glob"
    ],
    "soft_deny": [
      "Bash(rm -rf *)",
      "Bash(sudo *)"
    ]
  }
}
```

---

## 性能问题

### 1. 大文件操作

```bash
# ⚠️ 避免对大文件使用 Read/Write
Read 100MB_file.log    # 可能导致上下文膨胀
Write large_binary.bin  # 可能超时
```

**替代方案**：
- 使用 `grep -n "pattern" file` 替代全文读取
- 使用 `head -n 100 file` 读取部分内容
- 使用流式处理

### 2. 深度嵌套目录

```bash
# ⚠️ 避免在深层目录中操作
cd /very/deep/nested/directory/structure/project  # 性能下降
```

**建议**：
- 使用 `--add-dir` 指定工作目录
- 避免在 node_modules 中搜索

### 3. 频繁的上下文压缩

```bash
# ⚠️ 避免触发频繁自动压缩
# 在单个会话中处理过多任务
```

**建议**：
- 拆分长任务为多个会话
- 使用 `/compact` 手动触发
- 设置合理的 `cleanupPeriodDays`

---

## 配置陷阱

### 1. 循环 Hook

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "git status"
          }
        ]
      }
    ]
  }
}
```

**问题**：`git status` Hook 会触发自己！

**修复**：使用 `if` 条件
```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "security-check.sh",
            "if": "Bash(!git status)"  # 排除 git status
          }
        ]
      }
    ]
  }
}
```

### 2. 超时设置不当

```json
{
  "hooks": [
    {
      "type": "command",
      "command": "slow-script.sh",
      "timeout": 5  # ⚠️ 太短
    }
  ]
}
```

**建议**：
- 分析脚本实际执行时间
- 设置合理缓冲（如 1.5x 预期时间）
- 使用 `async: true` 处理长时间任务

### 3. Hook 死锁

```python
# ⚠️ PostToolUse Hook 尝试修改同一文件
def hook(input, response):
    if response['file'] == 'hooks.json':
        write_to_file(...)  # 可能导致死锁
```

**修复**：使用异步 Hook
```json
{
  "type": "command",
  "command": "async-handler.sh",
  "async": true
}
```

---

## 权限配置错误

### 1. 过于宽松的白名单

```json
{
  "permissions": {
    "allow": ["Bash(*)"]  # ❌ 允许所有命令
  }
}
```

### 2. 过于严格的规则

```json
{
  "permissions": {
    "allow": [],
    "deny": ["Bash(*)"]  # ⚠️ 阻止所有命令，包括 git
    "defaultMode": "dontAsk"
  }
}
```

**正确示例**：
```json
{
  "permissions": {
    "allow": [
      "Bash(git *)",
      "Bash(npm:*)",
      "Bash(npx:*)",
      "Bash(node:*)",
      "Bash(pnpm:*)",
      "Bash(yarn:*)",
      "Read",
      "Edit",
      "Write",
      "Glob",
      "Grep"
    ],
    "deny": [
      "Bash(rm -rf /*)",
      "Bash(sudo rm *)",
      "Bash(:(){:|:&};:)"
    ],
    "defaultMode": "default"
  }
}
```

---

## Session 管理问题

### 1. 会话持久化关闭

```bash
# ⚠️ 关闭会话持久化
claude --no-session-persistence -p "task"
```

**问题**：无法使用 `/resume`，无法追溯历史

### 2. Fork Session ID 冲突

```bash
# ⚠️ 频繁 fork 可能导致 ID 混乱
claude --fork-session -c "task1"
claude --fork-session -c "task2"
claude --fork-session -c "task3"
```

**建议**：使用有意义的 session 名称
```bash
claude -n "feature-auth" -c
```

---

## 最佳实践总结

### ✅ 推荐

| 场景 | 推荐做法 |
|------|----------|
| 权限控制 | 使用细粒度白名单 |
| 敏感信息 | 使用环境变量 |
| 长任务 | 使用 `context: fork` |
| 安全检查 | 使用 PreToolUse Hook |
| 会话管理 | 保持持久化启用 |

### ❌ 避免

| 场景 | 避免做法 |
|------|----------|
| 权限 | `--dangerously-skip-permissions` |
| 权限 | `allow: ["Bash(*)"]` |
| Hook | 循环触发 |
| 文件 | 全文读取大文件 |
| 会话 | `--no-session-persistence` |
