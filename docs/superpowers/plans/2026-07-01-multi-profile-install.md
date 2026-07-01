# Multi-Profile Skill Installation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `install.sh` install the `cdinfo` skill into any/all detected Claude and Codex profile directories (honoring `$CLAUDE_CONFIG_DIR` / `$CODEX_HOME`) instead of the hardcoded `~/.claude` / `~/.codex`.

**Architecture:** Refactor `install.sh` so its imperative flow lives in a `main()` function guarded by a `BASH_SOURCE`/`$0` check, making pure helper functions sourceable for unit tests. Add three small, testable functions (`active_profile`, `discover_profiles`, `parse_selection`) plus an interactive `select_and_install_skill` that wires discovery → picker → install. A new `test-install.sh` sources `install.sh` and tests the helpers with a temp `$HOME`.

**Tech Stack:** Bash (install.sh runs under `#!/usr/bin/env bash`), existing custom test harness (`pass`/`fail` shell functions).

---

## File Structure

- `install.sh` (modify) — wrap flow in `main()`, add source guard, add helper functions, replace hardcoded skill-install blocks.
- `test-install.sh` (create) — new test file that sources `install.sh` and exercises the helpers.
- `README.md` (modify) — document profile detection / env-var support.
- `AGENTS.md` (modify) — note the new `test-install.sh` command.

Each helper has one responsibility:
- `active_profile base env_value` — pure; returns the "active" profile path.
- `discover_profiles base env_value` — pure (depends only on `$HOME` + args); prints candidate dirs.
- `parse_selection input count default_idx` — pure; converts user input to indices, returns 1 on invalid.
- `select_and_install_skill base env_value name` — interactive glue; not unit-pure but integration-testable via piped stdin.

---

## Task 1: Make `install.sh` sourceable (wrap flow in `main()` + guard)

**Files:**
- Modify: `install.sh` (constants stay at top; imperative body from line 37 onward moves into `main()`; add guard at end)
- Create: `test-install.sh`

- [ ] **Step 1: Create the failing test harness**

Create `test-install.sh`:

```bash
#!/usr/bin/env bash
# test-install.sh - Test install.sh helper functions
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'
pass() { echo -e "${GREEN}PASS${NC}: $1"; }
fail() { echo -e "${RED}FAIL${NC}: $1"; exit 1; }

# Sentinel: set before sourcing. If main() runs on source, it will call
# `exit` or print the completion banner; we assert neither happened by
# checking a marker variable install.sh must NOT clobber.
SOURCE_GUARD_OK=1

# Source install.sh for its functions. The source guard must prevent main().
source "$SCRIPT_DIR/install.sh"

echo "=== install.sh tests ==="
echo ""

# Test 1: sourcing does not execute main()
echo "Test 1: install.sh is sourceable without running main"
[[ "$SOURCE_GUARD_OK" == "1" ]] && pass "sourced without side effects" || fail "main ran on source"

echo ""
echo "=== All install tests passed ==="
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `bash test-install.sh`
Expected: FAIL — either an error like `main: command not found` is absent but the current `install.sh` executes its imperative body on source (prints `[cd-info] ...` status lines and runs interactive `read`, hanging or writing to config). The test does not reach a clean "All install tests passed".

- [ ] **Step 3: Refactor `install.sh` to wrap flow in `main()` with a guard**

In `install.sh`, keep the constants and all `print_*` / `install_to_config` / `install_skill` function definitions where they are. Remove the standalone `CLAUDE_SKILLS_DIR` and `CODEX_SKILLS_DIR` lines (they become unused; new functions compute targets). Move the imperative body — currently the `if [[ ! -f "$CDINFO_PATH" ]]` check (lines 37-41) and everything from `# Detect available shells and install` (line 96) through the final `echo` lines (line 147) — into a new `main()` function, and put `set -e` at the top of `main()` instead of the top of the file.

The end of `install.sh` becomes:

