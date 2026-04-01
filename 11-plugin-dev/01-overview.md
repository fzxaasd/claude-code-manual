# 11.1 插件系统概述

> Claude Code 插件扩展机制核心指南

---

## 概述

Claude Code 插件是一种扩展机制，允许开发者通过配置文件打包 Skills、Agents、Hooks、MCP Servers 等功能。

插件清单文件必须位于 `.claude-plugin/plugin.json`（即插件根目录下的 `.claude-plugin/` 子目录中）。

```
插件目录
├── .claude-plugin/
│   └── plugin.json      # 插件清单（必需）
├── skills/              # 技能目录
├── agents/              # Agent 定义目录
├── hooks/               # Hook 配置目录
├── commands/            # 命令文件目录
├── output-styles/       # 输出样式目录
└── ...
```

---

## 插件清单字段

基于 `src/utils/plugins/schemas.ts` 的完整字段定义：

```json
{
  "name": "my-plugin",
  "version": "1.0.0",
  "description": "我的插件",
  "author": {
    "name": "Author Name",
    "email": "author@example.com",
    "url": "https://github.com/author"
  },
  "homepage": "https://github.com/user/my-plugin",
  "repository": "https://github.com/user/my-plugin",
  "license": "MIT",
  "keywords": ["productivity", "development"],
  "dependencies": ["helper-plugin@marketplace"],
  "strict": true,
  "commands": "./commands",
  "agents": "./agents",
  "hooks": "./hooks",
  "skills": "./skills",
  "outputStyles": "./styles",
  "mcpServers": {},
  "lspServers": {},
  "userConfig": {},
  "channels": []
}
```

### 字段详解

| 字段 | 类型 | 说明 |
|------|------|------|
| `name` | string | 插件名称 (kebab-case, 必须) |
| `version` | string | 语义版本 (semver) |
| `description` | string | 简短描述 |
| `author` | object | 作者信息 (name 必须, email/url 可选) |
| `homepage` | string | 主页 URL |
| `repository` | string | 源码仓库 URL |
| `license` | string | SPDX 许可证 (MIT, Apache-2.0) |
| `keywords` | string[] | 搜索标签 |
| `dependencies` | string[] | 依赖的其他插件 |
| `commands` | path/array/object | 命令文件路径 |
| `agents` | path/array | Agent 定义文件路径 |
| `hooks` | path/hooks | Hook 配置 |
| `skills` | path/array | 技能目录路径 |
| `outputStyles` | path/array | 输出样式目录 |
| `mcpServers` | object/path/MCPB | MCP 服务器配置 |
| `lspServers` | object/path | LSP 服务器配置 |
| `userConfig` | object | 用户可配置选项 |
| `channels` | array | 消息通道 (Telegram/Slack/Discord) |
| `settings` | object | 合并到 settings (仅限白名单) |

### Skills/Agents/Hooks 配置格式

这三个字段只支持两种格式：

1. **单个路径**: `"./skills"`
2. **路径数组**: `["./skills", "./extra-skills"]`

不支持 `{ directory, autoLoad }` 对象格式。

### Agent 文件格式

Agent 定义使用 **markdown 格式**，通过 frontmatter 定义元数据：

```markdown
---
name: reviewer
description: 代码审查 Agent
model: sonnet
allowedTools:
  - Read
  - Glob
  - Grep
  - Bash(git *)
disallowedTools:
  - Bash(rm *)
  - Write(/etc/**)
systemPrompt: 你是一个严格的代码审查员...
---

# Agent 内容

Agent 的 markdown 正文内容。
```

### outputStyles 配置

`outputStyles` 字段用于指定额外的输出样式文件或目录：

```json
{
  "outputStyles": "./custom-styles"
}
```

### mcpServers 配置格式

`mcpServers` 支持多种格式：

1. **内联对象**: `{ "server-name": { command: "npx", args: [...] } }`
2. **路径字符串**: `"./.mcp.json"` 或 `"./mcp-config.json"`
3. **MCPB 文件**: `"./servers.mcpb"` 或 URL `https://example.com/servers.mcpb`
4. **数组**: 混合以上类型的数组

MCPB 文件格式 (`.mcpb` 或 `.dxt`) 用于打包 MCP 服务器配置。

---

## 插件加载机制

### 加载来源

| 来源 | 路径 | 说明 |
|------|------|------|
| 用户级 | `~/.claude/plugins/` | 用户安装的插件 |
| 项目级 | `.claude/plugins/` | 项目内插件 |
| Built-in | `builtin@` | 内置插件，使用 `@builtin` 后缀 |

