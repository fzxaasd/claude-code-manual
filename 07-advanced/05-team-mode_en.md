# 7.5 Team Mode

> Deep analysis based on source code `src/tools/TeamCreateTool/`, `src/tools/TeamDeleteTool/`, `src/utils/agentSwarmsEnabled.ts`, `src/utils/swarm/teamHelpers.ts`

## Core Concepts

Team Mode (Agent Swarms) is a multi-agent collaboration mechanism that allows a Leader Agent to create and manage multiple Teammate Agents, working together to complete complex tasks.

```
┌────────────────────────────────────────────────────────────┐
│                    Team Mode Architecture                   │
├────────────────────────────────────────────────────────────┤
│                                                            │
│  Leader (team-lead)                                        │
│  ├── Create team                                          │
│  ├── Assign tasks                                         │
│  ├── Approve plans (Plan Mode integration)                │
│  └── Coordinate work                                      │
│       │                                                    │
│       ├── teammate-1@teamName                              │
│       ├── teammate-2@teamName                              │
│       └── teammate-N@teamName                              │
│                                                            │
└────────────────────────────────────────────────────────────┘
```

---

## Enable Conditions

Based on `src/utils/agentSwarmsEnabled.ts`:

```typescript
function isAgentSwarmsEnabled(): boolean {
  // Ant build: Always enabled
  if (process.env.USER_TYPE === 'ant') {
    return true
  }

  // External users: Must meet the following conditions
  // 1. CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS environment variable enabled
  // 2. Or --agent-teams CLI flag
  if (!isEnvTruthy(process.env.CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS)
      && !process.argv.includes('--agent-teams')) {
    return false
  }

  // killswitch - GrowthBook feature flag
  if (!getFeatureValue_CACHED_MAY_BE_STALE('tengu_amber_flint', true)) {
    return false
  }

  return true
}
```

**Enable Methods**:
```bash
# Method 1: Environment variable
export CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=true

# Method 2: CLI flag
claude --agent-teams
```

### Team Mode Environment Variables

| Environment Variable | Source | Description |
|----------|------|------|
| `CLAUDE_CODE_TEAMMATE_COMMAND` | constants.ts | Override teammate startup command |
| `CLAUDE_CODE_AGENT_COLOR` | constants.ts | Teammate display color |
| `CLAUDE_CODE_PLAN_MODE_REQUIRED` | constants.ts | Whether teammate must use Plan Mode |
| `CLAUDE_CODE_AGENT_ID` | global | Format: agentName@teamName |
| `CLAUDE_CODE_AGENT_NAME` | global | Teammate display name |

---

## Tool Definitions

### TeamCreateTool

Based on `src/tools/TeamCreateTool/TeamCreateTool.ts`:

```typescript
interface TeamCreateTool {
  name: "TeamCreate"
  input: {
    team_name: string           // Team name (required)
    description?: string        // Team description/purpose
    agent_type?: string         // Team leader role (e.g., "researcher")
  }
  output: {
    team_name: string           // Final team name
    team_file_path: string      // Team config file path (~/.claude/teams/{team-name}/config.json)
    lead_agent_id: string       // Leader agent ID (format: team-lead@teamName)
  }
  enabled: isAgentSwarmsEnabled()  // Feature switch
}
```

**Constraints**:
- Leader can only manage one team at a time
- Duplicate team names auto-generate unique names (using word slug)
- Team config stored in `~/.claude/teams/{team-name}/config.json`

### TeamDeleteTool

Based on `src/tools/TeamDeleteTool/TeamDeleteTool.ts`:

```typescript
interface TeamDeleteTool {
  name: "TeamDelete"
  input: {}                    // No parameters
  output: {
    success: boolean           // Whether successful
    message: string            // Result message
    team_name?: string         // Team name
  }
  enabled: isAgentSwarmsEnabled()
}
```

**Cleanup contents**:
- Team directory (`~/.claude/teams/{team-name}/`)
- Task directory (`~/.claude/tasks/{sanitized-team-name}/`)
- Git worktrees
- Teammate processes (tmux/iTerm2 pane)

**Prerequisite**: All teammates must be stopped (`isActive === false`). Returns error if teammates are still active.

---

## TeamFile Structure

Based on `src/utils/swarm/teamHelpers.ts`:

