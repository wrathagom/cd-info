#!/usr/bin/env bash
# install.sh - Install cd-info by adding source line to shell config files

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CDINFO_PATH="$SCRIPT_DIR/cd-info.sh"
SKILL_DIR="$SCRIPT_DIR/skills/cdinfo"
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

# Function to install AI coding assistant skill
install_skill() {
    local skills_dir="$1"
    local name="$2"
    local dest_dir="$skills_dir/cdinfo"

    if [[ ! -d "$SKILL_DIR" ]]; then
        print_warning "Skill directory not found at $SKILL_DIR, skipping..."
        return 1
    fi

    # Create skills directory if it doesn't exist
    if [[ ! -d "$skills_dir" ]]; then
        mkdir -p "$skills_dir"
        print_status "Created $skills_dir"
    fi

    # Check if skill already exists
    if [[ -d "$dest_dir" ]]; then
        print_status "Updating existing skill at $dest_dir"
        rm -rf "$dest_dir"
    fi

    # Copy the skill directory
    cp -r "$SKILL_DIR" "$dest_dir"
    print_success "Installed $name skill to $dest_dir/"
}

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
