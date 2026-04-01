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
    Notification?: HookRule[]
    UserPromptSubmit?: HookRule[]
    SessionStart?: HookRule[]
    SessionEnd?: HookRule[]
    Stop?: HookRule[]
    StopFailure?: HookRule[]
    SubagentStart?: HookRule[]
    SubagentStop?: HookRule[]
    PreCompact?: HookRule[]
    PostCompact?: HookRule[]
    PermissionRequest?: HookRule[]
    PermissionDenied?: HookRule[]
    Setup?: HookRule[]
    TeammateIdle?: HookRule[]
    TaskCreated?: HookRule[]
    TaskCompleted?: HookRule[]
    Elicitation?: HookRule[]
    ElicitationResult?: HookRule[]
    ConfigChange?: HookRule[]
    WorktreeCreate?: HookRule[]
    WorktreeRemove?: HookRule[]
    InstructionsLoaded?: HookRule[]
    CwdChanged?: HookRule[]
    FileChanged?: HookRule[]
  }
}
```

### Hook 事件详解

共 **27 种 Hook 事件**：

| 事件 | 触发时机 | 常见用途 |
|------|----------|----------|
| `PreToolUse` | 工具执行前 | 安全检查、权限验证 |
| `PostToolUse` | 工具执行后 | 记录日志、通知 |
| `PostToolUseFailure` | 工具执行失败 | 错误处理 |
| `Notification` | 通知事件 | 消息通知 |
| `UserPromptSubmit` | 用户提交提示词 | 内容审核、过滤 |
| `SessionStart` | 会话开始 | 初始化设置 |
| `SessionEnd` | 会话结束 | 清理资源 |
| `Stop` | 会话停止 | 优雅关闭 |
| `StopFailure` | 会话停止失败 | 错误处理 |
| `SubagentStart` | 子代理启动 | 监控代理 |
| `SubagentStop` | 子代理停止 | 清理代理资源 |
| `PreCompact` | 上下文压缩前 | 准备压缩数据 |
| `PostCompact` | 上下文压缩后 | 验证压缩结果 |
| `PermissionRequest` | 权限请求 | 自定义权限处理 |
| `PermissionDenied` | 权限拒绝 | 拒绝日志 |
| `Setup` | 设置完成 | 初始化插件 |
| `TeammateIdle` | 队友空闲 | 任务分配 |
| `TaskCreated` | 任务创建 | 跟踪任务 |
| `TaskCompleted` | 任务完成 | 汇总结果 |
| `Elicitation` | 请求用户输入 | 自定义输入收集 |
| `ElicitationResult` | 用户输入结果 | 处理用户响应 |
| `ConfigChange` | 配置变更 | 响应配置变化 |
| `WorktreeCreate` | Git worktree 创建 | 工作区管理 |
| `WorktreeRemove` | Git worktree 删除 | 清理工作区 |
| `InstructionsLoaded` | 指令加载 | 修改系统指令 |
| `CwdChanged` | 工作目录变更 | 路径相关操作 |
| `FileChanged` | 文件变更 | 文件监控 |

### HookRule

```typescript
interface HookRule {
  matcher?: string   // 匹配器（工具名或 "*"），可选
  hooks: HookEntry[] // Hook 执行列表
}
```

### HookEntry

支持 **4 种 Hook 类型**：

```typescript
// 类型 1: Shell 命令
interface CommandHook {
  type: 'command'
  command: string       // 命令路径
  timeout?: number      // 超时时间（秒）
  shell?: 'bash' | 'powershell'  // Shell 类型
  if?: string           // 条件规则，如 "Bash(git *)"
  once?: boolean        // 是否只运行一次
  async?: boolean       // 是否后台异步运行
  asyncRewake?: boolean // 异步运行，exit code 2 时唤醒模型
  statusMessage?: string // 自定义状态消息
}

// 类型 2: LLM 提示词
interface PromptHook {
  type: 'prompt'
  prompt: string        // 提示词内容
  model?: string        // 指定模型
  if?: string           // 条件规则
  once?: boolean        // 是否只运行一次
  statusMessage?: string // 自定义状态消息
}

// 类型 3: Agent 验证
interface AgentHook {
  type: 'agent'
  agent: string         // Agent 名称
  model?: string        // 指定模型
  if?: string           // 条件规则
  once?: boolean        // 是否只运行一次
  statusMessage?: string // 自定义状态消息
}

// 类型 4: HTTP 请求
interface HttpHook {
  type: 'http'
  url: string           // 请求 URL
  method?: string       // HTTP 方法
  body?: unknown        // 请求体
  headers?: Record<string, string> // 请求头
  allowedEnvVars?: string[] // 允许传递的环境变量
  if?: string           // 条件规则
  once?: boolean        // 是否只运行一次
  statusMessage?: string // 自定义状态消息
}
```

### HookEntry 字段说明

| 字段 | 类型 | 说明 |
|------|------|------|
| `type` | enum | Hook 类型：`command`/`prompt`/`agent`/`http` |
| `if` | string | 条件规则，格式如 `"Bash(git commit)"` |
| `once` | boolean | `true` 时只执行一次后自动移除 |
| `async` | boolean | `true` 时后台执行，不阻塞模型 |
| `asyncRewake` | boolean | `true` 时异步执行，exit code 2 唤醒模型 |
| `statusMessage` | string | 自定义状态消息 |

---

## MCP Server 配置

### McpServerConfig

```typescript
interface McpServerConfig {
  command: string
  args?: string[]
  env?: Record<string, string>
  transport?: 'stdio' | 'sse' | 'sse-ide' | 'http' | 'ws' | 'sdk'
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
  transport?: 'stdio' | 'sse' | 'http' | 'ws'
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
