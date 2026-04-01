# 7.6 Sandbox（沙箱环境）

> 基于源码 `src/utils/sandbox/sandbox-adapter.ts` 深度分析

## 核心概念

Sandbox 使用 `@anthropic-ai/sandbox-runtime` 包提供操作系统级别的隔离执行环境，用于安全运行 Bash 命令和限制文件/网络访问。

```
┌────────────────────────────────────────────────────────────┐
│                   Sandbox 架构                               │
├────────────────────────────────────────────────────────────┤
│                                                            │
│  Claude Code CLI                                            │
│       │                                                    │
│       ▼                                                    │
│  SandboxAdapter (sandbox-adapter.ts)                        │
│       │                                                    │
│       ▼                                                    │
│  @anthropic-ai/sandbox-runtime                              │
│       │                                                    │
│       ├── macOS: Bubblewrap (Linux) / SandboxKit (macOS)   │
│       ├── Linux: Bubblewrap                                │
│       └── WSL2: Linux namespace                            │
│                                                            │
└────────────────────────────────────────────────────────────┘
```

---

## 启用条件

### 平台支持

| 平台 | 支持状态 | 技术 |
|------|----------|------|
| macOS | ✅ 完全支持 | SandboxKit |
| Linux | ✅ 完全支持 | Bubblewrap |
| WSL2 | ✅ 支持 | Linux namespace |
| WSL1 | ❌ 不支持 | - |

### 依赖检查

```typescript
// 检查依赖是否可用
SandboxManager.checkDependencies()
// 返回 { errors: string[], warnings: string[] }
// errors 为空才可运行
```

### 启用方式

```json
// settings.json
{
  "sandbox": {
    "enabled": true
  }
}
```

---

## SandboxManager 接口

基于 `src/utils/sandbox/sandbox-adapter.ts` 导出的 `ISandboxManager`：

### 核心方法

```typescript
interface ISandboxManager {
  // 初始化
  initialize(sandboxAskCallback?: SandboxAskCallback): Promise<void>

  // 状态检查
  isSandboxingEnabled(): boolean          // 是否启用
  isSupportedPlatform(): boolean          // 平台是否支持
  isPlatformInEnabledList(): boolean       // 是否在 enabledPlatforms 中
  isSandboxEnabledInSettings(): boolean   // 设置中是否启用
  getSandboxUnavailableReason(): string | undefined  // 不可用原因
  isSandboxRequired(): boolean             // 是否必须沙箱
  areSandboxSettingsLockedByPolicy(): boolean  // 是否被策略锁定

  // Bash 相关
  isAutoAllowBashIfSandboxedEnabled(): boolean
  areUnsandboxedCommandsAllowed(): boolean
  getExcludedCommands(): string[]

  // 配置获取
  getFsReadConfig(): FsReadRestrictionConfig
  getFsWriteConfig(): FsWriteRestrictionConfig
  getNetworkRestrictionConfig(): NetworkRestrictionConfig
  getIgnoreViolations(): IgnoreViolationsConfig | undefined
  getEnableWeakerNestedSandbox(): boolean | undefined
  getAllowUnixSockets(): string[] | undefined
  getAllowLocalBinding(): boolean | undefined
  getProxyPort(): number | undefined
  getSocksProxyPort(): number | undefined
  getLinuxGlobPatternWarnings(): string[]  // Linux glob 警告

  // 网络
  waitForNetworkInitialization(): Promise<boolean>

  // 命令执行
  wrapWithSandbox(command: string, shell?: string, customConfig?: Partial<SandboxRuntimeConfig>, abortSignal?: AbortSignal): Promise<string>
  cleanupAfterCommand(): void

  // 沙箱违规
  getSandboxViolationStore(): SandboxViolationStore
  annotateStderrWithSandboxFailures(command: string, stderr: string): string

  // 设置
  setSandboxSettings(options: {
    enabled?: boolean
    autoAllowBashIfSandboxed?: boolean
    allowUnsandboxedCommands?: boolean
  }): Promise<void>
  refreshConfig(): void
  reset(): Promise<void>
}
```

---

## 配置结构

### SandboxRuntimeConfig