```bash
main() {
    set -e

    # Check if cd-info.sh exists
    if [[ ! -f "$CDINFO_PATH" ]]; then
        print_error "cd-info.sh not found at $CDINFO_PATH"
        exit 1
    fi

    # Detect available shells and install
    local installed=0

    if [[ -f "$HOME/.bashrc" ]] || command -v bash &>/dev/null; then
        install_to_config "$HOME/.bashrc" "bash"
        installed=1
    fi

    if [[ -f "$HOME/.zshrc" ]] || command -v zsh &>/dev/null; then
        install_to_config "$HOME/.zshrc" "zsh"
        installed=1
    fi

    if [[ $installed -eq 0 ]]; then
        print_error "No supported shell config found (.bashrc or .zshrc)"
        exit 1
    fi

    echo ""
    print_success "Shell integration complete!"

    # Ask about AI assistant skill installation
    echo ""
    print_status "Would you like to install skills for AI coding assistants?"
    echo "         This teaches Claude Code and Codex how to create .cdinfo files."

    read -p "         Install Claude Code skill? [y/N] " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        select_and_install_skill ".claude" "${CLAUDE_CONFIG_DIR:-}" "Claude Code"
    fi
    echo ""

    read -p "         Install Codex skill? [y/N] " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        select_and_install_skill ".codex" "${CODEX_HOME:-}" "Codex"
    fi

    print_success "Installation complete!"
    echo ""
    echo "To start using cd-info immediately, run:"
    echo ""
    echo "    source $CDINFO_PATH"
    echo ""
    echo "Or restart your terminal."
    echo ""
    echo "Create a .cdinfo file in any directory to display info when you cd into it."
    echo "See examples/.cdinfo.example for the file format."
}

# Run main only when executed directly, not when sourced (e.g. by tests)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
```

Also remove the `set -e` from line 4 (it now lives inside `main()`), and delete the two hardcoded lines:

```bash
CLAUDE_SKILLS_DIR="$HOME/.claude/skills"
CODEX_SKILLS_DIR="$HOME/.codex/skills"
```

Note: `select_and_install_skill` does not exist yet — it is added in Task 5. Until then `main()` references an undefined function, but `main()` is not invoked by the test (guard) or by later helper tests, so Tasks 1-4 pass. Task 5 defines it.

- [ ] **Step 4: Run the test to verify it passes**

Run: `bash test-install.sh`
Expected: PASS — prints `PASS: sourced without side effects` and `=== All install tests passed ===`.

- [ ] **Step 5: Commit**

```bash
git add install.sh test-install.sh
git commit -m "refactor: make install.sh sourceable for tests via main() guard"
```

---

## Task 2: `active_profile` helper

**Files:**
- Modify: `install.sh` (add function near the other helper functions, after `install_skill`)
- Modify: `test-install.sh` (add test)

- [ ] **Step 1: Write the failing test**

Add to `test-install.sh` before the final banner:

```bash
# Test 2: active_profile returns env value when set
echo "Test 2: active_profile with env value"
[[ "$(active_profile ".claude" "/x/.claude-work")" == "/x/.claude-work" ]] \
    && pass "returns env value" || fail "did not return env value"

# Test 3: active_profile falls back to \$HOME/<base> when env empty
echo "Test 3: active_profile default"
[[ "$(HOME=/tmp/xyz active_profile ".claude" "")" == "/tmp/xyz/.claude" ]] \
    && pass "returns HOME default" || fail "did not return HOME default"
```

- [ ] **Step 2: Run to verify it fails**

Run: `bash test-install.sh`
Expected: FAIL — `active_profile: command not found`.

- [ ] **Step 3: Implement `active_profile`**

Add to `install.sh` after the `install_skill` function (before `main()`):

```bash
# Returns the "active" profile path for a family.
# $1 = base name (e.g. ".claude"), $2 = env var value (may be empty)
active_profile() {
    local base="$1"
    local env_value="$2"
    if [[ -n "$env_value" ]]; then
        echo "$env_value"
    else
        echo "$HOME/$base"
    fi
}
```

- [ ] **Step 4: Run to verify it passes**

Run: `bash test-install.sh`
Expected: PASS — Tests 2 and 3 pass.

- [ ] **Step 5: Commit**

```bash
git add install.sh test-install.sh
git commit -m "feat: add active_profile helper to install.sh"
```

---

## Task 3: `discover_profiles` helper

**Files:**
- Modify: `install.sh` (add function after `active_profile`)
- Modify: `test-install.sh` (add test)

- [ ] **Step 1: Write the failing test**

Add to `test-install.sh` before the final banner:

