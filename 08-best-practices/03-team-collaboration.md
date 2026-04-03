# 8.3 团队协作规范

> 团队中使用 Claude Code 的最佳实践和规范

---

## 团队配置策略

### 1. 配置文件分层

```
项目根目录/
├── .claude/
│   ├── settings.json         # ✅ 提交 - 统一规范 (permissions 在 settings.json 的 permissions 字段)
├── .claudeignore             # ✅ 提交 - 忽略规则
└── settings.local.json      # ❌ 不提交 - 本地覆盖
```

### 2. 权限分级

| 级别 | 配置 | 适用人员 |
|------|------|----------|
| 严格 | `dontAsk` + 详细白名单 | 所有成员 |
| 中等 | `default` + 有限 allow | 开发者 |
| 宽松 | `acceptEdits` | 管理员 |

### 3. 统一配置示例

```json
// .claude/settings.json
{
  "permissions": {
    "defaultMode": "dontAsk",
    "allow": [
      "Read",
      "Write(src/**)",
      "Edit",
      "Glob",
      "Grep",
      "Bash(npm *)",
      "Bash(git *)",
      "Bash(pytest *)",
      "Bash(node *)"
    ],
    "deny": [
      "Bash(rm -rf .)",
      "Bash(rm -rf node_modules)",
      "Bash(sudo *)",
      "Write(*.env)",
      "Write(*.pem)",
      "Write(*.key)",
      "Write(/etc/**)"
    ]
  }
}
```

---

## Hooks 规范

### 1. 项目级 Hooks

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "hooks/pre-command.sh",
            "if": "git commit"
          }
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "hooks/post-command.sh"
          }
        ]
      }
    ]
  }
}
```

### 2. Hook 类型

Hook 支持 4 种类型（文档仅展示了 `command`）：

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",   // 命令型: 执行本地脚本
            "command": "hooks/pre-command.sh"
          }
        ]
      },
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "prompt",   // 提示型: 修改用户输入
            "prompt": "确保命令安全"
          }
        ]
      },
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "agent",    // Agent 型: LLM 判断是否执行
            "agent": "security-reviewer"
          }
        ]
      },
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "http",     // HTTP 型: 发送请求到外部服务
            "url": "https://hooks.example.com/check",
            "method": "POST"
          }
        ]
      }
    ]
  }
}
```

### Hook 附加字段

```json
{
  "type": "command",
  "command": "hooks/check.sh",
  "async": true,           // 异步执行，不阻塞工具
  "once": true,           // 仅执行一次后移除
  "asyncRewake": true,     // 异步钩子出错时唤醒模型
  "if": "Bash(git *)"     // 条件执行（permission rule 语法）
}
```

### 3. Hooks 目录结构

```
.claude/
├── hooks/
│   ├── pre-command.sh        # 执行前验证
│   ├── post-command.sh       # 执行后记录
│   ├── commit-msg.sh         # Git 提交信息验证
│   └── code-style.sh         # 代码风格检查
└── settings.json
```

### 3. 团队共享 Hooks

```bash
#!/bin/bash
# hooks/pre-command.sh
# 团队统一的命令执行前检查

COMMAND=$1

# 检查危险命令
if echo "$COMMAND" | grep -qE "^rm\s+-rf"; then
  echo "❌ 危险命令被阻止"
  exit 2
fi

# 检查是否在正确目录
if [[ "$COMMAND" == *"git push"* ]]; then
  if ! git diff-index --quiet HEAD -- 2>/dev/null; then
    echo "⚠️ 存在未提交的更改"
  fi
fi

exit 0
```

---

## Skills 规范

### 1. 团队 Skill 目录

```
~/.claude/skills/
├── team/
│   ├── code-review/         # 团队代码审查
│   ├── deploy/              # 部署流程
│   └── docs/                # 文档生成
└── personal/                # 个人 Skills
```

### 2. 团队 Skill 模板

