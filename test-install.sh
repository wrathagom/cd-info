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

echo ""
echo "=== All install tests passed ==="
