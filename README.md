# Claude Code 使用手册 / Claude Code Manual

> Deep Research + Practical Testing produced Complete Claude Code Usage Guide

**Version**: 2.0.0
**Last Updated**: 2026-04-01
**Source Version**: 2.1.81
**Status**: Direction Adjusted → Comprehensive Usage Manual + Plugin Development Guide

---

## 手册概述

本手册基于 Claude Code 源码深度分析编写，涵盖从安装配置到高级用法的完整知识体系。

**核心内容**:
- 详述 27 种 Hook 类型及使用场景
- 完整的 Skills/Agent/Plugins 开发指南
- 插件外挂开发指南
- 团队协作最佳实践

---

## 手册定位

本手册定位为 **Claude Code 完整使用手册**，包含两大核心部分：

1. **用户使用指南** - CLI 使用、配置、技能开发
2. **插件开发指南** - 如何为 Claude Code 开发插件外挂

---

## 快速导航

### 必读章节

| 优先级 | 章节 | 文件 | 说明 |
|--------|------|------|------|
| ⭐⭐⭐ | [Hook 类型详解](./05-hooks/01-hook-types.md) | 5.1 | 10种Hook类型 |
| ⭐⭐ | [权限配置](./06-config/02-settings-reference.md) | 6.2 | 生产环境必配 |
| ⭐⭐ | [Skills 系统](./04-skills/01-native-skills.md) | 4.1 | 自定义技能入门 |
| ⭐⭐⭐ | [插件系统](./07-advanced/03-plugins.md) | 7.3 | 插件开发基础 |

### 按需求查找

| 需求 | 推荐章节 |
|------|----------|
| 首次使用 | [快速上手](./01-getting-started/03-quick-start.md) |
| 自定义 Hooks | [Hook 类型详解](./05-hooks/01-hook-types.md) |
| 自定义 Skills | [技能创建规范](./04-skills/02-skill-creation.md) |
| 团队配置 | [项目级配置](./06-config/03-project-config.md) |
| 权限控制 | [工具权限管理](./03-tools/02-tool-permissions.md) |
| 多 Agent | [多 Agent 协作](./07-advanced/02-multi-agent.md) |
| 插件开发 | [插件系统](./07-advanced/03-plugins.md) |

---

## 目录结构

### 第一部分：基础入门
- [1.1 安装与认证](./01-getting-started/01-installation.md) ✅
- [1.2 核心概念](./01-getting-started/02-core-concepts.md) ✅
- [1.3 快速上手](./01-getting-started/03-quick-start.md) ✅

### 第二部分：命令行参数详解
- [2.1 全局选项](./02-cli/01-global-options.md) ✅
- [2.2 子命令](./02-cli/02-commands.md) ✅
- [2.3 环境变量](./02-cli/03-environment-variables.md) ✅

### 第三部分：工具系统（Tools）
- [3.1 内置工具清单](./03-tools/01-builtin-tools.md) ✅
- [3.2 工具权限管理](./03-tools/02-tool-permissions.md) ✅
- [3.3 MCP 工具集成](./03-tools/03-mcp-tools.md) ✅

### 第四部分：技能系统（Skills）
- [4.1 原生技能机制](./04-skills/01-native-skills.md) ✅
- [4.2 技能创建规范](./04-skills/02-skill-creation.md) ✅
- [4.3 技能与 Agent 配合](./04-skills/03-skills-and-agents.md) ✅

### 第五部分：Hooks 系统 ⭐ 核心
- [5.1 Hook 类型详解](./05-hooks/01-hook-types.md) ✅
- [5.2 配置与调试](./05-hooks/02-config-and-debug.md) ✅
- [5.3 Python Hooks 实践](./05-hooks/03-python-hooks.md) ✅
- [5.4 常见问题与坑点](./05-hooks/04-pitfalls.md) ✅

### 第六部分：配置体系
- [6.1 配置层次结构](./06-config/01-config-hierarchy.md) ✅
- [6.2 settings.json 完整字段](./06-config/02-settings-reference.md) ✅
- [6.3 项目级配置](./06-config/03-project-config.md) ✅

### 第七部分：进阶功能
- [7.1 Agent 系统](./07-advanced/01-agents.md) ✅
- [7.2 多 Agent 协作](./07-advanced/02-multi-agent.md) ✅
- [7.3 插件系统](./07-advanced/03-plugins.md) ✅
- [7.4 MCP 服务器](./07-advanced/04-mcp-servers.md) ✅
- [7.5 Team Mode](./07-advanced/05-team-mode.md) ✅
- [7.6 Sandbox](./07-advanced/06-sandbox.md) ✅
- [7.7 Plan Mode](./07-advanced/07-plan-mode.md) ✅

