#!/bin/bash
# Tide-inspired status line for Claude Code
# Layout mirrors Tide left prompt: os + repo + pwd + git
# Right side: quota (5h/7d) + context% + model + time

input=$(cat)

cwd=$(echo "$input" | jq -r '.workspace.current_dir // empty')
model_name=$(echo "$input" | jq -r '.model.display_name // .model.id // "unknown"')
used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
repo_owner=$(echo "$input" | jq -r '.workspace.repo.owner // empty')
repo_name_json=$(echo "$input" | jq -r '.workspace.repo.name // empty')
five_hour_pct=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
seven_day_pct=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')

dir="${cwd:-$(pwd)}"

# Abbreviate home directory to ~. Uses a case match (not parameter-expansion
# replacement) so there's no risk of a stray leading backslash surviving
# into the displayed path.
home_dir="$HOME"
case "$dir" in
    "$home_dir")
        display_dir="~"
        ;;
    "$home_dir"/*)
        display_dir="~${dir#"$home_dir"}"
        ;;
    *)
        display_dir="$dir"
        ;;
esac

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

# --- Repo info ---
# Which repo the cwd is inside of. Prefers the owner/name Claude Code
# derives from the origin remote (workspace.repo); falls back to the local
# git toplevel directory name when there's no (recognized) origin remote.
# tide-ish anchor blue #00AFFF -> \033[38;5;39m
repo_info=""
repo_toplevel=$(git -C "$dir" -c gc.auto=0 rev-parse --show-toplevel 2>/dev/null)
if [ -n "$repo_toplevel" ]; then
    if [ -n "$repo_owner" ] && [ -n "$repo_name_json" ]; then
        repo_display="${repo_owner}/${repo_name_json}"
    else
        repo_display=$(basename "$repo_toplevel")
    fi
    # Nerd Font octicon "repo" (U+F401)
    repo_icon=$(printf '\xef\x90\x81')
    repo_info=" \033[38;5;39m${repo_icon} ${repo_display}\033[0m"
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

# --- Right side: quota + context % + model + time ---
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

# Claude.ai subscription rate limits (5h session window / 7d weekly window).
# Only populated once Claude Code has received a first API response for a
# subscription session; there is no documented statusLine field for any
# other notion of "quota", so this is omitted entirely rather than faked
# when absent. Color: tide git-dirty gold #D7AF00 → \033[38;5;178m
quota_str=""
if [ -n "$five_hour_pct" ]; then
    five_int=$(printf '%.0f' "$five_hour_pct")
    quota_str="5h:${five_int}%"
fi
if [ -n "$seven_day_pct" ]; then
    week_int=$(printf '%.0f' "$seven_day_pct")
    if [ -n "$quota_str" ]; then
        quota_str="${quota_str} 7d:${week_int}%"
    else
        quota_str="7d:${week_int}%"
    fi
fi
if [ -n "$quota_str" ]; then
    right_part="\033[38;5;178m${quota_str}\033[0m  ${right_part}"
fi

# --- Compose output ---
# Apple icon (U+F179 = nf-fa-apple), tide_os_color: normal → use default
os_icon=$(printf '\xef\x85\xb9')

printf "%b%b %b%b  %b\n" \
    "${os_icon}" \
    "${repo_info}" \
    "${pwd_colored}" \
    "${git_info}" \
    "${right_part}"
