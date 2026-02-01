#!/usr/bin/env bash
# install.sh - Install cd-info by adding source line to shell config files

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CDINFO_PATH="$SCRIPT_DIR/cd-info.sh"
SOURCE_LINE="source \"$CDINFO_PATH\""
MARKER="# cd-info"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${CYAN}[cd-info]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[cd-info]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[cd-info]${NC} $1"
}

print_error() {
    echo -e "${RED}[cd-info]${NC} $1"
}

# Check if cd-info.sh exists
if [[ ! -f "$CDINFO_PATH" ]]; then
    print_error "cd-info.sh not found at $CDINFO_PATH"
    exit 1
fi

# Function to install to a config file
install_to_config() {
    local config_file="$1"
    local shell_name="$2"

    # Check if file exists
    if [[ ! -f "$config_file" ]]; then
        print_warning "$config_file does not exist, creating it..."
        touch "$config_file"
    fi

    # Check if already installed
    if grep -q "cd-info.sh" "$config_file" 2>/dev/null; then
        print_warning "cd-info already installed in $config_file"
        return 0
    fi

    # Add source line
    echo "" >> "$config_file"
    echo "$MARKER" >> "$config_file"
    echo "$SOURCE_LINE" >> "$config_file"

    print_success "Added cd-info to $config_file"
}

# Detect available shells and install
installed=0

# Check for bash
if [[ -f "$HOME/.bashrc" ]] || command -v bash &>/dev/null; then
    install_to_config "$HOME/.bashrc" "bash"
    installed=1
fi

# Check for zsh
if [[ -f "$HOME/.zshrc" ]] || command -v zsh &>/dev/null; then
    install_to_config "$HOME/.zshrc" "zsh"
    installed=1
fi

if [[ $installed -eq 0 ]]; then
    print_error "No supported shell config found (.bashrc or .zshrc)"
    exit 1
fi

echo ""
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
