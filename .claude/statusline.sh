#!/bin/bash
# Claude Code Statusline — flat minimal style (matching terminal aesthetic)

input=$(cat)

# Parse JSON fields
cwd=$(echo "$input" | jq -r '.workspace.current_dir // empty')
vim_mode=$(echo "$input" | jq -r '.vim.mode // empty')
used=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
model=$(echo "$input" | jq -r '.model.display_name // empty')
cost=$(echo "$input" | jq -r '.cost.total_cost_usd // "0"')

# Colors (matching minimal.zsh palette)
R=$'\e[0m'
_teal=$'\e[38;5;66m'
_dim=$'\e[38;5;242m'
_white=$'\e[38;5;252m'
_green=$'\e[0;32m'
_red=$'\e[0;31m'
_yellow=$'\e[0;33m'

# Separator
s="${_dim} │ ${R}"

# ── Path ──
cwd_display="${cwd/#$HOME/\~}"
out="${_teal}${cwd_display}${R}"

# ── Git branch + Vim mode ──
git_branch=$(cd "$cwd" 2>/dev/null && git rev-parse --abbrev-ref HEAD 2>/dev/null)
if [ -n "$git_branch" ]; then
    gc=$_green
    [ -n "$(cd "$cwd" 2>/dev/null && git status --porcelain 2>/dev/null)" ] && gc=$_red
    vm=""
    [ "$vim_mode" = "NORMAL" ] && vm=" ${_dim}·${R}"
    [ "$vim_mode" = "INSERT" ] && vm=" ${_dim}›${R}"
    out+="${s}${gc}${git_branch}${vm}${R}"
fi

# ── Model ──
if [ -n "$model" ] && [ "$model" != "null" ]; then
    model_lower=$(echo "$model" | tr 'A-Z' 'a-z')
    out+="${s}${_dim}${model_lower}${R}"
fi

# ── Cost ──
if [ -n "$cost" ] && [ "$cost" != "null" ] && [ "$cost" != "0" ]; then
    cf=$(printf '$%.2f' "$cost")
    out+="${s}${_dim}${cf}${R}"
fi

# ── Context dots (used) ──
if [ -n "$used" ] && [ "$used" != "null" ]; then
    ci=${used%.*}
    [ -z "$ci" ] && ci=0
    cc=$_green; [ "$ci" -gt 50 ] && cc=$_yellow; [ "$ci" -gt 80 ] && cc=$_red
    f=$((ci / 10)); e=$((10 - f))
    bar=""
    for ((i=0; i<f; i++)); do bar+="●"; done
    for ((i=0; i<e; i++)); do bar+="○"; done
    out+="${s}${cc}${bar}${R} ${_dim}${ci}%${R}"
fi

printf '%b' "$out"
