# 7.7 Plan Mode (计划模式)

> 基于源码 `src/tools/EnterPlanModeTool/`, `src/tools/ExitPlanModeTool/`, `src/utils/planModeV2.ts`, `src/utils/plans.ts` 深度分析

## 核心概念

Plan Mode 是一种专为复杂任务设计的探索和规划模式，允许 Claude Code 在开始编写代码之前先理解代码库、探索方案、设计实现策略。

```
┌────────────────────────────────────────────────────────────┐
│                      Plan Mode 流程                          │
├────────────────────────────────────────────────────────────┤
│                                                            │
│  1. 进入计划模式                                            │
│     └── EnterPlanModeTool                                  │
│         ├── 切换权限模式到 'plan'                          │
│         └── 禁止写文件（除 plan 文件外）                    │
│                                                            │
│  2. 探索阶段                                               │
│     ├── 探索代码库                                          │
│     ├── 理解现有模式                                        │
│     ├── 识别相似功能                                        │
│     └── 设计多种方案及其权衡                                 │
│                                                            │
│  3. 编写计划                                               │
│     └── 写入 ~/.claude/plans/{slug}.md                     │
│                                                            │
│  4. 退出计划模式                                            │
│     └── ExitPlanModeV2Tool                                 │
│         ├── 用户审批计划                                    │
│         └── 恢复执行模式                                    │
│                                                            │
└────────────────────────────────────────────────────────────┘
```

---

## 工具定义

### EnterPlanModeTool

基于 `src/tools/EnterPlanModeTool/EnterPlanModeTool.ts`：

```typescript
interface EnterPlanModeTool {
  name: "EnterPlanMode"
  input: {}                    // 无需参数
  output: {
    message: string            // 确认消息
  }
  enabled: boolean             // KAIROS channels 禁用
  isReadOnly: true            // 只读模式
}
```

**触发条件**：
- `KAIROS` 或 `KAIROS_CHANNELS` feature 开启且有活跃 channel 时禁用
- 子 Agent 上下文中不可用

### 工具属性

| 属性 | EnterPlanModeTool | ExitPlanModeV2Tool |
|------|------------------|-------------------|
| `isReadOnly` | `true` | `false`（会写文件） |
| `isConcurrencySafe` | `true` | `true` |

### ExitPlanModeV2Tool requiresUserInteraction()

队友 (isTeammate()) 返回 false — 无需本地用户交互
非队友返回 true — 需要用户确认才能退出

基于 `src/tools/ExitPlanModeTool/ExitPlanModeV2Tool.ts`：

```typescript
interface ExitPlanModeV2Tool {
  name: "ExitPlanMode"
  input: {
    allowedPrompts?: {         // 计划需要的语义权限 (新增)
      tool: 'Bash'
      prompt: string          // 如 "run tests"
    }[]
  }
  output: {
    plan: string | null        // 计划内容
    isAgent: boolean           // 是否为子 Agent
    filePath?: string          // 计划文件路径
    hasTaskTool?: boolean      // AgentTool 是否可用
    planWasEdited?: boolean    // 用户是否编辑过计划
    awaitingLeaderApproval?: boolean  // 等待团队领导审批
    requestId?: string         // 审批请求 ID
  }
  requiresUserInteraction: true  // 需要用户确认
}
```

**`allowedPrompts` 参数**：
- 用于在退出计划模式时请求特定的 Bash 权限
- `tool` 字段仅支持 `'Bash'`（源码限制为 `z.enum(['Bash'])`）
- 例如：`{ tool: 'Bash', prompt: 'run tests' }` 请求运行测试的权限
- Teammate 模式下：直接 allow，跳过权限 UI
- 非 Teammate 模式下：`checkPermissions` 返回 `behavior: 'ask'`，询问"是否退出计划模式"

**KAIROS 禁用门**：
- `ExitPlanModeV2Tool` 在 `KAIROS` 或 `KAIROS_CHANNELS` 功能开启且存在允许的频道时会被禁用
- 与 `EnterPlanModeTool` 使用相同的禁用逻辑

**权限验证**：
- 仅在 `mode === 'plan'` 时可用
- Teammate 模式下自动绕过权限 UI
- 普通用户需要确认对话框