```markdown
---
name: team-code-review
description: 团队统一代码审查流程
author: team
version: 1.0.0
---

# 团队代码审查

## 审查清单

- [ ] 代码风格检查通过
- [ ] 单元测试覆盖
- [ ] 无安全漏洞
- [ ] 文档更新

## 审查标准

1. **可读性**: 代码清晰易读
2. **可维护性**: 模块化设计
3. **性能**: 无明显性能问题
4. **安全**: 无安全漏洞
```

### 3. Skill 版本管理

```markdown
---
name: team-deploy
version: 1.0.0
updated: 2026-04-01
changelog:
  - "1.0.0: 初始版本"
  - "1.1.0: 添加预检查"
---

# 部署流程
```

---

## 命名规范

### 1. 项目命名

```json
// 注意: project.slug 和 project.language 不存在于源码中
{
  "project": {
    "name": "my-app"
  }
}
```

### 2. Agent 命名

```json
{
  "agents": {
    "frontend-reviewer": {...},
    "backend-reviewer": {...},
    "security-auditor": {...}
  }
}
```

### 3. Hook 命名

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash(deploy*)"
      }
    ]
  }
}
```

---

## 文档规范

### 1. 项目 README

```markdown
# 项目名称

## Claude Code 配置

### 安装
```bash
npm install
claude init
```

### 权限配置
本项目使用 `dontAsk` 权限模式。

### 团队 Hooks
- pre-command: 命令执行前检查
- post-command: 命令执行后记录
```

### 2. 贡献指南

```markdown
## Claude Code 使用规范

### 首次使用
1. 运行 `claude init`
2. 阅读 `.claude/settings.json`
3. 了解权限配置

### 开发流程
1. 使用 `claude` 启动会话
2. 遵循代码审查流程
3. 提交前运行测试
```

### 3. 团队文档结构

```
docs/
├── claude-code/
│   ├── getting-started.md
│   ├── configuration.md
│   ├── hooks.md
│   └── skills.md
└── contributing.md
```

---

## 协作流程

### 1. 新成员加入

```bash
# 1. 克隆项目
git clone git@github.com:team/project.git
cd project

# 2. 安装 Claude Code
brew install anthropic/formulae/claude-code

# 3. 初始化
claude init

# 4. 查看团队配置
# 直接查看 .claude/settings.json 或使用 /config 命令
cat .claude/settings.json

# 5. 了解权限
# Claude Code 会在需要时自动提示权限请求
```

### 2. 日常开发

```bash
# 1. 每日开始
claude
> pull latest changes
> review my tasks

# 2. 完成任务
> implement feature
> run tests
> commit with message

# 3. 代码审查
> use team-code-review skill
```

### 3. 问题处理

```bash
# 1. 诊断问题
claude "debug: 用户无法登录"

# 2. 记录问题
> save diagnostic to /docs/issues/login-bug.md

# 3. 修复问题
> fix the bug
> run regression tests
```

---

## 权限管理

### 1. 权限分级

**注意**: `permissionMode` 不存在，正确字段是 `permissions.defaultMode`。`"ask"` 不是有效值，应使用 `"default"`。

```json
// 开发者权限
{
  "permissions": {
    "defaultMode": "dontAsk",
    "allow": [
      "Read",
      "Write(src/**)",
      "Bash(npm *)",
      "Bash(git *)"
    ]
  }
}

// 高级权限 (需要申请)
{
  "permissions": {
    "defaultMode": "default",
    "allow": ["Bash(*)"]
  }
}
```

### 2. 权限申请流程

```
1. 填写权限申请表
2. 说明使用场景
3. 团队负责人审批
4. 更新配置文件
```

### 3. 审计日志

**注意**: `permission_audit.log` 不存在于源码中。权限使用记录需通过会话 Transcript 查看。

```bash
# 通过 Transcript 查看权限使用记录
claude "生成本月权限使用报告"
```

---

## 安全规范

### 1. 敏感操作

```bash
# 危险命令必须手动确认
> rm -rf node_modules