```typescript
interface SandboxRuntimeConfig {
  network: {
    allowedDomains: string[]       // 允许的域名
    deniedDomains: string[]        // 禁止的域名
    allowUnixSockets?: string[]   // 允许的 Unix socket
    allowAllUnixSockets?: boolean
    allowLocalBinding?: boolean   // 允许本地端口绑定
    httpProxyPort?: number        // HTTP 代理端口
    socksProxyPort?: number       // SOCKS 代理端口
  }
  filesystem: {
    denyRead: string[]            // 禁止读取的路径
    allowRead: string[]          // 允许读取的路径
    allowWrite: string[]         // 允许写入的路径
    denyWrite: string[]          // 禁止写入的路径
  }
  ignoreViolations?: Record<string, string[]>  // 忽略的违规
  enableWeakerNestedSandbox?: boolean
  enableWeakerNetworkIsolation?: boolean
  ripgrep: {
    command: string
    args: string[]
    argv0: string
  }
}
```

### 设置到配置的转换

`sandbox-adapter.ts` 中的 `convertToSandboxRuntimeConfig()` 函数：

```typescript
// 自动添加的路径
allowWrite: [
  '.',                                    // 当前目录
  getClaudeTempDir(),                     // Claude 临时目录
  ...additionalDirectories,                 // --add-dir 添加的目录
  worktreeMainRepoPath,                    // Git worktree 主仓库
]

// 自动禁止的路径
denyWrite: [
  ...settingsPaths,                        // 所有 settings.json 文件
  getManagedSettingsDropInDir(),           // Managed 设置目录
  '.claude/skills',                       // Skills 目录
  ...bareGitRepoFiles,                     // Bare git repo 文件
]
```

---

## 权限规则路径解析

### Claude Code 权限规则路径前缀

```typescript
resolvePathPatternForSandbox(pattern, source):
  "//path"  → "/path"           // 绝对路径 (从根) CC 特殊约定
  "/path"   → "$SETTINGS_DIR/path"  // 相对于 settings 文件目录 (CC 特殊约定)
  "~/path"  → 展开 home 目录 (标准)
  "./path"  → 相对路径 (标准)
  "path"    → 相对路径 (标准)
```

**说明**：
- `//path` 和 `/path` 是 Claude Code 权限规则的**特殊约定**
- `/path` 不是绝对路径，而是相对于 settings 文件所在目录
- 标准路径语义 (`~/`, `./`, `path`) 由 sandbox-runtime 处理

### Sandbox filesystem 设置路径语义

`sandbox.filesystem.*` 设置使用**标准路径语义**（与权限规则不同）：

```typescript
resolveSandboxFilesystemPath(pattern, source):
  "/path"   → "/path"           // 绝对路径 (按字面意思)
  "//path"  → "/path"           // 兼容 legacy 权限规则语法
  "~/path"  → 展开 home 目录
  "./path"  → 相对于 settings 目录
  "path"    → 相对于 settings 目录
```

**注意**：修复 #30067 后，`sandbox.filesystem.allowWrite` 中的 `/path` 被视为绝对路径，而非 settings-相对路径。

---

## 安全机制

### 1. Settings 文件保护

```typescript
// 禁止写入任何 settings.json 文件
denyWrite.push(...settingsPaths)

// 包括 managed 设置
denyWrite.push(getManagedSettingsDropInDir())
```

### 2. Skills 保护

```typescript
// .claude/skills 目录被保护
// Skills 有与 commands/agents 相同的权限级别
denyWrite.push(resolve(originalCwd, '.claude', 'skills'))
```

### 3. Git Bare Repo 保护

```typescript
// 防止在沙箱中植入 git 文件夹逃脱
// 安全问题：如果 cwd 存在 HEAD + objects/ + refs/ (bare repo 特征)，
// 攻击者可植入 config + core.fsmonitor 逃逸沙箱

denyWrite.push(...bareGitRepoFiles)
// 包括: HEAD, objects, refs, hooks, config

// 如果不存在则事后清理
scrubBareGitRepoFiles()
// 在 cleanupAfterCommand() 中调用，删除沙箱命令植入的文件
```

**安全机制**：
- 沙箱初始化时检测 bare repo 文件是否存在
- 存在的文件：添加 `denyWrite`（只读绑定）
- 不存在的文件：事后清理 `scrubBareGitRepoFiles()`

### 4. Worktree 支持

