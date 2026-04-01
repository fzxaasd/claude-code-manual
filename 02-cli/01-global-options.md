# Claude Code CLI 全局选项

> 基于 `claude --help` 和源码的完整参数参考

## 基本用法

```bash
claude [options] [command] [prompt]
```

## 核心选项

### 1. 认证与连接

| 参数 | 说明 | 示例 |
|------|------|------|
| `--add-dir <dirs...>` | 允许访问的额外目录（可重复） | `--add-dir /data/projects` |
| `--model <model>` | 指定模型 | `--model sonnet` |
| `--fallback-model <model>` | 模型过载时的备用模型 | `--fallback-model opus` |

### 2. 执行模式

| 参数 | 说明 | 示例 |
|------|------|------|
| `-p, --print` | 非交互模式，打印输出 | `claude -p "翻译代码"` |
| `-c, --continue` | 继续上次会话 | `claude -c` |
| `-r, --resume [id]` | 恢复指定会话 | `claude -r abc123` |
| `-n, --name <name>` | 会话名称 | `claude -n "feature-x"` |
| `--bare` | 最小模式，跳过自动发现 | `--bare` |
| `--input-format <format>` | 输入格式 (`text`, `stream-json`) | `--input-format stream-json` |
| `--output-format <format>` | 输出格式 (`text`, `json`, `stream-json`) | `--output-format json` |
| `--json-schema <schema>` | 结构化输出 Schema | `--json-schema '{"type":"object"}'` |

### 3. 会话控制

| 参数 | 说明 | 示例 |
|------|------|------|
| `--session-id <uuid>` | 指定会话 ID | `--session-id abc-123` |
| `--no-session-persistence` | 禁用会话持久化 | `--no-session-persistence` |
| `--fork-session` | 恢复时创建新会话 ID | `--fork-session -r abc123` |
| `--resume-session-at <message id>` | 恢复到指定消息 | `--resume-session-at msg_xyz` |
| `--rewind-files <user-message-id>` | 重置文件到指定状态 | `--rewind-files <id> --resume` |
| `--max-turns <turns>` | 非交互模式最大轮数 | `--max-turns 5` |

### 4. 权限控制

| 参数 | 说明 | 示例 |
|------|------|------|
| `--permission-mode <mode>` | 权限模式 | `--permission-mode auto` |
| `--dangerously-skip-permissions` | 跳过所有检查（危险） | |
| `--allow-dangerously-skip-permissions` | 允许此选项但不默认启用 | |
| `--allowed-tools <tools...>` | 允许的工具白名单（variadic） | `--allowed-tools Read,Bash(git:*)` |
| `--disallowed-tools <tools...>` | 禁止的工具黑名单（variadic） | `--disallowed-tools Write,Edit` |
| `--tools <tools...>` | 可用工具列表（variadic） | `--tools Read,Edit` 或 `--tools ""` 禁用全部 |

### 5. 配置

| 参数 | 说明 | 示例 |
|------|------|------|
| `--settings <file-or-json>` | 配置文件路径或 JSON 字符串 | `--settings ./config.json` |
| `--setting-sources <sources>` | 加载的配置源 | `--setting-sources user,project` |
| `--system-prompt <prompt>` | 系统提示词 | `--system-prompt "你是一个..."` |
| `--system-prompt-file <file>` | 从文件读取系统提示词 | `--system-prompt-file ./system.md` |
| `--append-system-prompt <prompt>` | 追加系统提示词 | |
| `--append-system-prompt-file <file>` | 从文件追加系统提示词 | |
| `--prefill <text>` | 预填充输入框（不提交） | `--prefill "初始内容"` |

### 6. Agent 配置

| 参数 | 说明 | 示例 |
|------|------|------|
| `--agent <agent>` | 指定 Agent（覆盖设置中的 agent） | `--agent reviewer` |
| `--agents <json>` | 自定义 Agents JSON | `--agents '{"codewriter":{"prompt":"..."}}'` |
| `--effort <level>` | 努力级别 (`low`, `medium`, `high`, `max`) | `--effort high` |
| `--betas <betas...>` | Beta 功能头部（variadic，API key 用户） | `--betas feature-x` |

### 7. 调试

| 参数 | 说明 | 示例 |
|------|------|------|
| `-d, --debug [filter]` | 调试模式 | `--debug hooks` |
| `--debug-to-stderr` | 调试输出到 stderr | |
| `--debug-file <path>` | 调试日志文件 | `--debug-file /tmp/debug.log` |
| `--verbose` | 覆盖 verbose 设置 | |
| `--mcp-debug` | MCP 调试模式（已废弃，使用 --debug） | |

### 8. MCP 配置

| 参数 | 说明 | 示例 |
|------|------|------|
| `--mcp-config <configs...>` | MCP 配置文件（variadic） | `--mcp-config ./mcp.json` |
| `--strict-mcp-config` | 仅使用 --mcp-config 的配置 | |
| `--plugin-dir <path>` | 插件目录 | `--plugin-dir ./plugins` |

### 9. 输出控制

| 参数 | 说明 | 示例 |
|------|------|------|
| `--include-hook-events` | 包含 Hook 生命周期事件（需 --output-format=stream-json） | |
| `--include-partial-messages` | 包含部分消息块（需 --print 和 --output-format=stream-json） | |
| `--replay-user-messages` | 重新输出用户消息确认（需 stream-json 模式） | |
| `--max-budget-usd <amount>` | 最大花费 | `--max-budget-usd 1.0` |
| `--task-budget <tokens>` | API 端任务预算 | |
| `--workload <tag>` | 工作负载标识（计费用） | `--workload cron-job` |

