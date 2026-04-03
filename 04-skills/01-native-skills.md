# Claude Code 原生技能机制

> 基于源码 `src/skills/loadSkillsDir.ts`, `src/utils/frontmatterParser.ts` 深度分析

## 核心概念

### 技能来源

```
policySettings > userSettings > projectSettings > bundled > plugin
```

| 来源 | 路径 | 说明 |
|------|------|------|
| Managed | `~/.claude/plugins/marketplaces/.../.claude/skills/` | 企业管理 |
| User | `~/.claude/skills/` | 用户全局 |
| Project | `.claude/skills/` | 项目级 |
| Bundled | 内置技能 | CLI 自带 |
| Plugin | `~/.claude/plugins/*/skills/` | 插件提供 |
| MCP | `mcpServers` 配置 | MCP 工具导出为技能 |
| Commands (legacy) | `commands/` 目录 | 旧版命令技能 |

> 注意: 技能名称来自目录名，而非 frontmatter 的 `name` 字段。

---

## SKILL.md Frontmatter 完整规范

基于 `src/utils/frontmatterParser.ts` 的完整字段定义：

```yaml
---
# 注意: 技能名称来自目录名，不是 frontmatter 字段
# === 核心字段 ===
description: 简短描述           # 推荐，技能用途
when_to_use: 使用场景描述       # 推荐，模型参考

# === 工具配置 ===
allowed-tools:                  # 可选，允许的工具
  - Read
  - Write
  - Edit
  - Bash(git *)

# === 参数定义 ===
arguments:                      # 可选，参数列表
  - name
  - description
argument-hint: "参数提示"       # 可选，参数示例

# === Agent 配置 ===
agent: agent-name              # 可选，使用的 Agent 名称
skills: skill-name              # 可选，agent 预加载技能列表
model: sonnet                   # 可选，指定模型
effort: medium                  # 可选，low/medium/high
context: inline                 # 可选，额外上下文或 fork

# === 条件激活 ===
paths:                         # 可选，路径模式
  - "*.sql"
  - "migrations/*.sql"
  - "{frontend,backend}/**/*.ts"

# === 行为控制 ===
user-invocable: true          # 默认 true，false=隐藏
disable-model-invocation: false # 默认 false
hide-from-slash-command-tool: false  # 默认 false
version: "1.0.0"             # 可选，版本号

# === Shell 配置 ===
shell: bash                   # 可选，bash 或 powershell

# === Hooks ===
hooks:                        # 可选，内置 Hooks
  PreToolUse:
    - matcher: "Bash"
      hooks:
        - type: command
          command: "python3 validate.py"
          timeout: 5

# === 技能内容 ===
---

# 技能内容（Markdown）

技能的具体描述和使用说明...

支持 `!` 块执行命令：
```!bash
echo "执行 shell 命令"
```
```

---

## Frontmatter 字段详解

### 核心字段

| 字段 | 类型 | 说明 |
|------|------|------|
| `name` | string | 显示名称（默认用目录名） |
| `description` | string | 技能描述，会显示在技能列表 |
| `when_to_use` | string | 使用建议（模型可参考） |
| `user-invocable` | boolean | 是否可通过 `/` 命令调用 |
| `hide-from-slash-command-tool` | boolean | 是否隐藏于 SlashCommand 工具 |

### 工具配置

| 字段 | 类型 | 说明 |
|------|------|------|
| `allowed-tools` | string/string[] | 允许的工具列表 |

**示例**：
```yaml
allowed-tools: "Read|Edit|Write"
allowed-tools:
  - Read
  - Write
  - Bash(git *)
```

### 模型与执行

| 字段 | 类型 | 说明 |
|------|------|------|
| `model` | string | 指定模型 |
| `effort` | 'low' \| 'medium' \| 'high' | effort 级别 |
| `context` | string | 额外上下文；`fork`=子 Agent 执行 |
| `agent` | string | 使用的 Agent 名称 |
| `skills` | string | agent 预加载技能列表 |
| `shell` | 'bash' \| 'powershell' | 默认 shell |

### 条件激活

