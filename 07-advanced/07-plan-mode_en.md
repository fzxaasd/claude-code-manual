# 7.7 Plan Mode

> Deep analysis based on source code `src/tools/EnterPlanModeTool/`, `src/tools/ExitPlanModeTool/`, `src/utils/planModeV2.ts`, `src/utils/plans.ts`

## Core Concepts

Plan Mode is an exploration and planning mode specifically designed for complex tasks. It allows Claude Code to understand the codebase, explore solutions, and design implementation strategies before writing code.

```
┌────────────────────────────────────────────────────────────┐
│                      Plan Mode Flow                         │
├────────────────────────────────────────────────────────────┤
│                                                            │
│  1. Enter Plan Mode                                        │
│     └── EnterPlanModeTool                                  │
│         ├── Switch permission mode to 'plan'              │
│         └── Disallow file writing (except plan files)     │
│                                                            │
│  2. Exploration Phase                                      │
│     ├── Explore codebase                                   │
│     ├── Understand existing patterns                       │
│     ├── Identify similar features                          │
│     └── Design multiple solutions and tradeoffs            │
│                                                            │
│  3. Write Plan                                             │
│     └── Write to ~/.claude/plans/{slug}.md                │
│                                                            │
│  4. Exit Plan Mode                                         │
│     └── ExitPlanModeV2Tool                                │
│         ├── User approves plan                             │
│         └── Resume execution mode                          │
│                                                            │
└────────────────────────────────────────────────────────────┘
```

---

## Tool Definitions

### EnterPlanModeTool

Based on `src/tools/EnterPlanModeTool/EnterPlanModeTool.ts`:

```typescript
interface EnterPlanModeTool {
  name: "EnterPlanMode"
  input: {}                    // No parameters
  output: {
    message: string            // Confirmation message
  }
  enabled: boolean             // Disabled when KAIROS channels active
  isReadOnly: true            // Read-only mode
}
```

**Trigger Conditions**:
- Disabled when `KAIROS` or `KAIROS_CHANNELS` feature is enabled and has active channel
- Not available in sub-agent context

### Tool Properties

| Property | EnterPlanModeTool | ExitPlanModeV2Tool |
|------|------------------|-------------------|
| `isReadOnly` | `true` | `false` (writes files) |
| `isConcurrencySafe` | `true` | `true` |

### ExitPlanModeV2Tool requiresUserInteraction()

Teammate (isTeammate()) returns false — no local user interaction required
Non-teammate returns true — requires user confirmation to exit

Based on `src/tools/ExitPlanModeTool/ExitPlanModeV2Tool.ts`:

```typescript
interface ExitPlanModeV2Tool {
  name: "ExitPlanMode"
  input: {
    allowedPrompts?: {         // Semantic permissions needed for plan (new)
      tool: 'Bash'
      prompt: string          // e.g., "run tests"
    }[]
  }
  output: {
    plan: string | null        // Plan content
    isAgent: boolean           // Whether it's a sub-agent
    filePath?: string          // Plan file path
    hasTaskTool?: boolean      // Whether AgentTool is available
    planWasEdited?: boolean    // Whether user edited the plan
    awaitingLeaderApproval?: boolean  // Waiting for team leader approval
    requestId?: string         // Approval request ID
  }
  requiresUserInteraction: true  // Requires user confirmation
}
```

**`allowedPrompts` parameter**:
- Used to request specific Bash permissions when exiting plan mode
- The `tool` field is restricted to `'Bash'` only (enum constraint)
- Example: `{ tool: 'Bash', prompt: 'run tests' }` requests permission to run tests
- Teammate mode: directly allow, skip permission UI
- Non-teammate mode: `checkPermissions` returns `behavior: 'ask'`, asks "Exit plan mode?"

**Permission Verification**:
- Only available when `mode === 'plan'`
- Automatically bypasses permission UI in Teammate mode
- Regular users need confirmation dialog

---

## Permission Mode Transition

### Plan Mode Permission State

```
┌────────────────────────────────────────────────────────────┐
│                Permission Mode Transition                   │
├────────────────────────────────────────────────────────────┤
│                                                            │
│  default/acceptEdits/auto ──[EnterPlanMode]──> plan          │
│                                                            │
│  plan ──[ExitPlanMode approved]──> restore prePlanMode       │
│                                                            │
│  plan ──[ExitPlanMode rejected]──> stay in plan mode        │
│                                                            │
└────────────────────────────────────────────────────────────┘
```

### Plan Mode Behavior Differences