```typescript
interface TeamFile {
  name: string                 // Team name
  description?: string         // Team description
  createdAt: number           // Creation timestamp
  leadAgentId: string         // Leader agent ID
  leadSessionId?: string      // Leader session UUID (for team discovery)
  hiddenPaneIds?: string[]    // Hidden pane IDs in UI
  teamAllowedPaths?: TeamAllowedPath[]  // Shared path permissions

  members: Array<{
    agentId: string           // Agent ID (format: name@teamName)
    name: string              // Agent name
    agentType?: string        // Agent type/role
    model?: string           // Model used
    prompt?: string          // Custom prompt
    color?: string           // UI display color
    planModeRequired?: boolean // Whether must use Plan Mode
    joinedAt: number          // Join time
    tmuxPaneId: string       // tmux pane ID
    cwd: string              // Working directory
    worktreePath?: string    // Git worktree path
    sessionId?: string       // Session ID
    subscriptions: string[]   // Subscribed message types
    backendType?: BackendType // Backend type ('tmux' | 'iterm2' | 'in-process')
    isActive?: boolean       // Whether active (false = idle/completed)
    mode?: PermissionMode    // Current permission mode
  }>
}

interface TeamAllowedPath {
  path: string        // Directory path (absolute)
  toolName: string   // Applicable tool (e.g., "Edit", "Write")
  addedBy: string    // Agent that added the rule
  addedAt: number    // Time added
}
```

**BackendType Type**:
```typescript
type BackendType = 'tmux' | 'iterm2' | 'in-process'
// - 'tmux': tmux pane (requires tmux installed)
// - 'iterm2': iTerm2 split pane (requires it2 CLI)
// - 'in-process': Run in same process (no independent terminal)
```

### Team File Storage

```bash
~/.claude/teams/{team-name}/config.json
~/.claude/tasks/{sanitized-team-name}/  # Task list directory
~/.claude/teams/{team-name}/inboxes/    # Message inboxes
```

**Mailbox path sanitization**: Non-alphanumeric characters are replaced with `-`, e.g., `team@name` → `team-name`.

### Teammate System Prompt Addendum

Source `src/utils/swarm/teammatePromptAddendum.ts` is auto-injected at teammate startup:

```
# Agent Teammate Communication

IMPORTANT: You are running as an agent in a team. To communicate with anyone on your team:
- Use the SendMessage tool with `to: "<name>"` to send messages to specific teammates
- Use the SendMessage tool with `to: "*"` sparingly for team-wide broadcasts

Just writing a response in text is not visible to others on your team - you MUST use the SendMessage tool.
```

**Note**: Text responses are not visible to other team members, must use SendMessage tool.

---

## Team Lifecycle

### 1. Create Team

```typescript
// Call TeamCreateTool
await team({
  team_name: "feature-backend",
  description: "Backend feature development team",
  agent_type: "tech-lead"
})

// Results:
// - Create ~/.claude/teams/feature-backend/config.json
// - Reset task list (~/.claude/tasks/feature-backend/)
// - Set AppState.teamContext
```

### 2. Add Teammate

```
┌────────────────────────────────────────────────────────────┐
│                    Add Teammate Flow                        │
├────────────────────────────────────────────────────────────┤
│                                                            │
│  1. Leader calls spawnTeammate                              │
│     └── Specify agent_type, prompt, tools, etc.            │
│                                                            │
│  2. Select backend type                                    │
│     ├── tmux: tmux pane                                    │
│     ├── iterm2: iTerm2 split pane                         │
│     └── in-process: same process                           │
│                                                            │
│  3. Create agent process                                   │
│     ├── Assign tmuxPaneId                                  │
│     ├── Set working directory (worktree)                  │
│     └── Initialize permission mode                         │
│                                                            │
│  4. Register to TeamFile                                   │
│     └── Add new entry to members array                    │
│                                                            │
└────────────────────────────────────────────────────────────┘
```

### 3. Communication Mechanism

**Message Passing**:
- Shared TeamFile (`~/.claude/teams/{team-name}/config.json`)
- Mailbox mechanism (`~/.claude/teams/{team-name}/inboxes/`)
- Task updates (`~/.claude/tasks/{taskListId}/`)

