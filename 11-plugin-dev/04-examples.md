# 11.4 开发示例

> 从零开始创建完整的 Claude Code 插件

---

## 示例：代码审查插件

### 项目结构

```
code-review-plugin/
├── .claude-plugin/
│   └── plugin.json
├── skills/
│   └── review/
│       └── SKILL.md
├── agents/
│   └── reviewer.md
├── hooks/
│   ├── hooks.json
│   └── security-hook.sh
└── output-styles/
    └── review.css
```

> 注意：插件清单必须位于 `.claude-plugin/plugin.json`，不是根目录的 `manifest.json`。

---

## 步骤 1: 创建项目

```bash
mkdir code-review-plugin && cd code-review-plugin
mkdir -p .claude-plugin skills/review agents hooks output-styles
```

---

## 步骤 2: 创建 plugin.json

```json
{
  "name": "code-review-plugin",
  "version": "1.0.0",
  "description": "代码审查插件 - 自动检查代码质量和安全问题",
  "author": {
    "name": "Developer"
  },
  "skills": "./skills",
  "agents": "./agents",
  "hooks": "./hooks",
  "outputStyles": "./output-styles",
  "mcpServers": {
    "eslint-server": {
      "command": "npx",
      "args": ["-y", "eslint-lsp"]
    }
  },
  "userConfig": {
    "enabled": {
      "type": "boolean",
      "description": "启用代码审查",
      "default": true
    },
    "strictMode": {
      "type": "boolean",
      "description": "严格模式",
      "default": false
    }
  }
}
```

> 注意：skills/agents/hooks 配置只支持路径字符串或数组，不支持 `{ directory, autoLoad }` 对象格式。

---

## 步骤 3: 创建 Skill

### skills/review/SKILL.md

```markdown
---
name: code-review
description: 自动代码审查助手
when_to_use: 当你需要审查代码或进行 PR 审查时使用
paths:
  - "*.ts"
  - "*.tsx"
  - "*.js"
  - "*.jsx"
tools:
  - Read
  - Glob
  - Grep
  - Bash(npm run lint)
  - Bash(git *)
version: "1.0.0"
---

# 代码审查助手

帮助你进行代码审查，发现潜在问题和改进建议。

## 审查范围

1. **代码质量**
   - 代码风格
   - 命名规范
   - 注释完整性

2. **安全性**
   - SQL 注入风险
   - XSS 漏洞
   - 敏感信息泄露

3. **性能**
   - 重复计算
   - 内存泄漏
   - 数据库查询效率

4. **可维护性**
   - 复杂度
   - 耦合度
   - 测试覆盖

## 使用方法

使用 code-review 技能审查代码：

```
> 使用 code-review 技能审查这个文件
> 使用 code-review 技能审查 PR
```

## 输出格式

审查报告包含：问题列表、严重程度评分、安全性评估、可读性评估等。
```

---

## 步骤 4: 创建 Agent

### agents/reviewer.md

```markdown
---
name: code-reviewer
description: 专业的代码审查 Agent
model: sonnet
effort: medium
tools:
  - Read
  - Glob
  - Grep
  - Bash(npm run lint)
  - Bash(npm test)
  - Bash(git diff)
  - Bash(git log)
disallowedTools:
  - Bash(rm -rf *)
  - Bash(sudo *)
  - Write(/etc/**)
maxTurns: 50
memory: project
skills:
  - code-review
  - security-check
hooks:
  PreToolUse:
    - matcher: "Bash"
      hooks:
        - type: command
          command: "${HOOK_DIR}/security-check.sh"
          timeout: 5
color: blue
---

# 代码审查专家 Agent

此 Agent 专注于代码质量和安全审查。

我是一个资深的代码审查专家，专注于：

1. **安全性审查**
   - 识别 SQL 注入、XSS、CSRF 等安全漏洞
   - 检查敏感信息处理
   - 验证认证授权逻辑

2. **代码质量**
   - 遵循项目代码规范
   - 检查命名和注释
   - 评估代码复杂度

3. **性能优化**
   - 识别性能瓶颈
   - 建议优化方案
   - 检查资源使用

4. **最佳实践**
   - 使用现代语言特性
   - 遵循 SOLID 原则
   - 适当的错误处理

请给出具体的改进建议和代码示例。
```

---

## 步骤 5: 创建 Hook

### hooks/security-hook.sh

```bash
#!/bin/bash
# 代码安全审查 Hook

COMMAND="$1"
TOOL_INPUT="$2"

# 检查危险操作
if echo "$TOOL_INPUT" | grep -qE "eval\(|exec\(|system\("; then
    echo "Warning: 潜在安全风险 — 动态代码执行"
    exit 0
fi

# 检查硬编码凭证
if echo "$TOOL_INPUT" | grep -qE "password\s*=\s*['\"][^'\"]+['\"]"; then
    echo "Warning: 检测到硬编码密码"
    exit 0
fi

exit 0
```

### hooks/hooks.json

```json
{
  "description": "代码安全审查 hooks",
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "${HOOK_DIR}/security-hook.sh",
            "timeout": 5
          }
        ]
      }
    ],
    "UserPromptSubmit": [
      {
        "matcher": "*commit*",
        "hooks": [
          {
            "type": "command",
            "command": "${HOOK_DIR}/pre-commit-check.sh",
            "timeout": 30
          }
        ]
      }
    ]
  }
}
```

---

## 步骤 6: 创建 output-styles

### output-styles/review.css

```css
/* 代码审查输出样式 */
.code-review {
  font-family: monospace;
  padding: 1em;
}

.review-issue {
  border-left: 3px solid var(--severity-color);
  padding-left: 1em;
  margin: 0.5em 0;
}

.review-issue.high { border-color: #dc3545; }
.review-issue.medium { border-color: #ffc107; }
.review-issue.low { border-color: #28a745; }
```

---

## 步骤 7: 本地测试

```bash
# 验证插件结构
cd code-review-plugin
ls -la .claude-plugin/

# 在 Claude Code 中安装
claude plugin install ./code-review-plugin

# 测试
> 使用 code-review 技能审查 src/auth/login.ts
```

---

## 完整目录

```
code-review-plugin/
├── .claude-plugin/
│   └── plugin.json
├── skills/
│   └── review/
│       └── SKILL.md
├── agents/
│   └── reviewer.md
├── hooks/
│   ├── hooks.json
│   └── security-hook.sh
└── output-styles/
    └── review.css
```

---

## 下一步

恭喜完成第一个插件！继续探索：

- MCP Server 集成
- LSP Server 集成
- 消息通道 (Telegram/Slack/Discord)
- 企业策略配置
