# 8.3 团队协作规范

> 团队中使用 Claude Code 的最佳实践和规范

---

## 团队配置策略

### 1. 配置文件分层

```
项目根目录/
├── .claude/
│   ├── settings.json         # ✅ 提交 - 统一规范
│   ├── permissions.json      # ✅ 提交 - 统一权限
│   └── hooks.json            # ✅ 提交 - 统一 Hooks
├── .claudeignore             # ✅ 提交 - 忽略规则
└── settings.local.json      # ❌ 不提交 - 本地覆盖
```

### 2. 权限分级

| 级别 | 配置 | 适用人员 |
|------|------|----------|
| 严格 | `limiting` + 详细白名单 | 所有成员 |
| 中等 | `ask` + 有限 allow | 开发者 |
| 宽松 | `all` | 管理员 |

### 3. 统一配置示例

```json
// .claude/settings.json
{
  "project": {
    "name": "team-project",
    "version": "1.0.0"
  },
  "permissionMode": "dontAsk",
  "permissions": {
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

### 2. Hooks 目录结构

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
{
  "project": {
    "name": "my-app",
    "slug": "my-app",
    "language": "zh-CN"
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
本项目使用 `limiting` 权限模式。

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
claude config show --scope project

# 5. 了解权限
claude permissions show
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

```json
// 开发者权限
{
  "permissionMode": "dontAsk",
  "permissions": {
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
  "permissionMode": "ask",
  "permissions": {
    "allow": ["*"]
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

```bash
# 查看权限使用记录
~/.claude/permission_audit.log

# 定期审计
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