| 字段 | 类型 | 说明 |
|------|------|------|
| `paths` | string/string[] | 路径模式匹配后才激活 |
| `arguments` | string/string[] | 接受的参数列表 |
| `argument-hint` | string | 参数使用提示/示例 |

**Paths 语法**：
```yaml
paths: "*.sql"                    # 单个
paths: "*.sql, migrations/*.sql"  # 逗号分隔
paths:                             # 数组
  - "*.sql"
  - "migrations/*.sql"
  - "{frontend,backend}/**/*.ts"  # 支持 brace expansion
```

### Shell 配置

| 字段 | 类型 | 说明 |
|------|------|------|
| `shell` | string | `bash` 或 `powershell` |

### 版本与元数据

| 字段 | 类型 | 说明 |
|------|------|------|
| `version` | string | 技能版本号 |

---

## 技能加载流程

```
┌──────────────────────────────────────────────────────────────┐
│                    技能加载流程                                │
├──────────────────────────────────────────────────────────────┤
│                                                              │
│  1. 扫描加载源                                                │
│     ├── userSettings: ~/.claude/skills/                      │
│     ├── projectSettings: .claude/skills/                     │
│     ├── policySettings: managed 目录                        │
│     ├── bundled: 内置技能                                     │
│     └── plugin: 插件 skills/ 目录                            │
│                                                              │
│  2. 解析 frontmatter                                          │
│     └── parseSkillFrontmatterFields()                       │
│                                                              │
│  3. 去重检查                                                │
│     └── getFileIdentity() - 解析符号链接                     │
│                                                              │
│  4. 分类                                                    │
│     ├── 无 paths → 无条件技能列表                            │
│     └── 有 paths → 条件技能池                               │
│                                                              │
│  5. 条件激活                                                │
│     └── 文件被访问时匹配 paths 模式                         │
│                                                              │
└──────────────────────────────────────────────────────────────┘
```

---

## 内置 Bundled Skills

基于 `src/skills/bundled/index.ts`：

### 注册机制

内置技能通过 `registerBundledSkill()` 注册，支持以下字段：

| 字段 | 类型 | 说明 |
|------|------|------|
| `name` | string | 技能名称（命令名） |
| `aliases` | string[] | 命令行别名 |
| `description` | string | 技能描述 |
| `whenToUse` | string | 使用场景描述 |
| `allowedTools` | string[] | 允许的工具列表 |
| `userInvocable` | boolean | 是否可通过 `/` 命令调用 |
| `isEnabled` | () => boolean | 启用条件函数 |
| `disableModelInvocation` | boolean | 是否禁用模型调用 |
| `context` | 'inline' \| 'fork' | 执行模式 |
| `agent` | string | 使用的 Agent 名称 |
| `files` | string[] | 关联文件 |
| `hooks` | HooksSettings | 内置 Hooks |

### 技能列表

| 技能 | 命令 | 别名 | 功能 | Feature Flag / 触发条件 | 备注 |
|------|------|------|------|-------------------------|------|
| updateConfig | `/updateConfig` | updateConfig | 更新配置 | 默认启用 | |
| keybindings-help | `/keybindings-help` | keybindings | 快捷键 | `isKeybindingCustomizationEnabled()` | ⚠️ userInvocable: false - 仅模型可调用 |
| verify | `/verify` | verify | 验证 | `USER_TYPE === 'ant'` | ANT-only |
| debug | `/debug` | debug | 调试 | 默认启用 | |
| lorem-ipsum | `/lorem-ipsum` | loremIpsum | 生成占位文本 | `USER_TYPE === 'ant'` | ANT-only |
| skillify | `/skillify` | skillify | 转换为技能 | `USER_TYPE === 'ant'` | ANT-only |
| remember | `/remember` | remember | 记忆 | `USER_TYPE === 'ant'` + `isAutoMemoryEnabled()` | ANT-only |
| simplify | `/simplify` | simplify | 简化文本 | 默认启用 | |
| batch | `/batch` | batch | 批量处理 | 默认启用 | |
| stuck | `/stuck` | stuck | 卡住帮助 | `USER_TYPE === 'ant'` | ANT-only |
| loop | `/loop` | loop | 循环任务 | `AGENT_TRIGGERS` | ⚠️ 运行时还需 `isKairosCronEnabled()` 检查 |
| schedule | `/schedule` | schedule | 远程调度 | `AGENT_TRIGGERS_REMOTE` 注册 + 运行时 `tengu_surreal_dali` + `allow_remote_sessions` | 需要 claude.ai OAuth 认证 |
| claude-api | `/claude-api` | claudeApi | Claude API | `BUILDING_CLAUDE_APPS` | |
| dream | `/dream` | dream | Dream Mode | `KAIROS` 或 `KAIROS_DREAM` | |
| hunter | `/hunter` | hunter | Code Hunter | `REVIEW_ARTIFACT` | |
| claude-in-chrome | `/claude-in-chrome` | claudeInChrome | Chrome 扩展 | `auto (shouldAutoEnableClaudeInChrome)` | |
| run-skill-generator | `/run-skill-generator` | runSkillGenerator | 技能生成器 | `RUN_SKILL_GENERATOR` | |

