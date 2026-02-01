# AGENTS.md

This file provides context for AI agents working on this codebase.

## Project Overview

cd-info is a shell function that displays helpful project information when users `cd` into directories containing a `.cdinfo` file. It wraps the shell's builtin `cd` command.

## Architecture

### Why a shell function?

`cd` is a shell builtin and cannot be replaced by an external binary. The working directory is per-process, so an external program changing directories wouldn't affect the parent shell. We must use a shell function that calls `builtin cd`.

### File Structure

```
cd-info/
├── cd-info.sh      # Main shell function (source this)
├── install.sh      # Adds source line to ~/.bashrc and ~/.zshrc
├── test.sh         # Test suite
├── README.md       # User documentation
├── AGENTS.md       # This file
├── .cdinfo         # Example for this repo
└── examples/
    └── .cdinfo.example
```

### Key Functions

- `cd()` - Overrides builtin cd, calls `_cdinfo_display` on success
- `_cdinfo_display()` - Parses and renders `.cdinfo` content in a box
- `cdinfo-init()` - Creates a template `.cdinfo` in current directory

## Code Conventions

### Shell Compatibility

- Must work in both Bash 4.0+ and Zsh 5.0+
- Use `[[` for conditionals (supported by both)
- Use `local` for function-scoped variables
- Avoid bashisms that don't work in zsh

### Testing

Run `./test.sh` after any changes. Tests cover:
- Syntax validation (bash and zsh)
- cd behavior (with/without .cdinfo, failure cases)
- Exit code preservation
- Configuration options
- cdinfo-init command

### Colors

Uses standard ANSI color codes (0-7 range) so colors respect terminal themes:
- 32: Green (inline code)
- 33: Yellow (bullets)
- 34: Blue (URLs)
- 35: Magenta (headers)
- 36: Cyan (box border)

## .cdinfo File Format

Content before `# --- END CD-INFO HEADER ---` is hidden. Everything after is displayed with syntax highlighting:

- Lines starting with `#` are headers (magenta)
- Lines starting with `-` (optionally indented) are bullets (yellow dash)
- Text between backticks is code (green)
- URLs starting with `http://` or `https://` are highlighted (blue)

## Common Tasks

### Adding a new syntax highlight

1. Add color variable in the color codes section
2. Add detection logic in the print loop
3. Update README.md syntax table
4. Add test case if needed

### Modifying box rendering

The box uses Unicode box-drawing characters (╭╮╰╯│─). Width is calculated from the longest line. Padding is added inside the box (2 spaces each side).

## Edge Cases to Preserve

- `cd` with no args goes to $HOME
- `cd -` goes to previous directory
- Failed `cd` commands preserve exit code and don't display anything
- Non-TTY output disables display (for scripts)
- Empty .cdinfo files are handled gracefully
- Missing header marker displays entire file content
