# Multi-Profile Skill Installation for `install.sh`

**Date:** 2026-07-01
**Status:** Approved (design)

## Problem

`install.sh` hardcodes the AI-assistant skill install targets:

```bash
CLAUDE_SKILLS_DIR="$HOME/.claude/skills"
CODEX_SKILLS_DIR="$HOME/.codex/skills"
```

Users running "multi-claude" style setups keep their Claude config under
non-standard directories (e.g. `~/.claude-personal`, `~/.claude-work`) selected
via the `$CLAUDE_CONFIG_DIR` environment variable, and Codex via `$CODEX_HOME`.
The installer ignores these, so the skill lands in `~/.claude/skills`, which the
active profile never reads. There is no flag, prompt, or env-var support to
redirect it.

The shell-integration portion of the installer (the `source` line added to
`.bashrc`/`.zshrc`) is already path-independent and is **out of scope**.

## Goals

- Install the `cdinfo` skill into the Claude/Codex profile(s) the user actually
  uses, including non-standard directories.
- Support installing into **multiple** profiles in a single run (e.g. personal
  and work).
- Respect `$CLAUDE_CONFIG_DIR` / `$CODEX_HOME`.
- Preserve existing behavior on a fresh machine with no profiles.

## Non-Goals

- Changing shell integration (the `source` line logic).
- Non-interactive / fully-scripted install flags. The skill-install flow is
  already interactive; keep it interactive.
- Validating that a directory is a "real" config dir — any matching directory is
  treated as a candidate.

## Design

### Profile discovery (shared, per family)

A single reusable function handles both Claude and Codex, parameterized by:

- base name — `.claude` or `.codex`
- env var name — `CLAUDE_CONFIG_DIR` or `CODEX_HOME`

Steps:

1. Glob `$HOME/<base>*`, keeping **directories only**. Because `.claude.json` is
   a file, it is naturally excluded.
2. If the env var is set and its path is not already in the list, append it.
   (This allows targets outside the `~/.claude*` glob, e.g. `~/work/claude`.)
3. Dedupe → candidate list.

### The picker

When the candidate list is non-empty, present a numbered **multi-select** list:

```
Select Claude profile(s) to install the cdinfo skill into:
  1) ~/.claude
  2) ~/.claude-personal  *  (active, default)
  3) ~/.claude-profile
  4) ~/.claude-work
Enter numbers (space/comma separated), 'all', or press Enter for default:
```

Rules:

- The **active** profile is marked `*` and is the default when the user presses
  Enter with no input. "Active" = the candidate whose path equals the env var;
  if the env var is unset, `$HOME/<base>` (e.g. `~/.claude`).
- Accepted input: space/comma-separated index numbers, the literal `all`, or
  empty (= default selection).
- Invalid input (non-numeric, out-of-range) re-prompts rather than aborting.
- For each selected directory, install the skill to
  `<selected>/skills/cdinfo`, reusing the existing `install_skill` copy logic
  (which already handles create-dir-if-missing and replace-if-existing).

### Fresh-machine fallback

If the glob finds no matching directories:

- Fall back to today's behavior: offer to create and install into the env-var
  path if set, otherwise `$HOME/<base>` (`~/.claude` / `~/.codex`).

### Surrounding flow (unchanged)

The two top-level gates remain:

- `Install Claude Code skill? [y/N]`
- `Install Codex skill? [y/N]`

Answering `y` now launches the picker for that family instead of writing to a
hardcoded path.

### Codex

Codex uses the identical picker path, globbing `$HOME/.codex*` and honoring
`$CODEX_HOME`. Today this typically lists a single directory, which is fine.

## Affected Code

- `install.sh`:
  - Remove hardcoded `CLAUDE_SKILLS_DIR` / `CODEX_SKILLS_DIR` constants.
  - Add a profile-discovery function and a picker function.
  - Rework the two `[y/N]` blocks to call discovery + picker, then invoke
    `install_skill` once per selected directory.
  - `install_skill` itself (copy logic) is largely reusable as-is.

## Testing

- Extend `test.sh` (or add cases) covering:
  - Discovery globs multiple `~/.claude*` dirs (use a temp `$HOME`).
  - Env-var path appended when outside the glob.
  - Env-var path pre-selected as default (Enter selects it).
  - `all` selects every candidate.
  - Multiple explicit selections install to each.
  - Empty candidate list falls back to create-default behavior.
  - Invalid input re-prompts.
- Manual smoke test with the real multi-claude setup
  (`~/.claude-personal`, `~/.claude-work`).

## Documentation

- Update `README.md` installation section to mention that the installer detects
  `~/.claude*` profiles and honors `$CLAUDE_CONFIG_DIR` / `$CODEX_HOME`.
