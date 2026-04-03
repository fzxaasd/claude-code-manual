# UpstreamProxy System

> Complete analysis based on source code `src/upstreamproxy/`

---

## Overview

UpstreamProxy is a MITM (Man-in-the-Middle) proxy system on the CCR (Cloud Code Remote) container side, used for traffic inspection and credential injection.

**This entire system is completely undocumented in user documentation.**

---

## System Architecture

```
User Process → Claude Code → UpstreamProxy → CCR Container → External Service
                         ↓
                    MITM Traffic Inspection
                    Credential Injection
                    CA Certificate Handling
```

---

## Environment Variables

| Variable | Description | Required |
|----------|-------------|----------|
| `CLAUDE_CODE_REMOTE` | Enable UpstreamProxy | Yes |
| `CCR_UPSTREAM_PROXY_ENABLED` | GrowthBook feature flag | No |
| `CLAUDE_CODE_REMOTE_SESSION_ID` | Session ID (token path) | Yes |
| `ANTHROPIC_BASE_URL` | API base URL override | No |

---

## NO_PROXY List

The following domains/addresses will **NOT** go through UpstreamProxy:

```typescript
const NO_PROXY_LIST = [
  // Local addresses
  'localhost', '127.0.0.1', '::1',
  '169.254.0.0/16', '10.0.0.0/8', '172.16.0.0/12', '192.168.0.0/16',

  // Anthropic services
  'anthropic.com', '.anthropic.com', '*.anthropic.com',

  // GitHub
  'github.com', 'api.github.com', '*.github.com', '*.githubusercontent.com',

  // Package managers
  'registry.npmjs.org', 'pypi.org', 'files.pythonhosted.org',
  'index.crates.io', 'proxy.golang.org'
]
```

---

## Security Features

### prctl Security

```typescript
prctl(PR_SET_DUMPABLE, 0)
```

Prevents ptrace attachment to the process, enhancing security.

### Token Acquisition

Read session token from container filesystem:

```
/run/ccr/session_token
```

### CA Certificate Handling

1. Download CCR CA certificate
2. Merge with system certificate bundle
3. Used for MITM HTTPS decryption

---

## API Endpoints

### Get CA Certificate

```
GET /v1/code/upstreamproxy/ca-cert
```

Returns MITM CA certificate for client use.

### WebSocket Relay

```
WebSocket /v1/code/upstreamproxy/ws
```

Establishes CONNECT to WebSocket tunnel.

---

## Protobuf Encoding

UpstreamProxy uses Protobuf-encoded messages:

```typescript
// Message format
wire format: tag=0x0a, varint length, then bytes
```

### UpstreamProxyChunk

```protobuf
message UpstreamProxyChunk {
  // Message content
}
```

---

## Workflow

### 1. Initialization

```typescript
// Detect if UpstreamProxy needs to be enabled
if (process.env.CLAUDE_CODE_REMOTE) {
  initUpstreamProxy()
}
```

### 2. Token Acquisition

```typescript
// Read session token from file
const token = readFileSync('/run/ccr/session_token', 'utf-8')
```

### 3. CA Certificate Download

```typescript
// Download and merge CA certificate
const caCert = await downloadCACert()
const mergedCert = mergeWithSystemCerts(caCert)
```

### 4. Proxy Startup

```typescript
// Start CONNECT to WebSocket relay
startRelay({
  port: UPSTREAM_PROXY_PORT,
  token,
  caCert: mergedCert
})
```

### 5. Environment Variable Setup

```typescript
// Set proxy environment variables
process.env.HTTPS_PROXY = `http://localhost:${UPSTREAM_PROXY_PORT}`
process.env.http_proxy = `http://localhost:${UPSTREAM_PROXY_PORT}`
```

---

## Use Cases

### Credential Injection

Used when injecting authentication credentials into external requests. For example:
- Adding Bearer token to API requests
- OAuth token refresh

### MITM Traffic Inspection

Decrypt HTTPS traffic passing through the proxy for:
- Security auditing
- Debugging
- Performance monitoring

---

## Integration with Claude Code

UpstreamProxy starts during Claude Code initialization:

```typescript
// src/init.ts
if (process.env.CLAUDE_CODE_REMOTE) {
  await initUpstreamProxy()
}
```

---

## Troubleshooting

### Check UpstreamProxy Status

```bash
# Check proxy port
echo $HTTPS_PROXY

# Check certificates
ls /run/ccr/
```

### Disable UpstreamProxy

There is currently no user-controllable disable switch. If MITM functionality is not needed, ensure the `CLAUDE_CODE_REMOTE` environment variable is not set.

---

## GrowthBook Feature

| Feature | Description |
|---------|-------------|
| `CCR_UPSTREAM_PROXY_ENABLED` | Controls whether UpstreamProxy is enabled |

---

## Security Considerations

1. **CA Certificate Merging**: Merging custom CA may affect TLS verification
2. **MITM Decryption**: HTTPS traffic is decrypted; do not abuse in production
3. **Token Storage**: Session tokens are stored in container filesystem; mind permission controls
