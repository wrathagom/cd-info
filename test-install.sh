#!/usr/bin/env bash
# test-install.sh - Test install.sh helper functions
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'
pass() { echo -e "${GREEN}PASS${NC}: $1"; }
fail() { echo -e "${RED}FAIL${NC}: $1"; exit 1; }

# Track temp dirs so they are cleaned up on any exit path (including fail()).
TMPDIRS=()
mktmp() { local d; d="$(mktemp -d)"; TMPDIRS+=("$d"); echo "$d"; }
trap 'rm -rf "${TMPDIRS[@]}"' EXIT

# Source install.sh for its functions. The source guard must prevent main().
source "$SCRIPT_DIR/install.sh"

echo "=== install.sh tests ==="
echo ""

# Test 1: sourcing does not execute main().
# Source in a subshell under a sandboxed HOME and assert it produces no output.
# If the guard were removed, main() would run and print status/banner lines
# (or block on prompts), so this fails when the guard is broken.
echo "Test 1: install.sh is sourceable without running main"
out="$(HOME="$(mktmp)" bash -c 'source "'"$SCRIPT_DIR"'/install.sh"' </dev/null 2>&1)"
[[ -z "$out" ]] && pass "sourced without side effects" || fail "main ran on source: $out"

# Test 2: active_profile returns env value when set
echo "Test 2: active_profile with env value"
[[ "$(active_profile ".claude" "/x/.claude-work")" == "/x/.claude-work" ]] \
    && pass "returns env value" || fail "did not return env value"

# Test 3: active_profile falls back to \$HOME/<base> when env empty
echo "Test 3: active_profile default"
[[ "$(HOME=/tmp/xyz active_profile ".claude" "")" == "/tmp/xyz/.claude" ]] \
    && pass "returns HOME default" || fail "did not return HOME default"

# Test 4: discover_profiles globs directories, excludes files
echo "Test 4: discover_profiles globbing"
THOME="$(mktmp)"
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

# Test 6b: discover_profiles ignores a trailing slash on the env value
echo "Test 6b: discover_profiles trailing-slash env no duplicate"
out="$(HOME="$THOME" discover_profiles ".claude" "$THOME/.claude-work/")"
count="$(printf '%s\n' "$out" | grep -c .)"
[[ "$count" -eq 3 ]] && pass "trailing slash not duplicated" \
    || fail "expected 3, got $count"

# Test 7: discover_profiles prints nothing when no matches
echo "Test 7: discover_profiles empty"
EMPTYHOME="$(mktmp)"
out="$(HOME="$EMPTYHOME" discover_profiles ".claude" "")"
[[ -z "$out" ]] && pass "empty output when no profiles" \
    || fail "expected empty output, got: $out"

rm -rf "$THOME" "$EMPTYHOME"

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

# Test 13: select_and_install_skill installs into multiple selected profiles
echo "Test 13: picker installs to selected profiles"
THOME="$(mktmp)"
mkdir -p "$THOME/.claude" "$THOME/.claude-work"
echo "1 2" | HOME="$THOME" select_and_install_skill ".claude" "" "Claude Code" >/dev/null 2>&1
[[ -d "$THOME/.claude/skills/cdinfo" && -d "$THOME/.claude-work/skills/cdinfo" ]] \
    && pass "installed into both selected profiles" \
    || fail "did not install into both profiles"
rm -rf "$THOME"

# Test 14: empty-input selects the pre-selected active (env) profile only
echo "Test 14: picker default selects active profile"
THOME="$(mktmp)"
mkdir -p "$THOME/.claude" "$THOME/.claude-work"
# env value points at .claude-work, so Enter (empty) should pick only that one
printf '\n' | HOME="$THOME" select_and_install_skill ".claude" "$THOME/.claude-work" "Claude Code" >/dev/null 2>&1
[[ -d "$THOME/.claude-work/skills/cdinfo" && ! -d "$THOME/.claude/skills/cdinfo" ]] \
    && pass "default installed only active profile" \
    || fail "default selection wrong"
rm -rf "$THOME"

# Test 15: fallback offers to create default when no profiles exist
echo "Test 15: fallback creates default profile"
THOME="$(mktmp)"
echo "y" | HOME="$THOME" select_and_install_skill ".claude" "" "Claude Code" >/dev/null 2>&1
[[ -d "$THOME/.claude/skills/cdinfo" ]] && pass "fallback created default" \
    || fail "fallback did not create default"
rm -rf "$THOME"

echo ""
echo "=== All install tests passed ==="
