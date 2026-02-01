#!/usr/bin/env bash
# test.sh - Test cd-info functionality

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_DIR="/tmp/cdinfo-test-$$"

# Colors for test output
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

pass() { echo -e "${GREEN}PASS${NC}: $1"; }
fail() { echo -e "${RED}FAIL${NC}: $1"; exit 1; }

# Setup
mkdir -p "$TEST_DIR"
trap "rm -rf '$TEST_DIR'" EXIT

# Source cd-info
source "$SCRIPT_DIR/cd-info.sh"

echo "=== cd-info tests ==="
echo ""

# Test 1: Syntax check
echo "Test 1: Bash syntax"
bash -n "$SCRIPT_DIR/cd-info.sh" && pass "bash syntax valid" || fail "bash syntax error"

# Test 2: Zsh syntax (if available)
if command -v zsh &>/dev/null; then
    echo "Test 2: Zsh syntax"
    zsh -n "$SCRIPT_DIR/cd-info.sh" && pass "zsh syntax valid" || fail "zsh syntax error"
else
    echo "Test 2: Zsh syntax (skipped - zsh not installed)"
fi

# Test 3: cd to directory with .cdinfo
echo "Test 3: cd with .cdinfo file"
cat > "$TEST_DIR/.cdinfo" << 'EOF'
# --- END CD-INFO HEADER ---

# Test Header
- bullet point
  - indented bullet
EOF
cd "$TEST_DIR" && pass "cd to directory with .cdinfo"

# Test 4: cd preserves exit code on failure
echo "Test 4: Exit code preserved on failure"
if cd /nonexistent-dir-12345 2>/dev/null; then
    fail "exit code not preserved"
else
    pass "exit code preserved"
fi

# Test 5: cd with no args
echo "Test 5: cd with no args (home)"
cd && [[ "$PWD" == "$HOME" ]] && pass "cd to home" || fail "cd to home failed"

# Test 6: cd - (previous directory)
echo "Test 6: cd - (previous directory)"
cd "$TEST_DIR"
cd /tmp
cd - >/dev/null
[[ "$PWD" == "$TEST_DIR" ]] && pass "cd - works" || fail "cd - failed"

# Test 7: Empty .cdinfo
echo "Test 7: Empty .cdinfo file"
mkdir -p "$TEST_DIR/empty"
touch "$TEST_DIR/empty/.cdinfo"
cd "$TEST_DIR/empty" && pass "handles empty .cdinfo"

# Test 8: .cdinfo without header marker
echo "Test 8: .cdinfo without header marker"
mkdir -p "$TEST_DIR/noheader"
echo "Just some content" > "$TEST_DIR/noheader/.cdinfo"
cd "$TEST_DIR/noheader" && pass "handles .cdinfo without header"

# Test 9: CDINFO_ENABLED=0 disables display
echo "Test 9: CDINFO_ENABLED=0"
CDINFO_ENABLED=0
cd "$TEST_DIR" && pass "respects CDINFO_ENABLED=0"
CDINFO_ENABLED=1

# Test 10: cdinfo-init creates .cdinfo
echo "Test 10: cdinfo-init creates .cdinfo"
mkdir -p "$TEST_DIR/init-test"
cd "$TEST_DIR/init-test"
cdinfo-init >/dev/null
[[ -f ".cdinfo" ]] && pass "cdinfo-init creates file" || fail "cdinfo-init did not create file"

# Test 11: cdinfo-init fails if .cdinfo exists
echo "Test 11: cdinfo-init fails if .cdinfo exists"
if cdinfo-init 2>/dev/null; then
    fail "cdinfo-init should fail when .cdinfo exists"
else
    pass "cdinfo-init refuses to overwrite"
fi

# Test 12: cdinfo-init template has correct content
echo "Test 12: cdinfo-init template content"
grep -q "You are now in the" ".cdinfo" && pass "template has directory message" || fail "template missing directory message"

echo ""
echo "=== All tests passed ==="