```typescript
// 检测 worktree 并允许写入主仓库
detectWorktreeMainRepoPath(cwd):
  // 在 worktree 中，.git 是一个文件，内容为 "gitdir: /path/to/main/repo/.git/worktrees/name"
  // 函数解析此文件获取主仓库路径
  // 缓存结果供整个会话使用

if (worktreeMainRepoPath) {
  allowWrite.push(worktreeMainRepoPath)
  // 允许 worktree 中的 git 操作写入主仓库
}
```

**Worktree 检测机制**：
- 在 `initialize()` 时调用一次并缓存
- 读取 `.git` 文件内容，匹配 `gitdir:` 格式
- 检查是否存在 `.git/worktrees/` 标记确认是 worktree
- 结果存储在 `worktreeMainRepoPath` 变量中

### 5. 配置选项

`sandbox-adapter.ts` 中的配置转换函数 `convertToSandboxRuntimeConfig()`：

```typescript
// 自动添加的路径
allowWrite: [
  '.',                                    // 当前目录
  getClaudeTempDir(),                     // Claude 临时目录
  ...additionalDirectories,               // --add-dir 添加的目录
  worktreeMainRepoPath,                   // Git worktree 主仓库
]

// 自动禁止的路径
denyWrite: [
  ...settingsPaths,                        // 所有 settings.json 文件
  getManagedSettingsDropInDir(),           // Managed 设置目录
  '.claude/skills',                       // Skills 目录
  ...bareGitRepoFiles,                    // Bare git repo 文件
]

// 实验性配置
enableWeakerNestedSandbox?: boolean    // 允许嵌套沙箱
enableWeakerNetworkIsolation?: boolean  // 允许更宽松的网络隔离
```

---

## 企业策略控制

### Managed Domains Only

```typescript
shouldAllowManagedSandboxDomainsOnly()
// 当 policySettings.sandbox.network.allowManagedDomainsOnly: true 时
// 只使用策略设置的域名
```

### Managed Read Paths Only

```typescript
shouldAllowManagedReadPathsOnly()
// 当 policySettings.sandbox.filesystem.allowManagedReadPathsOnly: true 时
// 只使用策略设置的 read 路径
```

### 策略锁定检测

```typescript
areSandboxSettingsLockedByPolicy()
// 检查 flagSettings 或 policySettings 是否设置了沙箱选项
// 如果设置了，localSettings 的沙箱设置将被忽略
```

---

## 生命周期

### 初始化流程

```
┌────────────────────────────────────────────────────────────┐
│                  沙箱初始化流程                              │
├────────────────────────────────────────────────────────────┤
│                                                            │
│  1. isSandboxingEnabled()                                  │
│     ├── 检查平台支持                                        │
│     ├── 检查依赖                                            │
│     └── 检查 enabledPlatforms                              │
│                                                            │
│  2. detectWorktreeMainRepoPath()                           │
│     └── 检测并缓存主仓库路径                                │
│                                                            │
│  3. convertToSandboxRuntimeConfig()                        │
│     └── 转换设置为运行时配置                                │
│                                                            │
│  4. BaseSandboxManager.initialize()                       │
│     └── 调用 sandbox-runtime 初始化                        │
│                                                            │
│  5. settingsChangeDetector.subscribe()                     │
│     └── 订阅设置变更，动态更新配置                          │
│                                                            │
└────────────────────────────────────────────────────────────┘
```

### 命令执行

```typescript
async function wrapWithSandbox(command: string, binShell?: string): Promise<string> {
  // 确保初始化完成
  await initializationPromise

  // 调用 sandbox-runtime 执行
  return BaseSandboxManager.wrapWithSandbox(command, binShell)
}

// 命令后清理
cleanupAfterCommand(): void {
  BaseSandboxManager.cleanupAfterCommand()
  scrubBareGitRepoFiles()  // 清理植入的 git 文件
}
```

### 动态配置更新

```typescript
// 设置变更时自动更新
settingsChangeDetector.subscribe(() => {
  const newConfig = convertToSandboxRuntimeConfig(settings)
  BaseSandboxManager.updateConfig(newConfig)
})

// 手动刷新
refreshConfig(): void {
  const newConfig = convertToSandboxRuntimeConfig(settings)
  BaseSandboxManager.updateConfig(newConfig)
}
```