```bash
# Test 4: discover_profiles globs directories, excludes files
echo "Test 4: discover_profiles globbing"
THOME="$(mktemp -d)"
mkdir -p "$THOME/.claude" "$THOME/.claude-work" "$THOME/.claude-personal"
touch "$THOME/.claude.json"
out="$(HOME="$THOME" discover_profiles ".claude" "")"
count="$(printf '%s\n' "$out" | grep -c .)"
[[ "$count" -eq 3 ]] && pass "found 3 dirs, excluded .claude.json" \
    || fail "expected 3 candidates, got $count"

# Test 5: discover_profiles appends env value when outside the glob
echo "Test 5: discover_profiles appends env target"
out="$(HOME="$THOME" discover_profiles ".claude" "/elsewhere/claude")"
count="$(printf '%s\n' "$out" | grep -c .)"
printf '%s\n' "$out" | grep -q "^/elsewhere/claude$" \
    && [[ "$count" -eq 4 ]] && pass "appended external env target" \
    || fail "did not append env target (count=$count)"

# Test 6: discover_profiles does not duplicate an env value already globbed
echo "Test 6: discover_profiles no duplicate"
out="$(HOME="$THOME" discover_profiles ".claude" "$THOME/.claude-work")"
count="$(printf '%s\n' "$out" | grep -c .)"
[[ "$count" -eq 3 ]] && pass "no duplicate for globbed env target" \
    || fail "expected 3, got $count"

# Test 7: discover_profiles prints nothing when no matches
echo "Test 7: discover_profiles empty"
EMPTYHOME="$(mktemp -d)"
out="$(HOME="$EMPTYHOME" discover_profiles ".claude" "")"
[[ -z "$out" ]] && pass "empty output when no profiles" \
    || fail "expected empty output, got: $out"

rm -rf "$THOME" "$EMPTYHOME"
```

- [ ] **Step 2: Run to verify it fails**

Run: `bash test-install.sh`
Expected: FAIL — `discover_profiles: command not found`.

- [ ] **Step 3: Implement `discover_profiles`**

Add to `install.sh` after `active_profile`:

```bash
# Prints candidate profile directories, one per line (none if no matches).
# $1 = base name (e.g. ".claude"), $2 = env var value (may be empty)
discover_profiles() {
    local base="$1"
    local env_value="$2"
    local -a found=()
    local d

    for d in "$HOME/$base"*; do
        [[ -d "$d" ]] && found+=("$d")
    done

    if [[ -n "$env_value" ]]; then
        local present=0 f
        for f in "${found[@]}"; do
            [[ "$f" == "$env_value" ]] && present=1 && break
        done
        [[ $present -eq 0 ]] && found+=("$env_value")
    fi

    if [[ ${#found[@]} -gt 0 ]]; then
        printf '%s\n' "${found[@]}"
    fi
}
```

- [ ] **Step 4: Run to verify it passes**

Run: `bash test-install.sh`
Expected: PASS — Tests 4-7 pass.

- [ ] **Step 5: Commit**

```bash
git add install.sh test-install.sh
git commit -m "feat: add discover_profiles helper to install.sh"
```

---

## Task 4: `parse_selection` helper

**Files:**
- Modify: `install.sh` (add function after `discover_profiles`)
- Modify: `test-install.sh` (add test)

- [ ] **Step 1: Write the failing test**

Add to `test-install.sh` before the final banner:

```bash
# Test 8: parse_selection empty input returns default index
echo "Test 8: parse_selection default"
[[ "$(parse_selection "" 4 2)" == "2" ]] && pass "empty -> default" \
    || fail "empty did not return default"

# Test 9: parse_selection 'all' expands to every index
echo "Test 9: parse_selection all"
[[ "$(parse_selection "all" 3 1)" == $'1\n2\n3' ]] && pass "all expands" \
    || fail "all did not expand"

# Test 10: parse_selection space- and comma-separated numbers
echo "Test 10: parse_selection numbers"
[[ "$(parse_selection "1 3" 4 1)" == $'1\n3' ]] && pass "space separated" \
    || fail "space separated failed"
[[ "$(parse_selection "1,3" 4 1)" == $'1\n3' ]] && pass "comma separated" \
    || fail "comma separated failed"

# Test 11: parse_selection dedupes repeats
echo "Test 11: parse_selection dedupe"
[[ "$(parse_selection "2 2" 4 1)" == "2" ]] && pass "dedupes" \
    || fail "did not dedupe"

# Test 12: parse_selection rejects out-of-range and non-numeric
echo "Test 12: parse_selection invalid input"
if parse_selection "9" 4 1 >/dev/null 2>&1; then
    fail "accepted out-of-range"
else
    pass "rejected out-of-range"
fi
if parse_selection "x" 4 1 >/dev/null 2>&1; then
    fail "accepted non-numeric"
else
    pass "rejected non-numeric"
fi
```

- [ ] **Step 2: Run to verify it fails**

Run: `bash test-install.sh`
Expected: FAIL — `parse_selection: command not found`.

- [ ] **Step 3: Implement `parse_selection`**

Add to `install.sh` after `discover_profiles`:

