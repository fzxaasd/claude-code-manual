# Claude Code 使用手册

> 基于源码深度分析编写，涵盖从安装配置到插件开发的完整知识体系

**版本**: 2.0.0 | **更新**: 2026-04-01 | **源码版本**: 2.1.81

---

## 快速导航

### 按场景查找

| 我想做什么 | 推荐阅读 |
|-----------|---------|
| 第一次用 Claude Code | [快速上手 →](./01-getting-started/03-quick-start.md) |
| 写自定义脚本自动化任务 | [Hook 类型详解 →](./05-hooks/01-hook-types.md) |
| 开发自己的技能(Skill) | [技能创建规范 →](./04-skills/02-skill-creation.md) |
| 开发插件/外挂 | [插件开发指南 →](./11-plugin-dev/01-overview.md) |
| 配置团队规范 | [团队协作规范 →](./08-best-practices/03-team-collaboration.md) |
| 理解权限和安全 | [工具权限管理 →](./03-tools/02-tool-permissions.md) |

---

## 核心要点（必读）

> ⚠️ 以下是从源码中发现的关键信息，已验证：

| 发现 | 重要性 | 相关章节 |
|------|--------|---------|
| **PreCommit Hook 不存在** | ⭐⭐⭐ | [Hook 类型详解](./05-hooks/01-hook-types.md) |
| 实际有 **10 种 Hook 类型**（非文档描述的27种） | ⭐⭐⭐ | [Hook 类型详解](./05-hooks/01-hook-types.md) |
| Plugin = Skills + Agents + Hooks 的组合 | ⭐⭐⭐ | [插件系统](./07-advanced/03-plugins.md) |
| 5 层配置优先级（Global > Project > ...） | ⭐⭐ | [配置层次结构](./06-config/01-config-hierarchy.md) |
| Skills paths 支持条件激活 | ⭐⭐ | [原生技能机制](./04-skills/01-native-skills.md) |

---

## 文档结构

### 第一阶段：入门（首次使用）

| 章节 | 内容 |
|------|------|
| [安装与认证](./01-getting-started/01-installation.md) | 安装步骤、认证配置 |
| [核心概念](./01-getting-started/02-core-concepts.md) | Agent、Tools、Skills、Hooks 基本概念 |
| [快速上手](./01-getting-started/03-quick-start.md) | 5分钟上手教程 |

### 第二阶段：基础配置

| 章节 | 内容 |
|------|------|
| [命令行参数](./02-cli/01-global-options.md) | CLI 全局选项、子命令 |
| [环境变量](./02-cli/03-environment-variables.md) | 环境变量配置 |
| [配置层次结构](./06-config/01-config-hierarchy.md) | Global/Project/Local 等 5 层配置 |
| [settings.json 字段](./06-config/02-settings-reference.md) | 完整配置项参考 |
| [项目级配置](./06-config/03-project-config.md) | .claude/ 目录配置 |

### 第三阶段：核心系统

#### 🔥 Hooks 系统（最重要）

| 章节 | 内容 | 状态 |
|------|------|------|
| [Hook 类型详解](./05-hooks/01-hook-types.md) | 10种Hook类型及使用场景 | ✅ |
| [配置与调试](./05-hooks/02-config-and-debug.md) | Hook 配置与问题排查 | ✅ |
| [Python Hooks 实践](./05-hooks/03-python-hooks.md) | Python 编写 Hook 示例 | ✅ |
| [常见问题与坑点](./05-hooks/04-pitfalls.md) | ⚠️ PreCommit 等不存在等 | ✅ |

#### ⚙️ Skills 系统

| 章节 | 内容 | 状态 |
|------|------|------|
| [原生技能机制](./04-skills/01-native-skills.md) | Skills 加载原理、条件激活 | ✅ |
| [技能创建规范](./04-skills/02-skill-creation.md) | frontmatter、参数定义 | ✅ |
| [技能与 Agent 配合](./04-skills/03-skills-and-agents.md) | 技能调用 Agent | ✅ |

#### 🔧 Tools 系统

| 章节 | 内容 | 状态 |
|------|------|------|
| [内置工具清单](./03-tools/01-builtin-tools.md) | Read/Write/Bash 等 | ✅ |
| [工具权限管理](./03-tools/02-tool-permissions.md) | allow/deny 配置 | ✅ |
| [MCP 工具集成](./03-tools/03-mcp-tools.md) | MCP 服务器集成 | ✅ |

### 第四阶段：进阶功能

| 章节 | 内容 | 状态 |
|------|------|------|
| [Agent 系统](./07-advanced/01-agents.md) | Agent 机制 | ✅ |
| [多 Agent 协作](./07-advanced/02-multi-agent.md) | Team Mode | ✅ |
| [内存系统](./09-memory/01-memory-overview.md) | 持久化记忆 | ✅ |
| [任务系统](./10-task-system/01-overview.md) | 任务管理 | ✅ |
| [Plan Mode](./07-advanced/07-plan-mode.md) | 规划模式 | ✅ |
| [Sandbox](./07-advanced/06-sandbox.md) | 沙箱安全 | ✅ |

### 第五阶段：最佳实践

| 章节 | 内容 | 状态 |
|------|------|------|
| [推荐使用模式](./08-best-practices/01-recommended-patterns.md) | ✅ |
| [避免使用的功能](./08-best-practices/02-avoid-these.md) | ⚠️ |
| [团队协作规范](./08-best-practices/03-team-collaboration.md) | ✅ |

### 第六阶段：插件开发

| 章节 | 内容 | 状态 |
|------|------|------|
| [插件系统概述](./11-plugin-dev/01-overview.md) | Plugin = Skills + Agents + Hooks | ✅ |
| [插件结构](./11-plugin-dev/02-structure.md) | 目录结构 | ✅ |
| [插件 API](./11-plugin-dev/03-api.md) | API 参考 | ✅ |
| [开发示例](./11-plugin-dev/04-examples.md) | 完整示例 | ✅ |

### 附录

| 章节 | 内容 |
|------|------|
| [测试脚本](./tests/) | 11 个验证脚本 |
| [源码验证状态](./README.md#测试验证) | 各系统验证结果 |

---

## 测试验证

所有核心系统已通过脚本验证：

| 测试项 | 脚本 | 状态 |
|--------|------|------|
| Hook 安全检查 | [00-hooks-test.sh](./tests/00-hooks-test.sh) | ✅ |
| Skill 系统 | [01-skills-test.sh](./tests/01-skills-test.sh) | ✅ |
| Config 配置 | [02-config-test.sh](./tests/02-config-test.sh) | ✅ |
| 工具权限 | [03-tools-test.sh](./tests/03-tools-test.sh) | ✅ |
| Agent 系统 | [04-agents-test.sh](./tests/04-agents-test.sh) | ✅ |
| 插件结构 | [05-plugins-test.sh](./tests/05-plugins-test.sh) | ✅ |
| 内存系统 | [06-memory-test.sh](./tests/06-memory-test.sh) | ✅ |
| 任务系统 | [07-tasks-test.sh](./tests/07-tasks-test.sh) | ✅ |
| CLI 参数 | [08-cli-test.sh](./tests/08-cli-test.sh) | ✅ |
| MCP 服务器 | [09-mcp-test.sh](./tests/09-mcp-test.sh) | ✅ |
| 沙箱配置 | [10-sandbox-test.sh](./tests/10-sandbox-test.sh) | ✅ |

---

## 贡献指南

发现问题或有补充内容？欢迎提交 Issue 或 PR。

> 本手册基于 Claude Code 源码 `src/` 目录分析编写。
