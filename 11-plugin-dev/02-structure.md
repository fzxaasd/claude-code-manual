# 11.2 插件结构

> 插件目录结构与配置文件详解

---

## 完整目录结构

```
my-plugin/
├── .claude-plugin/
│   └── plugin.json      # 插件清单（必需，位于 .claude-plugin/ 子目录）
├── package.json         # npm 包配置（可选）
├── skills/             # 技能目录
│   ├── hello/
│   │   └── SKILL.md
│   └── sql-optimizer/
│       └── SKILL.md
├── agents/             # Agent 定义目录
│   ├── reviewer.md
│   └── coder.md
├── hooks/              # Hook 配置
│   └── hooks.json
├── commands/           # 命令文件目录
│   └── README.md
├── output-styles/      # 输出样式目录
│   └── custom.css
└── tests/              # 测试
    └── plugin.test.ts
```

> 注意：插件清单文件必须位于 `.claude-plugin/plugin.json`，而不是根目录的 `manifest.json`。

---

## .claude-plugin/plugin.json

### 基础配置

```json
{
  "name": "my-plugin",
  "version": "1.0.0",
  "description": "插件描述",
  "author": {
    "name": "Author Name",
    "email": "author@example.com"
  },
  "repository": "https://github.com/user/my-plugin",
  "license": "MIT"
}
```

### Skills 配置

```json
{
  "skills": "./skills"
}
```

或多个路径：

```json
{
  "skills": ["./skills", "./extra-skills"]
}
```

仅支持路径字符串或字符串数组，**不支持** `{ directory, autoLoad }` 对象格式。

### Agents 配置

```json
{
  "agents": "./agents"
}
```

Agent 文件为 markdown 格式，详见下方 Agent 目录结构。

### Hooks 配置

```json
{
  "hooks": "./hooks"
}
```

### MCP Servers

```json
{
  "mcpServers": {
    "db-server": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-postgres"],
      "env": {
        "DATABASE_URL": "${user_config.DATABASE_URL}"
      }
    }
  }
}
```

MCP Servers 也支持：
- 路径引用：`"./.mcp.json"`
- MCPB 文件：`"./servers.mcpb"` 或 URL

### outputStyles 配置

```json
{
  "outputStyles": "./output-styles"
}
```

### 用户配置

```json
{
  "userConfig": {
    "apiKey": {
      "type": "string",
      "description": "API Key for external service",
      "sensitive": true,
      "required": false
    },
    "maxResults": {
      "type": "number",
      "description": "Maximum results to return",
      "default": 10,
      "min": 1,
      "max": 100
    }
  }
}
```

### channels 配置

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

---

## 技能目录结构

### 单技能目录

```
skills/
└── hello/
    ├── SKILL.md           # 必需
    ├── assets/            # 可选
    │   └── icon.png
    └── scripts/           # 可选
        └── helper.sh
```

### SKILL.md 结构

```markdown
---
name: hello
description: 打招呼技能
when_to_use: 当你需要问候时使用
paths:
  - "*.ts"
  - "*.js"
tools:
  - Bash
  - Read
version: "1.0.0"
---

# 打招呼技能

这是一个示例技能。

## 使用方法

直接说"你好"即可。
```

---

## Agent 目录结构

```
agents/
├── reviewer.md
└── coder.md
```

### Agent 定义（markdown + frontmatter）

```markdown
---
name: reviewer
description: 代码审查 Agent
model: sonnet
tools:
  - Read
  - Glob
  - Grep
  - Bash(git *)
disallowedTools:
  - Bash(rm *)
  - Write(/etc/**)
---

# 代码审查 Agent

Agent 的详细说明和使用指南。

系统提示来自 markdown 正文，不是 frontmatter 中的 system_prompt。

## 功能特点

1. 安全性检查
2. 代码质量评估
3. 性能分析
```

Agent frontmatter 字段说明：

| 字段 | 类型 | 说明 |
|------|------|------|
| `name` | string | Agent 名称 |
| `description` | string | 描述 |
| `model` | string | 默认模型 |
| `tools` | string[] | 允许的工具 |
| `disallowedTools` | string[] | 禁用的工具 |
| 系统提示 | - | 来自 markdown 正文内容，不是 frontmatter 字段 |

---

## Hooks 目录结构

```
hooks/
├── hooks.json
├── pre-check.sh
└── post-check.sh
```

### hooks.json

```json
{
  "description": "安全检查 hooks",
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PLUGIN_ROOT}/hooks/pre-check.sh",
            "timeout": 5,
            "if": "Bash(git commit)"
          }
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "*",
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PLUGIN_ROOT}/hooks/post-check.sh",
            "async": true
          }
        ]
      }
    ],
    "SessionStart": [
      {
        "hooks": [
          {
            "type": "prompt",
            "prompt": "Remember to follow security best practices"
          }
        ]
      }
    ],
    "Notification": [
      {
        "hooks": [
          {
            "type": "http",
            "url": "https://webhook.example.com/notify",
            "method": "POST",
            "allowedEnvVars": ["USER"]
          }
        ]
      }
    ]
  }
}
```

---

## 环境变量

插件可使用的模板变量（已在源码 `src/utils/hooks.ts`, `src/utils/plugins/pluginOptionsStorage.ts` 等验证）：

| 变量 | 说明 |
|------|------|
| `${CLAUDE_PLUGIN_ROOT}` | 版本化的插件安装目录（更新时重建） |
| `${CLAUDE_PLUGIN_DATA}` | 持久化数据目录（更新后保留） |
| `${CLAUDE_SKILL_DIR}` | 具体技能的子目录（与 PLUGIN_ROOT 不同，一个插件可有多个 skills） |
| `${user_config.KEY}` | userConfig 中定义的变量 |

---

## 下一步

- [11.3 插件 API](./03-api.md) - 类型参考
- [11.4 开发示例](./04-examples.md) - 完整示例
