# 7.2 Multi-Agent Collaboration

> Using multiple agents to collaboratively complete complex tasks

---

## Agent Collaboration Patterns

### Basic Patterns

| Pattern | Description | Use Case |
|---------|-------------|----------|
| Serial | One agent starts after another completes | Pipeline tasks |
| Parallel | Multiple agents work simultaneously | Independent subtasks |
| Hierarchical | Main agent coordinates sub-agents | Complex projects |

---

## Agent Communication

### Using Agent Tool

```bash
# Main agent calls sub-agent
> Use reviewer agent to review src/auth module
```

### Define Sub-agent

Agents must be defined via Markdown files in the `.claude/agents/` directory:

```markdown
---
name: reviewer
description: Code review agent
whenToUse: When code review is needed
tools:
  - Read
  - Glob
  - Grep
model: sonnet
---

# Code Review Agent

You are a professional code reviewer...
```

**Note**: Agents cannot be defined in `settings.json`. They must use Markdown files.

### Data Transfer Between Agents

```
Main Agent
    ↓ (task description + context)
Sub-agent 1 (reviewer)
    ↓ (review results)
Sub-agent 2 (fixer)
    ↓ (fix results)
Main Agent
    ↓
User
```

---

## Combining Skills and Agents

### Scenario: Automatic Code Review and Fix

#### 1. Create Review Skill

```markdown
---
name: auto-review
description: Automatically review code changes
paths:
  - "*.ts"
  - "*.tsx"
---

# Automatic Code Review

## Review Standards

1. Code style
2. Security vulnerabilities
3. Performance issues
4. Test coverage

## Output Format

```json
{
  "issues": [...],
  "score": 0-100,
  "recommendations": [...]
}
```
```

#### 2. Create Fix Skill

```markdown
---
name: auto-fix
description: Automatically fix review issues
---

# Automatic Fix

Fix code issues based on review results.
```

#### 3. Use Together

```bash
# Main agent
> Use auto-review skill to review code, then use auto-fix skill to fix issues
```

---

## Complex Collaboration Example

### Scenario: Complete Feature Development Flow

```
User request: Develop user authentication module

    ↓
Main Agent (Architect)
    ├─ Analyze requirements
    ├─ Decompose tasks
    └─ Assign to sub-agents

    ├─ → Agent: Database expert
    │       └─ Design data model
    │
    ├─ → Agent: API expert
    │       └─ Design interfaces
    │
    ├─ → Agent: Frontend expert
    │       └─ Implement UI
    │
    └─ → Agent: Test expert
            └─ Write tests

    ↓
Main Agent (Integrator)
    ├─ Integrate all parts
    ├─ Handle integration issues
    └─ Final review
```

### Implementation Configuration

Create multiple Markdown files in `.claude/agents/`:

```markdown
---
name: architect
description: Architecture design agent
whenToUse: When architecture design is needed
model: opus
---

# Architecture Design Agent

You focus on system architecture and design patterns...
```

```markdown
---
name: db-expert
description: Database expert
whenToUse: When database design or optimization is needed
tools:
  - Read
  - Write
  - Glob
model: sonnet
---

# Database Expert Agent

You specialize in database design, SQL optimization...
```

---

## Parallel Execution

### Using Skill Fork Mode

```markdown
---
name: batch-reviewer
description: Review multiple files in parallel
---

# Batch Review

Use fork mode to process multiple files in parallel.
Each file is assigned to an independent sub-agent.
```

### Execution Script

```bash
#!/bin/bash
# parallel_review.sh

FILES=$(find src -name "*.ts" | head -5)

for file in $FILES; do
  claude --skill batch-reviewer --file "$file" &
done

wait
```

---

## Agent Synchronization and Coordination

### Using Session Hooks

```json
{
  "hooks": {
    "SubagentStop": [
      {
        "matcher": "*",
        "command": "sync_results.sh"
      }
    ]
  }
}
```

**Correct Format**: Hooks are defined directly at the root level, no redundant `hooks` nesting field.

### Coordination Script Example

```bash
#!/bin/bash
# sync_results.sh
# Collect sub-agent results and aggregate

RESULT_FILE="/tmp/agent_results/$AGENT_ID.json"

# Save result
cat > "$RESULT_FILE"

# Check if all agents completed
COMPLETED=$(ls /tmp/agent_results/*.json 2>/dev/null | wc -l)
TOTAL=$1

if [ "$COMPLETED" -eq "$TOTAL" ]; then
  # Merge results
  jq -s 'add' /tmp/agent_results/*.json > /tmp/final_report.json
fi
```

---

## Team Collaboration System

### TeammateIdle Hook

Triggers when a teammate is idle:

```json
{
  "hooks": {
    "TeammateIdle": [
      {
        "matcher": "*",
        "hooks": [
          {
            "type": "command",
            "command": "reassign_task.sh"
          }
        ]
      }
    ]
  }
}
```

### TaskCreated / TaskCompleted Hooks

```json
{
  "hooks": {
    "TaskCreated": [
      {
        "matcher": "*",
        "hooks": [
          {
            "type": "command",
            "command": "log_task.sh create"
          }
        ]
      }
    ],
    "TaskCompleted": [
      {
        "matcher": "*",
        "hooks": [
          {
            "type": "command",
            "command": "log_task.sh complete"
          }
        ]
      }
    ]
  }
}
```

---

## Best Practices

### 1. Clear Responsibility Boundaries

Create separate agent files in `.claude/agents/`:

```markdown
---
name: frontend
description: Handle only frontend code
whenToUse: When frontend development is needed
tools:
  - Read
  - Write
  - Glob(src/**/*.tsx)
---

# Frontend Expert Agent
```

```markdown
---
name: backend
description: Handle only backend code
whenToUse: When backend development is needed
tools:
  - Read
  - Write
  - Glob(server/**/*.ts)
---

# Backend Expert Agent
```

### 2. Limit Tool Scope

```markdown
---
name: safe-agent
description: Safe mode agent, read-only operations
whenToUse: When security review is needed
tools:
  - Read
  - Glob
  - Grep
---

# Security Review Agent
```

### 3. Use Skill Layering

```
root skill (coordination)
├── sub-skill-1 (specific task)
├── sub-skill-2 (specific task)
└── sub-skill-3 (specific task)
```

### 4. Result Aggregation

- Unified output format
- Centralized logging
- Regular status synchronization

---

## Monitoring and Debugging

### Enable Debug Logging

```bash
export CLAUDE_DEBUG=agent
export CLAUDE_LOG_LEVEL=debug
```

### View Agent Execution

```bash
# List all agents
claude agents list

# View agent execution history
claude agents history <agent-id>
```

### Common Issues

| Issue | Solution |
|-------|----------|
| Agent not responding | Check tool permission configuration |
| Inconsistent results | Unify output format template |
| Deadlock | Add timeout mechanism |
| Resource contention | Use file locks for coordination |

---

## Template Configuration

### Quick Start Template

Create agent files in `.claude/agents/`:

```markdown
---
name: main
description: Main coordination agent
whenToUse: As main coordinator managing task flow
model: opus
---

# Main Coordination Agent

You are responsible for coordinating multiple sub-agents...
```

```markdown
---
name: worker
description: Worker agent
whenToUse: Execute specific development tasks
tools:
  - Read
  - Write
  - Glob
  - Grep
  - Bash
model: sonnet
---

# Worker Agent

You execute specific development tasks...
```

**Note**: Agents must be defined via Markdown files. They cannot be configured in `settings.json`.