**Subscription Mechanism**:
```typescript
// Message types teammate subscribes to (can be any custom string)
subscriptions: [
  "task_assignment",
  "plan_approval_request",
  "shutdown_request"
]
// Note: subscriptions is string[], no fixed enum values

### SendMessageTool Complete Protocol

Based on `src/tools/SendMessageTool/SendMessageTool.ts`:

```typescript
interface SendMessageTool {
  name: "SendMessage"
  input: {
    to: string          // Recipient: teammate name, "*" for broadcast, or "bridge:<session-id>" for cross-session
    summary?: string    // 5-10 word preview (required for string messages)
    message: string | StructuredMessage
  }
}
```

**StructuredMessage Types**:

```typescript
// Close request
{ type: 'shutdown_request', reason?: string }

// Close response (SendMessageTool tool layer)
{ type: 'shutdown_response', request_id: string, approve: boolean, reason?: string }

// Mailbox layer close messages
{ type: 'shutdown_approved', requestId: string, from: string, timestamp: string }
{ type: 'shutdown_rejected', requestId: string, from: string, reason: string, timestamp: string }

// Plan approval response
{ type: 'plan_approval_response', requestId: string, approved: boolean, feedback?: string, timestamp?: string, permissionMode?: PermissionMode }
// permissionMode is inherited from leader, plan mode converts to default

// Idle notification (missing from original doc)
{ type: 'idle_notification', from: string, timestamp: string, idleReason?: 'available' | 'interrupted' | 'failed', summary?: string, completedTaskId?: string, completedStatus?: 'resolved' | 'blocked' | 'failed', failureReason?: string }

// Mode set request (missing from original doc)
{ type: 'mode_set_request', mode: PermissionMode, from: string }

// Team permission update (missing from original doc)
{ type: 'team_permission_update', permissionUpdate: { type: 'addRules', rules: Array<{ toolName: string; ruleContent?: string }>, behavior: 'allow' | 'deny' | 'ask', destination: 'session' }, directoryPath: string, toolName: string }

// Task assignment (missing from original doc)
{ type: 'task_assignment', taskId: string, subject: string, description: string, assignedBy: string, timestamp: string }
```

**Permission Response Structure** (Mailbox protocol uses snake_case):
```typescript
// Mailbox layer
{ type: 'permission_response', request_id: string, subtype: 'success' | 'error', response?: { updated_input?: Record<string, unknown> }, error?: string }
```

**Output Types**:

```typescript
// Normal message
type MessageOutput = {
  success: boolean
  message: string
  routing?: { sender, target, summary, content }
}

// Broadcast
type BroadcastOutput = {
  success: boolean
  message: string
  recipients: string[]
  routing?: MessageRouting
}

// Request/Response
type RequestOutput = { success: boolean, request_id: string, target: string }
type ResponseOutput = { success: boolean, request_id?: string }
```

**Protocol Rules**:
- `shutdown_response` must be sent to `team-lead`
- Rejecting shutdown must provide `reason`
- Structured messages cannot be broadcast (`to: "*"`)
- Cross-session messages can only be plain text

### In-Process Backend

Run teammate in same process (no independent terminal):

```typescript
type BackendType = 'in-process'

// Characteristics:
// - Runs in same Node.js process
// - No independent tmux/iTerm2 pane
// - Terminated via AbortController signal
// - Suitable for lightweight tasks
// - Does NOT receive initial prompt via mailbox, passed directly via startInProcessTeammate()

// Shutdown flow:
// 1. Send shutdown_request to target
// 2. Target calls shutdown_response (approve: true)
// 3. Leader calls AbortController.abort()
// 4. Target process checks abort signal and exits
```

### CLI Flags Inheritance

Source `src/tools/shared/spawnMultiAgent.ts`: Leader's CLI config is auto-passed to teammates:

```typescript
buildInheritedCliFlags(): string
// Inherits: --dangerously-skip-permissions, --permission-mode, --model, --settings, --plugin-dir, --chrome/--no-chrome
```

**planModeRequired** is also passed to teammates via this mechanism.

### Swarm Permission Sync

Cross-agent permission coordination mechanism (`src/utils/swarm/teamHelpers.ts`):

```typescript
// Sync teammate permissions to TeamFile
syncTeammateMode(mode: PermissionMode, teamNameOverride?: string): void