> **注意**: `dream`、`hunter`、`runSkillGenerator` 的源码文件不存在于开源仓库中。它们通过 `require('./xxx.js')` 动态加载，由构建系统注入，仅在对应 feature flag 启用时可用。

---

## 目录结构规范

### 标准格式

```
skills/
├── skill-name/
│   └── SKILL.md        # 必须
├── another-skill/
│   ├── SKILL.md        # 必须
│   ├── schemas/        # 可选
│   ├── templates/      # 可选
│   └── examples/       # 可选
└── ...
```

**重要**：`skills/` 目录只支持目录格式，不支持单文件。

---

## 执行模式

### Inline（默认）

技能内容直接展开到当前对话：

```yaml
context: inline  # 默认
---
# 技能内容
```

### Fork（子 Agent）

技能在独立上下文中执行：

```yaml
context: fork
agent: general-purpose
---
# 技能内容
```

---

## 变量替换

### 可用变量

| 变量 | 说明 |
|------|------|
| `$ARGUMENTS` | 传入的参数 |
| `$1, $2, ...` | 按位置引用参数 |

### Shell 块

```markdown
技能内容...

```!bash
echo "执行 shell"
```
```

---

## 条件激活

### 路径模式

```yaml
# SQL 优化技能
paths:
  - "*.sql"
  - "migrations/*.sql"
  - "**/database/**/*.sql"
```

**模式语法**：
- `*.sql` - 单个文件
- `dir/*` - 目录下所有
- `dir/**` - 递归所有
- `{a,b}` - brace expansion
- 逗号分隔的多个模式

### 条件触发逻辑

```typescript
// 来自 loadSkillsDir.ts
function parseSkillPaths(frontmatter: FrontmatterData): string[] | undefined {
  const patterns = splitPathInFrontmatter(frontmatter.paths)
  // 移除 /** 后缀
  // 如果全为 **，返回 undefined
}
```

---

## Hooks 集成

技能可以内置 Hooks：

```yaml
hooks:
  PreToolUse:
    - matcher: "Bash"
      hooks:
        - type: command
          command: "python3 validate.py"
          timeout: 5
          if: "Bash(git *)"
  PostToolUse:
    - hooks:
        - type: command
          command: "log.py"
```

---

## 常见问题

### Q: 为什么我的技能不显示？

检查清单：
- [ ] SKILL.md 是否在 `skills/{name}/` 目录下？
- [ ] frontmatter 是否有描述？
- [ ] 是否被 `user-invocable: false` 隐藏？
- [ ] 是否被 `hide-from-slash-command-tool: true` 隐藏？

### Q: 条件技能为什么没激活？

检查清单：
- [ ] `paths` 模式是否正确？
- [ ] 匹配的文件是否被访问？
- [ ] 模式是否使用逗号分隔或 YAML 列表？

### Q: 工具权限不足？

```yaml
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash(git *)
  - Bash(npm *)
```

---

## 测试验证

运行测试脚本验证 Skills 配置：
```bash
bash tests/01-skills-test.sh
```
