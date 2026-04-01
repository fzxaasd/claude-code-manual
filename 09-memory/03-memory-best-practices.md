# 9.3 Memory 最佳实践

> 基于源码实现和 eval-validated 指南

## 核心原则

### 1. 只保存不可派生信息

Claude Code 会持续优化其派生信息的能力。以下内容**不应**保存到记忆中：

| 应保存 | 不应保存 |
|--------|----------|
| 用户偏好和角色背景 | 代码模式、架构 |
| 团队约定和工作流程 | Git 历史、文件结构 |
| 项目目标和截止日期 | 调试方案 (在代码中) |
| 外部系统引用 | CLAUDE.md 内容 |
| 用户反馈和纠正 | 进行中的任务 |

**原因**: 记忆会过时，而派生信息始终保持最新。

### 2. 及时保存显式请求

```typescript
// ✅ 立即保存
if (user.explicitly.asksToRemember(something)) {
  saveMemory(something)
}

// ✅ 立即移除
if (user.explicitly.asksToForget(something)) {
  removeMemory(something)
}
```

### 3. 包含 Why 而非只描述 What

```markdown
<!-- ❌ 只描述 What -->
集成测试必须使用真实数据库。

<!-- ✅ 包含 Why -->
集成测试必须使用真实数据库。

**Why:** 之前有过 mock 测试通过但生产迁移失败的案例。

**How to apply:** 在编写测试时，优先使用真实数据库连接。
```

---

## 4 种内存类型使用指南

### User (用户记忆)

**作用域**: `always private`

**何时保存**:
- 用户首次介绍自己
- 用户提到专业领域
- 用户说明经验水平
- 用户表达偏好

**示例**:

```markdown
---
name: user_role
description: 数据科学家，专注可观测性
type: user
---

用户是数据科学家，当前专注于可观测性/日志系统。

**Why:** 帮助 AI 根据用户背景调整解释深度。

**How to apply:** 解释技术概念时优先使用数据科学类比。
```

**常见保存时机**:
```
用户: "我做了十年后端开发"
→ 保存: 用户有深厚后端经验

用户: "这是第一次用 Docker"
→ 保存: Docker 新手，需要更多指导
```

### Feedback (反馈记忆)

**作用域**: `default to private. Save as team only when clearly a project-wide convention`

