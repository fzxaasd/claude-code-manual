# 7.6 Sandbox

> Deep analysis based on source code `src/utils/sandbox/sandbox-adapter.ts`

## Core Concepts

Sandbox uses the `@anthropic-ai/sandbox-runtime` package to provide OS-level isolated execution environment for safely running Bash commands and restricting file/network access.

```
┌────────────────────────────────────────────────────────────┐
│                   Sandbox Architecture                      │
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

## Enable Conditions

### Platform Support

| Platform | Support Status | Technology |
|------|----------|------|
| macOS | ✅ Fully supported | SandboxKit |
| Linux | ✅ Fully supported | Bubblewrap |
| WSL2 | ✅ Supported | Linux namespace |
| WSL1 | ❌ Not supported | - |

### Dependency Check

```typescript
// Check if dependencies are available
SandboxManager.checkDependencies()
// Returns { errors: string[], warnings: string[] }
// Can only run if errors is empty
```

### Enable Method

```json
// settings.json
{
  "sandbox": {
    "enabled": true
  }
}
```

---

## SandboxManager Interface

Based on `ISandboxManager` exported from `src/utils/sandbox/sandbox-adapter.ts`:

### Core Methods

```typescript
interface ISandboxManager {
  // Initialization
  initialize(sandboxAskCallback?: SandboxAskCallback): Promise<void>

  // Status checks
  isSandboxingEnabled(): boolean          // Whether enabled
  isSupportedPlatform(): boolean          // Whether platform supported
  isPlatformInEnabledList(): boolean       // Whether in enabledPlatforms
  isSandboxEnabledInSettings(): boolean   // Whether enabled in settings
  getSandboxUnavailableReason(): string | undefined  // Reason if unavailable
  isSandboxRequired(): boolean             // Whether sandbox is required
  areSandboxSettingsLockedByPolicy(): boolean  // Whether locked by policy

  // Bash related
  isAutoAllowBashIfSandboxedEnabled(): boolean
  areUnsandboxedCommandsAllowed(): boolean
  getExcludedCommands(): string[]

  // Configuration getters
  getFsReadConfig(): FsReadRestrictionConfig
  getFsWriteConfig(): FsWriteRestrictionConfig
  getNetworkRestrictionConfig(): NetworkRestrictionConfig
  getIgnoreViolations(): IgnoreViolationsConfig | undefined
  getEnableWeakerNestedSandbox(): boolean | undefined
  getAllowUnixSockets(): string[] | undefined
  getAllowLocalBinding(): boolean | undefined
  getProxyPort(): number | undefined
  getSocksProxyPort(): number | undefined
  getLinuxGlobPatternWarnings(): string[]  // Linux glob warnings
  checkDependencies(): { errors: string[], warnings: string[] }  // Dependency check
  getLinuxHttpSocketPath(): string | undefined  // Linux HTTP socket path
  getLinuxSocksSocketPath(): string | undefined  // Linux SOCKS socket path

  // Network
  waitForNetworkInitialization(): Promise<boolean>

  // Command execution
  wrapWithSandbox(command: string, binShell?: string, customConfig?: Partial<SandboxRuntimeConfig>, abortSignal?: AbortSignal): Promise<string>
  cleanupAfterCommand(): void

  // Sandbox violations
  getSandboxViolationStore(): SandboxViolationStore
  annotateStderrWithSandboxFailures(command: string, stderr: string): string