### 加载流程

```
1. 扫描插件目录
    ↓
2. 读取 .claude-plugin/plugin.json
    ↓
3. 验证插件清单
    ↓
4. 加载 Skills/Agents/Hooks
    ↓
5. 初始化 MCP/LSP Servers
    ↓
6. 注册到系统
```

---

## Built-in Plugins 机制

内置插件使用 `@builtin` 后缀的插件 ID 格式：

```
plugin-name@builtin
```

内置插件的特点：
- 随 CLI 一起发布，用户可在 `/plugin` UI 中启用/禁用
- 在 `/plugin` UI 中显示在 "Built-in" 分类下
- 可提供 skills、hooks、MCP servers 等多种组件
- 用户禁用状态会持久化到用户设置

---

## 插件市场 (Marketplace)

### Marketplace 来源类型

| Source | 说明 |
|--------|------|
| `url:https://...` | 直接 URL |
| `github:owner/repo` | GitHub 仓库 |
| `git:https://...` | 任意 Git |
| `npm:package` | NPM 包 |
| `file:path` | 本地文件 |
| `directory:path` | 本地目录 |
| `hostPattern:regex` | 匹配主机名 |
| `pathPattern:regex` | 匹配路径 |
| `settings` | 内联定义 |

### strict 字段 (Marketplace 条目)

`strict` 字段仅存在于 marketplace.json 的条目中，控制是否强制要求 plugin.json 存在：

```json
{
  "plugins": [
    {
      "id": "my-plugin",
      "source": "github:owner/repo",
      "strict": true
    }
  ]
}
```

| 值 | 说明 |
|----|------|
| `true` | 必须存在 plugin.json，否则安装失败 (默认) |
| `false` | plugin.json 可选 |

### sparsePaths (稀疏克隆)

对于 github 和 git 类型的 marketplace，支持 `sparsePaths` 字段实现稀疏克隆：

```json
{
  "source": "github",
  "repo": "owner/monorepo",
  "sparsePaths": [".claude-plugin", "plugins"]
}
```

### forceRemoveDeletedPlugins

在 marketplace.json 中设置，删除的插件会自动卸载：

```json
{
  "forceRemoveDeletedPlugins": true
}
```

### autoUpdate 机制

Marketplace 支持自动更新机制。在 `known_marketplaces.json` 中配置：

```json
{
  "marketplace-name": {
    "source": { "source": "github", "repo": "owner/plugins" },
    "autoUpdate": true
  }
}
```

官方 Anthropic marketplace 默认启用 autoUpdate（`knowledge-work-plugins` 除外）。

---

## 插件类型定义

### PluginManifest (完整结构)

```typescript
interface PluginManifest {
  // === 元数据 ===
  name: string
  version?: string
  description?: string
  author?: PluginAuthor
  homepage?: string
  repository?: string
  license?: string
  keywords?: string[]
  dependencies?: DependencyRef[]

  // === 内容路径 (仅支持路径字符串或数组) ===
  commands?: CommandPath | CommandPath[] | Record<string, CommandMetadata>
  agents?: AgentPath | AgentPath[]     // markdown 文件路径
  hooks?: HooksConfig
  skills?: SkillPath | SkillPath[]       // 目录路径
  outputStyles?: StylePath | StylePath[]
  strict?: boolean

  // === 服务配置 ===
  mcpServers?: McpConfig | McpBPath | RelativeJsonPath
  lspServers?: LspConfig | RelativeJsonPath

  // === 用户配置 ===
  userConfig?: Record<string, UserConfigOption>
  channels?: ChannelConfig[]

  // === 插件级设置 ===
  settings?: Record<string, unknown>
}
```

### DependencyRef (插件依赖)

```typescript
// 三种形式，统一转换为 "name" 或 "name@marketplace"
type DependencyRef =
  | "plugin"                       // 裸名称
  | "plugin@marketplace"           // 限定市场
  | "plugin@marketplace@^1.2"     // 带版本约束（静默忽略）
  | { name: string, marketplace?: string }  // 对象形式（忽略其他字段）
```

### Plugin ID 格式

```
plugin-name@marketplace-name
```

正则：`/^[a-z0-9][-a-z0-9._]*@[a-z0-9][-a-z0-9._]*$/i`

### InstalledPluginsFile (V1/V2)

