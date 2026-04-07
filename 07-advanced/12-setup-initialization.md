# Claude Code Setup 初始化流程

> 基于源码 `src/setup.ts`, `src/init.ts`, `src/bootstrap/` 完整分析

---

## 概述

Claude Code 启动时会执行复杂的初始化流程，涉及配置加载、环境检查、后台任务启动等多个阶段。

**18 个未在文档中记录的初始化行为。**

---

## setup() 函数执行顺序

### 1. Node.js 版本检查

```typescript
// src/setup.ts
require('node:version')
// 最低要求：Node.js >= 18
// 不满足则退出并报错
```

### 2. 自定义会话 ID

通过 `--session-id` 标志设置会话 ID：

```bash
claude --session-id <uuid>
```

### 3. UDS 消息服务器

通过 `feature('UDS_INBOX')` 启用：

```typescript
// 创建 Unix Domain Socket 用于进程间通信
// 默认位置：/tmpdir
// 可通过 `--messaging-socket-path` 覆盖
export CLAUDE_CODE_MESSAGING_SOCKET
```

### 4. Teammate Snapshot

为 Agent Swarm 捕获 teammate 模式状态：

```typescript
// 保存 teammate 模式的当前状态快照
captureTeammateModeSnapshot()
```

### 5. iTerm2/Terminal.app 备份恢复

如果 Claude Code 在终端配置期间被中断，自动恢复原始设置：

```typescript
// 仅交互式会话
if (isInteractive) {
  checkAndRestoreITerm2Backup()
  checkAndRestoreTerminalBackup()
}
```

### 6. CWD 初始化

```typescript
setCwd()
// 确保工作目录正确设置
```

### 7. Hooks 配置快照

捕获 hook 配置以检测篡改：

```typescript
captureHooksConfigSnapshot()
// 存储当前 hooks 配置用于后续验证
```

### 8. FileChanged 监视器

初始化文件系统监视器：

```typescript
initializeFileChangedWatcher()
// 监视文件变更事件
```

### 9. Git Worktree 创建

如果使用 `--worktree` 标志：

```bash
claude --worktree --tmux
# 先创建 worktree，然后启动 tmux session
```

### 10. 后台作业启动

| 后台任务 | 说明 |
|----------|------|
| Session Memory | 会话记忆管理 |
| Context Collapse | 上下文压缩 |
| Plugin Hooks | 插件钩子 |
| Attribution Hooks | 来源钩子 |
| Team Memory Sync | 团队记忆同步 |

### 11. Sinks 初始化

初始化分析/错误日志 sinks：

```typescript
initSinks()
// 设置日志输出目标
```

### 11. 发布说明检查

仅交互式会话：

```typescript
// 跳过条件：--bare 标志
// 获取 Logo v2 活动信息
checkForReleaseNotes()
```

### 12. Permission Mode 绕过验证

安全检查 `--dangerously-skip-permissions` 标志：

```typescript
// Root/Sudo 守卫
if (isRunningAsRoot() && !IS_SANDBOX && !CLAUDE_CODE_BUBBLEWRAP) {
  refuseToRun()
}

// Docker/沙箱守卫
if (process.env.USER_TYPE === 'ant' && isDocker() && hasNoInternet()) {
  // 允许绕过
}
```

### 13. `tengu_exit` 事件

启动时记录上次会话统计：

```typescript
logEvent('tengu_exit', {
  // 上次会话的统计数据
})
```

### 14. UpstreamProxy 初始化

仅 CCR 环境（`CLAUDE_CODE_REMOTE`）：

```typescript
if (process.env.CLAUDE_CODE_REMOTE) {
  initUpstreamProxy()
}
```

### 15. Startup Profiler 检查点

广泛的 `profileCheckpoint()` 调用用于启动性能测量：

```
setup_start
setup_node_version_check
setup_config_load
setup_env_vars
setup_proxy_mtls
setup_remote_managed_settings
setup_opentelemetry
setup_graceful_shutdown
setup_scratchpad
```

---

## --bare 模式

`--bare` 跳过以下内容：

- Hooks 加载
- LSP 初始化
- 插件同步
- Attribution
- 自动记忆
- 后台预取
- Keychain 读取
- CLAUDE.md 自动发现
- 发布说明检查

---

## 环境变量

| 变量 | 说明 |
|------|------|
| `CLAUDE_CODE_EXIT_AFTER_FIRST_RENDER` | 跳过所有后台预取（启动性能测量） |
| `CLAUDE_CODE_REMOTE` | 触发 UpstreamProxy 初始化 |
| `COREPACK_ENABLE_AUTO_PIN` | 设置为 `0` 防止 corepack 添加 yarnpkg |
| `IS_SANDBOX` | 沙箱检测 |
| `CLAUDE_CODE_BUBBLEWRAP` | Bubblewrap 检测 |
| `USER_TYPE` | `"ant"` 或 `"external"` — 决定访问 ant 内部功能 |
| `NODE_ENV` | `"test"` 时跳过 setup() 权限检查 |

---

## Migration 系统

启动时运行 11 个顺序迁移：

```typescript
const CURRENT_MIGRATION_VERSION = 11

runMigrations()
// 按顺序执行 migration_001 到 migration_011
```

---

## Deferred Prefetches

渲染后预取：