### 第八部分：最佳实践与禁忌
- [8.1 推荐使用模式](./08-best-practices/01-recommended-patterns.md) ✅
- [8.2 ⚠️ 避免使用的功能](./08-best-practices/02-avoid-these.md) ✅
- [8.3 团队协作规范](./08-best-practices/03-team-collaboration.md) ✅

### 第九部分：内存系统
- [9.1 内存系统概述](./09-memory/01-memory-overview.md) ✅

### 第十部分：任务系统
- [10.1 任务系统](./10-task-system/01-overview.md) ✅

### 第十一部分：插件外挂开发指南
- [11.1 插件系统概述](./11-plugin-dev/01-overview.md) ✅
- [11.2 插件结构](./11-plugin-dev/02-structure.md) ✅
- [11.3 插件 API](./11-plugin-dev/03-api.md) ✅
- [11.4 开发示例](./11-plugin-dev/04-examples.md) ✅

### 第十二部分：源码验证
- [源码对照验证]（规划中）🔄

---

## 核心发现

| 发现 | 重要性 | 章节 |
|------|--------|------|
| **PreCommit Hook 不存在** | ⭐⭐⭐ | [5.1 Hook 类型详解](./05-hooks/01-hook-types.md) |
| 10 种 Hook 类型 | ⭐⭐⭐ | [5.1 Hook 类型详解](./05-hooks/01-hook-types.md) |
| 5 层配置优先级 | ⭐⭐ | [6.1 配置层次结构](./06-config/01-config-hierarchy.md) |
| Skills paths 条件激活 | ⭐⭐ | [4.1 原生技能机制](./04-skills/01-native-skills.md) |
| Plugin = Skills + Agents + Hooks | ⭐⭐⭐ | [7.3 插件系统](./07-advanced/03-plugins.md) |

---

## 测试验证

| 测试 | 文件 | 状态 |
|------|------|------|
| Hook 安全检查 | [tests/00-hooks-test.sh](./tests/00-hooks-test.sh) | ✅ 通过 |
| Skill 系统验证 | [tests/01-skills-test.sh](./tests/01-skills-test.sh) | ✅ 通过 |
| Config 配置验证 | [tests/02-config-test.sh](./tests/02-config-test.sh) | ✅ 通过 |
| 工具权限验证 | [tests/03-tools-test.sh](./tests/03-tools-test.sh) | ✅ 通过 |
| Agent 系统验证 | [tests/04-agents-test.sh](./tests/04-agents-test.sh) | ✅ 通过 |
| 插件结构验证 | [tests/05-plugins-test.sh](./tests/05-plugins-test.sh) | ✅ 通过 |
| 内存系统验证 | [tests/06-memory-test.sh](./tests/06-memory-test.sh) | ✅ 通过 |
| 任务系统验证 | [tests/07-tasks-test.sh](./tests/07-tasks-test.sh) | ✅ 通过 |
| CLI 参数验证 | [tests/08-cli-test.sh](./tests/08-cli-test.sh) | ✅ 通过 |
| MCP 服务器验证 | [tests/09-mcp-test.sh](./tests/09-mcp-test.sh) | ✅ 通过 |
| 沙箱配置验证 | [tests/10-sandbox-test.sh](./tests/10-sandbox-test.sh) | ✅ 通过 |

---

## 统计数据

| 指标 | 数量 |
|------|------|
| 文档文件 | 40 |
| 测试脚本 | 11 |
| Hook 类型 | 27 |
| Skill frontmatter 字段 | 16 |
| 配置层级 | 5 |
| 源码验证项 | 进行中 |

---

## 状态说明

| 状态 | 含义 |
|------|------|
| ✅ | 已完成并验证 |
| ⭐ | 重要章节 |
| ⭐⭐ | 关键章节 |
| ⭐⭐⭐ | 必读章节 |

---

## 使用建议

1. **首次使用**: 从 [快速上手](./01-getting-started/03-quick-start.md) 开始
2. **Hooks 开发**: 先读 [Hook 类型详解](./05-hooks/01-hook-types.md)，再看 [Python Hooks](./05-hooks/03-python-hooks.md)
3. **团队配置**: 参考 [项目级配置](./06-config/03-project-config.md)

---

## 贡献指南

如发现文档问题或有补充内容，请提交 Issue 或 PR。

手册基于 Claude Code 源码 `src/` 目录分析编写，源码对照验证功能规划中。