# 敏感文件保护
# .env, *.pem, *.key 文件禁止修改
```

### 2. API Keys

```bash
# 永远不要在对话中暴露 keys
# 使用环境变量
export ANTHROPIC_API_KEY=xxx
```

### 3. 审计追踪

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "audit.sh"
          }
        ]
      }
    ]
  }
}
```

---

## 团队邮箱系统 (Team Mailbox)

### 1. 邮箱位置与结构

```
~/.claude/teams/{team_name}/inboxes/{agent_name}.json
```

每个 Agent 有一个独立的邮箱文件，用于团队成员之间的消息传递。

### 2. 消息类型

| 消息类型 | 用途 | 方向 |
|----------|------|------|
| `idle_notification` | Agent 空闲通知 | Worker -> Leader |
| `task_assignment` | 任务分配 | Leader -> Worker |
| `permission_request` | 权限请求 | Worker -> Leader |
| `sandbox_permission_request` | 沙箱网络权限请求 | Worker -> Leader |
| `permission_response` | 权限响应 | Leader -> Worker |
| `sandbox_permission_response` | 沙箱权限响应 | Leader -> Worker |
| `shutdown_request` | 关闭请求 | Leader -> Worker |
| `shutdown_approved` | 关闭确认 | Worker -> Leader |
| `shutdown_rejected` | 关闭拒绝 | Worker -> Leader |
| `plan_approval_request` | 计划审批请求 | Worker -> Leader |
| `plan_approval_response` | 计划审批响应 | Leader -> Worker |
| `mode_set_request` | 权限模式变更 | Leader -> Worker |
| `team_permission_update` | 团队权限更新广播 | Leader -> Workers |

### 3. 消息格式

```typescript
// 标准消息结构
interface TeammateMessage {
  from: string           // 发送者 Agent ID
  text: string           // 消息内容（JSON 字符串）
  timestamp: string      // ISO 时间戳
  read: boolean          // 是否已读
  color?: string         // 发送者颜色标记
  summary?: string       // 5-10 词摘要（UI 预览用）
}
```

### 4. Peer DM 可见性

当 Agent 向其他成员发送私信时，该消息的摘要会包含在空闲通知中：

```typescript
// 从最后一条助手消息提取 peer DM 摘要
"[to {agent_name}] {summary}"
```

这使得 Leader 可以追踪团队成员之间的通信状态。

---

## 执行后端 (Execution Backends)

### 1. 后端类型

| 后端 | 说明 | 使用场景 |
|------|------|----------|
| `tmux` | 传统 tmux 面板管理 | 标准终端环境 |
| `iterm2` | iTerm2 原生分屏 | iTerm2 用户 |
| `in-process` | 同 Node.js 进程的隔离上下文 | 轻量级/测试 |

### 2. tmux 后端

- 使用 tmux pane 进行 Agent 可视化
- 支持 pane 布局重平衡
- 支持 pane 隐藏/显示
- 可配置外部 session socket

### 3. iTerm2 后端

- 使用 iTerm2 原生 split panes
- 需要安装 `it2` CLI 工具
- 提供 pane 边框颜色和标题设置

### 4. in-process 后端

- 在同一 Node.js 进程中运行
- 使用隔离的上下文（AsyncLocalStorage）
- 适合测试和轻量级场景
- 支持 AbortController 进行生命周期管理

### 5. 后端配置

```json
// settings.json 中配置执行后端
{
  "swarm": {
    "backend": "tmux"  // 或 "iterm2", "in-process"
  }
}
```

---

## Agent 邮箱配置

### 1. 邮箱设置位置

```
~/.claude/teams/{team}/inboxes/{agent_name}.json
```

### 2. 环境变量

Agent 通过以下环境变量识别身份：