  // Settings
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

## Configuration Structure

### SandboxRuntimeConfig

```typescript
interface SandboxRuntimeConfig {
  network: {
    allowedDomains: string[]       // Allowed domains
    deniedDomains: string[]        // Denied domains
    allowUnixSockets?: string[]   // Allowed Unix sockets
    allowAllUnixSockets?: boolean
    allowLocalBinding?: boolean   // Allow local port binding
    httpProxyPort?: number        // HTTP proxy port
    socksProxyPort?: number       // SOCKS proxy port
  }
  filesystem: {
    denyRead: string[]            // Denied read paths
    allowRead: string[]          // Allowed read paths
    allowWrite: string[]         // Allowed write paths
    denyWrite: string[]          // Denied write paths
  }
  ignoreViolations?: Record<string, string[]>  // Ignored violations
  enableWeakerNestedSandbox?: boolean
  enableWeakerNetworkIsolation?: boolean
  ripgrep: {
    command: string
    args: string[]  // optional
  }
}
```

**Note**: `ripgrep` is configurable, allowing custom ripgrep command path and args. `argv0` is internal behavior, not a user-configurable field.

### Settings to Config Conversion

`convertToSandboxRuntimeConfig()` function in `sandbox-adapter.ts`:

```typescript
// Auto-added paths
allowWrite: [
  '.',                                    // Current directory
  getClaudeTempDir(),                     // Claude temp directory
  ...additionalDirectories,                 // --add-dir added directories
  worktreeMainRepoPath,                    // Git worktree main repo
]

// Auto-denied paths
denyWrite: [
  ...settingsPaths,                        // All settings.json files
  getManagedSettingsDropInDir(),           // Managed settings directory
  '.claude/skills',                       // Skills directory
  ...bareGitRepoFiles,                     // Bare git repo files
]
```

---

## Permission Rule Path Resolution

### Claude Code Permission Rule Path Prefixes

```typescript
resolvePathPatternForSandbox(pattern, source):
  "//path"  → "/path"           // Absolute path (from root) CC special convention
  "/path"   → "$SETTINGS_DIR/path"  // Relative to settings file directory (CC special convention)
  "~/path"  →  expand home directory (standard)
  "./path"  →  relative path (standard)
  "path"    →  relative path (standard)
```

**Explanation**:
- `//path` and `/path` are **special conventions** for Claude Code permission rules
- `/path` is not an absolute path, but relative to the settings file directory
- Standard path semantics (`~/`, `./`, `path`) are handled by sandbox-runtime

### Sandbox Filesystem Settings Path Semantics

`sandbox.filesystem.*` settings use **standard path semantics** (different from permission rules):

```typescript
resolveSandboxFilesystemPath(pattern, source):
  "/path"   → "/path"           // Absolute path (literal)
  "//path"  → "/path"           // Compatible with legacy permission rule syntax
  "~/path"  →  expand home directory
  "./path"  →  relative to settings directory
  "path"    →  relative to settings directory
```

**Note**: After fix #30067, `/path` in `sandbox.filesystem.allowWrite` is treated as absolute path, not settings-relative path.

---

## Security Mechanisms

### 1. Settings File Protection

```typescript
// Deny writing to any settings.json file
denyWrite.push(...settingsPaths)

// Including managed settings
denyWrite.push(getManagedSettingsDropInDir())

// Also deny writing to settings in current working directory if cwd differs from original
if (cwd !== originalCwd) {
  denyWrite.push(resolve(cwd, '.claude', 'settings.json'))
  denyWrite.push(resolve(cwd, '.claude', 'settings.local.json'))
}
```

### 2. Skills Protection

```typescript
// .claude/skills directory is protected
// Skills have the same permission level as commands/agents
denyWrite.push(resolve(originalCwd, '.claude', 'skills'))
```

### 3. Git Bare Repo Protection

```typescript
// Prevent escaping sandbox by planting git folder in cwd
// Security issue: If cwd contains HEAD + objects/ + refs/ (bare repo signatures),
// attacker could plant config + core.fsmonitor to escape sandbox

denyWrite.push(...bareGitRepoFiles)
// Includes: HEAD, objects, refs, hooks, config

// If files don't exist, clean up after the fact
scrubBareGitRepoFiles()
// Called in cleanupAfterCommand(), deletes sandbox-planted files
```

**Security mechanism**:
- At sandbox initialization, detect if bare repo files exist
- Existing files: add `denyWrite` (read-only bind)
- Non-existing files: post-cleanup `scrubBareGitRepoFiles()`

### 4. Worktree Support

```typescript
// Detect worktree and allow writing to main repo
detectWorktreeMainRepoPath(cwd):
  // In worktree, .git is a file containing "gitdir: /path/to/main/repo/.git/worktrees/name"
  // Function parses this file to get main repo path
  // Results cached for entire session

if (worktreeMainRepoPath) {
  allowWrite.push(worktreeMainRepoPath)
  // Allow git operations in worktree to write to main repo
}
```

**Worktree Detection Mechanism**:
- Called once during `initialize()` and cached
- Read `.git` file content, match `gitdir:` format
- Check for `.git/worktrees/` marker to confirm worktree
- Results stored in `worktreeMainRepoPath` variable

### 5. Configuration Options

Configuration conversion function `convertToSandboxRuntimeConfig()` in `sandbox-adapter.ts`:

```typescript
// Auto-added paths
allowWrite: [
  '.',                                    // Current directory
  getClaudeTempDir(),                     // Claude temp directory
  ...additionalDirectories,               // --add-dir added directories
  worktreeMainRepoPath,                   // Git worktree main repo
]

// Auto-denied paths
denyWrite: [
  ...settingsPaths,                        // All settings.json files
  getManagedSettingsDropInDir(),           // Managed settings directory
  '.claude/skills',                       // Skills directory
  ...bareGitRepoFiles,                    // Bare git repo files
]

// Experimental configurations
enableWeakerNestedSandbox?: boolean    // Allow nested sandbox
enableWeakerNetworkIsolation?: boolean  // Allow weaker network isolation
```

---

## Enterprise Policy Control

### Managed Domains Only

```typescript
shouldAllowManagedSandboxDomainsOnly()
// When policySettings.sandbox.network.allowManagedDomainsOnly: true
// Only use policy-configured domains
```

### Managed Read Paths Only

```typescript
shouldAllowManagedReadPathsOnly()
// When policySettings.sandbox.filesystem.allowManagedReadPathsOnly: true
// Only use policy-configured read paths
```

### Policy Lock Detection

```typescript
areSandboxSettingsLockedByPolicy()
// Check if sandbox options are set in flagSettings or policySettings
// If set, localSettings sandbox settings will be ignored
```

---

## Lifecycle

### Initialization Flow

```
┌────────────────────────────────────────────────────────────┐
│                  Sandbox Initialization Flow                │
├────────────────────────────────────────────────────────────┤
│                                                            │
│  1. isSandboxingEnabled()                                  │
│     ├── Check platform support                              │
│     ├── Check dependencies                                  │
│     └── Check enabledPlatforms                              │
│                                                            │
│  2. detectWorktreeMainRepoPath()                           │
│     └── Detect and cache main repo path                    │
│                                                            │
│  3. convertToSandboxRuntimeConfig()                        │
│     └── Convert settings to runtime config                 │
│                                                            │
│  4. BaseSandboxManager.initialize()                        │
│     └── Call sandbox-runtime to initialize                 │
│                                                            │
│  5. settingsChangeDetector.subscribe()                     │
│     └── Subscribe to settings changes, dynamically update │
│                                                            │
└────────────────────────────────────────────────────────────┘
```

### Command Execution

```typescript
async function wrapWithSandbox(command: string, binShell?: string): Promise<string> {
  // Ensure initialization is complete
  await initializationPromise

  // Call sandbox-runtime to execute
  return BaseSandboxManager.wrapWithSandbox(command, binShell)
}

// Cleanup after command
cleanupAfterCommand(): void {
  BaseSandboxManager.cleanupAfterCommand()
  scrubBareGitRepoFiles()  // Clean up planted git files
}
```

### Dynamic Config Updates

```typescript
// Auto-update on settings change
settingsChangeDetector.subscribe(() => {
  const newConfig = convertToSandboxRuntimeConfig(settings)
  BaseSandboxManager.updateConfig(newConfig)
})

// Manual refresh
refreshConfig(): void {
  const newConfig = convertToSandboxRuntimeConfig(settings)
  BaseSandboxManager.updateConfig(newConfig)
}
```

---

## Command Exclusion

### Add Excluded Commands

```typescript
addToExcludedCommands(command: string, permissionUpdates?: PermissionUpdate[]): string {
  // Extract Bash rules from permissionUpdates
  // Add to sandbox.excludedCommands
}
```

### failIfUnavailable

Controls behavior when sandbox fails to start:

```json
{
  "sandbox": {
    "enabled": true,
    "failIfUnavailable": true  // Exit on failure, default is false (warn only)
  }
}
```

**Purpose**: Enforce sandboxing as a hard gate in managed deployments. When `enabled=true` but sandbox can't start, CLI exits with error instead of just warning.

### enabledPlatforms

Restrict sandbox to specific platforms:

```json
{
  "sandbox": {
    "enabled": true,
    "enabledPlatforms": ["macos"]  // Only enable sandbox on macOS
  }
}
```

**Purpose**: Gradual rollout for enterprise deployments, e.g., NVIDIA enabling `autoAllowBashIfSandboxed` only on macOS first.

### Exclusion Examples

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

## Network Restrictions

### Domain Resolution

```typescript
// Extract domains from WebFetch permission rules
if (rule.toolName === "WebFetch" && rule.ruleContent?.startsWith("domain:")) {
  allowedDomains.push(rule.ruleContent.substring("domain:".length))
}
```

### Proxy Configuration

```typescript
// HTTP proxy
httpProxyPort: settings.sandbox?.network?.httpProxyPort

// SOCKS proxy
socksProxyPort: settings.sandbox?.network?.socksProxyPort
```

---

## Violation Handling

### Violation Storage

```typescript
getSandboxViolationStore(): SandboxViolationStore
// Store violation events for querying
```

### Callback Mechanism

```typescript
initialize(sandboxAskCallback?: SandboxAskCallback): Promise<void>

// Callback signature
type SandboxAskCallback = (hostPattern: NetworkHostPattern) => boolean
// Return true = allow, false = deny
```

### Ignore Violations

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

## Configuration Examples

### Least Privilege Configuration

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

### Enterprise Configuration

```json
{
  "sandbox": {
    "enabled": true,
    "failIfUnavailable": true,
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

**Security note**: `autoAllowBashIfSandboxed` **defaults to `true`**. When sandbox is enabled, commands are auto-allowed by default (protected by sandbox), and ask rules are skipped.

### macOS Configuration

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

## Best Practices

### 1. Explicitly Enable Platforms

```json
{
  "sandbox": {
    "enabled": true,
    "enabledPlatforms": ["macos", "linux"]
  }
}
```

### 2. Restrict Write Paths

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

### 3. Use Proxy for Logging

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

## Troubleshooting

### Sandbox Initialization Failure

```bash
# Check unavailability reason
node -e "console.log(SandboxManager.getSandboxUnavailableReason())"
```

### Missing Dependencies

```bash
# macOS: Dependencies are built-in
# Linux: Need to install
apt install bubblewrap socat
```

### Path Issues

```typescript
// Check glob pattern warnings (Linux/WSL)
SandboxManager.getLinuxGlobPatternWarnings()
// Linux bubblewrap does not fully support glob
```

---

## Relationship with Permissions

| Dimension | Sandbox | Permissions |
|------|---------|-------------|
| Layer | OS level | Application level |
| Granularity | Directory level | Tool/command level |
| Technology | namespace/container | Zod schema |
| Bypass | Disable/exclude commands | Permission rules |

**permissions.additionalDirectories integration**: `permissions.additionalDirectories` values affect both the permission verification path scope AND sandbox's `allowWrite` paths.

**dangerouslyDisableSandbox interaction**:
- When `allowUnsandboxedCommands: false`, `dangerouslyDisableSandbox` parameter is completely ignored
- All commands must run in sandbox or be excluded via `excludedCommands`
- When `autoAllowBashIfSandboxed: true`, sandboxed commands skip ask rules automatically, but non-sandboxed commands (like excludedCommands or dangerouslyDisableSandbox) still obey ask rules

**Recommendation**: Use both Sandbox and Permissions together for defense in depth.

---

## Undocumented Features

### enabledPlatforms Configuration

`enabledPlatforms` is an **undocumented enterprise configuration option** for NVIDIA enterprise deployments:

```json
{
  "sandbox": {
    "enabled": true,
    "enabledPlatforms": ["macos"]  // Enable sandbox only on macOS
  }
}
```

### Sandbox Internal Environment Variables

The following environment variables are automatically set inside sandbox:

| Variable | Description |
|----------|-------------|
| `TMPDIR` | Temporary directory |
| `CLAUDE_CODE_TMPDIR` | Claude Code dedicated temp directory |
| `TMPPREFIX` | Temporary file prefix |

### Ant User Danger Commands

Ant users (`USER_TYPE === 'ant'`) have special danger command list:
- `fa run`, `coo`, `gh`, `gh api`
- `curl`, `wget`, `git`, `kubectl`
- `aws`, `gcloud`, `gsutil`

### PowerShell Danger Detection

Complete PowerShell danger command pattern list including:
- `iex`, `invoke-expression`, `start-process`
- `register-wmievent`
- .exe suffix variants

### Windows Path Pattern Detection

NTFS special path patterns:
- ADS (Alternate Data Streams)
- 8.3 short filenames
- Long path prefixes (`\\?\`, `\\.\`)
- Trailing dots and spaces
- DOS device names
- Three or more consecutive dots

### Unix Socket Configuration

`allowUnixSockets` is **macOS only** (seccomp cannot filter by path on Linux).

`enableWeakerNetworkIsolation: true` allows access to `com.apple.trustd.agent` (**security-reducing** option).

### Denial Tracking System

`DENIAL_LIMITS` limits consecutive and total denials, falling back to prompt mode when exceeded.

### /sandbox Command

`/sandbox` command allows users to toggle sandbox state.

---

## Testing Verification

```bash
# Check platform support
node -e "console.log(SandboxManager.isSupportedPlatform())"

# Check dependencies
node -e "console.log(SandboxManager.checkDependencies())"

# Check enabled status
node -e "console.log(SandboxManager.isSandboxingEnabled())"
```
