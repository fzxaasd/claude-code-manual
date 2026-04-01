# Hook 系统详解

> 基于源码 `src/entrypoints/sdk/coreSchemas.ts` 深度分析

## 概述

Claude Code Hook 系统提供 27 种生命周期钩子，允许在关键事件点执行自定义逻辑。

---

## 完整的 Hook 类型（27种）

### 1. 工具执行类（4种）

#### PreToolUse ⭐ 最常用
**触发时机**: 工具执行前

**输入参数**:
```typescript
{
  hook_event_name: "PreToolUse",
  tool_name: string,           // 工具名称，如 "Bash", "Read"
  tool_input: unknown,          // 工具输入参数
  tool_use_id: string,          // 工具调用唯一 ID
  session_id: string,
  transcript_path: string,
  cwd: string,
  agent_id?: string,            // 子代理 ID（仅在子代理中）
  agent_type?: string           // 子代理类型
}
```

**响应选项**:
```json
{
  "continue": true,             // 是否继续执行（默认 true）
  "decision": "approve",        // approve | block
  "updatedInput": {...},        // 修改后的工具输入
  "permissionDecision": "allow", // 权限决策
  "additionalContext": "..."    // 附加上下文
}
```

**Exit Code**:
- `0`: 继续执行，stdout 可作为上下文传递给模型
- `2`: 阻止执行，stderr 显示给模型

---

#### PostToolUse
**触发时机**: 工具成功执行后

**输入参数**:
```typescript
{
  hook_event_name: "PostToolUse",
  tool_name: string,
  tool_input: unknown,
  tool_response: unknown,       // 工具执行结果
  tool_use_id: string,
  session_id: string,
  transcript_path: string,
  cwd: string
}
```

**用途**: 结果验证、日志记录、输出修改（MCP 工具）

---

#### PostToolUseFailure
**触发时机**: 工具执行失败

**输入参数**:
```typescript
{
  hook_event_name: "PostToolUseFailure",
  tool_name: string,
  tool_input: unknown,
  tool_use_id: string,
  error: string,                // 错误信息
  is_interrupt: boolean,        // 是否为中断错误
  session_id: string,
  transcript_path: string,
  cwd: string
}
```

**用途**: 错误处理、自动修复尝试、错误日志

---

#### PermissionDenied
**触发时机**: 自动模式拒绝工具执行

**输入参数**:
```typescript
{
  hook_event_name: "PermissionDenied",
  tool_name: string,
  tool_input: unknown,
  tool_use_id: string,
  reason: string,               // 拒绝原因
  session_id: string,
  transcript_path: string,
  cwd: string
}
```

**用途**: 权限申诉处理、替代方案建议

---

### 2. 会话生命周期（4种）

#### SessionStart
**触发时机**: 会话启动

**输入参数**:
```typescript
{
  hook_event_name: "SessionStart",
  source: "startup" | "resume" | "clear" | "compact",
  agent_type?: string,
  model?: string,
  session_id: string,
  transcript_path: string,
  cwd: string
}
```

**用途**: 初始化检查、资源预加载、环境准备

---

#### Setup
**触发时机**: Claude Code 初始化或维护任务时

**输入参数**:
```typescript
{
  hook_event_name: "Setup",
  trigger: "init" | "maintenance",  // init=启动时, maintenance=维护任务时
  session_id: string,
  transcript_path: string,
  cwd: string
}
```

**用途**: 环境初始化、依赖检查、配置验证

**注意**: HTTP Hook 不支持 Setup 事件

---

#### SessionEnd
**触发时机**: 会话结束

**输入参数**:
```typescript
{
  hook_event_name: "SessionEnd",
  session_id: string,
  transcript_path: string,
  cwd: string
}
```

**用途**: 清理、保存状态、最终报告

---

#### Stop
**触发时机**: Claude 响应结束前

**输入参数**:
```typescript
{
  hook_event_name: "Stop",
  stop_hook_active: boolean,   // Stop Hook 是否启用
  last_assistant_message?: string, // 最后一条助手消息
  session_id: string,
  transcript_path: string,
  cwd: string
}
```

**Exit Code**:
- `0`: 正常停止
- `2`: 继续对话，不停止

---

#### StopFailure
**触发时机**: API 错误导致停止

**输入参数**:
```typescript
{
  hook_event_name: "StopFailure",
  error: { ... },              // SDKAssistantMessageError
  error_details?: string,
  last_assistant_message?: string,
  session_id: string,
  transcript_path: string,
  cwd: string
}
```

**用途**: 错误日志、告警通知

---

### 3. 用户交互类（4种）

#### UserPromptSubmit ⭐ 常用
**触发时机**: 用户提交提示词

**输入参数**:
```typescript
{
  hook_event_name: "UserPromptSubmit",
  prompt: string,              // 用户输入内容
  session_id: string,
  transcript_path: string,
  cwd: string
}
```