---

## 权限模式转换

### Plan Mode 权限状态

```
┌────────────────────────────────────────────────────────────┐
│                  权限模式转换                                │
├────────────────────────────────────────────────────────────┤
│                                                            │
│  default/acceptEdits/auto ──[EnterPlanMode]──> plan        │
│                                                            │
│  plan ──[ExitPlanMode 审批通过]──> 恢复 prePlanMode        │
│                                                            │
│  plan ──[ExitPlanMode 拒绝]──> 保持 plan 模式              │
│                                                            │
└────────────────────────────────────────────────────────────┘
```

### Plan Mode 行为差异

| 行为 | 普通模式 | Plan Mode |
|------|---------|-----------|
| 文件写入 | 正常 | 限制（仅 plan 文件） |
| 工具执行 | 正常 | 受限 |
| 权限检查 | 正常 | 额外验证 |
| 计划审批 | 无 | 必须 |

---

## 计划文件管理

### 计划目录

基于 `src/utils/plans.ts`：

```typescript
// 配置：settings.json
settings.plansDirectory: string  // 相对路径或绝对路径

// 默认位置
~/.claude/plans/
```

**路径验证**：
- **默认**：使用 `~/.claude/plans/`（用户主目录）
- **自定义 `plansDirectory`**：验证必须在项目根目录下，防止路径遍历攻击
- 源码逻辑：若设置路径不在 `cwd` 内，则回退到 `~/.claude/plans/`

### 计划文件名

```typescript
// 主会话计划
getPlanFilePath(): `${slug}.md`
// 如：swift-violet-bird.md

// 子 Agent 计划
getPlanFilePath(agentId): `${slug}-agent-${agentId}.md`
// 如：swift-violet-bird-agent-subagent-1.md
```

### 计划恢复机制

```
┌────────────────────────────────────────────────────────────┐
│                  计划文件恢复流程                            │
├────────────────────────────────────────────────────────────┤
│                                                            │
│  1. 直接读取计划文件                                         │
│     └── 成功 → 返回计划                                      │
│                                                            │
│  2. 文件不存在时尝试恢复                                     │
│     ├── 远程会话 (CCR)                                       │
│     │   └── 尝试从文件快照恢复                               │
│     │       └── 尝试从消息历史恢复                           │
│     │           └── 尝试从 plan_file_reference 恢复          │
│     └── 本地会话 → 返回 null                                 │
│                                                            │
└────────────────────────────────────────────────────────────┘
```

**恢复来源**：
1. `ExitPlanMode` 工具输入中的 plan 字段
2. UserMessage 的 `planContent` 字段
3. `plan_file_reference` 附件

---

## V2 高级功能

### Plan Mode V2 Agent 数量

基于 `src/utils/planModeV2.ts`：

```typescript
// 根据订阅类型决定并行探索 Agent 数量
getPlanModeV2AgentCount(): number

// 返回值：
// - CLAUDE_CODE_PLAN_V2_AGENT_COUNT 环境变量 (1-10)
// - Claude Max + 20x 速率限制: 3
// - Enterprise/Team 订阅: 3
// - 其他: 1

getPlanModeV2ExploreAgentCount(): number
// 默认: 3 (可配置)
```

### Interview Phase (采访阶段)

```typescript
isPlanModeInterviewPhaseEnabled(): boolean

// 启用条件（满足任一即可）：
// 1. USER_TYPE === 'ant' (内部用户) - 始终启用
// 2. CLAUDE_CODE_PLAN_MODE_INTERVIEW_PHASE=true 环境变量
// 3. GrowthBook feature flag: tengu_plan_mode_interview_phase

// 功能：
// - 在 5 阶段计划流程前增加采访阶段
// - Claude 通过提问澄清需求
// - 作为参考群体，不受 Pewter Ledger 实验影响
```

**`mapToolResultToToolResultBlockParam` 差异**：
- Interview Phase 启用时：返回简化版 "DO NOT write or edit any files except the plan file. Detailed workflow instructions will follow."
- Interview Phase 禁用时：返回详细的 6 步操作指南

### Pewter Ledger (计划大小控制实验)

