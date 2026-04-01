# 安装与认证

> Claude Code 安装和配置指南

## 系统要求

| 要求 | 说明 |
|------|------|
| 操作系统 | macOS, Linux, Windows (WSL) |
| 内存 | 推荐 4GB+ |
| 磁盘 | 500MB 可用空间 |
| Node.js | 可选（用于插件） |
| Git | 推荐安装 |

---

## 安装方式

### 1. macOS (Homebrew)

```bash
brew install anthropic/formulae/claude-code
```

### 2. Linux/macOS (curl)

```bash
curl -fsSL https://downloads.anthropic.com/claude-code/install.sh | sh
```

### 3. npm

```bash
npm install -g @anthropic-ai/claude-code
```

### 4. Windows (winget)

```bash
winget install Anthropic.ClaudeCode
```

### 5. 手动安装

从 Anthropic 官网下载对应平台的安装包。

---

## 认证配置

### 方式 1: 交互式登录

```bash
claude auth login
```

这会打开浏览器进行 OAuth 认证。

**认证选项**：
```bash
claude auth login --sso           # SSO 单点登录
claude auth login --console       # Anthropic Console 登录
claude auth login --claudeai      # Claude.ai 登录
claude auth login --email <email> # 指定邮箱登录
```

### 方式 2: API Key

```bash
# 设置环境变量
export ANTHROPIC_API_KEY="sk-ant-..."

# 或使用 --settings
claude --settings '{"env":{"ANTHROPIC_API_KEY":"sk-ant-..."}}'
```

### 方式 3: API Helper 脚本

创建认证辅助脚本：

```bash
#!/bin/bash
# ~/.claude/api-key-helper
echo "sk-ant-your-api-key-here"
```

```json
// ~/.claude/settings.json
{
  "apiKeyHelper": "/path/to/api-key-helper"
}
```

---

## 代理配置

### 环境变量

```bash
export ANTHROPIC_BASE_URL="http://127.0.0.1:5000"
export HTTP_PROXY="http://proxy:8080"
export HTTPS_PROXY="http://proxy:8080"
```

### settings.json

```json
{
  "env": {
    "ANTHROPIC_BASE_URL": "http://127.0.0.1:5000",
    "ANTHROPIC_API_KEY": "sk-ant-..."
  }
}
```

---

## 首次使用检查

### 1. 验证安装

```bash
claude --version
```

### 2. 验证认证

```bash
claude auth status
```

### 3. 运行诊断

```bash
claude doctor
```

---

## 配置目录

| 路径 | 说明 |
|------|------|
| `~/.claude/settings.json` | 全局设置 |
| `~/.claude/skills/` | 全局技能 |
| `~/.claude/agents/` | 全局 Agent |
| `~/.claude/plugins/` | 插件 |
| `~/.claude/sessions/` | 会话历史 |

---

## 快速开始

### 1. 基本使用

```bash
# 启动交互式会话
claude

# 执行单次任务
claude -p "解释这个函数的用途"

# 继续上次会话
claude -c
```

### 2. 第一个项目配置

```bash
# 创建项目配置目录
mkdir -p .claude

# 创建项目设置
cat > .claude/settings.json << 'EOF'
{
  "$schema": "https://json.schemastore.org/claude-code-settings.json",
  "permissions": {
    "allow": [
      "Bash(git *)",
      "Bash(npm *)",
      "Bash(npx *)",
      "Read",
      "Edit",
      "Write",
      "Glob",
      "Grep"
    ],
    "deny": [
      "Bash(rm -rf /*)"
    ]
  }
}
EOF
```

### 3. 创建第一个技能

```bash
# 创建技能目录
mkdir -p .claude/skills/hello

# 创建技能文件
cat > .claude/skills/hello/SKILL.md << 'EOF'
---
name: hello
description: 简单的问候技能
when_to_use: 当你需要测试 Claude Code 时使用
---

# 打招呼技能

这是一个简单的示例技能。

## 用法

直接说"你好"或"hello"即可。
EOF
```

---

## 常见问题

### Q: 认证失败？

**解决方案**：
1. 检查 API Key 是否正确
2. 确认网络可以访问 Anthropic API
3. 检查代理设置

```bash
# 测试连接
curl -s https://api.anthropic.com/v1/messages
```

### Q: 权限被拒绝？

**解决方案**：
1. 检查 settings.json 权限配置
2. 使用 --permission-mode acceptEdits 测试

### Q: 找不到命令？

**解决方案**：
1. 确认安装成功
2. 检查 PATH 环境变量
3. 使用完整路径运行

```bash
/usr/local/bin/claude --version
```