```bash
# Converts a selection string into 1-based indices, one per line.
# $1 = raw input, $2 = candidate count, $3 = default index (used when empty).
# Prints selected indices in input order (deduped). Returns 1 on invalid input.
parse_selection() {
    local input="$1"
    local count="$2"
    local default_idx="$3"
    local -a out=()

    # Normalize commas to spaces
    input="$(echo "$input" | tr ',' ' ')"

    # Empty (only whitespace) -> default
    if [[ -z "${input// }" ]]; then
        echo "$default_idx"
        return 0
    fi

    if [[ "${input// }" == "all" ]]; then
        local i
        for ((i = 1; i <= count; i++)); do out+=("$i"); done
        printf '%s\n' "${out[@]}"
        return 0
    fi

    local tok
    for tok in $input; do
        [[ "$tok" =~ ^[0-9]+$ ]] || return 1
        (( tok >= 1 && tok <= count )) || return 1
        local seen=0 x
        for x in "${out[@]}"; do
            [[ "$x" == "$tok" ]] && seen=1 && break
        done
        [[ $seen -eq 0 ]] && out+=("$tok")
    done

    printf '%s\n' "${out[@]}"
    return 0
}
```

- [ ] **Step 4: Run to verify it passes**

Run: `bash test-install.sh`
Expected: PASS — Tests 8-12 pass.

- [ ] **Step 5: Commit**

```bash
git add install.sh test-install.sh
git commit -m "feat: add parse_selection helper to install.sh"
```

---

## Task 5: `select_and_install_skill` (picker + fallback glue)

**Files:**
- Modify: `install.sh` (add function after `parse_selection`)
- Modify: `test-install.sh` (add integration tests)

- [ ] **Step 1: Write the failing test**

Add to `test-install.sh` before the final banner:

```bash
# Test 13: select_and_install_skill installs into multiple selected profiles
echo "Test 13: picker installs to selected profiles"
THOME="$(mktemp -d)"
mkdir -p "$THOME/.claude" "$THOME/.claude-work"
echo "1 2" | HOME="$THOME" select_and_install_skill ".claude" "" "Claude Code" >/dev/null 2>&1
[[ -d "$THOME/.claude/skills/cdinfo" && -d "$THOME/.claude-work/skills/cdinfo" ]] \
    && pass "installed into both selected profiles" \
    || fail "did not install into both profiles"
rm -rf "$THOME"

# Test 14: empty-input selects the pre-selected active (env) profile only
echo "Test 14: picker default selects active profile"
THOME="$(mktemp -d)"
mkdir -p "$THOME/.claude" "$THOME/.claude-work"
# env value points at .claude-work, so Enter (empty) should pick only that one
printf '\n' | HOME="$THOME" select_and_install_skill ".claude" "$THOME/.claude-work" "Claude Code" >/dev/null 2>&1
[[ -d "$THOME/.claude-work/skills/cdinfo" && ! -d "$THOME/.claude/skills/cdinfo" ]] \
    && pass "default installed only active profile" \
    || fail "default selection wrong"
rm -rf "$THOME"

# Test 15: fallback offers to create default when no profiles exist
echo "Test 15: fallback creates default profile"
THOME="$(mktemp -d)"
echo "y" | HOME="$THOME" select_and_install_skill ".claude" "" "Claude Code" >/dev/null 2>&1
[[ -d "$THOME/.claude/skills/cdinfo" ]] && pass "fallback created default" \
    || fail "fallback did not create default"
rm -rf "$THOME"
```

- [ ] **Step 2: Run to verify it fails**

Run: `bash test-install.sh`
Expected: FAIL — `select_and_install_skill: command not found`.

- [ ] **Step 3: Implement `select_and_install_skill`**

Add to `install.sh` after `parse_selection`:

```bash
# Interactive: discover profiles for a family, prompt for selection, and
# install the skill into each selected dir's skills/ subdir.
# $1 = base name, $2 = env var value, $3 = display name
select_and_install_skill() {
    local base="$1"
    local env_value="$2"
    local name="$3"

    local active
    active="$(active_profile "$base" "$env_value")"

    local -a candidates=()
    local line
    while IFS= read -r line; do
        [[ -n "$line" ]] && candidates+=("$line")
    done < <(discover_profiles "$base" "$env_value")

    # Fallback: no candidates found
    if [[ ${#candidates[@]} -eq 0 ]]; then
        print_warning "No $name profiles found."
        read -p "         Create and install into $active? [y/N] " -n 1 -r
        echo ""
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            install_skill "$active/skills" "$name"
        fi
        return 0
    fi

    # Determine default index (position of active profile, else 1)
    local default_idx=1 i
    for i in "${!candidates[@]}"; do
        if [[ "${candidates[$i]}" == "$active" ]]; then
            default_idx=$((i + 1))
            break
        fi
    done

    print_status "Select $name profile(s) to install the cdinfo skill into:"
    for i in "${!candidates[@]}"; do
        local num=$((i + 1))
        local marker=""
        [[ $num -eq $default_idx ]] && marker="  *  (active, default)"
        echo "           $num) ${candidates[$i]}$marker"
    done

    local selection raw
    while true; do
        read -p "         Enter numbers (space/comma separated), 'all', or Enter for default: " -r raw
        if selection="$(parse_selection "$raw" "${#candidates[@]}" "$default_idx")"; then
            break
        fi
        print_warning "Invalid selection, try again."
    done

    local idx
    while IFS= read -r idx; do
        [[ -z "$idx" ]] && continue
        install_skill "${candidates[$((idx - 1))]}/skills" "$name"
    done <<< "$selection"
}
```

