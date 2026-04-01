# Claude Code 手册文档问题报告

> 检查日期: 2026-04-01
> 检查范围: 全部 37 个文档文件
> 状态: 待修复

---

## 一、断裂链接（Broken Links）

### 1. [README.md:106](README.md#L106) — 错误的目录名

```
./09-memory-system/01-overview.md
```

**问题**: 目录名为 `09-memory`，不是 `09-memory-system`。
**修复**: 改为 `./09-memory/01-memory-overview.md`

---

### 2. [MANUAL_INDEX.md:106](MANUAL_INDEX.md#L106) — 同上

**问题**: 同样指向了不存在的 `09-memory-system/` 目录。
**修复**: 改为 `./09-memory/01-memory-overview.md`

---

### 3. [PLAN.md](PLAN.md) — 同上

**问题**: 同上。
**修复**: 改为 `./09-memory/01-memory-overview.md`

---

### 4. [10-task-system/01-overview.md:420-421](10-task-system/01-overview.md#L420) — 引用不存在的文件

```markdown
- [TodoWrite Tool 使用](./02-todo-tool.md)
- [后台任务管理](./03-background-tasks.md)
```

**问题**: `02-todo-tool.md` 和 `03-background-tasks.md` 不存在。
**修复**: 删除这两个引用，或确认是否需要创建对应文档。

---

### 5. [01-getting-started/03-quick-start.md:226](01-getting-started/03-quick-start.md#L226) — 相对路径错误

```markdown
- [全局选项](./02-cli/01-global-options.md) - 命令行参数
```

**问题**: `03-quick-start.md` 位于 `01-getting-started/` 目录下，`./02-cli` 不存在。正确路径应为 `../02-cli/01-global-options.md`。
**修复**: 改为 `../02-cli/01-global-options.md`

---

## 二、编号/结构问题

### 6. [README.md:105-107](README.md#L105) — 缺少"第十部分"标题

**问题**: 目录从"第九部分"直接跳到"第十一部分"，跳过了"第十部分：任务系统"。
**修复**: 在 `9.1` 和 `10.1` 之间添加 `### 第十部分：任务系统` 标题。

---

### 7. [README.md:178](README.md#L178) — 编号跳跃

```markdown
2. **Hooks 开发**: 先读...
4. **团队配置**: 参考...
```

**问题**: 编号从 2 直接跳到 4，中间缺 3。
**修复**: 将 "4. **团队配置**" 改为 "3. **团队配置**"。

---

### 8. [README.md:152](README.md#L152) — 统计数据不准确

```
| 文档文件 | 37 |
```

**问题**: 实际文档文件数量为 41（37 个 .md + 4 个索引/计划文件）。
**修复**: 更新为 `41`。

---

## 三、术语不一致（Inconsistent Terminology）

### 9. [07-advanced/03-plugins.md:66, 77, 113, 284, 341](07-advanced/03-plugins.md#L66) — 使用了错误的插件清单文件名

多处引用了 `manifest.json`，但 Claude Code 插件清单文件名应为 `plugin.json`（位于 `.claude-plugin/` 目录下）。

**修复**: 将所有 `manifest.json` 引用改为 `plugin.json`。参考 `11-plugin-dev/02-structure.md:32` 的正确示例。

---

### 10. [08-best-practices/03-team-collaboration.md:491](08-best-practices/03-team-collaboration.md#L491) — 拼写错误

```markdown
[verson]
```

**问题**: 拼写错误，应为 `[version]`。
**修复**: 修正拼写。

---

### 11. [05-hooks/04-pitfalls.md:69](05-hooks/04-pitfalls.md#L69) — Unicode 箭头字符（次要）

**问题**: 使用 `→` (U+2192) 而非 ASCII `-->`，风格不一致。
**说明**: 非阻塞性问题。

---

## 四、无效配置值（Invalid Config Values）

> **说明**: `permissionMode`/`permissions.defaultMode` 的有效值为 `default`、`acceptEdits`、`bypassPermissions`、`dontAsk`、`plan`、`auto`。`all`、`limiting` 不是有效值。