### 10. 思考模式

| 参数 | 说明 | 示例 |
|------|------|------|
| `--thinking <mode>` | 思考模式 (`enabled`, `adaptive`, `disabled`) | `--thinking enabled` |
| `--max-thinking-tokens <tokens>` | 最大思考 token 数（已废弃） | |

### 11. 实验性功能

| 参数 | 说明 | 示例 |
|------|------|------|
| `--betas <betas...>` | Beta 功能标记（variadic） | `--betas feature-x` |
| `--chrome` | 启用 Chrome 集成 | |
| `--no-chrome` | 禁用 Chrome 集成 | |
| `--ide` | 自动连接 IDE | |
| `--tmux` | 创建 tmux 会话（需 --worktree） | `--tmux --worktree feature-x` |
| `-w, --worktree [name]` | Git worktree | `-w feature-auth` |
| `--init` | 运行初始化 hooks 后继续 | `--init` |
| `--init-only` | 运行初始化 hooks 后退出 | `--init-only` |
| `--maintenance` | 运行维护 hooks | `--maintenance` |

### 12. 远程控制

| 参数 | 说明 | 示例 |
|------|------|------|
| `--remote` | 启用远程控制 | `--remote "任务描述"` |
| `--remote-control [name]` | 远程控制（可选命名） | |
| `--rc [name]` | `--remote-control` 的别名 | |

### 13. 其他

| 参数 | 说明 | 示例 |
|------|------|------|
| `-v, --version` | 版本信息 | |
| `-h, --help` | 帮助信息 | |
| `--disable-slash-commands` | 禁用所有技能 | |
| `--file <specs...>` | 启动时下载的文件资源 | `--file file_abc:doc.txt` |
| `--deep-link-origin` | 深层链接启动信号 | |
| `--from-pr [value]` | 从 PR 恢复会话 | `--from-pr 123` |

---

## 权限模式 (permission-mode)

| 模式 | 说明 |
|------|------|
| `default` | 默认行为，询问用户 |
| `acceptEdits` | 自动接受编辑操作 |
| `bypassPermissions` | 绕过所有检查（危险） |
| `dontAsk` | 不询问，直接拒绝 |
| `plan` | 仅在计划模式下允许 |
| `auto` | 自动模式，基于分类器 |

---

## 输出格式 (output-format)

| 格式 | 说明 |
|------|------|
| `text` | 纯文本（默认） |
| `json` | JSON 结构化输出 |
| `stream-json` | 流式 JSON |

---

## 输入格式 (input-format)

| 格式 | 说明 |
|------|------|
| `text` | 纯文本（默认） |
| `stream-json` | 流式 JSON 输入 |

---

## 使用示例

### 1. 基本使用

```bash
# 交互模式
claude

# 非交互模式
claude -p "解释这段代码的含义"

# 继续上次会话
claude -c
```

### 2. 会话管理

```bash
# 命名会话
claude -n "feature-auth"

# 恢复指定会话
claude -r session-123

# 继续并使用新会话名
claude -c -n "new-session-name"

# Fork 新会话
claude --fork-session -r session-123
```

### 3. 权限控制

```bash
# 仅允许读取
claude --allowed-tools Read

# 自动接受编辑
claude --permission-mode acceptEdits

# 白名单模式
claude --allowed-tools "Read,Bash(git:*)"
```

### 4. 配置

```bash
# 使用配置文件
claude --settings ./config.json

# 只加载项目配置
claude --setting-sources project

# 自定义系统提示词
claude --append-system-prompt "始终用中文回答"

# 从文件加载系统提示词
claude --system-prompt-file ./system.md
```

### 5. 调试

```bash
# 调试所有
claude --debug

# 调试特定模块
claude --debug hooks,settings

# 排除特定模块
claude --debug "!file,!1p"

# 输出到文件
claude --debug-file /tmp/claude-debug.log
```

### 6. 高级

```bash
# Git worktree
claude -w feature-x

# 指定模型
claude --model opus

# 高努力级别
claude --effort max

# MCP 配置
claude --mcp-config ./mcp.json

# 限制花费
claude --max-budget-usd 5.0

# 思考模式
claude --thinking enabled "分析这段代码"

# 最大轮数
claude --print --max-turns 3 "执行任务"
```

### 7. 自定义 Agent

```bash
# 使用内置 Agent
claude --agent reviewer "审查代码变更"

# 自定义 Agent
claude --agents '{"myagent":{"description":"Custom agent","prompt":"You are..."}}'
```

### 8. 预填充与部分消息

```bash
# 预填充输入
claude --prefill "已完成代码审查"

# 包含部分消息（stream-json）
claude --print --output-format stream-json --include-partial-messages "分析"
```

---

## 环境变量

### 认证

```bash
export ANTHROPIC_API_KEY="sk-ant-..."
export ANTHROPIC_AUTH_TOKEN="..."
export ANTHROPIC_BASE_URL="https://api.anthropic.com"
```

### 调试

```bash
export CLAUDE_DEBUG=1
export CLAUDE_DEBUG_FILTER="hooks"
```

### 代理

```bash
export HTTP_PROXY="http://proxy:8080"
export HTTPS_PROXY="http://proxy:8080"
```

### 其他

```bash
export CLAUDE_CODE_SIMPLE=1          # 最小模式
export CLAUDE_CODE_DISABLE_TERMINAL_TITLE=1  # 禁用终端标题修改
```
