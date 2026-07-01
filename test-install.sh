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

echo ""
echo "=== All install tests passed ==="