```typescript
startDeferredPrefetches()
// 包括：
// - initUser
// - getUserContext
// - getRelevantTips
// - AWS/GCP 凭证预取
// - 文件计数
// - GrowthBook
// - 模型能力
```

### prefetchSystemContextIfSafe()

仅在信任建立后跳过 git context 预取：

```typescript
prefetchSystemContextIfSafe()
// 非交互式或已信任 → 立即预取
// 交互式且未信任 → 延迟到信任建立后
```

---

## Beta Headers

完整的 Beta Headers 列表（`src/constants/betas.ts`）：

| Header | 值 | Feature Gate |
|--------|-----|--------------|
| `CLAUDE_CODE_20250219_BETA_HEADER` | `claude-code-20250219` | - |
| `INTERLEAVED_THINKING_BETA_HEADER` | `interleaved-thinking-2025-05-14` | - |
| `CONTEXT_1M_BETA_HEADER` | `context-1m-2025-08-07` | - |
| `CONTEXT_MANAGEMENT_BETA_HEADER` | `context-management-2025-06-27` | - |
| `STRUCTURED_OUTPUTS_BETA_HEADER` | `structured-outputs-2025-12-15` | - |
| `WEB_SEARCH_BETA_HEADER` | `web-search-2025-03-05` | - |
| `TOOL_SEARCH_BETA_HEADER_1P` | `advanced-tool-use-2025-11-20` | Claude API / Foundry |
| `TOOL_SEARCH_BETA_HEADER_3P` | `tool-search-tool-2025-10-19` | Vertex AI / Bedrock |
| `EFFORT_BETA_HEADER` | `effort-2025-11-24` | - |
| `TASK_BUDGETS_BETA_HEADER` | `task-budgets-2026-03-13` | - |
| `PROMPT_CACHING_SCOPE_BETA_HEADER` | `prompt-caching-scope-2026-01-05` | - |
| `FAST_MODE_BETA_HEADER` | `fast-mode-2026-02-01` | - |
| `REDACT_THINKING_BETA_HEADER` | `redact-thinking-2026-02-12` | - |
| `TOKEN_EFFICIENT_TOOLS_BETA_HEADER` | `token-efficient-tools-2026-03-28` | - |
| `SUMMARIZE_CONNECTOR_TEXT_BETA_HEADER` | `summarize-connector-text-2026-03-13` | `feature('CONNECTOR_TEXT')` |
| `AFK_MODE_BETA_HEADER` | `afk-mode-2026-01-31` | `feature('TRANSCRIPT_CLASSIFIER')` |
| `CLI_INTERNAL_BETA_HEADER` | `cli-internal-2026-02-09` | `USER_TYPE === 'ant'` |
| `ADVISOR_BETA_HEADER` | `advisor-tool-2026-03-01` | - |

### Bedrock 专用 Headers

这些 headers 放入 `extraBodyParams`（不是 headers）：

```typescript
const BEDROCK_EXTRA_PARAMS_HEADERS = [
  INTERLEAVED_THINKING_BETA_HEADER,
  CONTEXT_1M_BETA_HEADER,
  TOOL_SEARCH_BETA_HEADER_3P
]
```

### Vertex 允许列表

允许在 Vertex `countTokens` API 上使用的 beta headers：

```typescript
const VERTEX_COUNT_TOKENS_ALLOWED_BETAS = [
  CLAUDE_CODE_20250219_BETA_HEADER,
  INTERLEAVED_THINKING_BETA_HEADER,
  CONTEXT_MANAGEMENT_BETA_HEADER
]
```

---

## Feature Flags

通过 `feature('NAME')` 启用的功能：

| Feature | 位置 | 说明 |
|---------|------|------|
| `UDS_INBOX` | setup.ts | 启动 UDS 消息服务器 |
| `DUMP_SYSTEM_PROMPT` | cli.tsx | `--dump-system-prompt` 快速路径 |
| `CHICAGO_MCP` | cli.tsx | `--computer-use-mcp` 快速路径 |
| `DAEMON` | cli.tsx | `--daemon-worker` 和 `daemon` 子命令 |
| `BRIDGE_MODE` | cli.tsx | `remote-control`/`bridge`/`sync`/`rc` |
| `BG_SESSIONS` | cli.tsx | `ps`/`logs`/`attach`/`kill`/`--bg` |
| `TEMPLATES` | cli.tsx | `new`/`list`/`reply` 模板命令 |
| `LODESTONE` | cli.tsx | `--handle-uri` 和 macOS URL 处理 |
| `KAIROS` | cli.tsx | `assistant` 模式 |
| `SSH_REMOTE` | cli.tsx | `ssh` 子命令 |
| `DIRECT_CONNECT` | cli.tsx | `server` 和 `open` 子命令 |
| `TRANSCRIPT_CLASSIFIER` | cli.tsx | Auto Mode (AFK) |
| `CONTEXT_COLLAPSE` | cli.tsx | 上下文压缩服务 |

---

## CLI 入口点差异

| 入口点 | 文件 | 特点 |
|--------|------|------|
| CLI (main.tsx) | main.tsx | 完整 REPL |
| MCP (mcp.ts) | mcp.ts | 仅内置工具，无 MCP 工具 |
| SDK | agentSdkTypes.ts | SDKMessage 流式传输 |
