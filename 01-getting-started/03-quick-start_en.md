# Quick Start

> Get started with Claude Code in 5 minutes

---

## First-Time Use

### 1. Installation and Login

```bash
# Install (macOS)
brew install anthropic/formulae/claude-code

# First login
claude
# Automatically opens browser for OAuth authentication
```

### 2. Basic Conversation

```bash
$ claude
# Enter interactive conversation

> Create a simple Hello World Python program
```

---

## Core Operations

### Editing Files

```bash
# Have Claude edit an existing file
> Modify main.py, change the function name to process_data

# Have Claude create a new file
> Create a config.yaml configuration file
```

### Executing Commands

```bash
# Claude will ask for confirmation before executing dangerous commands
> Run npm install

# Approve to execute
# y - Approve
# n - Deny
# a - Approve all subsequent commands
```

### Viewing Changes

```bash
# View changes before committing
> Show me the current changes

# View git diff
> git diff
```

---

## Common Shortcuts

### Interactive Mode

| Shortcut | Function |
|----------|----------|
| `Ctrl+C` | Interrupt current operation |
| `Ctrl+D` | Exit session |
| `Ctrl+L` | Clear screen |
| `Ctrl+O` | View full output |
| `Ctrl+S` | Save current session |
| `Tab` | Auto-complete |

### Command Mode

| Shortcut | Function |
|----------|----------|
| `↑/↓` | Command history |
| `Ctrl+R` | Search history |
| `!!` | Repeat last command |

---

## Common Command Examples

### File Operations

```bash
# Search files
claude "find all ts files"
claude "grep -r 'TODO' ."

# Batch rename
claude "rename all .js files to .mjs"
```

### Git Operations

```bash
# Commit code
claude "commit -m 'feat: add login feature'"

# Create PR
claude "create pull request"

# View changes
claude "git status && git diff"
```

### Development Tasks

```bash
# Start dev server
claude "npm run dev"

# Run tests
claude "pytest tests/"

# Code review
claude "review the recent commits"
```

---

## Minimal Viable Environment Setup

### 1. Create Project Configuration

```bash
mkdir -p .claude
cat > .claude/settings.json << 'EOF'
{
  "permissions": {
    "allow": ["Bash", "Read", "Write", "Edit"],
    "deny": ["rm -rf /"]
  }
}
EOF
```

### 2. Set Permission Mode

```bash
# Development environment - permissive
claude --permission-mode acceptEdits

# Production environment - strict restrictions
claude --permission-mode dontAsk
```

**settings.json Configuration**:
```json
{
  "permissions": {
    "defaultMode": "dontAsk"
  }
}
```

---

## First Complete Example

### Scenario: Create a React Component

```bash
$ claude

> Create a user card component UserCard.tsx
> Include avatar, username, email
> Use TypeScript and Tailwind CSS
```

Claude will:
1. Analyze existing code structure
2. Create component file
3. Display code content
4. Ask if adjustments are needed

---

## Session Management

### Save and Resume

```bash
# Resume session
claude --resume <session-id>

# New session (just run claude directly)
```

> Note: `claude sessions list` and `claude --new` commands do not exist.

### Export and Share

```bash
# Export conversation
claude "export this conversation as markdown"

# Save to file
Ctrl+S
```

---

## FAQ

### Q: How to interrupt a long-running task?
A: `Ctrl+C` or type `stop`

### Q: What to do when command execution is denied?
A: Check the `permissions` field configuration in `settings.json`, or use `claude --permission-mode acceptEdits`

### Q: How to view previous output?
A: `Ctrl+O` to open full output view

### Q: What to do if session history is lost?
A: Use `claude --resume <session-id>` to recover the session, or export regularly

---

## Next Steps

- [Installation and Authentication](./01-installation.md) - Detailed installation instructions
- [Core Concepts](./02-core-concepts.md) - Understand terminology in depth
- [Global Options](../02-cli/01-global-options.md) - Command line arguments
