# 技能创建规范

> 从源码深度解析 Claude Code 技能创建的最佳实践

## SKILL.md 标准模板

Claude Code 源码中的 `/skillify` 技能提供了标准模板：

```yaml
---
name: {{skill-name}}
description: {{一句话描述}}
allowed-tools:
  {{tool permission patterns}}
when_to_use: |
  详细描述何时自动调用此技能，包括触发短语和示例消息。
  Use when the user wants to cherry-pick a PR to a release branch.
  Examples: 'cherry-pick to release', 'CP this PR', 'hotfix.'
argument-hint: "{{参数占位符提示}}"
arguments:
  - name
  - description
context: {{inline 或 fork}}
model: "{{可选：指定模型}}"
effort: "{{可选：low/medium/high}}"
---

# 技能标题

技能详细描述...

## 输入
- `$arg_name`: 输入描述

## 目标
清晰陈述此工作流的目标。

## 步骤

### 1. 步骤名称
要执行的具体操作。

**成功标准**: 定义何时认为步骤完成。

**执行**: `Direct`（默认）、`Task agent`、`Teammate`、`[human]`
**产物**: 此步骤产生的数据/ID，供后续步骤使用
**人工检查点**: 何时暂停询问用户
```

---

## frontmatter 字段详解

### 1. 核心元数据

```yaml
---
name: skill-name                    # 技能标识符（可选，默认用目录名）
description: 简短描述                # 必需，会显示在 /skills 列表中
when_to_use: |                     # 关键！告诉模型何时自动调用
  当用户想要...时使用
  示例消息：'...', '...'
---
```

### 2. 参数定义

```yaml
---
argument-hint: "\"参数1\" \"参数2\""  # 参数示例格式
arguments:                            # 参数列表（空格分隔的字符串或字符串数组）
  - param1
  - param2
---
```

### 3. 工具权限

```yaml
---
allowed-tools: |                    # 最小权限原则
  Bash(gh:*)
  Read
  Edit
  Write
  Grep
---
```

### 4. 执行模式

```yaml
---
context: fork                       # 子 Agent 执行（独立上下文）
# 或者省略 context: inline         # 内联执行（当前会话）
model: "sonnet"                    # 可选：指定模型
effort: "high"                    # 可选：effort 级别
---
```

### 5. 条件激活

```yaml
---
paths:                              # 路径模式匹配后激活
  - "*.sql"
  - "migrations/*.sql"
  - "**/database/**/*.sql"
---
```

**路径匹配规则**:
- 模式中的 `/**` 后缀会被自动移除（`src/**` → `src/`）
- 如果所有模式都是 `**`（匹配全部），技能被视为无条件的
- 条件技能初始存储在 `conditionalSkills`，只有当匹配的文件被访问时才激活
- 激活后移至 `dynamicSkills`，之后无法停用

**路径模式示例**:
| 模式 | 匹配文件 |
|------|----------|
| `*.sql` | 根目录的 SQL 文件 |
| `src/**/*.ts` | src 目录及子目录的 TypeScript 文件 |
| `tests/` | tests 目录下的所有文件 |

### 6. 模型控制

```yaml
---
model: "sonnet"                    # 指定模型（可选）
effort: "high"                    # effort 级别（可选）: low/medium/high/max 或正整数
disable-model-invocation: true     # 禁用模型自动调用（可选）
---
```

**disable-model-invocation**: 设置为 `true` 时，禁用模型的自动调用功能。此字段用于高级场景，需要在 frontmatter 中显式声明。

---

## 执行模式对比

| 模式 | 描述 | 适用场景 |
|------|------|----------|
| `inline`（默认） | 在当前会话中执行 | 需要用户参与决策 |
| `fork` | 子 Agent 执行 | 自包含任务、不需要中途交互 |

### Fork 模式特点

```yaml
context: fork
```

- 在独立子 Agent 中运行
- 有自己的 token 预算
- 工具输出不在主上下文
- 适合长时间运行的后台任务

---

## 技能内容结构

### 1. 基础信息

```markdown
# 技能名称

## 简介
简短描述技能功能。

## 使用场景
何时应该使用此技能。
```

### 2. 输入参数

```markdown
## 输入
- `$target`: 目标文件或目录
- `$options`: 可选参数
```

### 3. 步骤

```markdown
## 步骤

### 1. 初始化
检查环境和依赖。

**成功标准**:
- 环境就绪
- 依赖已安装

### 2. 执行核心逻辑
执行主要任务。

**执行**: `Task agent`（可选：并行执行）
**产物**: 关键数据供后续使用
```

### 4. 错误处理

```markdown
## 错误处理

如果失败：
1. 记录错误日志
2. 清理临时文件
3. 返回错误信息
```

---

## 完整示例

```yaml
---
name: sql-migration
description: 数据库迁移执行和验证
when_to_use: |
  当你需要创建或执行数据库迁移时使用。
  示例：'执行迁移', '创建用户表迁移', 'migrate users'
argument-hint: "\"up\" 或 \"down\" [migration_name]"
arguments:
  - direction
  - name
allowed-tools:
  Bash(psql:*)
  Bash(psql -h *)
  Read
  Grep
context: inline
---
# SQL 迁移助手

执行数据库迁移并验证结果。

## 输入
- `$direction`: `up` 或 `down`
- `$name`: 可选的迁移名称

## 步骤

### 1. 准备迁移
检查迁移文件状态。

**成功标准**:
- 迁移文件存在
- 数据库连接正常

### 2. 执行迁移
```bash
alembic upgrade head
```

**成功标准**:
- 无错误输出
- 版本号已更新

### 3. 验证结果
确认迁移成功应用。

**成功标准**:
- 表结构正确
- 数据完整
```