| Behavior | Normal Mode | Plan Mode |
|------|---------|-----------|
| File writing | Normal | Restricted (plan files only) |
| Tool execution | Normal | Restricted |
| Permission checks | Normal | Additional verification |
| Plan approval | None | Required |

---

## Plan File Management

### Plan Directory

Based on `src/utils/plans.ts`:

```typescript
// Configuration: settings.json
settings.plansDirectory: string  // Relative or absolute path

// Default location
~/.claude/plans/
```

**Path Validation**:
- **Default**: Uses `~/.claude/plans/` (user home directory)
- **Custom `plansDirectory`**: Must be under project root, prevents path traversal
- Source logic: If custom path is outside `cwd`, falls back to `~/.claude/plans/`

### Plan Filename

```typescript
// Main session plan
getPlanFilePath(): `${slug}.md`
// e.g., swift-violet-bird.md

// Sub-agent plan
getPlanFilePath(agentId): `${slug}-agent-${agentId}.md`
// e.g., swift-violet-bird-agent-subagent-1.md
```

### Plan Recovery Mechanism

```
┌────────────────────────────────────────────────────────────┐
│                 Plan File Recovery Flow                     │
├────────────────────────────────────────────────────────────┤
│                                                            │
│  1. Read plan file directly                                │
│     └── Success → Return plan                               │
│                                                            │
│  2. If file doesn't exist, try recovery                    │
│     ├── Remote session (CCR)                                │
│     │   └── Try to restore from file snapshot              │
│     │       └── Try to restore from message history        │
│     │           └── Try to restore from plan_file_reference│
│     └── Local session → return null                        │
│                                                            │
└────────────────────────────────────────────────────────────┘
```

**Recovery Sources**:
1. `plan` field in ExitPlanMode tool input
2. `planContent` field in UserMessage
3. `plan_file_reference` attachment

---

## V2 Advanced Features

### Plan Mode V2 Agent Count

Based on `src/utils/planModeV2.ts`:

```typescript
// Determines parallel exploration agent count based on subscription type
getPlanModeV2AgentCount(): number

// Return values:
// - CLAUDE_CODE_PLAN_V2_AGENT_COUNT environment variable (1-10)
// - Claude Max + 20x rate limit: 3
// - Enterprise/Team subscription: 3
// - Other: 1

getPlanModeV2ExploreAgentCount(): number
// Default: 3 (configurable)
```

### Interview Phase

```typescript
isPlanModeInterviewPhaseEnabled(): boolean

// Enable conditions (any one):
// 1. USER_TYPE === 'ant' (internal users) - Always enabled
// 2. CLAUDE_CODE_PLAN_MODE_INTERVIEW_PHASE=true environment variable
// 3. GrowthBook feature flag: tengu_plan_mode_interview_phase

// Features:
// - Add interview phase before 5-stage plan process
// - Claude clarifies requirements through questions
// - As control group, not affected by Pewter Ledger experiment
```

**`mapToolResultToToolResultBlockParam` difference**:
- Interview Phase enabled: Returns simplified "DO NOT write or edit any files except the plan file. Detailed workflow instructions will follow."
- Interview Phase disabled: Returns detailed 6-step operation guide

### Pewter Ledger (Plan Size Control Experiment)

```typescript
type PewterLedgerVariant = 'trim' | 'cut' | 'cap' | null

getPewterLedgerVariant(): PewterLedgerVariant
// Controls Phase 4 "Final Plan" bullet count
// Experiment goal: Reduce plan file size, improve user acceptance rate
```

**Pewter Ledger Experiment Details**:

```
Experiment name: tengu_pewter_ledger
Control group: null
Treatment groups: 'trim' | 'cut' | 'cap' (progressively stricter)

Treatment arm explanations:
- trim: Prune suggestions, remove redundancy
- cut: Streamline content, reduce details
- cap: Hard cap, maximum bullet count

Baseline data (14 days, as of 2026-03-02, N=26.3M):
- p50: 4,906 chars
- p90: 11,617 chars
- mean: 6,207 chars
- 82% Opus 4.6

Rejection rate vs size relationship:
- <2K: 20%
- 20K+: 50%

Primary metric: session-level Avg Cost (fact__201omjcij85f)
- Opus output price is 5x input
- cost is proxy metric weighted by output

Guardrail metrics:
- feedback-bad rate
- requests/session (too thin plan → more iterations)
- tool error rate
```

**Note**:
- Interview Phase is not affected by Pewter Ledger experiment
- As control group, always uses original plan format

---

## Teammate Integration

### Team Leader Approval Flow

