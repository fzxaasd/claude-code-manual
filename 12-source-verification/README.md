# 源码对照验证

> 验证文档内容与 Claude Code 源码的准确性

**验证日期**: 2026-04-01
**源码版本**: 2.1.81

---

## 1. Hook 事件类型验证

### 源码位置
`src/entrypoints/sdk/coreTypes.ts:25-53`

### 验证结果

| # | 事件名称 | 源码状态 | 文档状态 | 一致性 |
|---|----------|----------|----------|--------|
| 1 | PreToolUse | ✅ | ✅ | ✓ |
| 2 | PostToolUse | ✅ | ✅ | ✓ |
| 3 | PostToolUseFailure | ✅ | ✅ | ✓ |
| 4 | Notification | ✅ | ✅ | ✓ |
| 5 | UserPromptSubmit | ✅ | ✅ | ✓ |
| 6 | SessionStart | ✅ | ✅ | ✓ |
| 7 | SessionEnd | ✅ | ✅ | ✓ |
| 8 | Stop | ✅ | ✅ | ✓ |
| 9 | StopFailure | ✅ | ✅ | ✓ |
| 10 | SubagentStart | ✅ | ✅ | ✓ |
| 11 | SubagentStop | ✅ | ✅ | ✓ |
| 12 | PreCompact | ✅ | ✅ | ✓ |
| 13 | PostCompact | ✅ | ✅ | ✓ |
| 14 | PermissionRequest | ✅ | ✅ | ✓ |
| 15 | PermissionDenied | ✅ | ✅ | ✓ |
| 16 | Setup | ✅ | ✅ | ✓ |
| 17 | TeammateIdle | ✅ | ✅ | ✓ |
| 18 | TaskCreated | ✅ | ✅ | ✓ |
| 19 | TaskCompleted | ✅ | ✅ | ✓ |
| 20 | Elicitation | ✅ | ✅ | ✓ |
| 21 | ElicitationResult | ✅ | ✅ | ✓ |
| 22 | ConfigChange | ✅ | ✅ | ✓ |
| 23 | WorktreeCreate | ✅ | ✅ | ✓ |
| 24 | WorktreeRemove | ✅ | ✅ | ✓ |
| 25 | InstructionsLoaded | ✅ | ✅ | ✓ |
| 26 | CwdChanged | ✅ | ✅ | ✓ |
| 27 | FileChanged | ✅ | ✅ | ✓ |

**总计**: 27 种 Hook 类型 ✅ 全部验证通过

---

## 2. Skill Frontmatter 字段验证

### 源码位置
`src/skills/loadSkillsDir.ts:185-264`

### 验证结果

| 字段名 | 源码 | 文档 | 说明 |
|--------|------|------|------|
| `name` | ✅ | ✅ | 技能名称 |
| `description` | ✅ | ✅ | 技能描述 |
| `when_to_use` | ✅ | ✅ | 使用场景说明 |
| `paths` | ✅ | ✅ | 条件激活路径模式 |
| `arguments` | ✅ | ✅ | 参数定义 |
| `argument-hint` | ✅ | ✅ | 参数提示 |
| `allowed-tools` | ✅ | ✅ | 允许使用的工具 |
| `hooks` | ✅ | ✅ | Hook 配置 |
| `context` | ✅ | ✅ | 执行上下文 (fork/inline) |
| `agent` | ✅ | ✅ | 指定 Agent |
| `model` | ✅ | ✅ | 指定模型 |
| `disable-model-invocation` | ✅ | ✅ | 禁用模型调用 |
| `user-invocable` | ✅ | ✅ | 是否可用户调用 |
| `version` | ✅ | ✅ | 版本号 |
| `effort` | ✅ | ✅ | 工作量估计 |
| `shell` | ✅ | ✅ | Shell 类型 |

**总计**: 16 个 frontmatter 字段 ✅ 全部验证通过

---

## 3. 配置层级验证

### 源码位置
`src/utils/settings/constants.ts:7-22`

### 验证结果

| 层级 | 源码 | 文档 | 优先级 |
|------|------|------|--------|
| 1 | userSettings | User Settings | 最低 |
| 2 | projectSettings | Project Settings | ↑ |
| 3 | localSettings | Local Settings | ↑ |
| 4 | flagSettings | Flag Settings | ↓ |
| 5 | policySettings | Policy Settings | 最高 |

**配置合并**: 高优先级覆盖低优先级 ✅ 验证通过

---

## 4. 权限规则验证

### 源码位置
`src/utils/permissions/shadowedRuleDetection.ts`

### 验证结果

| 规则 | 源码 | 文档 | 说明 |
|------|------|------|------|
| deny > allow | ✅ | ✅ | 拒绝优先 |
| local > project > user | ✅ | ✅ | 来源优先级 |
| 模式匹配 | ✅ | ✅ | glob 风格 |

**权限语法**:
```
ToolName              # 匹配所有调用
ToolName(pattern)     # 匹配特定模式
ToolName(!pattern)    # 排除模式
```

---

## 5. Skill 加载路径验证

### 源码位置
`src/skills/loadSkillsDir.ts:638-803`

### 验证结果

| 路径 | 源码 | 文档 | 说明 |
|------|------|------|------|
| `~/.claude/skills/` | ✅ | ✅ | 用户级 |
| `.claude/skills/` | ✅ | ✅ | 项目级 |
| 动态发现 | ✅ | ✅ | 文件操作时 |

### Skill 格式
- 目录格式: `skill-name/SKILL.md` ✅
- 单文件格式: 仅在 `/commands/` 支持 ✅

---

## 6. Agent 类型验证

### 源码位置
`src/tools/AgentTool/loadAgentsDir.ts`

### 验证结果

| 类型 | 源码 | 文档 | 说明 |
|------|------|------|------|
| Built-in | ✅ | ✅ | Explore, Plan, Verification |
| Custom | ✅ | ✅ | 用户定义 |
| Plugin | ✅ | ✅ | 插件提供 |

---

## 7. 关键发现确认

### PreCommit Hook 不存在 ✅

源码中没有找到任何 PreCommit 相关的事件类型或处理逻辑。文档中提供的替代方案 (UserPromptSubmit + PreToolUse) 是正确的。

### 条件激活 (paths) ✅

源码验证 `src/skills/loadSkillsDir.ts:997-1058`:
- 使用 `ignore` 库进行路径匹配
- 支持 glob 模式
- 与 CLAUDE.md 条件规则行为一致

---

## 8. 测试脚本验证

| 测试 | 脚本 | 结果 |
|------|------|------|
| Hook 安全检查 | 00-hooks-test.sh | ✅ 通过 |
| Skill frontmatter | 01-skills-test.sh | ✅ 通过 |
| Config JSON | 02-config-test.sh | ✅ 通过 |

---

## 总结

| 验证项 | 状态 | 详情 |
|--------|------|------|
| Hook 类型 (27) | ✅ | 全部验证通过 |
| Skill 字段 (16) | ✅ | 全部验证通过 |
| 配置层级 | ✅ | 验证通过 |
| 权限规则 | ✅ | 验证通过 |
| 加载路径 | ✅ | 验证通过 |
| 测试脚本 | ✅ | 全部通过 |

**文档准确性**: 100% ✅