**Exit Code**:
- `0`: 正常提交
- `2`: 阻止提交并清除输入

**用途**: 输入验证、内容过滤、安全检查

---

#### Notification
**触发时机**: 发送通知时

**输入参数**:
```typescript
{
  hook_event_name: "Notification",
  message: string,
  title?: string,
  notification_type: string,
  session_id: string,
  transcript_path: string,
  cwd: string
}
```

**用途**: 通知转发、第三方集成

---

#### Elicitation
**触发时机**: MCP 服务器请求用户输入

**输入参数**:
```typescript
{
  hook_event_name: "Elicitation",
  mcp_server_name: string,
  message: string,
  mode?: "form" | "url",
  url?: string,
  elicitation_id?: string,
  requested_schema?: Record<string, unknown>,
  session_id: string,
  transcript_path: string,
  cwd: string
}
```

**响应选项**:
```json
{
  "action": "accept" | "decline" | "cancel",
  "content": { ... }
}
```

**用途**: 自动化表单填充

---

#### ElicitationResult
**触发时机**: 用户响应 elicitation 后

**输入参数**:
```typescript
{
  hook_event_name: "ElicitationResult",
  mcp_server_name: string,
  elicitation_id?: string,
  mode?: "form" | "url",
  action: "accept" | "decline" | "cancel",
  content?: Record<string, unknown>,  // 用户提交的表单数据
  session_id: string,
  transcript_path: string,
  cwd: string
}
```

**用途**: 响应处理、覆盖修改

---

### 4. 子 Agent 类（2种）

#### SubagentStart
**触发时机**: 子 Agent 启动

**输入参数**:
```typescript
{
  hook_event_name: "SubagentStart",
  agent_id: string,
  agent_type: string,
  session_id: string,
  transcript_path: string,
  cwd: string
}
```

**用途**: 初始化上下文、资源分配

---

#### SubagentStop
**触发时机**: 子 Agent 结束前

**输入参数**:
```typescript
{
  hook_event_name: "SubagentStop",
  stop_hook_active: boolean,
  agent_id: string,
  agent_transcript_path: string,
  agent_type: string,
  last_assistant_message?: string,
  session_id: string,
  transcript_path: string,
  cwd: string
}
```

**Exit Code**:
- `0`: 正常停止
- `2`: 继续运行

---

### 5. 上下文压缩类（2种）

#### PreCompact
**触发时机**: 压缩前

**输入参数**:
```typescript
{
  hook_event_name: "PreCompact",
  trigger: "manual" | "auto",
  custom_instructions: string | null,
  session_id: string,
  transcript_path: string,
  cwd: string
}
```

**Exit Code**:
- `0`: stdout 追加为自定义压缩指令
- `2`: 阻止压缩

---

#### PostCompact
**触发时机**: 压缩后

**输入参数**:
```typescript
{
  hook_event_name: "PostCompact",
  trigger: "manual" | "auto",
  compact_summary: string,      // 压缩生成的摘要
  session_id: string,
  transcript_path: string,
  cwd: string
}
```

**用途**: 验证压缩质量、记录摘要

---

### 6. 权限与配置类（2种）

#### PermissionRequest
**触发时机**: 权限对话框显示

**输入参数**:
```typescript
{
  hook_event_name: "PermissionRequest",
  tool_name: string,
  tool_input: unknown,
  permission_suggestions?: PermissionUpdate[],
  session_id: string,
  transcript_path: string,
  cwd: string
}
```

**响应选项**:
```json
{
  "decision": {
    "behavior": "allow",
    "updatedInput": {...},
    "updatedPermissions": [...]
  } | {
    "behavior": "deny",
    "message": "...",
    "interrupt": true
  }
}
```

**用途**: 自动授权决策

---

#### ConfigChange
**触发时机**: 配置文件变更

**输入参数**:
```typescript
{
  hook_event_name: "ConfigChange",
  source: "user_settings" | "project_settings" | "local_settings" | "policy_settings" | "skills",
  file_path?: string,
  session_id: string,
  transcript_path: string,
  cwd: string
}
```

**Exit Code**:
- `0`: 接受变更
- `2`: 阻止变更

---

### 7. Git Worktree 类（2种）

#### WorktreeCreate
**触发时机**: 创建 worktree

**输入参数**:
```typescript
{
  hook_event_name: "WorktreeCreate",
  name: string,
  session_id: string,
  transcript_path: string,
  cwd: string
}
```

---

#### WorktreeRemove
**触发时机**: 删除 worktree

**输入参数**:
```typescript
{
  hook_event_name: "WorktreeRemove",
  worktree_path: string,
  session_id: string,
  transcript_path: string,
  cwd: string
}
```

---

### 8. 指令加载类（1种）

#### InstructionsLoaded
**触发时机**: 加载 CLAUDE.md 或其他指令文件

