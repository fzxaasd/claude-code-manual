# 11.3 插件 API

> 插件开发类型参考

---

## 重要说明

Claude Code 插件**无运行时 API**。插件通过 `plugin.json` 配置文件声明所有功能（Skills、Agents、Hooks、MCP Servers 等），没有 `initPlugin` 入口函数，也没有 `registerTool`、`registerSkill` 等运行时 API。

插件清单通过 `plugin.json` 配置驱动，不存在 `PluginAPI` 运行时接口。

---

## 核心类型

### PluginManifest

插件清单的完整结构定义（`src/utils/plugins/schemas.ts`）：

```typescript
interface PluginManifest {
  // 元数据
  name: string                      // 必须，kebab-case
  version?: string                  // semver
  description?: string
  author?: PluginAuthor
  homepage?: string
  repository?: string
  license?: string
  keywords?: string[]
  dependencies?: DependencyRef[]

  // 内容路径（仅支持路径字符串或数组）
  commands?: CommandPath | CommandPath[] | Record<string, CommandMetadata>
  agents?: AgentPath | AgentPath[]
  hooks?: HooksConfig
  skills?: SkillPath | SkillPath[]
  outputStyles?: StylePath | StylePath[]
  strict?: boolean

  // 服务配置
  mcpServers?: McpConfig | McpBPath | RelativeJsonPath
  lspServers?: LspConfig | RelativeJsonPath

  // 用户配置
  userConfig?: Record<string, UserConfigOption>
  channels?: ChannelConfig[]

  // 插件级设置
  settings?: Record<string, unknown>
}
```

### PluginAuthor

```typescript
interface PluginAuthor {
  name: string        // 必须
  email?: string
  url?: string
}
```

### DependencyRef

```typescript
type DependencyRef =
  | "plugin"                           // 裸名称
  | "plugin@marketplace"               // 限定市场
  | "plugin@marketplace@^1.2"          // 带版本约束（静默忽略）
  | { name: string; marketplace?: string }  // 对象形式（忽略其他字段）
```

---

## AgentDefinition

Agent 使用 **markdown 格式**（不是 JSON），通过 frontmatter 定义：

```typescript
interface AgentDefinition {
  name: string              // frontmatter: name
  description: string       // frontmatter: description
  model?: string            // frontmatter: model
  allowed_tools?: string[]  // frontmatter: allowed_tools
  disallowed_tools?: string[] // frontmatter: disallowed_tools
  system_prompt?: string     // frontmatter: system_prompt
}
```

### 示例 (agents/reviewer.md)

```markdown
---
name: reviewer
description: 代码审查 Agent
model: sonnet
allowed_tools:
  - Read
  - Glob
  - Grep
  - Bash(git *)
disallowed_tools:
  - Bash(rm *)
  - Write(/etc/**)
system_prompt: 你是一个严格的代码审查员...
---

# 代码审查 Agent

Agent 的详细说明和使用指南。
```

---

## HookDefinition

Hooks 通过 `hooks.json` 配置文件定义：

```typescript
interface HooksConfig {
  description?: string
  hooks: {
    PreToolUse?: HookRule[]
    PostToolUse?: HookRule[]
    PostToolUseFailure?: HookRule[]
    UserPromptSubmit?: HookRule[]
    SessionStart?: HookRule[]
    SessionEnd?: HookRule[]
    PermissionRequest?: HookRule[]
    PermissionDenied?: HookRule[]
    TaskCreated?: HookRule[]
    TaskCompleted?: HookRule[]
  }
}

interface HookRule {
  matcher: string      // 匹配器（工具名或 "*"）
  hooks: HookEntry[]
}

interface HookEntry {
  type: 'command'
  command: string      // 命令路径（支持 ${HOOK_DIR} 变量）
  timeout?: number     // 超时时间（秒）
}
```

---

## MCP Server 配置

### McpServerConfig

```typescript
interface McpServerConfig {
  command: string
  args?: string[]
  env?: Record<string, string>
  transport?: 'stdio' | 'socket'
}
```

### mcpServers 格式

`plugin.json` 中 mcpServers 支持以下格式：

```json
// 格式 1: 内联对象
{
  "mcpServers": {
    "db-server": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-postgres"],
      "env": { "DATABASE_URL": "${user_config.DATABASE_URL}" }
    }
  }
}

// 格式 2: MCPB 文件路径
{
  "mcpServers": "./servers.mcpb"
}

// 格式 3: 远程 MCPB URL
{
  "mcpServers": "https://example.com/servers.mcpb"
}

// 格式 4: 配置文件路径
{
  "mcpServers": "./.mcp.json"
}

// 格式 5: 数组（混合）
{
  "mcpServers": ["./local.mcp.json", "./remote.mcpb"]
}
```

---

## LSP Server 配置

### LspServerConfig

```typescript
interface LspServerConfig {
  command: string
  args?: string[]
  extensionToLanguage: Record<string, string>  // { ".ts": "typescript" }
  transport?: 'stdio' | 'socket'
  env?: Record<string, string>
  initializationOptions?: unknown
  settings?: unknown
  workspaceFolder?: string
  startupTimeout?: number
  shutdownTimeout?: number
  restartOnCrash?: boolean
  maxRestarts?: number
}
```

---

## PluginError 类型

插件系统定义了 25 种错误类型（`src/types/plugin.ts`）：

| 错误类型 | 说明 |
|----------|------|
| `path-not-found` | 组件路径不存在 |
| `git-auth-failed` | Git 认证失败 |
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

## 下一步

- [11.4 开发示例](./04-examples.md) - 完整开发示例