| 环境变量 | 说明 |
|----------|------|
| `CLAUDE_CODE_TEAM_NAME` | 团队名称 |
| `CLAUDE_CODE_AGENT_ID` | Agent 唯一标识 (格式: agentName@teamName) |
| `CLAUDE_CODE_AGENT_NAME` | Agent 名称 |
| `CLAUDE_CODE_AGENT_COLOR` | UI 显示颜色 |

### 3. Team Lead 识别

Team Lead 没有设置 `CLAUDE_CODE_AGENT_ID` 环境变量，或者其值为 `team-lead`。其他成员通过此特征识别 Leader。

---

## 权限同步系统 (Permission Sync)

### 1. 权限请求流程

```
Worker 遇到权限提示
    ↓
Worker 发送 permission_request 到 Leader 邮箱
    ↓
Leader 轮询邮箱检测到请求
    ↓
用户通过 Leader UI 审批/拒绝
    ↓
Leader 发送 permission_response 到 Worker 邮箱
    ↓
Worker 继续执行
```

### 2. 文件系统结构

```
~/.claude/teams/{team_name}/
├── permissions/
│   ├── pending/           # 待处理的请求
│   │   └── {request_id}.json
│   └── resolved/          # 已处理的请求（自动清理）
│       └── {request_id}.json
└── inboxes/
    └── {agent_name}.json
```

### 3. 权限请求消息格式

```typescript
interface PermissionRequestMessage {
  type: 'permission_request'
  request_id: string
  agent_id: string        // Worker 的 agent_id
  tool_name: string       // 需要权限的工具名
  tool_use_id: string     // 原始 toolUseID
  description: string    // 人类可读的描述
  input: Record<string, unknown>
  permission_suggestions: unknown[]
}
```

### 4. 权限响应消息格式

```typescript
// 成功响应
{
  type: 'permission_response',
  request_id: string,
  subtype: 'success',
  response: {
    updated_input?: Record<string, unknown>
    permission_updates?: unknown[]
  }
}

// 拒绝响应
{
  type: 'permission_response',
  request_id: string,
  subtype: 'error',
  error: string
}
```

### 5. Sandbox 权限

当沙箱运行时检测到非允许主机的网络访问时：

```typescript
interface SandboxPermissionRequestMessage {
  type: 'sandbox_permission_request'
  requestId: string
  workerId: string
  workerName: string
  workerColor?: string
  hostPattern: { host: string }
  createdAt: number
}
```

### 6. 团队权限更新广播

Leader 可以向所有成员广播权限更新：

```typescript
interface TeamPermissionUpdateMessage {
  type: 'team_permission_update'
  permissionUpdate: {
    type: 'addRules'
    rules: Array<{ toolName: string; ruleContent?: string }>
    behavior: 'allow' | 'deny' | 'ask'
    destination: 'session'
  }
  directoryPath: string
  toolName: string
}
```

---

## 质量保证

### 1. 代码质量

```bash
# 提交前检查
> lint && test && build

# 代码审查
> use team-code-review skill
```

### 2. 测试覆盖

```bash
# 单元测试
claude "run unit tests"

# 集成测试
claude "run integration tests"

# E2E 测试
claude "run e2e tests"
```

### 3. 性能监控

```bash
# 定期检查
claude "check build performance"
claude "analyze bundle size"
```

---

## 问题反馈

### 1. 问题模板

```markdown
## 问题描述
[详细描述问题]

## 复现步骤
1.
2.
3.

## 期望行为
[期望结果]

## 实际行为
[实际结果]

## Claude Code 版本
[version]

## 配置信息
[相关配置]
```

### 2. 反馈渠道

| 类型 | 渠道 |
|------|------|
| 配置问题 | GitHub Issue |
| 功能建议 | 团队讨论 |
| 安全问题 | 私下沟通 |
| 文档改进 | PR |

### 3. 持续改进

```bash
# 定期回顾
> review Claude Code usage last month
> identify improvements
> update team guidelines
```