- [ ] **Step 4: Run to verify it passes**

Run: `bash test-install.sh`
Expected: PASS — Tests 13-15 pass.

- [ ] **Step 5: Commit**

```bash
git add install.sh test-install.sh
git commit -m "feat: add multi-profile picker to install.sh skill install"
```

---

## Task 6: Syntax check + full regression run

**Files:**
- No code changes; verification only.

- [ ] **Step 1: Bash syntax check for install.sh**

Run: `bash -n install.sh`
Expected: no output, exit 0.

- [ ] **Step 2: Run the new install test suite**

Run: `bash test-install.sh`
Expected: ends with `=== All install tests passed ===`.

- [ ] **Step 3: Run the existing suite to confirm no regressions**

Run: `./test.sh`
Expected: ends with `=== All tests passed ===`.

- [ ] **Step 4: Manual smoke test against real multi-claude setup**

Run: `bash install.sh` and, at the Claude prompt, confirm the picker lists your real `~/.claude*` profiles with `~/.claude-personal` marked `*  (active, default)`. Select `~/.claude-personal` and verify:

Run: `ls ~/.claude-personal/skills/cdinfo`
Expected: the skill files are present.

(Answer `N` to Codex, or test it too if desired.)

- [ ] **Step 5: Commit (if any fixes were needed)**

```bash
git add -A
git commit -m "test: verify multi-profile install end to end"
```

---

## Task 7: Update documentation

**Files:**
- Modify: `README.md` (Installation section, around lines 30-41)
- Modify: `AGENTS.md` (Testing section, around lines 44-52)

- [ ] **Step 1: Update README Installation section**

In `README.md`, after the manual-install code block (line 41), add:

```markdown

### AI assistant skills

The installer can also install a skill that teaches Claude Code and Codex how to
create `.cdinfo` files. It detects your profile directories automatically:

- Any `~/.claude*` directory is offered in a picker (so multi-profile / "multi-claude"
  setups work), and you can install into one, several, or all of them.
- `$CLAUDE_CONFIG_DIR` and `$CODEX_HOME` are honored: the active profile is
  pre-selected as the default, and a custom path outside `~/.claude*` is included.
- On a fresh machine with no profiles, it offers to create the default
  (`~/.claude` / `~/.codex`, or the env-var path if set).
```

- [ ] **Step 2: Update AGENTS.md Testing section**

In `AGENTS.md`, change the Testing section (line 46) from:

```markdown
Run `./test.sh` after any changes. Tests cover:
```

to:

```markdown
Run `./test.sh` after any changes (covers `cd-info.sh`). Run `bash test-install.sh`
to test `install.sh` helper functions. Tests cover:
```

Also add to the File Structure block (after the `test.sh` line, line 21):

```markdown
├── test-install.sh # install.sh helper tests
```

- [ ] **Step 3: Commit**

```bash
git add README.md AGENTS.md
git commit -m "docs: document multi-profile skill install"
```

---

## Self-Review Notes

- **Spec coverage:** profile discovery (Task 3), env-var include + pre-select active (Tasks 2, 3, 5), multi-select picker with `all`/default/invalid handling (Tasks 4, 5), fresh-machine fallback (Task 5), Codex via same path (Task 1 `main()` passes `.codex`/`$CODEX_HOME`), docs (Task 7), tests (Tasks 2-6). All spec sections mapped.
- **Type/name consistency:** function names `active_profile`, `discover_profiles`, `parse_selection`, `select_and_install_skill`, and existing `install_skill` are used identically across tasks. `install_skill` is called with `<dir>/skills` as its first arg (matching its existing `skills_dir` parameter, which appends `/cdinfo`).
- **Ordering note:** `parse_selection` outputs indices in input order (not sorted); tests use already-ascending inputs so expectations are deterministic.
