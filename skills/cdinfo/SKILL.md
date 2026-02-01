---
name: cdinfo
description: Create a .cdinfo file for the current repository. Use when asked to create a cdinfo file, add directory info, or set up cd-info for a project.
---

# Create cdinfo File

Create a `.cdinfo` file for the current repository that displays helpful project information when users `cd` into the directory.

## File Format

The `.cdinfo` file has two sections:

1. **Header (optional)** - Hidden metadata before the marker `# --- END CD-INFO HEADER ---`
2. **Content** - Everything after the marker is displayed to the user

## Syntax Highlighting

The cd-info tool automatically highlights:
- Lines starting with `#` → Magenta (use for section headers)
- Lines starting with `-` → Yellow bullet (use for list items)
- Text in backticks → Green (use for commands)
- URLs (http/https) → Blue (use for links)

## Template

```
# ============================================================
# This file is used by cd-info to display directory information
# Learn more: https://github.com/wrathagom/cd-info
# ============================================================
# --- END CD-INFO HEADER ---

# Quick Commands
  - `<common command 1>`  <description>
  - `<common command 2>`  <description>

# Development
  - `<dev command>`  <description>

# Links
  - Docs: <url>
  - Issues: <url>
```

## Instructions

1. Analyze the repository to understand:
   - The project type (Node, Python, Go, Rust, etc.)
   - Common commands from package.json, Makefile, README, etc.
   - Important links (docs, issues, CI/CD)
   - Any setup or prerequisites

2. Create a `.cdinfo` file in the repository root with:
   - The standard header (hidden section)
   - Quick commands section with the most frequently used commands
   - Additional sections as relevant (Development, Testing, Deployment, Links)

3. Keep it concise - show only the most useful 5-10 commands

4. Use proper indentation (2 spaces) for list items to align nicely

## Examples

### Node.js Project
```
# --- END CD-INFO HEADER ---

# Quick Commands
  - `npm install`     Install dependencies
  - `npm run dev`     Start dev server
  - `npm test`        Run tests
  - `npm run build`   Build for production

# Links
  - Docs: https://example.com/docs
```

### Python Project
```
# --- END CD-INFO HEADER ---

# Quick Commands
  - `pip install -e .`   Install in dev mode
  - `pytest`             Run tests
  - `python -m app`      Run the app

# Virtual Environment
  - `python -m venv .venv && source .venv/bin/activate`
```

### Go Project
```
# --- END CD-INFO HEADER ---

# Quick Commands
  - `go build`       Build the binary
  - `go test ./...`  Run all tests
  - `go run .`       Run directly

# Development
  - `make lint`      Run linters
  - `make docker`    Build Docker image
```