V1 格式：`plugins` 为 `Record<PluginId, PluginInstallationEntry>`
V2 格式：`plugins` 为 `Record<PluginId, PluginInstallationEntry[]>`，支持多作用域安装

作用域类型：`'managed' | 'user' | 'project' | 'local'`

---

## 用户配置 (userConfig)

插件可以声明用户可配置的选项：

```json
{
  "userConfig": {
    "apiKey": {
      "type": "string",
      "title": "API Key",
      "description": "Your API key for the service",
      "required": true,
      "sensitive": true,
      "default": null
    },
    "maxResults": {
      "type": "number",
      "title": "Max Results",
      "description": "Maximum number of results to return",
      "min": 1,
      "max": 100,
      "default": 10
    }
  }
}
```

### 配置字段类型

| 字段 | 类型 | 说明 |
|------|------|------|
| `type` | enum | string/number/boolean/directory/file |
| `title` | string | 显示名称 (必须) |
| `description` | string | 帮助文本 (必须) |
| `required` | boolean | 是否必填 |
| `default` | any | 默认值 |
| `multiple` | boolean | 允许多个值 (string 类型) |
| `sensitive` | boolean | 敏感数据，存 Keychain |
| `min/max` | number | 数值范围 (number 类型) |

### 配置存储

| 类型 | 存储位置 |
|------|----------|
| 非敏感 | `settings.json` → `pluginConfigs[id].options` |
| 敏感 | macOS Keychain / `.credentials.json` |

### 模板变量

配置值可通过 `${user_config.KEY}` 模板变量引用，用于 MCP/LSP server config 环境变量、Hook 命令参数等。

---

## channels 配置 (消息通道)

插件可以声明消息通道（通过 MCP server 注入消息）：

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

支持的通道类型：Telegram、Slack、Discord 等。`server` 字段值必须匹配 `mcpServers` 中的某个 key。

---

## PluginError 类型体系

插件系统定义了 20+ 种错误类型（`src/types/plugin.ts`）：

| 错误类型 | 说明 |
|----------|------|
| `path-not-found` | 组件路径不存在 |
| `git-auth-failed` | Git 认证失败 (ssh/https) |
| `git-timeout` | Git 操作超时 |
| `network-error` | 网络错误 |
| `manifest-parse-error` | 清单文件解析失败 |
| `manifest-validation-error` | 清单字段验证失败 |
| `plugin-not-found` | 插件在市场中未找到 |
| `marketplace-not-found` | 市场未找到 |
| `marketplace-load-failed` | 市场加载失败 |
| `mcp-config-invalid` | MCP 配置无效 |
| `mcp-server-suppressed-duplicate` | MCP 服务器重复被抑制 |
| `hook-load-failed` | Hook 加载失败 |
| `component-load-failed` | 组件加载失败 |
| `mcpb-download-failed` | MCPB 文件下载失败 |
| `mcpb-extract-failed` | MCPB 文件解压失败 |
| `mcpb-invalid-manifest` | MCPB 清单无效 |
| `marketplace-blocked-by-policy` | 市场被企业策略阻止 |
| `dependency-unsatisfied` | 依赖未满足 |
| `lsp-config-invalid` | LSP 配置无效 |
| `lsp-server-start-failed` | LSP 服务器启动失败 |
| `lsp-server-crashed` | LSP 服务器崩溃 |
| `lsp-request-timeout` | LSP 请求超时 |
| `lsp-request-failed` | LSP 请求失败 |
| `plugin-cache-miss` | 插件缓存未命中 |
| `generic-error` | 通用错误 |

---

## 开发工作流

### 1. 创建项目

```bash
mkdir my-plugin && cd my-plugin
mkdir -p .claude-plugin skills agents hooks
```

### 2. 编写 plugin.json

```json
{
  "name": "my-plugin",
  "version": "1.0.0",
  "description": "我的插件",
  "author": { "name": "Author" },
  "skills": "./skills",
  "agents": "./agents"
}
```

### 3. 实现功能

```
my-plugin/
├── .claude-plugin/
│   └── plugin.json
├── skills/
│   └── hello/SKILL.md
└── agents/
    └── assistant.md
```

### 4. 测试

```bash
# 本地测试
claude plugin install ./my-plugin

# 验证插件
claude plugin validate ./my-plugin
```

---

## 下一步

- [11.2 插件结构](./02-structure.md) - 详细目录结构
- [11.3 插件 API](./03-api.md) - 类型参考
- [11.4 开发示例](./04-examples.md) - 完整示例
