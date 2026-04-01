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
arguments:                            # 参数列表
  - param1: 参数1说明
  - param2: 参数2说明
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
  - direction: "up 或 down"
  - name: "迁移名称（可选）"
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

## 技能格式参考

| 字段 | 说明 | Claude Code 实现 |
|------|------|-----------------|
| 标识 | `name` | 必需 |
| 描述 | `description` | 必需 |
| 使用场景 | `when_to_use` | 推荐 |
| 条件激活 | `paths` | 可选 |
| 工具限制 | `allowed-tools` | 可选 |
| 执行模式 | `context` | 可选 |

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
