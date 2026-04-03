# Claude Code 使用手册

> 本手册基于 [instructkr/claude-code](https://github.com/instructkr/claude-code) 源码分析编写，涵盖从安装配置到插件开发的完整知识体系。

**版本**: 2.2.0 | **更新**: 2026-04-03 | **源码版本**: 2.1.81

---

## 致谢

本手册的所有内容均基于 [instructkr/claude-code](https://github.com/instructkr/claude-code) 开源项目的源码分析编写。

特别感谢：
- 本手册通过深度阅读源码目录，归纳总结出 45 篇文档
- 所有技术细节均经过源码验证，确保准确性

---

## 本手册说明

### 文档来源

本文档不是官方文档，而是基于开源源码的**独立分析总结**：

| 文档类型 | 数量 | 说明 |
|---------|------|------|
| 入门指南 | 3 篇 | 安装、核心概念、快速上手 |
| CLI 参考 | 3 篇 | 命令行参数、子命令、环境变量 |
| 工具系统 | 3 篇 | 内置工具、权限管理、MCP集成 |
| 技能系统 | 3 篇 | 原生机制、技能创建、与Agent配合 |
| Hook 系统 | 4 篇 | 27种Hook类型、配置调试、Python实践、常见问题 |
| 配置体系 | 3 篇 | 配置层次、settings.json、项目配置 |
| 进阶功能 | 14 篇 | Agent、多Agent、插件、MCP、Team Mode、Sandbox、Plan Mode、Voice Mode、Bridge Remote、Companion/Buddy、UpstreamProxy、Setup流程、Server/Remote/Coordinator、Components/Screens |
| 最佳实践 | 3 篇 | 推荐模式、避免使用、团队协作 |
| 内存系统 | 4 篇 | 概述、API、最佳实践、Agent 记忆 |
| 任务系统 | 1 篇 | 任务管理 |
| 插件开发 | 4 篇 | 概述、结构、API、开发示例 |
| **总计** | **45 篇** | 覆盖 Claude Code 全部核心系统 |

### 源码验证

所有文档内容均经过源码验证，包括：
- Hook 类型数量和触发时机
- 配置加载优先级
- Skill frontmatter 字段定义
- Agent 生命周期
- 工具权限模型

---

## 快速导航

### 按场景查找

| 我想做什么 | 推荐阅读 |
|-----------|---------|
| 第一次用 Claude Code | [快速上手](./01-getting-started/03-quick-start.md) |
| 安装 Claude Code | [安装与认证](./01-getting-started/01-installation.md) |
| 理解基本概念 | [核心概念](./01-getting-started/02-core-concepts.md) |
| 写 Hooks 自动化脚本 | [Hook 类型详解](./05-hooks/01-hook-types.md) |
| 开发自定义 Skill | [技能创建规范](./04-skills/02-skill-creation.md) |
| 配置 Claude Code | [settings.json 参考](./06-config/02-settings-reference.md) |
| 团队共享配置 | [项目级配置](./06-config/03-project-config.md) |
| 开发插件/外挂 | [插件开发指南](./11-plugin-dev/01-overview.md) |
| 理解权限和安全 | [工具权限管理](./03-tools/02-tool-permissions.md) |
| 多 Agent 协作 | [多 Agent 协作](./07-advanced/02-multi-agent.md) |

---

## 核心发现（必读）

> 以下是从源码中发现的关键信息，已通过源码验证：

| 发现 | 重要性 | 相关章节 |
|------|--------|---------|
| **PreCommit Hook 不存在** | ⭐⭐⭐ | [Hook 类型详解](./05-hooks/01-hook-types.md) |
| 实际有 **27 种 Hook 类型** | ⭐⭐⭐ | [Hook 类型详解](./05-hooks/01-hook-types.md) |
| **Plugin = Skills + Agents + Hooks + Tools** | ⭐⭐⭐ | [插件系统](./07-advanced/03-plugins.md) |
| **6 层配置优先级** | ⭐⭐ | [配置层次结构](./06-config/01-config-hierarchy.md) |
| **Skill frontmatter 有 17 个字段** | ⭐⭐ | [原生技能机制](./04-skills/01-native-skills.md) |
| Skills 支持 **条件激活** (paths/arguments) | ⭐⭐ | [原生技能机制](./04-skills/01-native-skills.md) |

---

## 完整目录结构

### 第一部分：入门指南

| 章节 | 内容 | 状态 |
|------|------|------|
| [安装与认证](./01-getting-started/01-installation.md) | Homebrew/curl 安装、认证配置 | ✅ |
| [核心概念](./01-getting-started/02-core-concepts.md) | Agent、Tools、Skills、Hooks 基本概念 | ✅ |
| [快速上手](./01-getting-started/03-quick-start.md) | 5分钟上手教程 | ✅ |

### 第二部分：命令行参考

| 章节 | 内容 | 状态 |
|------|------|------|
| [全局选项](./02-cli/01-global-options.md) | CLI 全局选项 | ✅ |
| [子命令](./02-cli/02-commands.md) | 所有子命令详解 | ✅ |
| [环境变量](./02-cli/03-environment-variables.md) | 环境变量配置 | ✅ |

### 第三部分：工具系统

| 章节 | 内容 | 状态 |
|------|------|------|
| [内置工具清单](./03-tools/01-builtin-tools.md) | Read/Write/Bash/Glob/Grep 等 | ✅ |
| [工具权限管理](./03-tools/02-tool-permissions.md) | allow/deny/permit 配置 | ✅ |
| [MCP 工具集成](./03-tools/03-mcp-tools.md) | MCP 服务器集成 | ✅ |

### 第四部分：技能系统

| 章节 | 内容 | 状态 |
|------|------|------|
| [原生技能机制](./04-skills/01-native-skills.md) | 加载原理、优先级、条件激活 | ✅ |
| [技能创建规范](./04-skills/02-skill-creation.md) | SKILL.md 规范、frontmatter | ✅ |
| [技能与 Agent 配合](./04-skills/03-skills-and-agents.md) | 技能调用 Agent | ✅ |

### 第五部分：Hooks 系统 🔥 核心

| 章节 | 内容 | 状态 |
|------|------|------|
| [Hook 类型详解](./05-hooks/01-hook-types.md) | **27种 Hook 类型及触发时机** | ✅ |
| [配置与调试](./05-hooks/02-config-and-debug.md) | Hook 配置与问题排查 | ✅ |
| [Python Hooks 实践](./05-hooks/03-python-hooks.md) | Python 编写 Hook 示例 | ✅ |
| [常见问题与坑点](./05-hooks/04-pitfalls.md) | ⚠️ PreCommit 等不存在 | ✅ |

### 第六部分：配置体系

| 章节 | 内容 | 状态 |
|------|------|------|
| [配置层次结构](./06-config/01-config-hierarchy.md) | 6 层配置优先级 | ✅ |
| [settings.json 参考](./06-config/02-settings-reference.md) | 完整配置项说明 | ✅ |
| [项目级配置](./06-config/03-project-config.md) | .claude/ 目录配置 | ✅ |

### 第七部分：进阶功能

| 章节 | 内容 | 状态 |
|------|------|------|
| [Agent 系统](./07-advanced/01-agents.md) | Agent 机制详解 | ✅ |
| [多 Agent 协作](./07-advanced/02-multi-agent.md) | 多 Agent 通信 | ✅ |
| [插件系统](./07-advanced/03-plugins.md) | 插件安装与管理 | ✅ |
| [MCP 服务器](./07-advanced/04-mcp-servers.md) | MCP 服务器配置 | ✅ |
| [Team Mode](./07-advanced/05-team-mode.md) | 团队协作模式 | ✅ |
| [Sandbox](./07-advanced/06-sandbox.md) | 沙箱安全机制 | ✅ |
| [Plan Mode](./07-advanced/07-plan-mode.md) | 规划模式 | ✅ |
| [Voice Mode](./07-advanced/09-voice-mode.md) | 语音模式 | ✅ |
| [Bridge Remote](./07-advanced/08-bridge-remote.md) | 远程连接 | ✅ |
| [Companion/Buddy 系统](./companion-buddy-system.md) | 桌面伴侣系统 | ✅ |
| [UpstreamProxy 系统](./upstream-proxy-system.md) | CCR MITM 代理 | ✅ |

### 第八部分：最佳实践

| 章节 | 内容 | 状态 |
|------|------|------|
| [推荐使用模式](./08-best-practices/01-recommended-patterns.md) | 最佳实践 | ✅ |
| [避免使用的功能](./08-best-practices/02-avoid-these.md) | ⚠️ 避坑指南 | ✅ |
| [团队协作规范](./08-best-practices/03-team-collaboration.md) | 团队配置建议 | ✅ |

### 第九部分：内存系统

| 章节 | 内容 | 状态 |
|------|------|------|
| [内存系统概述](./09-memory/01-memory-overview.md) | 持久化记忆机制 | ✅ |
| [内存 API](./09-memory/02-memory-api.md) | API 参考 | ✅ |
| [内存最佳实践](./09-memory/03-memory-best-practices.md) | 使用建议 | ✅ |
| [Agent 记忆系统](./09-memory/04-agent-memory.md) | Agent 专用持久化记忆 | ✅ |

### 第十部分：任务系统

| 章节 | 内容 | 状态 |
|------|------|------|
| [任务系统概述](./10-task-system/01-overview.md) | 任务管理 | ✅ |

### 第十一部分：插件开发指南

| 章节 | 内容 | 状态 |
|------|------|------|
| [插件系统概述](./11-plugin-dev/01-overview.md) | 插件架构说明 | ✅ |
| [插件结构](./11-plugin-dev/02-structure.md) | 目录结构 | ✅ |
| [插件 API](./11-plugin-dev/03-api.md) | API 参考 | ✅ |
| [开发示例](./11-plugin-dev/04-examples.md) | 完整开发示例 | ✅ |

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

## 统计数据

| 指标 | 数量 |
|------|------|
| 文档文件 | 45 |
| 测试脚本 | 11 |
| Hook 类型 | 27 |
| Skill frontmatter 字段 | 16 |
| 配置层级 | 6 |
| 进阶功能模块 | 9 |

---

## 贡献指南

发现问题或有补充内容？欢迎提交 Issue 或 PR。

所有内容均基于源码分析，如发现与实际不符，请以源码为准。
