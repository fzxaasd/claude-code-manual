# 7.8 Bridge/Remote System

> Claude Code 的跨 IDE 集成与远程会话机制

## 概述

Bridge 系统是 Claude Code 与外部 IDE（VS Code、JetBrains 等）集成的核心机制，同时支持远程会话连接。源码位于 `src/bridge/` 目录。

```
┌────────────────────────────────────────────────────────────┐
│                   Bridge 系统架构                           │
├────────────────────────────────────────────────────────────┤
│                                                            │
│  Claude Code (主会话)                                      │
│       │                                                    │
│       ├── Bridge API ─────────── VS Code Extension        │
│       ├── Remote Bridge ──────── 远程 SSH 会话             │
│       └── Bridge Messaging ───── 跨进程通信                │
│                                                            │
└────────────────────────────────────────────────────────────┘
```

---

## 核心组件

### Bridge 类型定义

基于 `src/bridge/types.ts`：

```typescript
interface BridgeConfig {
  enabled: boolean
  host: string
  port: number
  sessionId: string
  authToken: string
}

interface BridgeSession {
  id: string
  type: 'vscode' | 'jetbrains' | 'remote' | 'web'
  status: 'connecting' | 'connected' | 'disconnected'
  lastActivity: number
}
```

### 文件清单

| 文件 | 功能 |
|------|------|
| `bridgeMain.ts` | 主入口，初始化 Bridge 服务 |
| `bridgeApi.ts` | Bridge API 定义 |
| `bridgeConfig.ts` | Bridge 配置管理 |
| `bridgeEnabled.ts` | Bridge 功能开关检查 |
| `bridgeMessaging.ts` | Bridge 消息协议 |
| `bridgePermissionCallbacks.ts` | Bridge 权限回调 |
| `bridgePointer.ts` | Bridge 指针操作 |
| `bridgeStatusUtil.ts` | Bridge 状态工具 |
| `bridgeUI.ts` | Bridge UI 组件 |
| `initReplBridge.ts` | REPL Bridge 初始化 |
| `remoteBridgeCore.ts` | 远程 Bridge 核心逻辑 |
| `replBridge.ts` | REPL Bridge 实现 |
| `replBridgeTransport.ts` | REPL Bridge 传输层 |
| `codeSessionApi.ts` | 代码会话 API |
| `createSession.ts` | 会话创建 |
| `jwtUtils.ts` | JWT 认证工具 |
| `sessionRunner.ts` | 会话运行器 |
| `trustedDevice.ts` | 信任设备管理 |
| `workSecret.ts` | 工作密钥 |

---

## VS Code 集成

### VS Code Extension 接口

```typescript
interface VSCodeBridgeAPI {
  // 发送消息到 Claude Code
  sendMessage(message: BridgeMessage): Promise<void>

  // 注册消息处理器
  onMessage(handler: (message: BridgeMessage) => void): void

  // 获取当前会话状态
  getSessionStatus(): Promise<BridgeSession>

  // 执行工具调用
  executeTool(tool: string, input: object): Promise<ToolResult>
}
```

### 消息协议

```typescript
interface BridgeMessage {
  type: 'tool_request' | 'tool_response' | 'permission_request' | 'permission_response'
  sessionId: string
  payload: unknown
  timestamp: number
}
```

### 权限回调

基于 `bridgePermissionCallbacks.ts`：

```typescript
// Bridge 权限回调接口
interface BridgePermissionCallback {
  onPermissionRequest(request: PermissionRequest): Promise<PermissionResponse>
  onToolExecution(tool: string, input: object): Promise<ToolResult>
}
```

---

## Remote Bridge

### 远程连接配置

基于 `remoteBridgeCore.ts`：

```typescript
interface RemoteBridgeConfig {
  remoteHost: string
  remotePort: number
  useSSH: boolean
  sshKeyPath?: string
  username?: string
}
```

### 连接流程

```
1. 建立 SSH 隧道（如果需要）
    ↓
2. 连接到 Remote Bridge 服务
    ↓
3. 交换 JWT 认证令牌
    ↓
4. 创建 Bridge 会话
    ↓
5. 同步状态和上下文
```

### JWT 认证

基于 `jwtUtils.ts`：

```typescript
interface WorkSecret {
  secret: string
  expiresAt: number
  sessionId: string
}

// 生成工作密钥
function generateWorkSecret(sessionId: string): WorkSecret

// 验证工作密钥
function verifyWorkSecret(secret: string): boolean
```

---

## Bridge Messaging

### 消息类型