// Batch update multiple teammate permissions
setMultipleMemberModes(
  teamName: string,
  modeUpdates: Array<{ memberName: string, mode: PermissionMode }>
): boolean

// Set single teammate permission
setMemberMode(teamName: string, memberName: string, mode: PermissionMode): boolean
```

**Use Cases**:
- Leader uniformly adjusts team permission mode
- Teammate permission changes auto-sync to TeamFile
- Batch set permissions for multiple teammates

```typescript
// Example: Leader adjusts team permissions
setMemberMode("my-team", "backend-dev", "acceptEdits")

// Example: Batch update
setMultipleMemberModes("my-team", [
  { memberName: "backend-dev", mode: "acceptEdits" },
  { memberName: "tester", mode: "default" }
])
```

### Mailbox-Based Permission Sync

Complete permission coordination mechanism based on `src/utils/swarm/permissionSync.ts`:

#### Core Flow

```
┌────────────────────────────────────────────────────────────┐
│           Swarm Permission Sync Flow                        │
├────────────────────────────────────────────────────────────┤
│                                                            │
│  1. Worker agent encounters tool call requiring permission │
│                                                            │
│  2. Worker sends permission_request to Leader mailbox     │
│     └── writePermissionRequest() / sendPermissionRequestViaMailbox()
│                                                            │
│  3. Leader polls mailbox, detects permission request      │
│     └── readPendingPermissions()
│                                                            │
│  4. User approves/rejects via Leader UI                   │
│                                                            │
│  5. Leader sends permission_response to Worker mailbox    │
│     └── sendPermissionResponseViaMailbox()
│                                                            │
│  6. Worker polls mailbox, gets response and continues     │
│     └── pollForResponse() / readResolvedPermission()
│                                                            │
└────────────────────────────────────────────────────────────┘
```

#### Request Data Structure

```typescript
interface SwarmPermissionRequest {
  id: string                    // Unique request ID
  workerId: string             // Worker's CLAUDE_CODE_AGENT_ID
  workerName: string           // Worker's CLAUDE_CODE_AGENT_NAME
  workerColor?: string         // Worker's CLAUDE_CODE_AGENT_COLOR
  teamName: string             // Team name
  toolName: string             // Tool name (e.g., "Bash", "Edit")
  toolUseId: string            // Original toolUseID
  description: string          // Human-readable description
  input: Record<string, unknown>  // Serialized tool input
  permissionSuggestions: unknown[]  // Permission suggestions
  status: 'pending' | 'approved' | 'rejected'
  resolvedBy?: 'worker' | 'leader'
  resolvedAt?: number
  feedback?: string            // Rejection feedback message
  updatedInput?: Record<string, unknown>  // Modified input
  permissionUpdates?: PermissionUpdate[]  // Applied permission rules
  createdAt: number
}
```

#### Response Data Structure

```typescript
interface PermissionResolution {
  decision: 'approved' | 'rejected'
  resolvedBy: 'worker' | 'leader'
  feedback?: string
  updatedInput?: Record<string, unknown>
  permissionUpdates?: PermissionUpdate[]
}

// Legacy response type (worker polling)
interface PermissionResponse {
  requestId: string
  decision: 'approved' | 'denied'
  timestamp: string
  feedback?: string
  updatedInput?: Record<string, unknown>
  permissionUpdates?: unknown[]
}
```

#### Core APIs

```typescript
// ============ File-based operations ============

// Create permission request
async function writePermissionRequest(request: SwarmPermissionRequest): Promise<SwarmPermissionRequest>

// Read pending permission requests (Leader side)
async function readPendingPermissions(teamName?: string): Promise<SwarmPermissionRequest[]>

// Read resolved permission request (Worker side)
async function readResolvedPermission(requestId: string, teamName?: string): Promise<SwarmPermissionRequest | null>

// Resolve permission request (Leader side)
async function resolvePermission(
  requestId: string,
  resolution: PermissionResolution,
  teamName?: string
): Promise<boolean>

// Poll for permission response (Worker side)
async function pollForResponse(
  requestId: string,
  agentName?: string,
  teamName?: string
): Promise<PermissionResponse | null>

// ============ Mailbox-based operations ============

// Send permission request to Leader (Worker side)
async function sendPermissionRequestViaMailbox(
  request: SwarmPermissionRequest
): Promise<boolean>