```
Agent requests to exit plan mode
        ↓
  isPlanModeRequired()?
        ↓
    Yes ────────── No
     ↓              ↓
Send plan_approval_request to mailbox
        ↓
Wait for team-lead approval
        ↓
  Receive approval response
        ↓
Continue execution / Re-plan
```

### Permission Special Handling

| Scenario | Permission Behavior |
|------|---------|
| Teammate calls ExitPlanMode | Auto-allow, send approval request |
| Non-teammate calls | Show confirmation dialog |
| `plan_mode_required=true` teammate | Must have plan to exit (forced plan mode) |

### Forced Plan Mode (Plan Mode Required)

```typescript
isPlanModeRequired(): boolean

// Triggers (any one):
// 1. TeammateContext.planModeRequired = true
// 2. DynamicTeamContext.planModeRequired = true
// 3. Environment variable CLAUDE_CODE_PLAN_MODE_REQUIRED=true
```

**Source**: `src/utils/teammate.ts:149-156`

---

## Configuration Options

### settings.json Configuration

```json
{
  // Plan file directory (relative to project root)
  "plansDirectory": ".claude/plans/",

  // Show context clear option
  "showClearContextOnPlanAccept": false,

  // Use auto mode during plan mode
  "useAutoModeDuringPlan": true,

  // Skip auto mode permission prompt
  "skipAutoPermissionPrompt": false
}
```

### Environment Variables

| Variable | Description | Value Range |
|------|------|--------|
| `CLAUDE_CODE_PLAN_V2_AGENT_COUNT` | Parallel exploration agent count | 1-10 |
| `CLAUDE_CODE_PLAN_V2_EXPLORE_AGENT_COUNT` | Exploration agent count | 1-10 |
| `CLAUDE_CODE_PLAN_MODE_INTERVIEW_PHASE` | Enable interview phase | true/false |
| `CLAUDE_CODE_PLAN_MODE_REQUIRED` | Force plan mode for teammates | true/false |

---

## Usage Examples

### Enter Plan Mode

```
> Help me refactor the entire authentication system

# Claude Code will call EnterPlanMode
# Switch to read-only exploration mode
```

### Plan Phase Operations

```
# Explore codebase
Read src/auth/...

# Understand existing patterns
Grep pattern "jwt" src/

# Design solution
Write .claude/plans/xxx.md
# Include:
# - Problem analysis
# - Solution comparison
# - Implementation steps
# - Risk assessment
```

### Exit Plan Mode

```
# Call ExitPlanMode
# User approves plan
# Start implementation
```

---

## Best Practices

### 1. Plan File Structure

```markdown
# Authentication System Refactoring Plan

## Problem Analysis
- Current authentication logic is tightly coupled
- JWT refresh mechanism has issues
- Lack of unified error handling

## Solution Comparison

### Solution A: Modular Refactoring
Pros: Small changes, low risk
Cons: Cannot fundamentally solve the problem

### Solution B: Complete Redesign
Pros: Clean architecture, easy to maintain
Cons: Large workload

## Recommended Solution
Solution B, with progressive migration

## Implementation Steps
1. Create new auth-core module
2. Implement basic authentication logic
3. Migrate existing code
4. Update tests
5. Deploy and verify

## Risk Assessment
- Data migration risk → Rollback plan prepared
- Downtime → Blue-green deployment
```

### 2. Effective Plan Key Points

```
✅ Clear problem definition
✅ Multiple solution comparison
✅ Clear implementation steps
✅ Risk assessment and mitigation
✅ Time/resource estimation

❌ Vague goals
❌ Single solution
❌ Implementation steps without details
❌ Ignoring potential risks
```

### 3. Team Collaboration

```
1. Leader creates task → Assign to agent
2. Agent enters Plan Mode → Write plan
3. Agent calls ExitPlanMode → Request approval
4. Leader approves plan → Agent executes
5. Leader accepts result → Task complete
```

---

## Comparison with Other Modes

| Feature | Normal Mode | Plan Mode | Auto Mode |
|------|---------|-----------|-----------|
| File writing | Full | Plan files only | Auto per rules |
| Permission prompts | Ask each time | Plan approval | Auto-handled |
| Use case | Simple tasks | Complex refactoring | Batch operations |
| User interaction | High | Medium | Low |

---

## Testing Verification

Verify Plan Mode configuration:
```bash
# Check plan directory
ls ~/.claude/plans/

# View plan file
cat ~/.claude/plans/xxx.md

# Test permission configuration
claude --debug permissions
```
