# 11.4 Development Examples

> Creating a complete Claude Code plugin from scratch

---

## Example: Code Review Plugin

### Project Structure

```
code-review-plugin/
├── .claude-plugin/
│   └── plugin.json
├── skills/
│   └── review/
│       └── SKILL.md
├── agents/
│   └── reviewer.md
├── hooks/
│   ├── hooks.json
│   └── security-hook.sh
└── output-styles/
    └── review.css
```

> Note: Plugin manifest must be located in `.claude-plugin/plugin.json`, not `manifest.json` in root directory.

---

## Step 1: Create Project

```bash
mkdir code-review-plugin && cd code-review-plugin
mkdir -p .claude-plugin skills/review agents hooks output-styles
```

---

## Step 2: Create plugin.json

```json
{
  "name": "code-review-plugin",
  "version": "1.0.0",
  "description": "Code review plugin - Automatically check code quality and security issues",
  "author": {
    "name": "Developer"
  },
  "skills": "./skills",
  "agents": "./agents",
  "hooks": "./hooks",
  "outputStyles": "./output-styles",
  "mcpServers": {
    "eslint-server": {
      "command": "npx",
      "args": ["-y", "eslint-lsp"]
    }
  },
  "userConfig": {
    "enabled": {
      "type": "boolean",
      "description": "Enable code review",
      "default": true
    },
    "strictMode": {
      "type": "boolean",
      "description": "Strict mode",
      "default": false
    }
  }
}
```

> Note: skills/agents/hooks configuration only supports path strings or arrays, does not support `{ directory, autoLoad }` object format.

---

## Step 3: Create Skill

### skills/review/SKILL.md

```markdown
---
name: code-review
description: Automated code review assistant
when_to_use: Use when you need to review code or perform PR review
paths:
  - "*.ts"
  - "*.tsx"
  - "*.js"
  - "*.jsx"
tools:
  - Read
  - Glob
  - Grep
  - Bash(npm run lint)
  - Bash(git *)
version: "1.0.0"
---

# Code Review Assistant

Helps you perform code reviews, discovering potential issues and improvement suggestions.

## Review Scope

1. **Code Quality**
   - Code style
   - Naming conventions
   - Comment completeness

2. **Security**
   - SQL injection risks
   - XSS vulnerabilities
   - Sensitive information leakage

3. **Performance**
   - Redundant calculations
   - Memory leaks
   - Database query efficiency

4. **Maintainability**
   - Complexity
   - Coupling
   - Test coverage

## Usage

Use code-review skill to review code:

```
> Use code-review skill to review this file
> Use code-review skill to review PR
```

## Output Format

Review report includes: Issue list, severity ratings, security assessment, readability assessment, etc.
```

---

## Step 4: Create Agent

### agents/reviewer.md

```markdown
---
name: code-reviewer
description: Professional code review Agent
model: sonnet
effort: medium
tools:
  - Read
  - Glob
  - Grep
  - Bash(npm run lint)
  - Bash(npm test)
  - Bash(git diff)
  - Bash(git log)
disallowedTools:
  - Bash(rm -rf *)
  - Bash(sudo *)
  - Write(/etc/**)
maxTurns: 50
memory: project
skills:
  - code-review
  - security-check
hooks:
  PreToolUse:
    - matcher: "Bash"
      hooks:
        - type: command
          command: "${CLAUDE_PLUGIN_ROOT}/hooks/security-check.sh"
          timeout: 5
color: blue
---

# Code Review Expert Agent

This Agent focuses on code quality and security review.

I am a senior code review expert focused on:

1. **Security Review**
   - Identify SQL injection, XSS, CSRF and other security vulnerabilities
   - Check sensitive information handling
   - Verify authentication/authorization logic

2. **Code Quality**
   - Follow project code conventions
   - Check naming and comments
   - Evaluate code complexity

3. **Performance Optimization**
   - Identify performance bottlenecks
   - Suggest optimization solutions
   - Check resource usage

4. **Best Practices**
   - Use modern language features
   - Follow SOLID principles
   - Appropriate error handling

Please provide specific improvement suggestions and code examples.
```

---

## Step 5: Create Hook

### hooks/security-hook.sh

```bash
#!/bin/bash
# Code security review Hook

COMMAND="$1"
TOOL_INPUT="$2"

# Check dangerous operations
if echo "$TOOL_INPUT" | grep -qE "eval\(|exec\(|system\("; then
    echo "Warning: Potential security risk — Dynamic code execution"
    exit 0
fi

# Check hardcoded credentials
if echo "$TOOL_INPUT" | grep -qE "password\s*=\s*['\"][^'\"]+['\"]"; then
    echo "Warning: Hardcoded password detected"
    exit 0
fi

exit 0
```

### hooks/hooks.json

```json
{
  "description": "Code security review hooks",
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PLUGIN_ROOT}/hooks/security-hook.sh",
            "timeout": 5
          }
        ]
      }
    ],
    "UserPromptSubmit": [
      {
        "matcher": "*commit*",
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PLUGIN_ROOT}/hooks/pre-commit-check.sh",
            "timeout": 30
          }
        ]
      }
    ]
  }
}
```

---

## Step 6: Create output-styles

### output-styles/review.css

```css
/* Code review output styles */
.code-review {
  font-family: monospace;
  padding: 1em;
}

.review-issue {
  border-left: 3px solid var(--severity-color);
  padding-left: 1em;
  margin: 0.5em 0;
}

.review-issue.high { border-color: #dc3545; }
.review-issue.medium { border-color: #ffc107; }
.review-issue.low { border-color: #28a745; }
```

---

## Step 7: Local Testing

```bash
# Verify plugin structure
cd code-review-plugin
ls -la .claude-plugin/

# Install in Claude Code
claude plugin install ./code-review-plugin

# Test
> Use code-review skill to review src/auth/login.ts
```

---

## Complete Directory

```
code-review-plugin/
├── .claude-plugin/
│   └── plugin.json
├── skills/
│   └── review/
│       └── SKILL.md
├── agents/
│   └── reviewer.md
├── hooks/
│   ├── hooks.json
│   └── security-hook.sh
└── output-styles/
    └── review.css
```

---

## Next Steps

Congratulations on completing your first plugin! Continue exploring:

- MCP Server integration
- LSP Server integration
- Message channels (Telegram/Slack/Discord)
- Enterprise policy configuration