// Send permission response to Worker (Leader side)
async function sendPermissionResponseViaMailbox(
  workerName: string,
  resolution: PermissionResolution,
  requestId: string,
  teamName?: string
): Promise<boolean>

// ============ Sandbox permissions ============

// Worker requests sandbox network access permission
async function sendSandboxPermissionRequestViaMailbox(
  host: string,
  requestId: string,
  teamName?: string
): Promise<boolean>

// Leader responds to sandbox permission request
async function sendSandboxPermissionResponseViaMailbox(
  workerName: string,
  requestId: string,
  host: string,
  allow: boolean,
  teamName?: string
): Promise<boolean>

// ============ Helper functions ============

// Check if team leader
function isTeamLeader(teamName?: string): boolean

// Check if Swarm Worker
function isSwarmWorker(): boolean

// Get team leader name
async function getLeaderName(teamName?: string): Promise<string | null>

// Generate unique request ID
function generateRequestId(): string

// Cleanup old resolved requests
async function cleanupOldResolutions(
  teamName?: string,
  maxAgeMs?: number
): Promise<number>
```

#### File Storage Structure

```
~/.claude/teams/{team-name}/
├── config.json              # Team config
├── permissions/
│   ├── pending/             # Pending requests
│   │   └── perm-{timestamp}-{random}.json
│   └── resolved/            # Resolved requests
│       └── perm-{timestamp}-{random}.json
└── inboxes/                 # Message inboxes
    └── {teammate-name}.json # One JSON file per teammate
```

#### Usage Examples

```typescript
// Worker: Send permission request
const request = createPermissionRequest({
  toolName: 'Bash',
  toolUseId: 'toolu_xxx',
  input: { command: 'rm -rf node_modules' },
  description: 'Remove node_modules directory'
})
await sendPermissionRequestViaMailbox(request)

// Leader: Read and process requests
const pending = await readPendingPermissions()
for (const req of pending) {
  // Display for user approval
  const decision = await showPermissionDialog(req)
  await resolvePermission(req.id, decision)
}

// Worker: Poll for response
const response = await pollForResponse(request.id)
if (response?.decision === 'approved') {
  // Continue execution
}
```

#### Sandbox Permission Sync

Used when Worker agent's sandbox needs network access:

```typescript
// Worker: Request sandbox network access
const sandboxReqId = generateSandboxRequestId()
await sendSandboxPermissionRequestViaMailbox('npmjs.com', sandboxReqId)

// Leader: Approve sandbox network request
await sendSandboxPermissionResponseViaMailbox(
  workerName,
  sandboxReqId,
  'npmjs.com',
  true  // allow
)
```

### TeammateSpawnConfig

Based on `src/utils/swarm/backends/types.ts`:

```typescript
type TeammateSpawnConfig = TeammateIdentity & {
  prompt: string           // Initial prompt
  cwd: string             // Working directory
  model?: string          // Specified model
  systemPrompt?: string   // System prompt
  systemPromptMode?: 'default' | 'replace' | 'append'  // System prompt mode
  worktreePath?: string   // Git worktree path
  parentSessionId: string // Parent session ID
  permissions?: string[] // Tool permission list
  allowPermissionPrompts?: boolean  // Whether to allow permission prompts
}

type TeammateIdentity = {
  name: string           // Teammate name
  teamName: string      // Team name
  color?: AgentColorName  // UI color
  planModeRequired?: boolean  // Whether must use Plan Mode
}
```

### 4. Delete Team

```typescript
// Constraint: Cannot have active teammates
if (activeMembers.length > 0) {
  return {
    success: false,
    message: "Cannot cleanup team with N active member(s)"
  }
}

// Cleanup flow
await cleanupTeamDirectories(teamName)
// ├── Destroy git worktrees
// ├── Delete team directory
// └── Delete task directory
```

---

## Difference from AgentTool

| Feature | AgentTool | Team Mode |
|---------|-----------|-----------|
| Context | Shared main session | Independent process |
| Communication | Direct call | Asynchronous messaging |
| Task management | None | Built-in |
| Concurrency control | None | Multi-task coordination |
| Permission control | Unified | Each agent can be independent |
| Use case | Simple subtasks | Complex collaboration |

---

## Plan Mode Integration

### Team Leader Approval Flow

```typescript
// Teammate calls ExitPlanMode
if (isTeammate() && isPlanModeRequired()) {
  // Send approval request to leader
  await writeToMailbox('team-lead', {
    type: 'plan_approval_request',
    planContent: plan,
    requestId: generateRequestId(...)
  })

  return {
    awaitingLeaderApproval: true,
    requestId: ...
  }
}