**输入参数**:
```typescript
{
  hook_event_name: "InstructionsLoaded",
  file_path: string,
  memory_type: "User" | "Project" | "Local" | "Managed",
  load_reason: "session_start" | "nested_traversal" | "path_glob_match" | "include" | "compact",
  globs?: string[],
  trigger_file_path?: string,
  parent_file_path?: string,
  session_id: string,
  transcript_path: string,
  cwd: string
}
```

**用途**: 审计追踪、指令变更检测

---

### 9. 文件与目录监控（2种）

#### CwdChanged
**触发时机**: 工作目录变更

**输入参数**:
```typescript
{
  hook_event_name: "CwdChanged",
  old_cwd: string,
  new_cwd: string,
  session_id: string,
  transcript_path: string,
  cwd: string
}
```

**用途**: 环境变量注入、路径更新

---

#### FileChanged
**触发时机**: 监视的文件变更

**输入参数**:
```typescript
{
  hook_event_name: "FileChanged",
  file_path: string,
  event: "change" | "add" | "unlink",
  session_id: string,
  transcript_path: string,
  cwd: string
}
```

**用途**: 配置热重载、依赖监听

---

### 10. 团队协作类（3种）

#### TeammateIdle
**触发时机**: 队友空闲

**输入参数**:
```typescript
{
  hook_event_name: "TeammateIdle",
  teammate_name: string,
  team_name: string,
  session_id: string,
  transcript_path: string,
  cwd: string
}
```

---

#### TaskCreated
**触发时机**: 任务创建

**输入参数**:
```typescript
{
  hook_event_name: "TaskCreated",
  task_id: string,
  task_subject: string,
  task_description?: string,
  teammate_name?: string,
  team_name?: string,
  session_id: string,
  transcript_path: string,
  cwd: string
}
```

---

#### TaskCompleted
**触发时机**: 任务完成

**输入参数**:
```typescript
{
  hook_event_name: "TaskCompleted",
  task_id: string,
  task_subject: string,
  task_description?: string,
  teammate_name?: string,
  team_name?: string,
  session_id: string,
  transcript_path: string,
  cwd: string
}
```

---

## Hook 执行规范

### Exit Code 语义

| Exit Code | 语义 | 适用 Hook |
|-----------|------|-----------|
| 0 | 成功/继续 | 所有 Hook |
| 1 | 非阻塞错误 | 所有 Hook |
| 2 | 阻塞错误 | PreToolUse, Stop, SubagentStop, PreCompact, ConfigChange |

### 基础 Hook 输入

所有 Hook 都包含以下基础字段：

```typescript
{
  session_id: string,          // 会话 ID
  transcript_path: string,      // 转录文件路径
  cwd: string,                  // 当前工作目录
  permission_mode?: string,     // 权限模式
  agent_id?: string,            // 子代理 ID（仅子代理中）
  agent_type?: string           // 子代理类型
}
```

### Hook 响应字段

所有同步 Hook 响应支持以下通用字段：

```typescript
{
  continue?: boolean,           // 是否继续（默认 true）
  suppressOutput?: boolean,     // 抑制输出
  stopReason?: string,          // 停止原因
  decision?: "approve" | "block", // 决策
  systemMessage?: string,       // 系统消息，插入到上下文
  reason?: string,              // 原因说明
  hookSpecificOutput?: {...}    // Hook 特定输出
}
```

### HTTP Hook 限制

HTTP Hook 不支持以下事件：
- `Setup`
- `SessionStart`

尝试在这些事件中使用 HTTP Hook 将被忽略。

---

## 配置示例

### 完整配置结构

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash|Edit|Write",
        "hooks": [
          {
            "type": "command",
            "command": "python3 security-check.py",
            "timeout": 5,
            "if": "Bash(git *)"
          }
        ]
      }
    ],
    "PostToolUse": [...],
    "UserPromptSubmit": [...],
    "SessionStart": [...],
    "PreCompact": [...],
    "FileChanged": [...]
  }
}
```

### Hook 类型支持

| type | 说明 |
|------|------|
| command | 执行 shell 命令 |
| prompt | 调用 LLM 处理 |
| agent | 调用 Agent 处理 |
| http | 发送 HTTP 请求 |

---

## ⚠️ 重要发现

1. **Claude Code 不支持 PreCommit Hook**
   - ❌ `PreCommit` 不存在！
   - 使用 `PreToolUse` + `UserPromptSubmit` 组合替代

2. **Hook 来源优先级**
   ```
   policySettings > flagSettings > localSettings > projectSettings > userSettings
   ```

3. **配置位置**
   - 用户级: `~/.claude/settings.json`
   - 项目级: `.claude/settings.json`
   - 本地级: `.claude/settings.local.json`
   - 插件级: `~/.claude/plugins/*/hooks/hooks.json`

---

## 测试验证

运行测试脚本验证 Hook 配置：
```bash
bash tests/00-hooks-test.sh
```
