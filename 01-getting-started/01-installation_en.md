# Installation and Authentication

> Claude Code installation and configuration guide

## System Requirements

| Requirement | Description |
|-------------|-------------|
| Operating System | macOS, Linux, Windows (WSL) |
| Memory | 4GB+ recommended |
| Disk | 500MB free space |
| Node.js | Optional (for plugins) |
| Git | Recommended |

---

## Installation Methods

### 1. macOS (Homebrew)

```bash
brew install anthropic/formulae/claude-code
```

### 2. Linux/macOS (curl)

```bash
curl -fsSL https://downloads.anthropic.com/claude-code/install.sh | sh
```

### 3. npm

```bash
npm install -g @anthropic-ai/claude-code
```

### 4. Windows (winget)

```bash
winget install Anthropic.ClaudeCode
```

### 5. Manual Installation

Download the installer for your platform from the Anthropic website.

---

## Authentication Configuration

### Method 1: Interactive Login

```bash
claude auth login
```

This opens a browser for OAuth authentication.

**Authentication Options**:
```bash
claude auth login --sso           # SSO single sign-on
claude auth login --console       # Anthropic Console login
claude auth login --claudeai      # Claude.ai login
claude auth login --email <email> # Login with specified email
```

### Method 2: API Key

```bash
# Set environment variable
export ANTHROPIC_API_KEY="sk-ant-..."

# Or use --settings
claude --settings '{"env":{"ANTHROPIC_API_KEY":"sk-ant-..."}}'
```

### Method 3: API Helper Script

Create an authentication helper script:

```bash
#!/bin/bash
# ~/.claude/api-key-helper
echo "sk-ant-your-api-key-here"
```

```json
// ~/.claude/settings.json
{
  "apiKeyHelper": "/path/to/api-key-helper"
}
```

---

## Proxy Configuration

### Environment Variables

```bash
export ANTHROPIC_BASE_URL="http://127.0.0.1:5000"
export HTTP_PROXY="http://proxy:8080"
export HTTPS_PROXY="http://proxy:8080"
```

### settings.json

```json
{
  "env": {
    "ANTHROPIC_BASE_URL": "http://127.0.0.1:5000",
    "ANTHROPIC_API_KEY": "sk-ant-..."
  }
}
```

---

## First-Time Usage Check

### 1. Verify Installation

```bash
claude --version
```

### 2. Verify Authentication

```bash
claude auth status
```

### 3. Run Diagnostics

```bash
claude doctor
```

---

## Configuration Directories

| Path | Description |
|------|-------------|
| `~/.claude/settings.json` | Global settings |
| `~/.claude/skills/` | Global skills |
| `~/.claude/agents/` | Global agents |
| `~/.claude/plugins/` | Plugins |
| `~/.claude/sessions/` | Session history |

---

## Quick Start

### 1. Basic Usage

```bash
# Start interactive session
claude

# Execute single task
claude -p "explain what this function does"

# Continue previous session
claude -c
```

### 2. First Project Configuration

```bash
# Create project config directory
mkdir -p .claude

# Create project settings
cat > .claude/settings.json << 'EOF'
{
  "$schema": "https://json.schemastore.org/claude-code-settings.json",
  "permissions": {
    "allow": [
      "Bash(git *)",
      "Bash(npm *)",
      "Bash(npx *)",
      "Read",
      "Edit",
      "Write",
      "Glob",
      "Grep"
    ],
    "deny": [
      "Bash(rm -rf /*)"
    ]
  }
}
EOF
```

### 3. Create Your First Skill

```bash
# Create skill directory
mkdir -p .claude/skills/hello

# Create skill file
cat > .claude/skills/hello/SKILL.md << 'EOF'
---
name: hello
description: A simple greeting skill
when_to_use: When you need to test Claude Code
---

# Greeting Skill

This is a simple example skill.

## Usage

Simply say "hello" or "hi".
EOF
```

---

## FAQ

### Q: Authentication fails?

**Solutions**:
1. Verify API Key is correct
2. Confirm network can reach Anthropic API
3. Check proxy settings

```bash
# Test connection
curl -s https://api.anthropic.com/v1/messages
```

### Q: Permission denied?

**Solutions**:
1. Check settings.json permission configuration
2. Use --permission-mode acceptEdits for testing

### Q: Command not found?

**Solutions**:
1. Confirm installation succeeded
2. Check PATH environment variable
3. Use full path to run

```bash
/usr/local/bin/claude --version
```