// Note: isTeammate() returns true for teammates, team-lead is not a teammate
// Actual leader-side check uses isTeamLead() (src/tools/ExitPlanModeTool/ExitPlanModeV2Tool.ts)
```

### Permission Mode Sync

```typescript
// Sync teammate permission changes to TeamFile
function syncTeammateMode(mode: PermissionMode): void {
  if (!isTeammate()) return
  setMemberMode(teamName, agentName, mode)
}

// Team leader can view all teammates' permission modes
```

---

## Configuration Options

### Team File Paths

```bash
# Default location
~/.claude/teams/{team-name}/

# Team config
~/.claude/teams/{team-name}/config.json

# Message mailbox
~/.claude/teams/{team-name}/inboxes/

# Task list
~/.claude/tasks/{sanitized-team-name}/
```

### Task List Isolation

```typescript
// Team = Project = Task list
// Each team has independent task numbering space
setLeaderTeamName(sanitizeName(teamName))
// Task numbers start from 1
```

---

## Usage Examples

### Create Team

```json
{
  "tool": "TeamCreate",
  "input": {
    "team_name": "api-refactor",
    "description": "API refactoring team",
    "agent_type": "architect"
  }
}
```

### Response

```json
{
  "team_name": "api-refactor",
  "team_file_path": "/home/user/.claude/teams/api-refactor/config.json",
  "lead_agent_id": "team-lead@api-refactor"
}
```

### Delete Team

```json
{
  "tool": "TeamDelete",
  "input": {}
}
```

---

## Best Practices

### 1. Team Structure

```
✅ Recommended structure:
├── tech-lead     (Leader) - Architecture decisions, task assignment
├── backend-dev   (Teammate) - Backend development
├── frontend-dev  (Teammate) - Frontend development
└── tester       (Teammate) - Testing and verification

❌ Avoid:
├── manager       (Leader) - Only assigns tasks
├── developer     (Teammate) - Unclear role
└── developer2    (Teammate) - Unclear responsibilities
```

### 2. Permission Management

```typescript
// Shared paths - teammates can directly edit
teamAllowedPaths: [
  { path: "/project/src", toolName: "Edit", addedBy: "team-lead" }
]

// Permission modes - each teammate can be independently set
members: [
  { name: "backend-dev", mode: "acceptEdits" },
  { name: "tester", mode: "default" }
]
```

### 3. Worktree Isolation

```typescript
// Each teammate uses independent worktree
members: [
  {
    name: "backend-dev",
    worktreePath: "/project/.git/worktrees/backend-dev"
  }
]
// Avoid file conflicts
```

---

## Session Cleanup

### Automatic Cleanup

```typescript
// Register teams created by session
registerTeamForSessionCleanup(teamName)

// Cleanup at session end
cleanupSessionTeams()
// ├── killOrphanedTeammatePanes()
// └── cleanupTeamDirectories()
```

### Cleanup Flow

```
┌────────────────────────────────────────────────────────────┐
│                    Session Cleanup Flow                      │
├────────────────────────────────────────────────────────────┤
│                                                            │
│  1. SIGINT/SIGTERM triggers gracefulShutdown              │
│                                                            │
│  2. cleanupSessionTeams() is called                       │
│                                                            │
│  3. For each session-created team:                         │
│     ├── killOrphanedTeammatePanes()                        │
│     │   └── Kill tmux/iTerm2 pane processes               │
│     └── cleanupTeamDirectories()                           │
│         ├── Destroy git worktrees                           │
│         ├── Delete team directory                          │
│         └── Delete task directory                          │
│                                                            │
└────────────────────────────────────────────────────────────┘
```

---

## Troubleshooting

### Cannot Create Team

```bash
# Check if feature is enabled
echo $CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS

# Check GrowthBook feature flag
# tengu_amber_flint must be true
```

### Team Directory Leftover

```bash
# View leftover teams
ls ~/.claude/teams/

