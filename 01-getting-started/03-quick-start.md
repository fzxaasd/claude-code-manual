# 1.3 快速上手

> 5 分钟上手 Claude Code

---

## 首次使用

### 1. 安装与登录

```bash
# 安装（macOS）
brew install anthropic/formulae/claude-code

# 首次登录
claude
# 会自动打开浏览器进行 OAuth 认证
```

### 2. 基本对话

```bash
$ claude
# 进入交互式对话

> 帮我创建一个简单的 Hello World Python 程序
```

---

## 核心操作

### 编辑文件

```bash
# 让 Claude 编辑现有文件
> 修改 main.py，将函数名改为 process_data

# 让 Claude 创建新文件
> 创建 config.yaml 配置文件
```

### 执行命令

```bash
# Claude 会询问是否执行危险命令
> 运行 npm install

# 批准后执行
# y - 批准
# n - 拒绝
# a - 批准所有后续命令
```

### 查看差异

```bash
# 提交前查看变更
> 给我看看现在的改动

# 查看 git diff
> git diff
```

---

## 常用快捷键

### 交互模式

| 快捷键 | 功能 |
|--------|------|
| `Ctrl+C` | 中断当前操作 |
| `Ctrl+D` | 退出会话 |
| `Ctrl+L` | 清屏 |
| `Ctrl+O` | 查看完整输出 |
| `Ctrl+S` | 保存当前会话 |
| `Tab` | 自动补全 |

### 命令模式

| 快捷键 | 功能 |
|--------|------|
| `↑/↓` | 历史命令 |
| `Ctrl+R` | 搜索历史 |
| `!!` | 重复上一命令 |

---

## 常用命令示例

### 文件操作

```bash
# 搜索文件
claude "查找所有 ts 文件"
claude "grep -r 'TODO' ."

# 批量重命名
claude "将所有 .js 重命名为 .mjs"
```

### Git 操作

```bash
# 提交代码
claude "commit -m 'feat: add login feature'"

# 创建 PR
claude "创建 pull request"

# 查看变更
claude "git status && git diff"
```

### 开发任务

```bash
# 启动开发服务器
claude "npm run dev"

# 运行测试
claude "pytest tests/"

# 代码审查
claude "review the recent commits"
```

---

## 配置最小可用环境

### 1. 创建项目配置

```bash
mkdir -p .claude
cat > .claude/settings.json << 'EOF'
{
  "permissions": {
    "allow": ["Bash", "Read", "Write", "Edit"],
    "deny": ["rm -rf /"]
  }
}
EOF
```

### 2. 设置权限模式

```bash
# 开发环境 - 宽松权限
export CLAUDE_PERMISSION_MODE=all

# 生产环境 - 严格限制
export CLAUDE_PERMISSION_MODE=limiting
```

---

## 第一个完整示例

### 场景：创建 React 组件

```bash
$ claude

> 创建一个用户卡片组件 UserCard.tsx
> 包含头像、用户名、邮箱
> 使用 TypeScript 和 Tailwind CSS
```

Claude 会：
1. 分析现有代码结构
2. 创建组件文件
3. 展示代码内容
4. 询问是否需要调整

---

## 会话管理

### 保存与恢复

```bash
# 查看所有会话
claude sessions list

# 恢复会话
claude --resume <session-id>

# 新会话
claude --new
```

### 导出与分享

```bash
# 导出会话记录
claude "导出这次对话的 markdown"

# 保存为文件
Ctrl+S
```

---

## 常见问题

### Q: 如何中断长时间运行的任务？
A: `Ctrl+C` 或输入 `stop`

### Q: 命令执行被拒绝怎么办？
A: 检查 `permissions.json` 配置，或使用 `claude --permissions all`

### Q: 如何查看之前的输出？
A: `Ctrl+O` 打开完整输出视图

### Q: 会话历史丢失怎么办？
A: 使用 `claude sessions list` 恢复，或定期导出

---

## 下一步

- [安装与认证](./01-installation.md) - 详细安装说明
- [核心概念](./02-core-concepts.md) - 深入理解术语
- [全局选项](../02-cli/01-global-options.md) - 命令行参数
