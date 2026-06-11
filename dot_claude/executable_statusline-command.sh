#!/bin/bash
# Tide-inspired status line for Claude Code
# Layout mirrors Tide left prompt: os + pwd + git
# Right side: model + context% + time

input=$(cat)

cwd=$(echo "$input" | jq -r '.workspace.current_dir // empty')
model_name=$(echo "$input" | jq -r '.model.display_name // .model.id // "unknown"')
used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')

dir="${cwd:-$(pwd)}"

# Abbreviate home directory to ~
home_dir="$HOME"
display_dir="${dir/#$home_dir/\~}"

# Tide pwd colors (rgb approximations → nearest 256-color)
# tide_pwd_color_anchors: #00AFFF → \033[38;5;39m
# tide_pwd_color_dirs:    #0087AF → \033[38;5;31m
# Color the last path component (anchor) differently from parent dirs
parent_dir=$(dirname "$display_dir")
base_dir=$(basename "$display_dir")

if [ "$parent_dir" = "." ] || [ "$parent_dir" = "~" ] || [ "$display_dir" = "~" ]; then
    # Single-component path (home or root of something)
    pwd_colored="\033[38;5;39m${display_dir}\033[0m"
else
    # Parent dirs dimmer, anchor (last segment) brighter
    # Normalize trailing slash situation
    parent_part="${parent_dir}/"
    if [ "$parent_dir" = "/" ]; then
        parent_part="/"
    fi
    pwd_colored="\033[38;5;31m${parent_part}\033[0m\033[38;5;39m${base_dir}\033[0m"
fi

# --- Git info ---
# tide_git_color_branch:    #5FD700 → \033[38;5;76m
# tide_git_color_dirty:     #D7AF00 → \033[38;5;178m
# tide_git_color_staged:    #D7AF00 → \033[38;5;178m
# tide_git_color_untracked: #00AFFF → \033[38;5;39m
git_info=""
git_branch=$(git -C "$dir" -c gc.auto=0 symbolic-ref --short HEAD 2>/dev/null)
if [ -n "$git_branch" ]; then
    # Check working tree state (skip locks)
    git_status=$(git -C "$dir" -c gc.auto=0 status --porcelain 2>/dev/null)
    staged=$(echo "$git_status" | grep -c '^[MADRC]')
    unstaged=$(echo "$git_status" | grep -c '^.[MD]')
    untracked=$(echo "$git_status" | grep -c '^??')

    # Choose branch color: dirty (any change) = #D7AF00, clean = #5FD700
    if [ "$staged" -gt 0 ] || [ "$unstaged" -gt 0 ] || [ "$untracked" -gt 0 ]; then
        branch_color="\033[38;5;178m"
    else
        branch_color="\033[38;5;76m"
    fi

    # Tide git icon (U+F1D3 = nf-fa-git) — falls back gracefully if font missing
    git_info=" ${branch_color}$(printf '\xef\x87\x93') ${git_branch}\033[0m"

    # Append indicators: + staged, ! unstaged, ? untracked
    [ "$staged" -gt 0 ]    && git_info="${git_info}\033[38;5;178m +${staged}\033[0m"
    [ "$unstaged" -gt 0 ]  && git_info="${git_info}\033[38;5;178m !${unstaged}\033[0m"
    [ "$untracked" -gt 0 ] && git_info="${git_info}\033[38;5;39m ?${untracked}\033[0m"
fi

# --- Right side: model + context % + time ---
# tide_time_color: #5F8787 → \033[38;5;66m
time_str=$(date +"%I:%M %p")
right_part="\033[38;5;66m${time_str}\033[0m"

# Model name (tide context color #D7AF87 → \033[38;5;180m)
right_part="\033[38;5;180m${model_name}\033[0m  ${right_part}"

# Context window usage (tide cmd_duration color #87875F → \033[38;5;101m)
if [ -n "$used_pct" ]; then
    pct_int=$(printf '%.0f' "$used_pct")
    right_part="\033[38;5;101mctx:${pct_int}%\033[0m  ${right_part}"
fi

# --- Compose output ---
# Apple icon (U+F179 = nf-fa-apple), tide_os_color: normal → use default
os_icon=$(printf '\xef\x85\xb9')

printf "%b %b%b  %b\n" \
    "${os_icon}" \
    "${pwd_colored}" \
    "${git_info}" \
    "${right_part}"
