# Components 和 Screens 未文档化功能

> 基于源码 `src/components/`, `src/screens/`, `src/dialogLaunchers.tsx` 完整分析

---

## Overlay 系统

### Non-Modal Overlays

```typescript
// src/context/overlayContext.tsx
const NON_MODAL_OVERLAYS = new Set(['autocomplete'])
// autocomplete overlays 不会禁用 TextInput focus
```

### Escape 键协调

Overlay 系统解决当 overlays（如 Select with onCancel）打开时的 Escape 键处理：

```typescript
// 使用 useRegisterOverlay(id, enabled) 注册 active overlays
```

### Prompt Overlay 系统

两通道 overlay 系统：

```typescript
useSetPromptOverlay()          // 斜杠命令建议数据
useSetPromptOverlayDialog()    // 任意对话框节点
```

---

## 全局搜索对话框

**键盘快捷键**：`Ctrl+Shift+F` / `Cmd+Shift+F`

```typescript
// src/components/GlobalSearchDialog.tsx
interface GlobalSearchFeatures {
  debouncedRipgrepSearch  // 防抖 grep 搜索
  fuzzyPicker            // 模糊选择器
  filePreview            // 文件预览
  externalEditorOpen     // 在外部编辑器中打开
}
```

### 文件引用格式

```
@filename#L    // 带行号
filename:L     // 同上
```

---

## 权限对话框系统

### 反馈模式

Tab 键切换输入模式（接受/拒绝）：

```typescript
// src/components/permissions/
interface PermissionDialog {
  feedbackModes: {
    yesNo: 'yes' | 'no'
    tabToToggle: 'accept' | 'reject'
  }
}
```

### confirm:cycleMode 快捷键

循环切换权限确认模式：

```typescript
// 键盘快捷键映射
'confirm:cycleMode' -> cyclePermissionMode()
```

---

## MCP 对话框

### MCPServerMultiselectDialog

多选 MCP 服务器审批对话框：

```typescript
// src/components/MCPServerMultiselectDialog.tsx
// 将服务器分区为 approved/rejected
// 分析跟踪: tengu_mcp_multidialog_choice
```

---

## 反馈调查

```typescript
// src/components/FeedbackSurvey/
type FeedbackSurveyState =
  | 'closed'
  | 'open'
  | 'thanks'
  | 'transcript_prompt'
  | 'submitting'
  | 'submitted'

// 支持可选的数字输入
// 集成记忆调查
```

---

## Dialog Launchers

`src/dialogLaunchers.tsx` 中定义的对话框启动器：

| 函数 | 对话框 | 说明 |
|------|--------|------|
| `launchSnapshotUpdateDialog` | SnapshotUpdateDialog | Agent 记忆快照更新提示 |
| `launchInvalidSettingsDialog` | InvalidSettingsDialog | 设置验证错误显示 |
| `launchAssistantSessionChooser` | AssistantSessionChooser | Bridge 会话选择器 |
| `launchAssistantInstallWizard` | AssistantInstallWizard | Assistant 安装向导 |
| `launchTeleportResumeWrapper` | TeleportResumeWrapper | Teleport 会话选择器 |
| `launchTeleportRepoMismatchDialog` | TeleportRepoMismatchDialog | 本地 checkout 选择器 |
| `launchResumeChooser` | ResumeChooser | 交互式会话选择器 |

---

## 对话框类型

### 完整对话框列表

| 对话框 | 位置 | 说明 |
|--------|------|------|
| `TeleportResumeWrapper` | `components/TeleportResumeWrapper.js` | Teleport 会话选择器 |
| `TeleportRepoMismatchDialog` | `components/TeleportRepoMismatchDialog.js` | 本地 repo 选择器 |
| `IdleReturnDialog` | `components/IdleReturnDialog.js` | 空闲超时处理 |
| `ExitFlow` | `components/ExitFlow.jsx` | 退出流程处理 |
| `CostThresholdDialog` | `components/CostThresholdDialog.js` | 成本限制警告 |
| `ChannelDowngradeDialog` | `components/ChannelDowngradeDialog.js` | Channel 降级处理 |
| `IdeAutoConnectDialog` | `components/IdeAutoConnectDialog.js` | IDE 自动连接 |
| `IdeOnboardingDialog` | `components/IdeOnboardingDialog.js` | IDE 入门 |
| `ClaudeMdExternalIncludesDialog` | `components/ClaudeMdExternalIncludesDialog.js` | Claude.md 外部包含 |
| `InvalidSettingsDialog` | `components/InvalidSettingsDialog.jsx` | 设置错误 |
| `SnapshotUpdateDialog` | `components/agents/SnapshotUpdateDialog.js` | Agent 记忆快照 |
| `DevChannelsDialog` | `components/DevChannelsDialog.js` | Dev channels 审批 |
| `ClaudeInChromeOnboarding` | `components/ClaudeInChromeOnboarding.js` | Chrome 扩展入门 |
| `GroveDialog` | `components/grove/Grove.js` | Grove 策略对话框 |
| `GlobalSearchDialog` | `components/GlobalSearchDialog.tsx` | 全局搜索 |
| `HistorySearchDialog` | `components/HistorySearchDialog.tsx` | 对话历史搜索 |