# Manual cleanup
rm -rf ~/.claude/teams/{team-name}/
rm -rf ~/.claude/tasks/{sanitized-name}/
```

### Teammate Active Status Issues

```typescript
// After teammate crash, isActive may still be true
// TeamDelete will refuse cleanup
// Solutions:
// 1. Wait for teammate to actually stop
// 2. Manually kill tmux/iTerm2 pane
// 3. Restart Claude Code
```

---

## Testing Verification

```bash
# Verify feature is enabled
node -e "console.log(require('./src/utils/agentSwarmsEnabled').isAgentSwarmsEnabled())"

# Check team directories
ls ~/.claude/teams/

# View team config
cat ~/.claude/teams/{team-name}/config.json
```

---

## Undocumented Features

### Mailbox Message Structure

```typescript
interface TeammateMessage {
  from: string
  text: string
  timestamp: string
  read: boolean              // Whether message has been read
  color?: string             // Teammate color
  summary?: string           // 5-10 word preview summary
}
```

### File Locking Mechanism

Mailbox uses proper-lockfile for concurrent access:
```typescript
const LOCK_OPTIONS = {
  retries: {
    retries: 10,
    minTimeout: 5,
    maxTimeout: 100,
  },
}
```

### SendMessage Internal Routing

**UDS_INBOX Feature Flag**:
```typescript
// Conditionally includes uds: addressing
'Recipient: teammate name, "*" for broadcast, "uds:<socket-path>" for a local peer, or "bridge:<session-id>" for a Remote Control peer'
```

**In-Process Agent Direct Routing**:
```typescript
// If target is in same process, route directly without mailbox
if (typeof input.message === 'string' && input.to !== '*') {
  const registered = appState.agentNameRegistry.get(input.to)
  // Route directly to in-process teammate
}
```

### InboxPoller Priority Mechanism

Poll interval is fixed at 1000ms (1 second).

**Message Processing Priority Order**:
1. Permission Requests - Leader routes to ToolUseConfirmQueue
2. Permission Responses - Worker executes callbacks
3. Sandbox Permission Requests - Leader routes to workerSandboxPermissions
4. Sandbox Permission Responses - Worker executes callbacks
5. Team Permission Updates - Worker applies permission updates
6. Mode Set Requests - Worker changes mode and syncs to config.json
7. Plan Approval Requests - Leader auto-approves and writes response
8. Shutdown Requests - Teammate side passes through to UI
9. Shutdown Approvals - Leader kills pane and removes from team
10. Regular Messages - Submit immediately when idle, queue when busy

### agentNameRegistry

Mechanism for SendMessage to route by name instead of full agentId:
```typescript
// AppStateStore.ts
agentNameRegistry: Map<string, AgentId>
```

### parseAddress Supported Prefixes

```typescript
type AddressScheme = 'uds' | 'bridge' | 'other'

// Supported prefix formats:
// "uds:<socket-path>" - Unix Domain Socket
// "bridge:<session-id>" - Remote Control peer
// "/<path>" - Legacy UDS format (no prefix)
```

### TeammateExecutor Interface

Interface that abstracts teammate lifecycle operations:
```typescript
interface TeammateExecutor {
  readonly type: BackendType
  isAvailable(): Promise<boolean>
  spawn(config: TeammateSpawnConfig): Promise<TeammateSpawnResult>
  sendMessage(agentId: string, message: TeammateMessage): Promise<void>
  terminate(agentId: string, reason?: string): Promise<boolean>
  kill(agentId: string): Promise<boolean>
  isActive(agentId: string): Promise<boolean>
}
```

### TeamMemorySync Service

Complete team memory bidirectional sync service:
- Sync between local filesystem and server
- Secret scanning (PSR M22174)
- Conflict resolution with retry
- ETag conditional requests
- Batch upload size limits
- Requires OAuth authentication

### TeammateLayoutManager

Feature for managing teammate pane layouts (undocumented).

### Reconnection System

Teammate reconnection handling mechanism (undocumented).

### Mailbox Class (In-Memory)

In-memory message queue for in-process teammates:
```typescript
class Mailbox {
  private queue: Message[]
  private waiters: Waiter[]
  send(msg: Message): void
  poll(fn: (msg: Message) => boolean = () => true): Message | undefined
  receive(fn: (msg: Message) => boolean = () => true): Promise<Message>
  subscribe = this.changed.subscribe
}
```
