# Claude Code Manual

> This manual is based on source code analysis of [instructkr/claude-code](https://github.com/instructkr/claude-code), covering the complete knowledge system from installation to plugin development.

**Version**: 2.0.0 | **Updated**: 2026-04-01 | **Source Version**: 2.1.81

---

## Acknowledgments

All content in this manual is based on source code analysis of the [instructkr/claude-code](https://github.com/instructkr/claude-code) open source project.

Special thanks:
- This manual covers 39 documents through deep source code reading
- All technical details are verified against source code for accuracy

---

## About This Manual

### Document Sources

This is NOT official documentation, but an **independent analysis summary** based on open source code:

| Category | Count | Description |
|----------|-------|-------------|
| Getting Started | 3 | Installation, Core Concepts, Quick Start |
| CLI Reference | 3 | Command-line options, subcommands, environment variables |
| Tools System | 3 | Built-in tools, permission management, MCP integration |
| Skills System | 3 | Native mechanism, skill creation, Agent integration |
| Hooks System | 4 | 27 Hook types, configuration & debugging, Python practices, common issues |
| Configuration | 3 | Hierarchy, settings.json, project config |
| Advanced Features | 9 | Agent, Multi-Agent, Plugins, MCP, Team Mode, Sandbox, Plan Mode, Voice Mode, Bridge Remote |
| Best Practices | 3 | Recommended patterns, things to avoid, team collaboration |
| Memory System | 4 | Overview, API, best practices, Agent memory |
| Task System | 1 | Task management |
| Plugin Development | 4 | Overview, structure, API, development examples |
| **Total** | **40** | Covers all core Claude Code systems |

### Source Verification

All documents are verified against source code:
- Hook type count and trigger timing
- Configuration loading priority
- Skill frontmatter field definitions
- Agent lifecycle
- Tool permission model

---

## Quick Navigation

### Find by Scenario

| What I want to do | Recommended Reading |
|-------------------|-------------------|
| First time using Claude Code | [Quick Start](./01-getting-started/03-quick-start.md) |
| Install Claude Code | [Installation & Auth](./01-getting-started/01-installation.md) |
| Understand basic concepts | [Core Concepts](./01-getting-started/02-core-concepts.md) |
| Write Hook automation scripts | [Hook Types](./05-hooks/01-hook-types.md) |
| Develop custom Skills | [Skill Creation](./04-skills/02-skill-creation.md) |
| Configure Claude Code | [settings.json Reference](./06-config/02-settings-reference.md) |
| Share team configuration | [Project Config](./06-config/03-project-config.md) |
| Develop plugins | [Plugin Development Guide](./11-plugin-dev/01-overview.md) |
| Understand permissions & security | [Tool Permissions](./03-tools/02-tool-permissions.md) |
| Multi-Agent collaboration | [Multi-Agent](./07-advanced/02-multi-agent.md) |

---

## Key Findings (Must Read)

> Key information discovered from source code, verified against source:

| Finding | Importance | Related Chapter |
|---------|-----------|----------------|
| **PreCommit Hook does not exist** | ⭐⭐⭐ | [Hook Types](./05-hooks/01-hook-types.md) |
| Actually **27 Hook types** | ⭐⭐⭐ | [Hook Types](./05-hooks/01-hook-types.md) |
| **Plugin = Skills + Agents + Hooks + Tools** | ⭐⭐⭐ | [Plugin System](./07-advanced/03-plugins.md) |
| **6-layer configuration priority** | ⭐⭐ | [Config Hierarchy](./06-config/01-config-hierarchy.md) |
| **Skill frontmatter has 17 fields** | ⭐⭐ | [Native Skills](./04-skills/01-native-skills.md) |
| Skills support **conditional activation** (paths/arguments) | ⭐⭐ | [Native Skills](./04-skills/01-native-skills.md) |

---

## Complete Directory Structure

### Part 1: Getting Started

| Chapter | Content | Status |
|---------|---------|--------|
| [Installation & Auth](./01-getting-started/01-installation.md) | Homebrew/curl install, auth config | ✅ |
| [Core Concepts](./01-getting-started/02-core-concepts.md) | Agent, Tools, Skills, Hooks basics | ✅ |
| [Quick Start](./01-getting-started/03-quick-start.md) | 5-minute tutorial | ✅ |

### Part 2: CLI Reference

| Chapter | Content | Status |
|---------|---------|--------|
| [Global Options](./02-cli/01-global-options.md) | CLI global options | ✅ |
| [Subcommands](./02-cli/02-commands.md) | All subcommands detailed | ✅ |
| [Environment Variables](./02-cli/03-environment-variables.md) | Environment variable config | ✅ |

### Part 3: Tools System

| Chapter | Content | Status |
|---------|---------|--------|
| [Built-in Tools](./03-tools/01-builtin-tools.md) | Read/Write/Bash/Glob/Grep etc. | ✅ |
| [Tool Permissions](./03-tools/02-tool-permissions.md) | allow/deny/permit config | ✅ |
| [MCP Tools](./03-tools/03-mcp-tools.md) | MCP server integration | ✅ |

### Part 4: Skills System

| Chapter | Content | Status |
|---------|---------|--------|
| [Native Skills](./04-skills/01-native-skills.md) | Loading principles, priority, conditional activation | ✅ |
| [Skill Creation](./04-skills/02-skill-creation.md) | SKILL.md spec, frontmatter | ✅ |
| [Skills & Agents](./04-skills/03-skills-and-agents.md) | Skills calling Agents | ✅ |

### Part 5: Hooks System 🔥 Core

| Chapter | Content | Status |
|---------|---------|--------|
| [Hook Types](./05-hooks/01-hook-types.md) | **27 Hook types and triggers** | ✅ |
| [Config & Debug](./05-hooks/02-config-and-debug.md) | Hook config & troubleshooting | ✅ |
| [Python Hooks](./05-hooks/03-python-hooks.md) | Python Hook examples | ✅ |
| [Common Issues](./05-hooks/04-pitfalls.md) | ⚠️ PreCommit etc. don't exist | ✅ |

### Part 6: Configuration System

| Chapter | Content | Status |
|---------|---------|--------|
| [Config Hierarchy](./06-config/01-config-hierarchy.md) | 6-layer priority | ✅ |
| [settings.json Reference](./06-config/02-settings-reference.md) | Complete config reference | ✅ |
| [Project Config](./06-config/03-project-config.md) | .claude/ directory config | ✅ |

### Part 7: Advanced Features

| Chapter | Content | Status |
|---------|---------|--------|
| [Agent System](./07-advanced/01-agents.md) | Agent mechanism detailed | ✅ |
| [Multi-Agent](./07-advanced/02-multi-agent.md) | Multi-Agent communication | ✅ |
| [Plugin System](./07-advanced/03-plugins.md) | Plugin install & management | ✅ |
| [MCP Servers](./07-advanced/04-mcp-servers.md) | MCP server config | ✅ |
| [Team Mode](./07-advanced/05-team-mode.md) | Team collaboration mode | ✅ |
| [Sandbox](./07-advanced/06-sandbox.md) | Sandbox security | ✅ |
| [Plan Mode](./07-advanced/07-plan-mode.md) | Plan mode | ✅ |
| [Voice Mode](./07-advanced/09-voice-mode.md) | Voice mode | ✅ |
| [Bridge Remote](./07-advanced/08-bridge-remote.md) | Remote connection | ✅ |

### Part 8: Best Practices

| Chapter | Content | Status |
|---------|---------|--------|
| [Recommended Patterns](./08-best-practices/01-recommended-patterns.md) | Best practices | ✅ |
| [Avoid These](./08-best-practices/02-avoid-these.md) | ⚠️ Pitfalls guide | ✅ |
| [Team Collaboration](./08-best-practices/03-team-collaboration.md) | Team config suggestions | ✅ |

### Part 9: Memory System

| Chapter | Content | Status |
|---------|---------|--------|
| [Memory Overview](./09-memory/01-memory-overview.md) | Persistent memory | ✅ |
| [Memory API](./09-memory/02-memory-api.md) | API reference | ✅ |
| [Memory Best Practices](./09-memory/03-memory-best-practices.md) | Usage suggestions | ✅ |
| [Agent Memory](./09-memory/04-agent-memory.md) | Agent-specific persistent memory | ✅ |

### Part 10: Task System

| Chapter | Content | Status |
|---------|---------|--------|
| [Task Overview](./10-task-system/01-overview.md) | Task management | ✅ |

### Part 11: Plugin Development Guide

| Chapter | Content | Status |
|---------|---------|--------|
| [Plugin Overview](./11-plugin-dev/01-overview.md) | Plugin architecture | ✅ |
| [Plugin Structure](./11-plugin-dev/02-structure.md) | Directory structure | ✅ |
| [Plugin API](./11-plugin-dev/03-api.md) | API reference | ✅ |
| [Dev Examples](./11-plugin-dev/04-examples.md) | Complete examples | ✅ |

---

## Test Verification

All core systems verified via scripts:

| Test | Script | Status |
|------|--------|--------|
| Hook Security | [00-hooks-test.sh](./tests/00-hooks-test.sh) | ✅ |
| Skills System | [01-skills-test.sh](./tests/01-skills-test.sh) | ✅ |
| Config | [02-config-test.sh](./tests/02-config-test.sh) | ✅ |
| Tool Permissions | [03-tools-test.sh](./tests/03-tools-test.sh) | ✅ |
| Agent System | [04-agents-test.sh](./tests/04-agents-test.sh) | ✅ |
| Plugin Structure | [05-plugins-test.sh](./tests/05-plugins-test.sh) | ✅ |
| Memory System | [06-memory-test.sh](./tests/06-memory-test.sh) | ✅ |
| Task System | [07-tasks-test.sh](./tests/07-tasks-test.sh) | ✅ |
| CLI Options | [08-cli-test.sh](./tests/08-cli-test.sh) | ✅ |
| MCP Servers | [09-mcp-test.sh](./tests/09-mcp-test.sh) | ✅ |
| Sandbox Config | [10-sandbox-test.sh](./tests/10-sandbox-test.sh) | ✅ |

---

## Statistics

| Metric | Count |
|--------|-------|
| Document Files | 39 |
| Test Scripts | 11 |
| Hook Types | 27 |
| Skill Frontmatter Fields | 16 |
| Config Layers | 6 |
| Advanced Feature Modules | 9 |

---

## Contribution Guide

Found an issue or have additions? Welcome to submit Issue or PR.

All content is based on source code analysis. If you find anything that doesn't match the actual implementation, the source code takes precedence.

---

## 中文版

For Chinese version, see [README.md](./README.md)