```typescript
type PewterLedgerVariant = 'trim' | 'cut' | 'cap' | null

getPewterLedgerVariant(): PewterLedgerVariant
// 控制 Phase 4 "Final Plan" 子弹数量
// 实验目标：减少计划文件大小，提升用户接受率
```

**Pewter Ledger 实验详情**：

```
实验名称: tengu_pewter_ledger
控制组: null
实验组: 'trim' | 'cut' | 'cap' (逐步严格)

实验臂说明：
- trim: 修剪建议，去除冗余
- cut: 精简内容，减少细节
- cap: 硬性限制，最大子弹数

基线数据 (14天, 截止 2026-03-02, N=26.3M):
- p50: 4,906 chars
- p90: 11,617 chars
- mean: 6,207 chars
- 82% Opus 4.6

拒绝率与大小关系:
- <2K: 20%
- 20K+: 50%

主要指标: session-level Avg Cost (fact__201omjcij85f)
- Opus 输出价格是输入的 5 倍
- cost 是输出加权的代理指标

护栏指标:
- feedback-bad rate
- requests/session (过薄计划 → 更多迭代)
- tool error rate
```

**注意**：
- Interview Phase (采访阶段) 不受 Pewter Ledger 实验影响
- 作为参考群体，始终使用原始计划格式

---

## Teammate 集成

### 团队领导审批流程

```
Agent 请求退出计划模式
        ↓
  isPlanModeRequired()?
        ↓
    Yes ────────── No
     ↓              ↓
发送 plan_approval_request  到 mailbox
        ↓
等待 team-lead 审批
        ↓
  收到审批响应
        ↓
继续执行 / 重新规划
```

### 权限特殊处理

| 场景 | 权限行为 |
|------|---------|
| Teammate 调用 ExitPlanMode | 自动 allow，发送审批请求 |
| 非 Teammate 调用 | 显示确认对话框 |
| `plan_mode_required=true` teammate | 必须有计划才能退出（强制计划模式） |

### 强制计划模式 (Plan Mode Required)

```typescript
isPlanModeRequired(): boolean

// 触发条件（满足任一）：
// 1. TeammateContext 中 planModeRequired = true
// 2. DynamicTeamContext 中 planModeRequired = true
// 3. 环境变量 CLAUDE_CODE_PLAN_MODE_REQUIRED=true
```

**源码位置**: `src/utils/teammate.ts:149-156`

---

## 配置选项

### settings.json 配置

```json
{
  // 计划文件目录 (相对于项目根目录)
  "plansDirectory": ".claude/plans/",

  // 显示上下文清除选项
  "showClearContextOnPlanAccept": false,

  // 计划模式期间使用自动模式
  "useAutoModeDuringPlan": true,

  // 跳过自动模式权限提示
  "skipAutoPermissionPrompt": false
}
```

### 环境变量

| 变量 | 说明 | 值范围 |
|------|------|--------|
| `CLAUDE_CODE_PLAN_V2_AGENT_COUNT` | 并行探索 Agent 数 | 1-10 |
| `CLAUDE_CODE_PLAN_V2_EXPLORE_AGENT_COUNT` | 探索 Agent 数 | 1-10 |
| `CLAUDE_CODE_PLAN_MODE_INTERVIEW_PHASE` | 启用采访阶段 | true/false |
| `CLAUDE_CODE_PLAN_MODE_REQUIRED` | Teammate 强制计划模式 | true/false |

---

## 使用示例

### 进入计划模式

```
> 帮我重构整个认证系统

# Claude Code 会调用 EnterPlanMode
# 切换到只读探索模式
```

### 计划阶段操作

```
# 探索代码库
Read src/auth/...

# 理解现有模式
Grep pattern "jwt" src/

# 设计方案
Write .claude/plans/xxx.md
# 包含：
# - 问题分析
# - 方案对比
# - 实现步骤
# - 风险评估
```

### 退出计划模式

```
# 调用 ExitPlanMode
# 用户审批计划
# 开始实现
```

---

## 最佳实践

### 1. 计划文件结构

