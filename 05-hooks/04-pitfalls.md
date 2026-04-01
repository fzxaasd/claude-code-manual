# 常见问题与坑点

> Claude Code Hooks 系统的问题排查指南

## 问题分类

### 1. Hook 不触发

#### 症状
配置了 Hook 但从未执行。

#### 可能原因

| 原因 | 检查方法 | 解决方案 |
|------|----------|----------|
| JSON 语法错误 | `python3 -m json.tool settings.json` | 修复 JSON |
| Hook 类型拼写错误 | 对比 `hooksConfigManager.ts` | 使用正确的类型名 |
| matcher 不匹配 | 检查工具名是否匹配 | 修改 matcher |
| 文件路径错误 | 检查配置文件位置 | 移动到正确位置 |

#### 排查步骤

```bash
# 1. 验证 JSON 语法
python3 -m json.tool ~/.claude/settings.json > /dev/null

# 2. 查看已注册的 Hooks
claude /hooks

# 3. 启用调试
claude --debug hooks

# 4. 检查配置文件
cat ~/.claude/settings.json | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('hooks', {}))"
```

### 2. Hook 超时

#### 症状
Hook 执行时间过长或超时。

#### 原因
- 脚本执行时间超过 `timeout`
- 网络请求阻塞
- 死循环

#### 解决方案

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "long-running-script.sh",
            "timeout": 30,
            "async": true
          }
        ]
      }
    ]
  }
}
```

### 3. 循环触发

#### 症状
Hook 触发自己，导致无限循环。

#### 示例问题

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "git status"
          }
        ]
      }
    ]
  }
}
```

`git status` 会再次触发 PreToolUse Hook！

#### 解决方案

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "security-check.sh",
            "if": "Bash(!git status)"
          }
        ]
      }
    ]
  }
}
```

### 4. Exit Code 行为错误

#### 常见误解

| Exit Code | 预期 | 实际 |
|-----------|------|------|
| 0 | 失败 | 成功（无输出） |
| 2 | 错误 | 阻塞（显示给模型） |
| 其他 | 错误 | 非阻塞（只显示给用户） |

#### 正确理解

```
Exit 0  → 成功，stdout 可选传递给模型
Exit 2  → 阻塞错误，stderr 显示给模型
其他    → 非阻塞错误，stderr 只显示给用户
```

### 5. 权限问题

#### 症状
Hook 脚本无执行权限。

#### 解决

```bash
chmod +x .claude/hooks/*.sh
chmod +x .claude/hooks/*.py
```

### 6. 环境变量缺失

#### 症状
脚本依赖的环境变量不存在。

#### 解决

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "script.sh",
            "env": {
              "MY_VAR": "value"
            }
          }
        ]
      }
    ]
  }
}
```

### 7. 工作目录错误

#### 症状
脚本找不到文件，但文件存在。

#### 解决

```bash
# 使用绝对路径
python3 /absolute/path/to/script.py

# 或在脚本开始时切换目录
cd "$(dirname "$0")"
```

### 8. 多个 Hook 执行顺序

#### 问题
多个匹配的 Hook 执行顺序不确定。

#### 解决
使用单个 Hook 调用脚本，在脚本内部处理逻辑：

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash|Edit|Write",
        "hooks": [
          {
            "type": "command",
            "command": "python3 combined-hook.py"
          }
        ]
      }
    ]
  }
}
```

---

## 调试技巧

### 1. 简单调试

```python
#!/usr/bin/env python3
import sys
import json

data = json.loads(sys.stdin.read())
print(f"DEBUG: {json.dumps(data, indent=2)}", file=sys.stderr)
sys.exit(0)
```

### 2. 条件调试

```python
import os

if os.environ.get('DEBUG_HOOKS'):
    print(f"DEBUG: {data}", file=sys.stderr)
```

### 3. 日志文件

```python
import logging

logging.basicConfig(
    filename='/tmp/claude-hooks.log',
    level=logging.DEBUG
)

logging.debug(f"Hook input: {data}")
```

---

## 常见错误对照表

| 错误 | 原因 | 解决 |
|------|------|------|
| Hook 不执行 | JSON 语法错误 | 验证 JSON |
| Hook 超时 | timeout 太短 | 增加 timeout |
| 循环触发 | Hook 触发自己 | 使用 `if` 条件 |
| 无权限 | chmod 问题 | 添加执行权限 |
| 找不到文件 | 路径错误 | 使用绝对路径 |
| Exit 0 但不工作 | 逻辑错误 | 检查脚本逻辑 |
| Exit 2 无效 | 工具不支持 | 确认工具类型 |