### 12. [06-config/02-settings-reference.md:250](06-config/02-settings-reference.md#L250) — defaultMode 枚举错误

```markdown
| `defaultMode` | enum | 默认权限模式 (default/all/ask/limiting/bypass) |
```

**问题**: `all` 和 `limiting` 不是 `permissions.defaultMode` 的有效值。
**修复**: 更新为 `default/acceptEdits/bypassPermissions/dontAsk/plan/auto`。

---

### 13. [06-config/02-settings-reference.md:371](06-config/02-settings-reference.md#L371) — Enterprise 配置示例含无效值

```json
"defaultMode": "limiting"
```

**修复**: 改为 `"dontAsk"` 或 `"default"`。

---

### 14. [06-config/03-project-config.md:441](06-config/03-project-config.md#L441) — 严格模板含无效值

```json
"defaultMode": "limiting"
```

**修复**: 改为有效值。

---

### 15. [08-best-practices/01-recommended-patterns.md:106, 282](08-best-practices/01-recommended-patterns.md#L106) — permissionMode 含无效值 "limiting"

```json
"permissionMode": "limiting"
```

**问题**: `limiting` 不是有效值。
**修复**: 改为 `"dontAsk"` 或其他有效值。（两处均需修复）

---

### 16. [08-best-practices/01-recommended-patterns.md:112](08-best-practices/01-recommended-patterns.md#L112) — permissionMode 含无效值 "all"

```json
"permissionMode": "all"
```

**问题**: `all` 不是有效值。
**修复**: 改为 `"dontAsk"` 或其他有效值。

---

### 17. [08-best-practices/03-team-collaboration.md:38, 353](08-best-practices/03-team-collaboration.md#L38) — permissionMode 含无效值 "limiting"

```json
"permissionMode": "limiting"
```

**问题**: `limiting` 不是有效值。
**修复**: 改为 `"dontAsk"` 或其他有效值。（两处均需修复）

---

## 五、权限配置格式错误

### 18. [08-best-practices/02-avoid-these.md:23-27](08-best-practices/02-avoid-these.md#L23) — deny 数组格式错误

```json
"deny": [
  { "tool": "Bash", "match": "rm -rf /" },
  { "tool": "Bash", "match": "sudo rm *" },
  { "tool": "Bash", "match": "chmod 777 *" }
]
```

**问题**: `permissions.deny` 数组格式应为字符串形式 `["Bash(rm -rf *)", "Bash(sudo rm *)", "Bash(chmod 777 *)"]`，而非对象数组。
**修复**: 更新为正确的字符串格式。

---

## 六、自相矛盾

### 19. [07-advanced/04-mcp-servers.md:534, 562](07-advanced/04-mcp-servers.md#L534) — 命令存在性前后矛盾

**问题**: 第 534 行明确说 `claude mcp test` 和 `claude mcp get` 命令不存在，但第 562-563 行的故障排除步骤中又使用了 `claude mcp get <name>` 命令。
**修复**: 移除第 562-563 行的 `claude mcp get` 命令引用，改为使用其他验证方式（如 `/mcp list` 或检查配置文件）。

---

### 20. [08-best-practices/02-avoid-these.md:68](08-best-practices/02-avoid-these.md#L68) — 误导性说明

```bash
# ❌ 危险！等同于 dangerously-skip-permissions
claude --bypassPermissions
```

**问题**: `--bypassPermissions` 是 `--permission-mode bypassPermissions` 的简写形式，与 `--dangerously-skip-permissions` 是否完全等同需要验证。当前注释可能造成误导。
**修复**: 澄清或确认两者是否等同。

---

## 问题汇总