```markdown
# 认证系统重构计划

## 问题分析
- 当前认证逻辑耦合度高
- JWT 刷新机制存在问题
- 缺乏统一的错误处理

## 方案对比

### 方案 A：模块化重构
优点：改动小，风险低
缺点：无法根本解决问题

### 方案 B：全新设计
优点：架构清晰，易维护
缺点：工作量大

## 推荐方案
方案 B，配合渐进式迁移

## 实现步骤
1. 创建新的 auth-core 模块
2. 实现基础认证逻辑
3. 迁移现有代码
4. 更新测试
5. 部署验证

## 风险评估
- 数据迁移风险 → 已准备回滚方案
- 停机时间 → 蓝绿部署
```

### 2. 有效计划要点

```
✅ 明确的问题定义
✅ 多种方案对比
✅ 清晰的实现步骤
✅ 风险评估和缓解措施
✅ 时间/资源估算

❌ 模糊的目标
❌ 单一方案
❌ 缺乏细节的实现步骤
❌ 忽视潜在风险
```

### 3. 团队协作

```
1. Leader 创建任务 → 指定 Agent
2. Agent 进入 Plan Mode → 编写计划
3. Agent 调用 ExitPlanMode → 请求审批
4. Leader 审批计划 → Agent 执行
5. Leader 验收结果 → 任务完成
```

---

## 与其他模式对比

| 特性 | 普通模式 | Plan Mode | Auto Mode |
|------|---------|-----------|-----------|
| 文件写入 | 完全 | 仅 plan 文件 | 按规则自动 |
| 权限提示 | 每次询问 | 计划审批 | 自动处理 |
| 适用场景 | 简单任务 | 复杂重构 | 批量操作 |
| 用户交互 | 高 | 中 | 低 |

---

## 未记录的功能细节

### Feature-Gated 配置

以下配置项需要 `TRANSCRIPT_CLASSIFIER` feature 才能生效：

| 配置项 | Feature Gate | 说明 |
|--------|--------------|------|
| `useAutoModeDuringPlan` | TRANSCRIPT_CLASSIFIER | 计划阶段使用自动模式 |
| `skipAutoPermissionPrompt` | TRANSCRIPT_CLASSIFIER | 跳过自动模式确认 |

### EnterPlanModeTool 错误行为

子 Agent 上下文中使用会抛出错误：

```typescript
if (context.agentId) {
  throw new Error('EnterPlanMode tool cannot be used in agent contexts')
}
```

### ExitPlanModeV2Tool 验证逻辑

退出计划模式时的验证：

```typescript
// 仅在计划模式中调用，否则记录遥测事件
if (!isInPlanMode()) {
  logEvent('tengu_exit_plan_mode_called_outside_plan')
  return { error: 'You are not in plan mode...' }
}
```

### Auto Mode 状态恢复

退出计划模式时自动处理 Auto Mode 状态：

```typescript
// 捕获计划期间是否使用了 auto mode
const wasAutoModeActive = autoModeStateModule?.isAutoModeActive()

// 恢复状态或添加通知
if (finalRestoringAuto) {
  autoModeStateModule?.setAutoModeActive(true)
} else if (wasAutoModeActive) {
  setNeedsAutoModeExitAttachment(true)
}

// 权限生命周期管理
permissionSetupModule?.stripDangerousPermissionsForAutoMode()
// ... 执行完成后 ...
restoreDangerousPermissions()
```

### 工具属性

| 属性 | 值 | 说明 |
|------|-----|------|
| `shouldDefer` | `true` | 延迟执行 |
| `maxResultSizeChars` | `100000` | 最大结果大小 |
| `searchHint` | "switch to plan mode to design an approach before coding" | ToolSearch 提示 |

### CCR Web UI 计划编辑

CCR Web UI 可以编辑计划并重新持久化：

```typescript
if (updatedInput?.plan) {
  // 写入编辑后的计划
  await writeFile(filePath, updatedInput.plan, 'utf-8')
  // 更新远程快照
  await persistFileSnapshotIfRemote()
}
```

### Session Forking 计划复制

```typescript
// 不同于 copyPlanForResume 复用 slug
// copyPlanForFork 生成新 slug
const newSlug = generateSlug()
copyPlanToForkedPath(originalPath, newSlug)
```

### Plan Slug 清理

`/clear` 命令清理计划 slug 缓存：

```typescript
clearPlanSlug()      // 清理单个 slug
clearAllPlanSlugs()  // 清理所有 slugs
```