---

## 最佳实践

### 1. when_to_use 是关键

```yaml
# ❌ 模糊描述
when_to_use: "处理数据"

# ✅ 具体描述
when_to_use: |
  当用户需要创建新的数据库表时使用。
  示例：'创建用户表', 'add table', '新表 users'
```

### 2. 最小权限原则

```yaml
# ❌ 过于宽松
allowed-tools: "Bash|Read|Write|Edit"

# ✅ 精确指定
allowed-tools:
  Bash(npm:*)
  Bash(node:*)
  Read
```

### 3. 明确的成功标准

每个步骤必须有 `**成功标准**:`，告诉模型何时可以继续。

### 4. Fork vs Inline 选择

```yaml
# ✅ Fork：自包含任务
context: fork
# 例子：代码格式化、依赖检查、静态分析

# ✅ Inline：需要交互
# （省略 context 或显式 inline）
# 例子：重构需要审查、调试需要反馈
```

### 5. 产物链

如果步骤之间有数据依赖，使用 `**产物**:` 标注：

```markdown
### 1. 生成代码
生成代码文件。

**产物**: `{file_path}` - 生成的文件路径

### 2. 验证代码
验证生成的文件。

**成功标准**: 文件存在且可执行
```

---

## 未文档化的功能

### 变量替换

| 变量 | 说明 | 作用域 |
|------|------|--------|
| `${CLAUDE_SKILL_DIR}` | 技能自己的目录路径 | 文件和插件技能 |
| `${CLAUDE_SESSION_ID}` | 当前会话标识符 | 所有技能类型 |
| `${CLAUDE_PLUGIN_ROOT}` | 插件根目录 | 插件技能 |
| `${CLAUDE_PLUGIN_DATA}` | 插件数据目录 | 插件技能 |

### 未文档化的 frontmatter 字段

以下字段在源码中存在：

| 字段 | 说明 |
|------|------|
| `hide-from-slash-command-tool` | 控制 SlashCommand 工具中的可见性 |
| `immediate` | true 时绕过队列立即执行 |
| `skills` | Agent 预加载的技能列表（仅用于 Agent 定义，非 Skill frontmatter） |

**以下字段在源码中不存在，不要使用**：
- `isSensitive` - 不存在
- `kind: 'workflow'` - 不存在
- `availability` - 不存在
- `disableNonInteractive` - 这是 Command 属性，不是 frontmatter 字段

### Shell 命令块

```markdown
!`shell command`                    // 内联执行

```!
echo "shell command"
```
```

Shell 块在技能加载期间执行，用于准备上下文。注意：`!` 块语法是 `` ```! `` 后直接换行（不加语言名），否则语言名会被当作命令的一部分执行。

### Skill 权限自动授权

使用"安全"属性的技能会自动授予权限：

```typescript
const SAFE_SKILL_PROPERTIES = new Set([
  'type', 'progressMessage', 'contentLength', 'argNames', 'model',
  'effort', 'source', 'pluginInfo', 'disableNonInteractive', 'skillRoot',
  'context', 'agent', 'getPromptForCommand', 'frontmatterKeys',
  'name', 'description', 'hasUserSpecifiedDescription', 'isEnabled',
  'isHidden', 'aliases', 'isMcp', 'argumentHint', 'whenToUse', 'paths',
  'version', 'disableModelInvocation', 'userInvocable', 'loadedFrom',
  'immediate', 'userFacingName'
])
```

### Remote Skills (实验性)

特性标志: `EXPERIMENTAL_SKILL_SEARCH` + `USER_TYPE === 'ant'`

具有 `_canonical_` 前缀的远程技能从 AKI/GCS 加载。

### Bundled Skill 文件提取

Bundled 技能可以指定首次调用时提取到磁盘的文件：

```typescript
files?: Record<string, string>  // { "path": "content" }
```

### model: inherit

显式使用父级模型的语法：

```yaml
model: inherit  # 使用调用技能的模型
```

### effort 值

effort 可以是字符串或正整数：

```yaml
effort: low      # 字符串
effort: 42        # 整数
```

---

## 技能格式参考

| 字段 | 说明 | 必需 |
|------|------|------|
| `name` | 技能标识符 | 是 |
| `description` | 一句话描述 | 是 |
| `when_to_use` | 何时自动调用 | 推荐 |
| `allowed-tools` | 工具权限白名单 | 可选 |
| `arguments` | 参数定义 | 可选 |
| `argument-hint` | 参数示例格式 | 可选 |
| `context` | `inline` 或 `fork` | 可选 |
| `model` | 指定模型，`inherit` 使用父级模型 | 可选 |
| `effort` | `low`/`medium`/`high` 或正整数 | 可选 |
| `agent` | fork 模式时的 agent 类型 | 可选 |
| `shell` | 执行 shell 类型 | 可选 |
| `hide-from-slash-command-tool` | 从 /skills 列表隐藏 | 可选 |
| `disable-model-invocation` | 禁用模型调用 | 可选 |
| `paths` | 路径模式激活 | 可选 |
| `files` | 相关文件 | 可选 |
| `immediate` | 绕过队列立即执行 | 可选 |
| `isSensitive` | ❌ 不存在，不要使用 | - |
| `availability` | ❌ 不存在，不要使用 | - |
| `disableNonInteractive` | ❌ 这是 Command 属性，不是 frontmatter 字段 | - |

### 完整示例

创建技能时使用以下格式：

```yaml
---
name: my-skill
description: 技能描述
when_to_use: |
  当处理 SQL 文件时使用
paths:
  - "*.sql"
  - "migrations/*.sql"
allowed-tools: "Read|Edit|Bash(psql *)"
context: inline
---
```
