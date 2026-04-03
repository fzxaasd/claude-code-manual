# Components and Screens - Undocumented Features

> Based on complete analysis of source code: `src/components/`, `src/screens/`, `src/dialogLaunchers.tsx`

---

## Overlay System

### Non-Modal Overlays

```typescript
// src/context/overlayContext.tsx
const NON_MODAL_OVERLAYS = new Set(['autocomplete'])
// autocomplete overlays do not disable TextInput focus
```

### Escape Key Coordination

The Overlay system handles Escape key processing when overlays are open (e.g., Select with onCancel):

```typescript
// Use useRegisterOverlay(id, enabled) to register active overlays
```

### Prompt Overlay System

Two-channel overlay system:

```typescript
useSetPromptOverlay()          // Slash command suggestion data
useSetPromptOverlayDialog()    // Arbitrary dialog node
```

---

## Global Search Dialog

**Keyboard Shortcut**: `Ctrl+Shift+F` / `Cmd+Shift+F`

```typescript
// src/components/GlobalSearchDialog.tsx
interface GlobalSearchFeatures {
  debouncedRipgrepSearch  // Debounced grep search
  fuzzyPicker            // Fuzzy picker
  filePreview            // File preview
  externalEditorOpen     // Open in external editor
}
```

### File Reference Format

```
@filename#L    // With line number
filename:L     // Same as above
```

---

## Permission Dialog System

### Feedback Modes

Tab key toggles input mode (accept/reject):

```typescript
// src/components/permissions/
interface PermissionDialog {
  feedbackModes: {
    yesNo: 'yes' | 'no'
    tabToToggle: 'accept' | 'reject'
  }
}
```

### confirm:cycleMode Shortcut

Cycles through permission confirmation modes:

```typescript
// Keyboard shortcut mapping
'confirm:cycleMode' -> cyclePermissionMode()
```

---

## MCP Dialog

### MCPServerMultiselectDialog

Multi-select MCP server approval dialog:

```typescript
// src/components/MCPServerMultiselectDialog.tsx
// Partitions servers into approved/rejected
// Analytics tracking: tengu_mcp_multidialog_choice
```

---

## Feedback Survey

```typescript
// src/components/FeedbackSurvey/
type FeedbackSurveyState =
  | 'closed'
  | 'open'
  | 'thanks'
  | 'transcript_prompt'
  | 'submitting'
  | 'submitted'

// Supports optional numeric input
// Integrated memory survey
```

---

## Dialog Launchers

Dialog launchers defined in `src/dialogLaunchers.tsx`:

| Function | Dialog | Description |
|----------|--------|-------------|
| `launchSnapshotUpdateDialog` | SnapshotUpdateDialog | Agent memory snapshot update prompt |
| `launchInvalidSettingsDialog` | InvalidSettingsDialog | Settings validation error display |
| `launchAssistantSessionChooser` | AssistantSessionChooser | Bridge session chooser |
| `launchAssistantInstallWizard` | AssistantInstallWizard | Assistant installation wizard |
| `launchTeleportResumeWrapper` | TeleportResumeWrapper | Teleport session chooser |
| `launchTeleportRepoMismatchDialog` | TeleportRepoMismatchDialog | Local checkout chooser |
| `launchResumeChooser` | ResumeChooser | Interactive session chooser |

---

## Dialog Types

### Complete Dialog List

| Dialog | Location | Description |
|--------|----------|-------------|
| `TeleportResumeWrapper` | `components/TeleportResumeWrapper.js` | Teleport session chooser |
| `TeleportRepoMismatchDialog` | `components/TeleportRepoMismatchDialog.js` | Local repo chooser |
| `IdleReturnDialog` | `components/IdleReturnDialog.js` | Idle timeout handling |
| `ExitFlow` | `components/ExitFlow.jsx` | Exit flow handling |
| `CostThresholdDialog` | `components/CostThresholdDialog.js` | Cost limit warning |
| `ChannelDowngradeDialog` | `components/ChannelDowngradeDialog.js` | Channel downgrade handling |
| `IdeAutoConnectDialog` | `components/IdeAutoConnectDialog.js` | IDE auto-connect |
| `IdeOnboardingDialog` | `components/IdeOnboardingDialog.js` | IDE onboarding |
| `ClaudeMdExternalIncludesDialog` | `components/ClaudeMdExternalIncludesDialog.js` | Claude.md external includes |
| `InvalidSettingsDialog` | `components/InvalidSettingsDialog.jsx` | Settings error |
| `SnapshotUpdateDialog` | `components/agents/SnapshotUpdateDialog.js` | Agent memory snapshot |
| `DevChannelsDialog` | `components/DevChannelsDialog.js` | Dev channels approval |
| `ClaudeInChromeOnboarding` | `components/ClaudeInChromeOnboarding.js` | Chrome extension onboarding |
| `GroveDialog` | `components/grove/Grove.js` | Grove policy dialog |
| `GlobalSearchDialog` | `components/GlobalSearchDialog.tsx` | Global search |
| `HistorySearchDialog` | `components/HistorySearchDialog.tsx` | Chat history search |

---

## Permission Request Components

Tool-specific permission request handling:

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

## AppState Context-Related Fields

### Undocumented Fields

| Field | Description |
|-------|-------------|
| `contentReplacementState` | Tool result content budget management |
| `computer_useMcpState` | Chicago MCP session state (allowlist, grants, screenshots) |
| `workerSandboxPermissions` | Network access approval queue |
| `pendingWorkerRequest` | Pending permission request |
| `pendingSandboxRequest` | Pending sandbox request |
| `replContext` | REPL tool VM context |
| `denialTracking` | Classifier mode denial tracking |
| `tungstenPanel*` | Tmux panel state |
| `bagel*` | Web browser tool state |

---

## Settings Related

### Display Settings

```typescript
interface DisplaySettings {
  syntaxHighlightingDisabled: boolean
  prefersReducedMotion: boolean
  terminalTitleFromRename: boolean
}
```

### Spinner Configuration

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
  fastModePerSessionOptIn: boolean  // Session-level fast mode opt-in
}
```

---

## Keyboard Shortcuts

### Configurable Shortcuts

```typescript
// src/components/ConfigurableShortcutHint.tsx
// src/components/design-system/KeyboardShortcutHint.tsx
// src/hooks/useGlobalKeybindings.ts
// src/hooks/useCommandKeybindings.ts
```

### confirm:cycleMode

Cycles permission confirmation modes:

```bash
# Shortcut binding
confirm:cycleMode -> cycleThroughConfirmationModes()
```

---

## Ink UI Framework

### Core Components

| Component | Description |
|-----------|-------------|
| `Button` | Interactive button with focus/hover/active states |
| `Link` | Hyperlink with terminal hyperlink fallback |
| `Text` | Styled text |
| `Box` | Layout container |
| `FocusManager` | Keyboard focus management |
| `useInput` | Input event handling |
| `useSelection` | Selection management |
| `useTerminalFocus` | Terminal focus |
| `useTerminalViewport` | Terminal viewport size |

---

## Screens

### Main Screens

```typescript
// src/screens/
REPL.tsx                  // Main interactive REPL screen
ResumeConversation.tsx    // Session resume chooser
Doctor.tsx               // Health check diagnostic screen
```

---

## Setup Dialog

Setup dialog in `src/interactiveHelpers.tsx`:

```typescript
showSetupScreens()  // Orchestrates the following flow:
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

Workspace trust boundary dialog:

```typescript
interface TrustDialogContent {
  mcpServers: MCP server info
  hooks: Hooks info
  bashPermissions: Bash permissions
  apiKeyHelpers: API key helpers
}
```