### 拒绝审批显示

用户拒绝退出计划模式时显示当前计划内容：

```typescript
// 拒绝时显示 RejectedPlanMessage 组件
return { message: renderToolUseRejectedMessage(planContent) }
```

### TeamCreate 提示

计划审批通过后提示并行化：

```typescript
if (hasTaskTool) {
  hint += '\n\nIf this plan can be broken down into multiple independent tasks, consider using the TeamCreate tool to create a team and parallelize the work.'
}
```

### Interview Phase 不受影响原因

Interview Phase（ants 用户）不受 Pewter Ledger 实验影响，因为：
- ants 使用 interview-phase 工作流
- Pewter Ledger 只应用于 5-phase 工作流
- Interview Phase 作为参考组保持不变

---

## 未文档化的功能

### useAutoModeDuringPlan 设置

控制 Plan Mode 期间是否使用自动模式语义：

```typescript
// settings.json
{
  "useAutoModeDuringPlan": true  // 默认 true
}
```

### skipAutoPermissionPrompt 设置

控制自动模式选择加入对话框的行为：

```typescript
{
  "skipAutoPermissionPrompt": true  // 跳过自动模式选择加入对话框
}
```

### prePlanMode 和 strippedDangerousRules

内部权限上下文字段：

```typescript
type ToolPermissionContext = {
  readonly strippedDangerousRules?: ToolPermissionRulesBySource
  readonly shouldAvoidPermissionPrompts?: boolean
  readonly awaitAutomatedChecksBeforeDialog?: boolean
  readonly prePlanMode?: PermissionMode  // 进入 Plan Mode 前的权限模式
}
```

**`prePlanMode`**: 存储进入 Plan Mode 前的权限模式，用于 ExitPlanMode 恢复原始模式。

**`strippedDangerousRules`**: 当 Plan Mode 期间使用自动模式时，危险权限（如 `Bash(*)`, `Agent(*)`, `PowerShell(iex:*)`）会被剥离并存储在此处，以便后续恢复。

### Circuit Breaker 行为

ExitPlanMode 包含电路断路器机制，防止通过 ExitPlanMode 绕过自动模式：

```typescript
// 如果 prePlanMode 是 auto 类模式但现在门控关闭，则恢复到 'default'
if (feature('TRANSCRIPT_CLASSIFIER')) {
  const prePlanRaw = appState.toolPermissionContext.prePlanMode ?? 'default'
  if (
    prePlanRaw === 'auto' &&
    !(permissionSetupModule?.isAutoModeGateEnabled() ?? false)
  ) {
    // 恢复到 'default' 而非 'auto'
  }
}
```

### planWasEdited 输出字段

ExitPlanMode 的输出包含此字段，指示用户是否编辑了计划：

```typescript
planWasEdited: boolean  // 用户是否编辑了计划（CCR UI 或 Ctrl+G）
```

### Ultraplan 功能

CCR（Cloud Code Remote）的超级规划功能：

- 使用 `tengu_ultraplan_model` GrowthBook 配置（默认 Opus 4.6）
- 30 分钟超时
- 权限模式: `'plan'`
- 两个执行目标: `'local'`（回传执行）或 `'remote'`（CCR 中执行）

### Plan 文件恢复机制

Plan 文件可以在 CCR 会话期间增量持久化到 transcript snapshots：

```typescript
export async function persistFileSnapshotIfRemote(): Promise<void>
```

### plansDirectory 安全验证

如果用户设置的 plansDirectory 超出项目根目录，会静默回退到 `~/.claude/plans/`。

### GrowthBook Feature Flags

| Flag | 说明 |
|------|------|
| `tengu_plan_mode_interview_phase` | Interview phase |
| `tengu_pewter_ledger` | Plan size control (trim/cut/cap) |
| `tengu_auto_mode_config.enabled` | Auto mode availability |
| `tengu_ultraplan_model` | Ultraplan 使用的模型 |

---

## 测试验证

验证 Plan Mode 配置：
```bash
# 检查计划目录
ls ~/.claude/plans/

# 查看计划文件
cat ~/.claude/plans/xxx.md

# 测试权限配置
claude --debug permissions
```