---

## 命令排除

### 添加排除命令

```typescript
addToExcludedCommands(command: string, permissionUpdates?: PermissionUpdate[]): string {
  // 从 permissionUpdates 中提取 Bash 规则
  // 添加到 sandbox.excludedCommands
}
```

### 排除示例

```json
{
  "sandbox": {
    "excludedCommands": [
      "docker",
      "kubectl",
      "helm"
    ]
  }
}
```

---

## 网络限制

### 域名解析

```typescript
// 从 WebFetch 权限规则中提取域名
if (rule.toolName === "WebFetch" && rule.ruleContent?.startsWith("domain:")) {
  allowedDomains.push(rule.ruleContent.substring("domain:".length))
}
```

### 代理配置

```typescript
// HTTP 代理
httpProxyPort: settings.sandbox?.network?.httpProxyPort

// SOCKS 代理
socksProxyPort: settings.sandbox?.network?.socksProxyPort
```

---

## 违规处理

### 违规存储

```typescript
getSandboxViolationStore(): SandboxViolationStore
// 存储违规事件供查询
```

### 回调机制

```typescript
initialize(sandboxAskCallback?: SandboxAskCallback): Promise<void>

// 回调签名
type SandboxAskCallback = (hostPattern: NetworkHostPattern) => boolean
// 返回 true = 允许, false = 拒绝
```

### 忽略违规

```json
{
  "sandbox": {
    "ignoreViolations": {
      "network": ["*.internal.company.com"]
    }
  }
}
```

---

## 配置示例

### 最小权限配置

```json
{
  "sandbox": {
    "enabled": true,
    "filesystem": {
      "allowWrite": ["./src"],
      "denyWrite": ["/etc", "/root", "/home"]
    },
    "network": {
      "allowedDomains": ["api.github.com"]
    }
  }
}
```

### 企业配置

```json
{
  "sandbox": {
    "enabled": true,
    "network": {
      "allowManagedDomainsOnly": true
    },
    "filesystem": {
      "allowManagedReadPathsOnly": true
    },
    "autoAllowBashIfSandboxed": true,
    "allowUnsandboxedCommands": false
  }
}
```

### macOS 配置

```json
{
  "sandbox": {
    "enabled": true,
    "enabledPlatforms": ["macos"],
    "network": {
      "allowUnixSockets": ["/var/run/docker.sock"],
      "allowAllUnixSockets": false
    }
  }
}
```

---

## 最佳实践

### 1. 明确启用平台

```json
{
  "sandbox": {
    "enabled": true,
    "enabledPlatforms": ["macos", "linux"]
  }
}
```

### 2. 限制写入路径

```json
{
  "sandbox": {
    "enabled": true,
    "filesystem": {
      "allowWrite": ["./src", "./tests", "./scripts"]
    }
  }
}
```

### 3. 使用代理进行日志

```json
{
  "sandbox": {
    "enabled": true,
    "network": {
      "httpProxyPort": 8080
    }
  }
}
```

---

## 故障排除

### 沙箱初始化失败

```bash
# 检查不可用原因
node -e "console.log(SandboxManager.getSandboxUnavailableReason())"
```

### 依赖缺失

```bash
# macOS: 依赖已内置
# Linux: 需要安装
apt install bubblewrap socat
```

### 路径问题

```typescript
// 检查 glob 模式警告 (Linux/WSL)
SandboxManager.getLinuxGlobPatternWarnings()
// Linux 上的 bubblewrap 不完全支持 glob
```

---

## 与 Permissions 的关系

| 维度 | Sandbox | Permissions |
|------|---------|-------------|
| 层级 | OS 级别 | 应用级别 |
| 粒度 | 目录级别 | 工具/命令级别 |
| 技术 | namespace/container | Zod schema |
| 绕过 | 禁用/排除命令 | 权限规则 |

**推荐**：同时使用 Sandbox 和 Permissions 实现纵深防御。

---

## 测试验证

```bash
# 检查平台支持
node -e "console.log(SandboxManager.isSupportedPlatform())"

# 检查依赖
node -e "console.log(SandboxManager.checkDependencies())"

# 检查启用状态
node -e "console.log(SandboxManager.isSandboxingEnabled())"
```
