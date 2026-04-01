# Claude Code 使用手册 - 研究计划

> 完整使用手册 + 测试驱动验证

**最后更新**: 2026-04-01 19:00
**状态**: 最终审查完成

---

## 执行状态

### 核心系统分析进度

| 系统 | 源码文件 | 状态 | 文档 |
|------|----------|------|------|
| Hook 系统 | `src/entrypoints/sdk/coreSchemas.ts` | ✅ | `05-hooks/01-hook-types.md` |
| 工具系统 | `src/tools.ts`, `src/Tool.ts` | ✅ | `03-tools/01-builtin-tools.md` |
| Agent 系统 | `src/tools/AgentTool/loadAgentsDir.ts` | ✅ | `07-advanced/01-agents.md` |
| 配置系统 | `src/utils/settings/types.ts`, `constants.ts` | ✅ | `06-config/02-settings-reference.md` |
| Skills 系统 | `src/skills/`, `src/utils/frontmatterParser.ts` | ✅ | `04-skills/01-native-skills.md` |
| 插件系统 | `src/utils/plugins/schemas.ts` | ✅ | `11-plugin-dev/01-overview.md` |
| Plan Mode | `src/utils/planModeV2.ts`, `plans.ts` | ✅ | `07-advanced/07-plan-mode.md` |
| MCP 系统 | `src/services/mcp/types.ts` | ✅ | `07-advanced/04-mcp-servers.md` |
| Team Mode | `src/tools/TeamTool/` | ✅ | `07-advanced/05-team-mode.md` |
| Sandbox | `src/sandbox/`, `sandboxTypes.ts` | ✅ | `07-advanced/06-sandbox.md` |
| Memory | `src/memdir/memoryTypes.ts` | ✅ | `09-memory/01-memory-overview.md` |
| Task System | `src/utils/tasks.ts`, `src/Task.ts` | ✅ | `10-task-system/01-overview.md` |
| Bridge/Remote | `src/bridges/` | ✅ | `07-advanced/08-bridge-remote.md` |
| Voice Mode | `src/voice/` | ✅ | `07-advanced/09-voice-mode.md` |

### 核心发现 ⭐⭐⭐

| 发现 | 源码位置 | 重要性 |
|------|----------|--------|
| **27 种 Hook 类型** | `coreSchemas.ts` | ⭐⭐⭐ |
| **26 核心工具 + 15 条件工具** | `tools.ts` | ⭐⭐⭐ |
| **Plugin 完整类型定义** | `schemas.ts` (1700+ 行) | ⭐⭐⭐ |
| **Plan Mode V2 Agent 机制** | `planModeV2.ts` | ⭐⭐ |
| **5 层配置优先级** | `constants.ts` | ⭐⭐ |
| **100+ 配置字段** | `types.ts` | ⭐⭐ |
| **3 种 Agent 类型** | `loadAgentsDir.ts` | ⭐⭐ |
| **PreCommit Hook 不存在** | `coreSchemas.ts` | ⭐⭐⭐ |

---

## 手册结构

### 第一部分：基础入门
- [x] 1.1 安装与认证
- [x] 1.2 核心概念
- [x] 1.3 快速上手

### 第二部分：命令行参数
- [x] 2.1 全局选项
- [x] 2.2 子命令
- [x] 2.3 环境变量

### 第三部分：工具系统
- [x] 3.1 内置工具清单
- [x] 3.2 工具权限管理
- [x] 3.3 MCP 工具集成

### 第四部分：技能系统
- [x] 4.1 原生技能机制
- [x] 4.2 技能创建规范
- [x] 4.3 技能与 Agent 配合

### 第五部分：Hooks 系统
- [x] 5.1 Hook 类型详解（27 种）
- [x] 5.2 配置与调试
- [x] 5.3 Python Hooks 实践
- [x] 5.4 常见问题与坑点

