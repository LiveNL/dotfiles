#!/usr/bin/env bash
# Claude Code statusline, two lines:
#   1. model | session cost / today / block | burn rate | context
#   2. path, branch, worktree, ahead/behind, diff numbers
#
# Per-session figures (model, session cost, context %) come straight from the
# stdin session JSON — always fresh, zero cost. ccusage is only consulted for
# the GLOBAL figures (today / block / burn rate): one cold run parses all of
# ~/.claude/projects (~29s wall, 300%+ CPU), so exactly one background refresh
# runs per TTL across ALL sessions, at lowest priority, guarded by a lock.

input=$(cat)

state="${TMPDIR:-/tmp}/claude-statusline"
mkdir -p "$state"

gcache="$state/usage-global"
lock="$state/refresh.lock"

# ---- global ccusage refresh (background, single-flight, nice'd) ----
now=$(date +%s)
gcache_mtime=$(stat -f %m "$gcache" 2>/dev/null || echo 0)
if [ $((now - gcache_mtime)) -gt 300 ]; then
  # Clear a lock left behind by a crashed refresher
  lock_mtime=$(stat -f %m "$lock" 2>/dev/null || echo 0)
  if [ "$lock_mtime" != 0 ] && [ $((now - lock_mtime)) -gt 600 ]; then
    rmdir "$lock" 2>/dev/null
  fi

  if mkdir "$lock" 2>/dev/null; then
    printf '%s' "$input" > "$gcache.in"
    (
      nice -n 19 timeout 240 ccusage statusline < "$gcache.in" > "$gcache.tmp" 2>/dev/null \
        && [ -s "$gcache.tmp" ] && mv "$gcache.tmp" "$gcache"
      rm -f "$gcache.in" "$gcache.tmp"
      rmdir "$lock" 2>/dev/null
    ) >/dev/null 2>&1 </dev/null &
  fi
fi

# Extract the global figures from the cached (ANSI-colored) ccusage line
global=$(sed $'s/\x1b\\[[0-9;]*m//g' "$gcache" 2>/dev/null)
today=$(printf '%s' "$global" | grep -o '\$[0-9.,]* today' | head -1)
block=$(printf '%s' "$global" | grep -o '\$[0-9.,]* block ([^)]*)' | head -1)
burn=$(printf '%s' "$global" | grep -o '\$[0-9.,]*/hr' | head -1)

# ---- per-session figures straight from stdin ----
IFS=$'\t' read -r model cost pct ctx dir < <(printf '%s' "$input" | jq -r '
  [ (.model.display_name // "?"),
    (.cost.total_cost_usd // 0),
    (.context_window.used_percentage // 0 | floor),
    ((.context_window.total_input_tokens // 0) + (.context_window.total_output_tokens // 0)),
    (.workspace.current_dir // "") ] | @tsv' 2>/dev/null)

C_GREEN=$'\033[32m'
C_YELLOW=$'\033[33m'
C_RED=$'\033[31m'
C_CYAN=$'\033[36m'
C_MAGENTA=$'\033[35m'
C_DIM=$'\033[2m'
C_RST=$'\033[0m'

# Group divider, shared by both lines so they read on the same rhythm.
SEP=" ${C_DIM}|${C_RST} "

# Spend is context, not signal — it is already spent and nothing on the line can
# change it. The whole group stays dim so the two live numbers below can be the
# only colour on the line.
line1="${C_DIM}🤖 ${model}${C_RST}"

money="💰 $(printf '$%.2f' "${cost:-0}") session"
[ -n "$today" ] && money+=" / ${today}"
[ -n "$block" ] && money+=" / ${block}"
line1+="${SEP}${C_DIM}${money}${C_RST}"

# Burn rate is the one figure worth reacting to mid-session, so it gets the same
# green/amber/red treatment as the context gauge. Thresholds in $/hr.
if [ -n "$burn" ]; then
  rate=${burn#\$}
  rate=${rate%/hr}
  rate=${rate//,/}

  burn_color=$C_GREEN
  awk -v r="$rate" 'BEGIN { exit !(r >= 30) }' && burn_color=$C_YELLOW
  awk -v r="$rate" 'BEGIN { exit !(r >= 60) }' && burn_color=$C_RED

  line1+="${SEP}🔥 ${burn_color}${burn}${C_RST}"
fi

if [ "${ctx:-0}" != "0" ]; then
  ctx_color=$C_GREEN
  [ "$pct" -ge 50 ] && ctx_color=$C_YELLOW
  [ "$pct" -ge 80 ] && ctx_color=$C_RED
  ctx_fmt=$(printf "%'d" "$ctx" 2>/dev/null || printf '%s' "$ctx")
  line1+="${SEP}🧠 ${ctx_color}${ctx_fmt} (${pct}%)${C_RST}"
fi

# ---- line 2: path + git ----
if [ -z "$dir" ] || [ ! -d "$dir" ]; then
  printf '%s\n' "$line1"
  exit 0
fi

seg="${C_CYAN}📁 ${dir/#$HOME/~}${C_RST}"

if git -C "$dir" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  branch=$(git -C "$dir" branch --show-current 2>/dev/null)
  [ -z "$branch" ] && branch=$(git -C "$dir" rev-parse --short HEAD 2>/dev/null)
  seg+="${SEP}${C_MAGENTA}⎇ ${branch}${C_RST}"

  # Linked worktree: git-dir differs from the shared common dir
  git_dir=$(git -C "$dir" rev-parse --git-dir 2>/dev/null)
  common_dir=$(git -C "$dir" rev-parse --git-common-dir 2>/dev/null)
  if [ "$git_dir" != "$common_dir" ]; then
    wt_name=$(basename "$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null)")
    seg+=" ${C_YELLOW}⌂ ${wt_name}${C_RST}"
  fi

  counts=$(git -C "$dir" rev-list --left-right --count '@{upstream}...HEAD' 2>/dev/null)
  if [ -n "$counts" ]; then
    behind=${counts%%$'\t'*}
    ahead=${counts##*$'\t'}
    [ "$ahead" != "0" ] && seg+=" ${C_YELLOW}↑${ahead}${C_RST}"
    [ "$behind" != "0" ] && seg+=" ${C_YELLOW}↓${behind}${C_RST}"
  fi

  # Staged + unstaged vs HEAD; untracked counted separately
  read -r files adds dels <<<"$(git -C "$dir" diff HEAD --shortstat 2>/dev/null | awk '
    { f=0; a=0; d=0
      for (i = 1; i <= NF; i++) {
        if ($(i+1) ~ /^files?,?$/)      f = $i
        if ($(i+1) ~ /^insertions?/)    a = $i
        if ($(i+1) ~ /^deletions?/)     d = $i
      }
      print f, a, d }')"
  untracked=$(git -C "$dir" ls-files --others --exclude-standard 2>/dev/null | head -100 | wc -l | tr -d ' ')

  # Collected first so the divider is emitted once, whichever half is present.
  stats=""
  if [ -n "$files" ] && [ "$files" != "0" ]; then
    stats+="${C_GREEN}+${adds:-0}${C_RST}${C_DIM}/${C_RST}${C_RED}-${dels:-0}${C_RST} ${C_DIM}·${files}f${C_RST}"
  fi
  if [ "${untracked:-0}" != "0" ]; then
    [ -n "$stats" ] && stats+=" "
    stats+="${C_DIM}?${untracked}${C_RST}"
  fi

  [ -n "$stats" ] && seg+="${SEP}${stats}"
fi

printf '%s\n%s\n' "$line1" "$seg"
