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
