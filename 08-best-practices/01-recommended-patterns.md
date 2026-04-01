# 8.1 推荐使用模式

> 经过验证的最佳实践和使用模式

---

## 工作流程模式

### 1. 增量开发模式

```
需求 → 拆分 → 实施 → 测试 → 审查 → 合并
```

**适用场景**: 大型功能开发
**优点**: 风险可控, 便于 review

```bash
# 最佳实践
> 将这个功能拆分成 3-4 个小任务
> 每次只完成一个小任务
> 完成后进行代码审查
> 再进行下一个任务
```

### 2. 探索验证模式

```
假设 → 验证 → 结论 → 实施
```

**适用场景**: 技术选型, 问题诊断
**优点**: 减少试错成本

```bash
# 最佳实践
> 先用 Read 和 Grep 分析现有代码
> 确认技术可行性
> 再开始实施
```

### 3. 渐进增强模式

```
现有代码 → 理解 → 小改 → 测试 → 大改
```

**适用场景**: 重构, 优化
**优点**: 保持功能稳定

---

## 项目组织模式

### 1. 单一职责目录

```
src/
├── features/
│   ├── auth/
│   │   ├── components/
│   │   ├── hooks/
│   │   └── services/
│   └── dashboard/
├── shared/
│   ├── components/
│   └── utils/
└── tests/
```

### 2. 按领域组织

```
domain/
├── users/
├── orders/
├── products/
└── shared/
```

### 3. 分层架构

```
layers/
├── presentation/
├── application/
├── domain/
└── infrastructure/
```

---

## 配置模式

### 1. 分层配置

```json
// ~/.claude/settings.json (用户级)
{
  "permissionMode": "ask",
  "model": "sonnet"
}

// .claude/settings.json (项目级)
{
  "permissionMode": "dontAsk",
  "permissions": {...}
}

// .claude/settings.local.json (本地)
{
  "permissionMode": "acceptEdits"
}
```

### 2. 权限配置模式

```json
{
  "permissions": {
    "allow": [
      "Read",
      "Write(src/**)",
      "Edit",
      "Glob",
      "Grep",
      "Bash(npm run *)",
      "Bash(npm test)",
      "Bash(git *)"
    ],
    "deny": [
      "Bash(rm -rf *)",
      "Bash(sudo *)",
      "Write(*.env)",
      "Write(*.pem)"
    ]
  }
}
```

### 3. Hook 配置模式

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "hooks/validate.sh"
          }
        ]
      }
    ]
  }
}
```

---

## Skill 设计模式

### 1. 原子化 Skill

每个 Skill 只做一件事:

```markdown
---
name: eslint-fix
description: 运行 ESLint 并自动修复
---

# ESLint Fix

执行 eslint --fix 并报告结果。
```

### 2. 组合 Skill

多个原子 Skill 组合:

```markdown
---
name: code-review
description: 完整代码审查流程
---

# 代码审查流程

1. 运行 eslint-fix
2. 运行 prettier-format
3. 运行 unit-tests
4. 生成审查报告
```

### 3. 条件激活 Skill

```markdown
---
name: python-lint
paths:
  - "**/*.py"
---

# Python Linting
```

---

## 协作模式

### 1. 主人-助手模式

```
用户 (决策者)
    ↓ 指令
Claude (执行者)
    ↓ 建议
用户 (审批)
```

### 2. 配对编程模式

```
用户 ←→ Claude
  ↕        ↕
 键盘     代码
```

### 3. 代码审查模式

```
Claude (实现者)
    ↓ PR
Claude (审查者)
    ↓ 反馈
Claude (修复者)
```

---

## 调试模式

### 1. 分步调试

```bash
> 分步执行这个函数
> 在第 5 行添加断点
> 检查变量 x 的值
> 继续执行到第 10 行
```

### 2. 增量修改

```bash
> 先修改函数签名
> 验证编译通过
> 再修改函数体
> 验证测试通过
```

### 3. 回滚策略

```bash
# 每次重大修改后测试
> git commit -m "WIP: step 1"

# 问题发生时回滚
> git reset --soft HEAD~1
```

---

## 安全模式

### 1. 最小权限原则

```json
{
  "permissionMode": "dontAsk",
  "permissions": {
    "allow": ["Read", "Glob", "Grep"],
    "deny": ["Write", "Bash"]
  }
}
```

### 2. 命令白名单

```json
{
  "permissions": {
    "allow": [
      "Bash(npm run *)",
      "Bash(npm test)",
      "Bash(git status)",
      "Bash(git log)"
    ]
  }
}
```

### 3. 敏感操作确认

```bash
> 确认要执行这个命令吗？
> 这是不可逆操作
> 建议先备份数据
```

---

## 性能模式

### 1. 上下文管理

```bash
# 定期压缩会话
> compact

# 开始新会话而不是继续
> start new session
```

### 2. 批量操作

```bash
# 而不是逐个处理
> 批量重命名所有 test 文件为 *.spec

# 而不是逐个搜索
> 搜索所有 TODO 并生成报告
```

### 3. 增量更新

```bash
# 而不是全量重建
> npm run build -- --watch

# 而不是全部测试
> npm test -- --grep "auth"
```

---

## 版本控制模式

### 1. 原子提交

```bash
# 一个提交只做一件事
> commit: 添加用户认证功能
> commit: 修复登录页面样式
> commit: 添加单元测试
```

### 2. 提交前检查

```bash
# 提交前自动检查
> git add .
> npm test
> git commit -m "feat: add feature"
```

### 3. 分支策略

```
main (生产)
  ↑
develop (开发)
  ↑
feature/xxx (功能分支)
```

---

## 文档模式

### 1. 代码即文档

```typescript
// 使用清晰的命名
const isUserAuthenticated = true;

// 添加必要的注释
/**
 * 计算订单总价
 * @param items - 订单项列表
 * @returns 总价（单位：分）
 */
function calculateTotal(items: Item[]): number
```

### 2. 变更记录

```markdown
## 2026-04-01

### 新增
- 用户认证功能

### 修改
- 优化登录页面性能

### 修复
- 修复 Token 过期问题
```

### 3. README 结构

```markdown
# 项目名称

## 快速开始
## 功能特性
## 配置说明
## 开发指南
## API 文档
```

---

## 错误处理模式

### 1. 防御性编程

```bash
# 检查前置条件
> 在修改之前先备份
> 确认文件存在
> 验证输入参数
```

### 2. 渐进式回退

```bash
> 先尝试最简单的方案
> 如果失败再尝试复杂方案
> 最终回退到手动处理
```

### 3. 错误日志

```bash
# 记录错误信息
> 将错误日志保存到 /tmp/error.log
> 分析错误原因
> 提出解决方案
```

---

## 模板文件

### 项目初始化模板

```bash
mkdir -p .claude
cat > .claude/settings.json << 'EOF'
{
  "permissionMode": "ask",
  "permissions": {
    "allow": ["Read", "Write", "Edit", "Glob", "Grep"],
    "deny": ["Bash(rm -rf *)"]
  }
}
EOF
```

### Pre-commit Hook 模板

```bash
#!/bin/bash
# .git/hooks/pre-commit
claude --command "run lint && run tests"
```