---

## 权限请求组件

工具特定的权限请求处理：

```typescript
// src/components/permissions/PermissionRequest.tsx
const TOOL_PERMISSION_HANDLERS = {
  FileEdit: true,
  FileWrite: true,
  Bash: true,
  PowerShell: true,
  WebFetch: true,
  NotebookEdit: true,
  GlobTool: true,
  GrepTool: true,
  FileReadTool: true,
  ReviewArtifact: feature('REVIEW_ARTIFACT'),
  Workflow: feature('WORKFLOW_SCRIPTS'),
  Monitor: feature('MONITOR_TOOL'),
  Skill: true,
  AskUserQuestion: true
}
```

---

## AppState 上下文相关字段

### 未记录的字段

| 字段 | 说明 |
|------|------|
| `contentReplacementState` | 工具结果内容预算管理 |
| `computerUseMcpState` | Chicago MCP 会话状态（allowlist、grants、screenshots） |
| `workerSandboxPermissions` | 网络访问批准队列 |
| `pendingWorkerRequest` | 待处理权限请求 |
| `pendingSandboxRequest` | 待处理沙箱请求 |
| `replContext` | REPL 工具 VM 上下文 |
| `denialTracking` | Classifier 模式拒绝追踪 |
| `tungstenPanel*` | Tmux 面板状态 |
| `bagel*` | Web 浏览器工具状态 |

---

## 设置相关

### 显示设置

```typescript
interface DisplaySettings {
  syntaxHighlightingDisabled: boolean
  prefersReducedMotion: boolean
  terminalTitleFromRename: boolean
}
```

### Spinner 配置

```typescript
interface SpinnerConfig {
  spinnerTipsEnabled: boolean
  spinnerVerbs: {
    mode: 'append' | 'prepend'
    verbs: string[]
  }
  spinnerTipsOverride: {
    excludeDefault: boolean
    tips: string[]
  }
}
```

### Fast Mode

```typescript
// src/commands/fast/fast.tsx
interface FastModeConfig {
  fastModePerSessionOptIn: boolean  // 会话级别 fast mode opt-in
}
```

---

## 键盘快捷键

### 可配置快捷键

```typescript
// src/components/ConfigurableShortcutHint.tsx
// src/components/design-system/KeyboardShortcutHint.tsx
// src/hooks/useGlobalKeybindings.ts
// src/hooks/useCommandKeybindings.ts
```

### confirm:cycleMode

循环权限确认模式：

```bash
# 快捷键绑定
confirm:cycleMode -> cycleThroughConfirmationModes()
```

---

## Ink UI 框架

### 核心组件

| 组件 | 说明 |
|------|------|
| `Button` | 交互按钮，支持 focus/hover/active 状态 |
| `Link` | 超链接，支持终端超链接 fallback |
| `Text` | 样式文本 |
| `Box` | 布局容器 |
| `FocusManager` | 键盘焦点管理 |
| `useInput` | 输入事件处理 |
| `useSelection` | 选择管理 |
| `useTerminalFocus` | 终端焦点 |
| `useTerminalViewport` | 终端视口大小 |

---

## 屏幕

### 主屏幕

```typescript
// src/screens/
REPL.tsx                  // 主交互 REPL 屏幕
ResumeConversation.tsx    // 会话恢复选择器
Doctor.tsx               // 健康检查诊断屏幕
```

---

## Setup 对话框

`src/interactiveHelpers.tsx` 中的设置对话框：

```typescript
showSetupScreens()  // 编排以下流程：
// - onboarding
// - trust dialog
// - MCP approvals
// - Grove dialog
// - API key approval
// - bypass permissions dialog
// - auto mode opt-in
// - dev channels
// - Chrome onboarding
```

### TrustDialog

工作区信任边界对话框：

```typescript
interface TrustDialogContent {
  mcpServers: MCP server info
  hooks: Hooks info
  bashPermissions: Bash permissions
  apiKeyHelpers: API key helpers
}
```
