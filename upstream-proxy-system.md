# UpstreamProxy 系统

> 基于源码 `src/upstreamproxy/` 完整分析

---

## 概述

UpstreamProxy 是 CCR（Cloud Code Remote）容器端的 MITM（中间人）代理系统，用于流量检查和凭证注入。

**整个系统完全未在用户文档中记录。**

---

## 系统架构

```
用户进程 → Claude Code → UpstreamProxy → CCR 容器 → 外部服务
                         ↓
                    MITM 流量检查
                    凭证注入
                    CA 证书处理
```

---

## 环境变量

| 变量 | 说明 | 必需 |
|------|------|------|
| `CLAUDE_CODE_REMOTE` | 启用 UpstreamProxy | 是 |
| `CCR_UPSTREAM_PROXY_ENABLED` | GrowthBook 功能开关 | 否 |
| `CLAUDE_CODE_REMOTE_SESSION_ID` | 会话 ID（令牌路径） | 是 |
| `ANTHROPIC_BASE_URL` | API 基础 URL 覆盖 | 否 |

---

## NO_PROXY 列表

以下域名/地址**不会**通过 UpstreamProxy：

```typescript
const NO_PROXY_LIST = [
  // 本地地址
  'localhost', '127.0.0.1', '::1',
  '169.254.0.0/16', '10.0.0.0/8', '172.16.0.0/12', '192.168.0.0/16',

  // Anthropic 服务
  'anthropic.com', '.anthropic.com', '*.anthropic.com',

  // GitHub
  'github.com', 'api.github.com', '*.github.com', '*.githubusercontent.com',

  // 包管理器
  'registry.npmjs.org', 'pypi.org', 'files.pythonhosted.org',
  'index.crates.io', 'proxy.golang.org'
]
```

---

## 安全特性

### prctl 安全

```typescript
prctl(PR_SET_DUMPABLE, 0)
```

阻止 ptrace 附加到进程，增强安全性。

### 令牌获取

从容器文件系统读取会话令牌：

```
/run/ccr/session_token
```

### CA 证书处理

1. 下载 CCR CA 证书
2. 与系统证书包合并
3. 用于 MITM HTTPS 解密

---

## API 端点

### 获取 CA 证书

```
GET /v1/code/upstreamproxy/ca-cert
```

返回 MITM CA 证书供客户端使用。

### WebSocket 中继

```
WebSocket /v1/code/upstreamproxy/ws
```

建立 CONNECT 到 WebSocket 的隧道。

---

## Protobuf 编码

UpstreamProxy 使用 Protobuf 编码的消息：

```typescript
// 消息格式
wire format: tag=0x0a, varint length, then bytes
```

### UpstreamProxyChunk

```protobuf
message UpstreamProxyChunk {
  // 消息内容
}
```

---

## 工作流程

### 1. 初始化

```typescript
// 检测是否需要启用
if (process.env.CLAUDE_CODE_REMOTE) {
  initUpstreamProxy()
}
```

### 2. 令牌获取

```typescript
// 从文件读取会话令牌
const token = readFileSync('/run/ccr/session_token', 'utf-8')
```

### 3. CA 证书下载

```typescript
// 下载并合并 CA 证书
const caCert = await downloadCACert()
const mergedCert = mergeWithSystemCerts(caCert)
```

### 4. 代理启动

```typescript
// 启动 CONNECT 到 WebSocket 中继
startRelay({
  port: UPSTREAM_PROXY_PORT,
  token,
  caCert: mergedCert
})
```

### 5. 环境变量设置

```typescript
// 设置代理环境变量
process.env.HTTPS_PROXY = `http://localhost:${UPSTREAM_PROXY_PORT}`
process.env.http_proxy = `http://localhost:${UPSTREAM_PROXY_PORT}`
```

---

## 使用场景

### 凭证注入

当需要向外部请求注入认证凭证时使用。例如：
- API 请求添加 Bearer token
- OAuth 令牌刷新

### MITM 流量检查

对通过代理的 HTTPS 流量进行解密检查，用于：
- 安全审计
- 调试
- 性能监控

---

## 与 Claude Code 集成

UpstreamProxy 在 Claude Code 初始化时启动：

```typescript
// src/init.ts
if (process.env.CLAUDE_CODE_REMOTE) {
  await initUpstreamProxy()
}
```

---

## 故障排查

### 检查 UpstreamProxy 状态

```bash
# 查看代理端口
echo $HTTPS_PROXY

# 检查证书
ls /run/ccr/
```

### 禁用 UpstreamProxy

目前没有用户可控制的禁用开关。如果不需要 MITM 功能，确保不设置 `CLAUDE_CODE_REMOTE` 环境变量。

---

## GrowthBook Feature

| Feature | 说明 |
|---------|------|
| `CCR_UPSTREAM_PROXY_ENABLED` | 控制是否启用 UpstreamProxy |

---

## 安全注意事项

1. **CA 证书合并**: 合并自定义 CA 可能影响 TLS 验证
2. **MITM 解密**: HTTPS 流量被解密，请勿在生产环境滥用
3. **令牌存储**: 会话令牌存储在容器文件系统中，注意权限控制
