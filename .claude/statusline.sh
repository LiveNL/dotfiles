#!/bin/bash

input=$(cat)

cwd=$(echo "$input" | jq -r '.workspace.current_dir')
model=$(echo "$input" | jq -r '.model.display_name')
cost=$(echo "$input" | jq -r '.cost.total_cost_usd // 0')
dur_ms=$(echo "$input" | jq -r '.cost.total_duration_ms // 0')
in_tok=$(echo "$input" | jq -r '.context_window.total_input_tokens // 0')
out_tok=$(echo "$input" | jq -r '.context_window.total_output_tokens // 0')
ctx_size=$(echo "$input" | jq -r '.context_window.context_window_size // 200000')

_gray=$'\e[38;5;66m'
_green=$'\e[38;5;2m'
_yellow=$'\e[38;5;3m'
_red=$'\e[38;5;1m'
_reset=$'\e[0m'

cwd_display="${cwd/#$HOME/~}"

git_branch=$(cd "$cwd" 2>/dev/null && git rev-parse --abbrev-ref HEAD 2>/dev/null)
git_info=""
if [ -n "$git_branch" ]; then
    if [ -n "$(cd "$cwd" && git status --porcelain 2>/dev/null)" ]; then
        git_info=" ${_red}${git_branch}${_reset}"
    else
        git_info=" ${_green}${git_branch}${_reset}"
    fi
fi

dur_s=$((dur_ms / 1000))
dur_h=$((dur_s / 3600))
dur_m=$(((dur_s % 3600) / 60))
if [ $dur_h -gt 0 ]; then
    dur_fmt="${dur_h}h${dur_m}m"
else
    dur_fmt="${dur_m}m"
fi

cost_fmt=$(printf "\$%.2f" "$cost")

ctx_pct=$(echo "scale=0; ($in_tok + $out_tok) * 100 / $ctx_size" | bc)
bar_filled=$((ctx_pct / 10))
bar_empty=$((10 - bar_filled))

if [ "$ctx_pct" -lt 50 ]; then
    bar_color=$_green
elif [ "$ctx_pct" -lt 80 ]; then
    bar_color=$_yellow
else
    bar_color=$_red
fi

bar="${bar_color}"
for ((i=0; i<bar_filled; i++)); do bar+="█"; done
bar+="${_gray}"
for ((i=0; i<bar_empty; i++)); do bar+="░"; done
bar+="${_reset}"

echo "${_gray}${cwd_display}${_reset}${git_info} [${model}] ${_gray}${dur_fmt}${_reset} ${cost_fmt} ${bar} ${ctx_pct}%"
