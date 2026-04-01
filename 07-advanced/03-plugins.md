# 插件系统

> Claude Code 插件安装、配置与管理

## 核心概念

### 插件架构

```
┌─────────────────────────────────────────────┐
│ Claude Code                                 │
│  ┌─────────────┐  ┌─────────────────────┐ │
│  │ 内置功能    │  │ 插件系统            │ │
│  └─────────────┘  │  ┌───────────────┐  │ │
│                    │  │ Plugin A     │  │ │
│                    │  │ - Skills     │  │ │
│                    │  │ - Hooks      │  │ │
│                    │  │ - Agents     │  │ │
│                    │  └───────────────┘  │ │
│                    │  ┌───────────────┐  │ │
│                    │  │ Plugin B     │  │ │
│                    │  │ - Skills     │  │ │
│                    │  │ - Tools     │  │ │
│                    │  └───────────────┘  │ │
│                    └─────────────────────┘ │
└─────────────────────────────────────────────┘
```

---

## 插件管理 CLI

### 基本命令

| 命令 | 说明 |
|------|------|
| `claude plugin list` | 列出已安装插件 |
| `claude plugin install <name>` | 安装插件 |
| `claude plugin uninstall <name>` | 卸载插件 |
| `claude plugin enable <name>` | 启用插件 |
| `claude plugin disable <name>` | 禁用插件 |
| `claude plugin update <name>` | 更新插件 |
| `claude plugin validate <path>` | 验证插件清单 |

### 市场管理

```bash
# 列出可用市场
claude plugin marketplace list

# 添加市场
claude plugin marketplace add <source>

# 从 Claude Desktop 导入
claude mcp add-from-claude-desktop
```

---

## 插件结构

### 目录结构

```
plugin-name/
├── plugin.json              # 插件清单
├── skills/
│   └── my-skill/
│       └── SKILL.md
├── agents/
│   └── my-agent.md
├── hooks/
│   └── hooks.json
└── README.md
```

### plugin.json

```json
{
  "id": "my-plugin@marketplace",
  "name": "My Plugin",
  "version": "1.0.0",
  "description": "插件描述",
  "author": "Author Name",
  "homepage": "https://github.com/author/plugin",
  "skills": [
    {
      "name": "my-skill",
      "path": "skills/my-skill"
    }
  ],
  "agents": [
    {
      "name": "my-agent",
      "path": "agents/my-agent.md"
    }
  ],
  "hooks": {
    "path": "hooks/hooks.json"
  }
}
```

---

## 插件技能

### 创建插件技能

```
my-plugin/
├── plugin.json
└── skills/
    └── custom-skill/
        └── SKILL.md
```

### SKILL.md 示例

```markdown
---
name: custom-skill
description: 自定义技能描述
when_to_use: 当你需要...时使用
---

# 自定义技能

这是插件提供的技能。
```

---

## 插件 Hooks

### hooks.json 格式

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

## 企业配置

### 只允许插件自定义

```json
{
  "strictPluginOnlyCustomization": ["skills", "agents", "hooks"]
}
```

这会阻止用户直接编辑这些配置，只允许通过插件添加。

### 市场白名单

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

## 插件市场

### 官方市场

```
anthropic-tools (官方)
├── claude-code-snippets
├── git-helpers
└── productivity-tools
```

### 第三方市场

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

### 添加自定义市场

```bash
# 通过 CLI
claude plugin marketplace add --type github --repo my-org/plugins

# 通过 settings.json
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

## 安全考虑

### 插件信任

安装插件前会显示信任警告：

```
⚠️ 此插件将能够：
- 读写项目文件
- 执行 shell 命令
- 访问配置的 MCP 服务器

确认安装吗？
```

### 信任消息

企业可以自定义信任消息：

```json
{
  "pluginTrustMessage": "所有内部市场插件已经过安全审核。"
}
```

### 插件只读

```json
{
  "strictPluginOnlyCustomization": true
}
```

这会锁定所有自定义配置，只能通过插件修改。

---

## 故障排查

### 插件不加载

1. 检查插件目录存在
2. 验证 plugin.json 格式
3. 查看错误日志

```bash
# 验证插件
claude plugin validate ./my-plugin

# 调试模式
claude --debug plugin
```

### 技能不显示

1. 检查 SKILL.md 位置
2. 验证 frontmatter
3. 确认插件已启用

```bash
# 列出所有技能
claude /skills

# 查看技能详情
claude /skill-name --help
```

---

## 推荐插件

### 1. 官方插件

| 插件 | 功能 |
|------|------|
| claude-code-snippets | 代码片段 |
| git-helpers | Git 辅助工具 |
| productivity-tools | 生产力工具 |

### 2. 常用 MCP 服务器

```bash
# GitHub 集成
claude mcp add github -- npx -y @modelcontextprotocol/server-github

# 文件系统
claude mcp add filesystem -- npx -y @modelcontextprotocol/server-filesystem

# Slack
claude mcp add slack -- npx -y @modelcontextprotocol/server-slack
```

---

## 开发插件

### 创建新插件

1. 创建目录结构
2. 编写 plugin.json
3. 添加技能/Agents/Hooks
4. 测试验证
5. 发布到市场

### 本地测试

```bash
# 使用 --plugin-dir 测试
claude --plugin-dir ./my-plugin

# 验证清单
claude plugin validate ./my-plugin
```
