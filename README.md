# cd-info

A simple shell function that displays helpful project information when you `cd` into a directory containing a `.cdinfo` file.

## Demo

```
$ cd ~/Projects/cd-info
╭──────────────────────────────────────────────────────────╮
│                                                          │
│ # Getting Started                                        │
│   - `source ./cd-info.sh`   Try it in current shell      │
│   - `./install.sh`          Install permanently          │
│                                                          │
│ # Links                                                  │
│   - Repo: https://github.com/wrathagom/cd-info           │
│                                                          │
╰──────────────────────────────────────────────────────────╯
```

With syntax highlighting:
- `#` headers in **magenta**
- `-` bullets in **yellow**
- `` `code` `` in **green**
- URLs in **blue**
- Box border in **cyan**

All colors respect your terminal theme.

## Installation

```bash
git clone https://github.com/wrathagom/cd-info.git
cd cd-info
./install.sh
```

Or manually add to your `~/.bashrc` or `~/.zshrc`:

```bash
source /path/to/cd-info/cd-info.sh
```

## Agent Skill

This repo includes an agent skill named `cdinfo` (see `AGENTS.md`) for AI assistants to create `.cdinfo` files for projects.

## Usage

Create a `.cdinfo` file in any directory using the init command:

```bash
cd ~/Projects/my-app
cdinfo-init
```

Or create one manually:

```bash
cat > .cdinfo << 'EOF'
# Quick Commands
  - `./test.sh`  Run tests
  - `ls -la`     List files
EOF
```

Now whenever you `cd` into that directory, the info will be displayed.

## .cdinfo File Format

### Simple Format

Just put the text you want displayed:

```
# Quick Commands
  - `./test.sh`  Run tests
  - `ls -la`     List files
```

### With Header (Recommended)

Use a header block to add metadata that won't be displayed:

```
# ============================================================
# This file is used by cd-info to display directory information
# Learn more: https://github.com/wrathagom/cd-info
# ============================================================
# --- END CD-INFO HEADER ---

# Getting Started
  - `source ./cd-info.sh`   Try it in current shell
  - `./install.sh`          Install permanently

# Links
  - Repo: https://github.com/wrathagom/cd-info
```

Everything after `# --- END CD-INFO HEADER ---` will be displayed.

### Syntax Highlighting

| Syntax | Color | Example |
|--------|-------|---------|
| `# text` | Magenta | Section headers |
| `- text` | Yellow bullet | List items (can be indented) |
| `` `text` `` | Green | Inline code/commands |
| `https://...` | Blue | URLs |

## Commands

| Command | Description |
|---------|-------------|
| `cdinfo-init` | Create a `.cdinfo` template in the current directory |

## Configuration

Set these environment variables to customize behavior:

| Variable | Default | Description |
|----------|---------|-------------|
| `CDINFO_ENABLED` | `1` | Set to `0` to disable cd-info |
| `CDINFO_COLOR_ENABLED` | `1` | Set to `0` to disable colored output |
| `CDINFO_HEADER_MARKER` | `# --- END CD-INFO HEADER ---` | Custom header end marker |

Example:

```bash
# Disable colors
export CDINFO_COLOR_ENABLED=0

# Temporarily disable cd-info
export CDINFO_ENABLED=0
```

## How It Works

cd-info creates a shell function named `cd` that:

1. Calls `builtin cd` with all your arguments
2. Checks if the new directory contains a `.cdinfo` file
3. Displays the contents in a formatted box with syntax highlighting
4. Preserves the original exit code

It's designed to be invisible when there's no `.cdinfo` file and won't interfere with scripts or non-interactive shells.

## Compatibility

- Bash 4.0+
- Zsh 5.0+

## Development

Run the test suite:

```bash
./test.sh
```

## Tips

- Add `.cdinfo` to your global `.gitignore` if you don't want to commit these files
- Or commit them to share helpful commands with your team
- Use consistent formatting across projects for a better experience

## License

MIT