| # | 文件 | 行 | 严重性 | 类型 |
|----|------|-----|--------|------|
| 1 | README.md | 106 | 🔴 高 | 断裂链接 |
| 2 | MANUAL_INDEX.md | 106 | 🔴 高 | 断裂链接 |
| 3 | PLAN.md | — | 🔴 高 | 断裂链接 |
| 4 | 10-task-system/01-overview.md | 420-421 | 🔴 高 | 断裂链接 |
| 5 | 01-getting-started/03-quick-start.md | 226 | 🟡 中 | 相对路径错误 |
| 6 | README.md | 105-107 | 🟡 中 | 缺少章节标题 |
| 7 | README.md | 178 | 🟢 低 | 编号跳跃 |
| 8 | README.md | 152 | 🟢 低 | 统计数据不准确 |
| 9 | 07-advanced/03-plugins.md | 66,77,113,284,341 | 🔴 高 | 术语错误 |
| 10 | 08-best-practices/03-team-collaboration.md | 491 | 🟢 低 | 拼写错误 |
| 11 | 05-hooks/04-pitfalls.md | 69 | 🟢 低 | 风格不一致 |
| 12 | 06-config/02-settings-reference.md | 250 | 🔴 高 | 无效枚举值 |
| 13 | 06-config/02-settings-reference.md | 371 | 🔴 高 | 无效配置值 |
| 14 | 06-config/03-project-config.md | 441 | 🔴 高 | 无效配置值 |
| 15 | 08-best-practices/01-recommended-patterns.md | 106, 282 | 🔴 高 | 无效配置值 |
| 16 | 08-best-practices/01-recommended-patterns.md | 112 | 🔴 高 | 无效配置值 |
| 17 | 08-best-practices/03-team-collaboration.md | 38, 353 | 🔴 高 | 无效配置值 |
| 18 | 08-best-practices/02-avoid-these.md | 23-27 | 🔴 高 | 格式错误 |
| 19 | 07-advanced/04-mcp-servers.md | 534, 562 | 🟡 中 | 自相矛盾 |
| 20 | 08-best-practices/02-avoid-these.md | 68 | 🟡 中 | 误导性说明 |

**总计**: 20 个问题
- 🔴 高优先级: 13 个
- 🟡 中优先级: 4 个
- 🟢 低优先级: 3 个

---

## 修复优先级建议

### P0 — 必须修复（会导致用户配置错误）
1. **问题 12** — [06-config/02-settings-reference.md:250](06-config/02-settings-reference.md#L250) — defaultMode 枚举值错误
2. **问题 13** — [06-config/02-settings-reference.md:371](06-config/02-settings-reference.md#L371) — Enterprise 配置无效值
3. **问题 14** — [06-config/03-project-config.md:441](06-config/03-project-config.md#L441) — 严格模板无效值
4. **问题 15** — [08-best-practices/01-recommended-patterns.md:106,282](08-best-practices/01-recommended-patterns.md#L106) — permissionMode "limiting" 无效
5. **问题 16** — [08-best-practices/01-recommended-patterns.md:112](08-best-practices/01-recommended-patterns.md#L112) — permissionMode "all" 无效
6. **问题 17** — [08-best-practices/03-team-collaboration.md:38,353](08-best-practices/03-team-collaboration.md#L38) — permissionMode "limiting" 无效
7. **问题 18** — [08-best-practices/02-avoid-these.md:23-27](08-best-practices/02-avoid-these.md#L23) — deny 格式错误
8. **问题 9** — [07-advanced/03-plugins.md](07-advanced/03-plugins.md#L66) — manifest.json 应为 plugin.json

### P1 — 建议修复（影响文档可用性）
9. **问题 1-3** — README.md / MANUAL_INDEX.md / PLAN.md 断裂链接
10. **问题 4** — 10-task-system 引用不存在的文件
11. **问题 5** — quick-start 相对路径错误
12. **问题 19** — MCP servers 自相矛盾

### P2 — 可选修复
13. **问题 6** — 缺少"第十部分"标题
14. **问题 7** — 编号跳跃
15. **问题 8** — 统计数据不准确
16. **问题 10** — 拼写错误
17. **问题 11** — Unicode 字符风格
18. **问题 20** — 误导性说明