### 第六部分：配置体系
- [x] 6.1 配置层次结构
- [x] 6.2 settings.json 完整字段
- [x] 6.3 项目级配置

### 第七部分：进阶功能
- [x] 7.1 Agent 系统
- [x] 7.2 多 Agent 协作
- [x] 7.3 插件系统
- [x] 7.4 MCP 服务器
- [x] 7.5 Team Mode
- [x] 7.6 Sandbox
- [x] 7.7 Plan Mode
- [x] 7.8 Bridge/Remote
- [x] 7.9 Voice Mode

### 第八部分：最佳实践
- [x] 8.1 推荐使用模式
- [x] 8.2 避免使用的功能
- [x] 8.3 团队协作规范

### 第九部分：内存与任务
- [x] 9.1 内存系统概述
- [x] 9.2 Memory API
- [x] 9.3 Memory 最佳实践
- [x] 10.1 任务系统

### 第十一部分：插件开发
- [x] 11.1 插件系统概述
- [x] 11.2 插件结构
- [x] 11.3 插件 API
- [x] 11.4 开发示例

### 第十二部分：源码验证
- [x] 源码对照验证

---

## 测试脚本状态

| 编号 | 文件 | 覆盖范围 | 状态 |
|------|------|----------|------|
| 00 | hooks-test.sh | 27种Hook类型验证 | ✅ |
| 01 | skills-test.sh | 技能系统frontmatter验证 | ✅ |
| 02 | config-test.sh | 配置JSON语法验证 | ✅ |
| 03 | tools-test.sh | 工具系统验证 | ✅ |
| 04 | agents-test.sh | Agent定义验证 | ✅ |
| 05 | plugins-test.sh | 插件结构验证 | ✅ |
| 06 | memory-test.sh | 内存系统验证 | ✅ |
| 07 | tasks-test.sh | 任务系统验证 | ✅ |
| 08 | cli-test.sh | CLI参数解析验证 | ✅ |
| 09 | mcp-test.sh | MCP服务器配置验证 | ✅ |
| 10 | sandbox-test.sh | 沙箱配置验证 | ✅ |

**测试脚本完成率**: 11/11 = 100%

---

## 最终审查结果

### 已修复问题

1. **06-config/03-project-config.md**
   - 移除无效 `defaultMode: "all"` 值（替换为 `"ask"`）
   - 移除无效 `defaultMode: "limiting"` 值（替换为 `"dontAsk"`）
   - 修复环境变量示例中的无效值

2. **关键验证通过**
   - `11-plugin-dev/01-overview.md` - 使用 `plugin.json` ✅
   - `03-tools/02-tool-permissions.md` - 无无效值 ✅
   - `06-config/03-project-config.md` - 无顶层 `permissionMode` ✅
   - `05-hooks/01-hook-types.md` - 包含 Setup Hook ✅

3. **章节完整性**
   - 7.8 Bridge/Remote 存在 ✅
   - 7.9 Voice Mode 存在 ✅
   - 索引链接正确 ✅

---

## 完成总结

### 核心系统深度分析 (14/14)
- Hook 系统 (27种类型)
- 工具系统 (40+工具)
- Agent 系统 (3种类型)
- 配置系统 (100+字段)
- Skills 系统 (bundled + paths)
- 插件系统 (1700+行 schema)
- Plan Mode (V2 Agent机制)
- MCP 系统 (7种Transport)
- Team Mode (团队协作)
- Sandbox (安全隔离)
- Memory 系统 (4种类型)
- Task 系统 (TodoWriteTool + 7种任务类型)
- Bridge/Remote (远程桥接)
- Voice Mode (语音模式)

### 已验证文档
- 所有章节文档已与源码对照
- 所有测试脚本已创建
- 交叉引用一致性检查通过

**手册完成状态**: 100%
- 14/14 核心系统分析 ✅
- 11/11 测试脚本 ✅
- 100% 文档章节 ✅
- 源码验证完成 ✅

---