**何时保存**:
- 用户纠正 AI 行为 ("no not that", "don't", "stop doing X")
- 用户确认有效方法 ("yes exactly", "perfect, "keeping doing that")
- 用户接受不寻常选择

**示例**:

```markdown
---
name: feedback_testing
description: 集成测试必须使用真实数据库
type: feedback
---

集成测试必须使用真实数据库，不使用 mocks。

**Why:** 之前有过 mock 测试通过但生产迁移失败的案例。

**How to apply:** 在编写测试时，优先使用真实数据库连接。
```

**保存格式**:
1. 规则本身
2. **Why:** 原因
3. **How to apply:** 应用场景

**冲突处理**:
```typescript
// 保存前检查是否与团队记忆冲突
if (privateMemory.conflictsWith(teamMemory)) {
  // 选择 1: 不保存
  // 选择 2: 记录为覆盖说明
}
```

### Project (项目记忆)

**作用域**: `private or team, but strongly bias toward team`

**何时保存**:
- 项目里程碑或目标
- 截止日期或约束
- 决策及其原因
- 正在进行的工作

**⚠️ 日期处理**:

```markdown
<!-- ❌ 相对日期 (会过期) -->
用户: Thursday 开始冻结

<!-- ✅ 绝对日期 (保持有效) -->
**Why:** 用户说 Thursday
**How to apply:** 转换: Thursday → 2026-04-02
```

**示例**:

```markdown
---
name: project_status
description: merge freeze 2026-04-02
type: project
---

合并冻结从 2026-04-02 开始，移动团队正在发布分支。

**Why:** Q2 季度的关键目标。

**How to apply:** 标记任何在此日期后的非关键 PR 工作。
```

### Reference (参考记忆)

**作用域**: `usually team`

**何时保存**:
- 外部系统信息
- 文档位置
- 通信频道

**示例**:

```markdown
---
name: reference_jira
description: Linear 项目 INGEST 用于 pipeline bugs
type: reference
---

Pipeline bugs 在 Linear 项目 "INGEST" 中追踪。

**Why:** 快速定位相关信息源。

**How to apply:** 提及 pipeline bugs 时引用此记忆。
```

---

## 保存流程

### 两步保存法

**Step 1**: 写入记忆文件

```markdown
---
name: {{唯一标识}}
description: {{一行描述，用于判断相关性}}
type: {{类型}}
---

记忆内容...

**Why:** {{原因}}
**How to apply:** {{应用场景}}
```

**Step 2**: 更新 MEMORY.md 索引

```markdown
<!-- MEMORY.md -->
- [用户角色](user/role.md) — 数据科学家，专注可观测性
- [测试政策](feedback/testing.md) — 必须使用真实数据库
- [v2.0 发布](project/v2-launch.md) — 4月15日发布
```

**索引规则**:
- 每行一个链接
- 不超过 ~150 字符
- 包含标题 + 一行钩子

---

## 访问记忆

### 何时访问

```
✅ 访问:
- 记忆看起来相关时
- 用户明确要求检查/回忆时
- 开始新任务时

❌ 忽略:
- 用户说 "ignore memory about X" → 完全忽略
- 记忆可能过时 → 先验证
```

### 信任记忆

**验证规则**:

```typescript
// 记忆命名文件路径
if (memory.namesFilePath) {
  verifyFileExists(memory)
}

// 记忆命名函数/标志
if (memory.namesFunctionOrFlag) {
  grepForIt(memory)
}

// 用户要基于记忆行动
if (memory.willActOnRecommendation) {
  verifyFirst()  // 先验证
}
```

**过时处理**:
```markdown
如果记忆与当前信息冲突:
1. 信任观察到的当前状态
2. 更新或删除过时记忆
3. 不要基于过时记忆行动
```

---

## 命名规范

### 好命名

```markdown
user_role.md
feedback_testing_policy.md
project_v2_release.md
reference_linear_ingest.md
```

### 避免

```markdown
memory.md        # 太通用
notes.md         # 太模糊
untitled.md      # 无意义
important.md     # 所有都重要
```

---

## 团队记忆

### 与个人记忆的区别

| 维度 | 个人记忆 | 团队记忆 |
|------|---------|---------|
| 位置 | `~/.claude/projects/...` | `{project}/.claude/` |
| 访问 | 仅本人 | 团队成员 |
| 作用域 | private | team |

### 作用域选择

```typescript
user:     "always private"
// 任何情况下都私有

feedback: "default to private"
// 除非是明确的团队约定，否则私有
// 例如: 测试政策 → 团队
// 例如: 沟通偏好 → 私有

project:  "private or team, bias toward team"
// 强烈偏向团队
// 例如: 截止日期 → 团队

reference: "usually team"
// 通常团队
// 例如: Jira 项目 → 团队
```

---

## 常见问题

### Q: 用户要我保存 PR 列表

```markdown
<!-- ❌ 这样做是噪声 -->
用户: 保存这个周的 PR 列表

<!-- ✅ 先问什么值得记住 -->
用户: 保存这个周的 PR 列表
AI: 这个 PR 列表值得保存的是:
- [ ] 有什么 surprising 的？
- [ ] 有什么 non-obvious 的？
```

### Q: 个人偏好 vs 团队约定

```typescript
// 用户说 "stop summarizing"
feedback_testing: 私有
// 原因: 个人沟通偏好

// 用户说 "always use real db in tests"
feedback_testing: 团队
// 原因: 项目测试政策
```

### Q: 记忆过时了

```markdown
<!-- 当记忆与现实冲突时 -->
如果记忆冲突:
1. 信任当前观察
2. 立即更新/删除记忆
3. 不等下次对话
```

### Q: 太多记忆文件

```markdown
<!-- MEMORY.md 限制: -->
- 最多 200 行
- 最多 25,000 字节
- 每条索引 < ~150 字符

<!-- 解决方案: -->
1. 合并相关记忆
2. 保持索引条目简短
3. 详细记忆放在主题文件
```

---

## Eval 验证结果

以下指南经过 eval 验证，证明有效:

### ✅ H1: 验证函数/文件声明

**问题**: 记忆声明函数/文件存在，但可能已改名/删除

**验证方法**:
```bash
# 文件路径
ls path/to/file

# 函数/标志
grep -rn "functionName" --include="*.ts"
```

**eval 结果**: 0/2 → 3/3 (通过)

### ✅ H5: 读端噪声拒绝

**问题**: 记忆是 repo 状态的快照，会过时

**指南**:
```
如果用户问最近的/当前的状态:
→ 优先使用 git log 或读代码
→ 不要依赖记忆快照
```

**eval 结果**: 0/2 → 3/3 (通过)

### ✅ H6: 忽略指令

**问题**: 用户说 "ignore memory about X"，Claude 却引用后覆盖

**正确行为**:
```
用户: ignore memory about X
→ 行为: 如同 MEMORY.md 为空
→ 不应用、不引用、不提及
```

**eval 结果**: 改进显著

---

## KAIROS 每日日志模式

### 模式说明

```typescript
// KAIROS feature 启用时:
// - 记忆追加到每日日志文件
// - 不维护实时 MEMORY.md 索引
// - 夜间 /dream 技能蒸馏到主题文件

// 日志路径
getAutoMemDailyLogPath(date)
// <autoMemPath>/logs/YYYY/MM/YYYY-MM-DD.md
```

### 何时使用

- Assistant 模式 (long-lived sessions)
- 需要保留完整历史记录
- 不需要跨会话共享

### 记录格式

```markdown
<!-- 每日日志条目格式 -->
[2026-04-01 09:15]
- 用户纠正: 不要在 diff 末尾总结
- 发现: 项目使用 pnpm，不是 npm
- 保存: user_dev_preference.md

[2026-04-01 14:30]
- 用户确认: 单个 PR 优于多个小 PR
- 截止日期: 4 月 15 日 v2 发布
```

---

## 最佳实践清单

### 保存前检查

- [ ] 这是不可派生信息吗？
- [ ] 包含 **Why** 了吗？
- [ ] 相对日期转成绝对日期了吗？
- [ ] 有冲突的团队记忆吗？
- [ ] 文件名是否唯一且有意义？

### 访问时检查

- [ ] 用户明确要求了吗？
- [ ] 记忆引用了文件/函数吗？
- [ ] 如果是，需要先验证吗？
- [ ] 记忆可能过时吗？

### 维护检查

- [ ] MEMORY.md 超过 200 行了吗？
- [ ] 有过时记忆需要清理吗？
- [ ] 有重复记忆需要合并吗？
