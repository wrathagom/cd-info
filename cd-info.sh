#!/usr/bin/env bash
# cd-info.sh - A shell function that displays helpful project information when changing directories
# Source this file in your .bashrc or .zshrc

# Configuration (can be overridden via environment variables)
: "${CDINFO_ENABLED:=1}"
: "${CDINFO_COLOR_ENABLED:=1}"
: "${CDINFO_HEADER_MARKER:="# --- END CD-INFO HEADER ---"}"

# Helper function to display .cdinfo content in a formatted box
_cdinfo_display() {
    local cdinfo_file="$1"

    # Check if file exists and is readable
    [[ ! -r "$cdinfo_file" ]] && return 0

    # Check if we're in an interactive terminal
    [[ ! -t 1 ]] && return 0

    # Check if cd-info is enabled
    [[ "$CDINFO_ENABLED" != "1" ]] && return 0

    # Read content after the header marker
    local content=""
    local found_marker=0
    local line

    while IFS= read -r line || [[ -n "$line" ]]; do
        if [[ $found_marker -eq 1 ]]; then
            content+="$line"$'\n'
        elif [[ "$line" == "$CDINFO_HEADER_MARKER" ]]; then
            found_marker=1
        fi
    done < "$cdinfo_file"

    # If no marker found, display entire file (for simple .cdinfo files)
    if [[ $found_marker -eq 0 ]]; then
        content=$(cat "$cdinfo_file")
    fi

    # Remove trailing newlines and check if content is empty
    while [[ "$content" == *$'\n' ]]; do
        content="${content%$'\n'}"
    done
    [[ -z "$content" ]] && return 0

    # Add consistent padding (blank line at end)
    content+=$'\n'

    # Find the longest line for box width
    local max_width=0
    local lines=()
    while IFS= read -r line; do
        lines+=("$line")
        local len=${#line}
        (( len > max_width )) && max_width=$len
    done <<< "$content"

    # Minimum width and add padding
    (( max_width < 20 )) && max_width=20
    local box_width=$((max_width + 4))

    # Color codes
    local color_reset=""
    local color_box=""
    local color_text=""
    local color_header=""
    local color_bullet=""
    local color_code=""
    local color_url=""

    if [[ "$CDINFO_COLOR_ENABLED" == "1" && -t 1 ]]; then
        color_reset=$'\033[0m'
        color_box=$'\033[36m'       # Cyan for box
        color_text=$'\033[0m'       # Default for text
        color_header=$'\033[35m'    # Magenta for headers (#)
        color_bullet=$'\033[33m'    # Yellow for bullets (-)
        color_code=$'\033[32m'      # Green for inline code
        color_url=$'\033[34m'       # Blue for URLs
    fi

    # Print top border
    printf '\n%s╭' "$color_box"
    printf '─%.0s' $(seq 1 $box_width)
    printf '╮%s\n' "$color_reset"

    # Print content lines
    for line in "${lines[@]}"; do
        local padding=$((max_width - ${#line}))

        # Colorize inline `code` and URLs
        local colored_line="$line"
        if [[ -n "$color_code" && "$line" == *'`'* ]]; then
            colored_line=$(printf '%s' "$colored_line" | sed "s/\`\([^\`]*\)\`/\`${color_code}\1${color_reset}\`/g")
        fi
        if [[ -n "$color_url" && "$line" =~ https?:// ]]; then
            colored_line=$(printf '%s' "$colored_line" | sed "s|https\?://[^[:space:]]*|${color_url}&${color_reset}|g")
        fi

        # Headers: lines starting with #
        if [[ "$line" =~ ^# ]]; then
            printf '%s│%s  %s%s%*s  %s│%s\n' \
                "$color_box" "$color_header" "$colored_line" "$color_reset" "$padding" "" "$color_box" "$color_reset"
        # Bullets: lines starting with - (optionally indented)
        elif [[ "$line" =~ ^[[:space:]]*- ]]; then
            local prefix="${colored_line%%[-]*}"
            local rest="${colored_line#*-}"
            printf '%s│  %s%s%s-%s%s%*s  %s│%s\n' \
                "$color_box" "$color_text" "$prefix" "$color_bullet" "$color_text$rest" "$color_reset" "$padding" "" "$color_box" "$color_reset"
        else
            printf '%s│%s  %s%s%*s  %s│%s\n' \
                "$color_box" "$color_text" "$colored_line" "$color_reset" "$padding" "" "$color_box" "$color_reset"
        fi
    done

    # Print bottom border
    printf '%s╰' "$color_box"
    printf '─%.0s' $(seq 1 $box_width)
    printf '╯%s\n\n' "$color_reset"
}

# Override the cd command
cd() {
    # Call the builtin cd with all arguments
    builtin cd "$@"
    local exit_code=$?

    # Only display info if cd succeeded
    if [[ $exit_code -eq 0 ]]; then
        _cdinfo_display "$PWD/.cdinfo"
    fi

    # Preserve the original exit code
    return $exit_code
}

# Create a .cdinfo template in the current directory
cdinfo-init() {
    local cdinfo_file="$PWD/.cdinfo"
    local dir_name="${PWD##*/}"
    local dir_path="${PWD/#$HOME/\~}"

    if [[ -f "$cdinfo_file" ]]; then
        echo "cd-info: .cdinfo already exists in this directory"
        return 1
    fi

    cat > "$cdinfo_file" << EOF
# ============================================================
# This file is used by cd-info to display directory information
# Learn more: https://github.com/wrathagom/cd-info
# ============================================================
# --- END CD-INFO HEADER ---

You are now in the $dir_path directory.
To edit this message, edit the .cdinfo file in this directory.

EOF

    echo "cd-info: Created $cdinfo_file"
}