基于 `bridgeMessaging.ts`：

| 消息类型 | 说明 |
|----------|------|
| `handshake` | 建立连接握手 |
| `heartbeat` | 心跳保活 |
| `tool_request` | 工具调用请求 |
| `tool_response` | 工具调用响应 |
| `permission_request` | 权限请求 |
| `permission_response` | 权限响应 |
| `sync_state` | 状态同步 |
| `error` | 错误消息 |

### 消息格式

```typescript
interface BridgeMessage {
  id: string              // 唯一消息 ID
  type: BridgeMessageType  // 消息类型
  from: string            // 发送方 ID
  to: string              // 接收方 ID
  payload: unknown        // 消息内容
  timestamp: number       // 时间戳
  sequence: number        // 序列号（用于排序）
}
```

---

## 状态管理

### Bridge 状态

基于 `bridgeStatusUtil.ts`：

```typescript
type BridgeStatus = 'disconnected' | 'connecting' | 'connected' | 'error'

interface BridgeStatusInfo {
  status: BridgeStatus
  lastConnected?: number
  error?: string
  retryCount: number
}
```

### 状态转换

```
disconnected ──[connect()]──> connecting
     ↑                              │
     │                    [success] ↓
     │                   connected
     │                              │
     │                    [error/timeout]
     │                              ↓
     └────────────<─────── error ────┘
     │
     └──[disconnect()]──> disconnected
```

---

## 配置选项

### settings.json 配置

```json
{
  "bridge": {
    "enabled": true,
    "autoConnect": true,
    "preferredIde": "vscode"
  }
}
```

### 环境变量

| 变量 | 说明 |
|------|------|
| `CLAUDE_BRIDGE_ENABLED` | 启用 Bridge |
| `CLAUDE_BRIDGE_PORT` | Bridge 端口 |
| `CLAUDE_REMOTE_HOST` | 远程主机 |
| `CLAUDE_REMOTE_PORT` | 远程端口 |

---

## 代码会话 API

基于 `codeSessionApi.ts`：

```typescript
interface CodeSession {
  id: string
  language: string
  file?: string
  context: {
    workingDirectory: string
    openFiles: string[]
    cursorPosition?: { line: number; column: number }
  }
}

// 创建代码会话
async function createCodeSession(config: CodeSessionConfig): Promise<CodeSession>

// 更新会话上下文
async function updateSessionContext(sessionId: string, context: Partial<CodeSession['context']>): Promise<void>

// 销毁会话
async function destroyCodeSession(sessionId: string): Promise<void>
```

---

## 信任设备管理

基于 `trustedDevice.ts`：

```typescript
interface TrustedDevice {
  deviceId: string
  deviceName: string
  addedAt: number
  lastUsed?: number
  publicKey: string
}

// 注册信任设备
async function registerTrustedDevice(device: TrustedDevice): Promise<void>

// 列出信任设备
async function listTrustedDevices(): Promise<TrustedDevice[]>

// 移除信任设备
async function removeTrustedDevice(deviceId: string): Promise<void>
```

---

## 故障排除

### 无法连接 Bridge

```bash
# 检查 Bridge 是否启用
echo $CLAUDE_BRIDGE_ENABLED

# 检查端口占用
lsof -i :$CLAUDE_BRIDGE_PORT

# 查看 Bridge 日志
claude bridge debug
```

### Remote 连接失败

```bash
# 验证 SSH 配置
ssh -v user@remote-host

# 检查远程端口
nc -zv remote-host $CLAUDE_REMOTE_PORT

# 测试 JWT 认证
claude bridge auth --test
```

### IDE 扩展问题

```bash
# VS Code
# 1. 重新安装扩展
code --install-extension anthropic.claude-code

# 2. 检查扩展日志
# View > Output > Claude Code

# JetBrains
# 1. 重启 IDE
# 2. 检查插件设置
```

---

## 最佳实践

### 安全建议

1. **使用 SSH 隧道**：远程连接始终使用 SSH 隧道加密
2. **定期轮换密钥**：定期更新 Work Secret
3. **设备信任**：仅信任已知设备
4. **会话超时**：设置合理的会话超时时间

### 性能优化

1. **减少消息频率**：批量处理工具调用
2. **使用压缩**：大消息启用压缩
3. **连接复用**：保持长连接避免频繁建立

---

## 测试验证

```bash
# 检查 Bridge 状态
claude bridge status

# 启动 Bridge 服务
claude bridge start

# 连接测试
claude bridge connect --ide vscode

# 远程连接测试
claude bridge connect --remote user@host
```
