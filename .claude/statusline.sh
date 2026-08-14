#!/usr/bin/env bash
# Claude Code statusline — one row, four groups.
#
# Claude Code and tmux already draw three to four lines of chrome under every
# prompt, so the statusline gets one. Everything fits because the old second
# line repeated itself: in a worktree the ticket appeared in the path, in the
# branch and in the worktree name — 134 characters to say one thing. The
# collapse rules below delete the repetition rather than the facts.
#
# Colour is spent once. Context percentage is the only figure that changes what
# you do next, so it is the only one carrying a hue; everything else is dim and
# the icons are slate. Diff counts stay dim on purpose — green and red there
# would collide with the green and red the context gauge uses to mean something
# entirely different.
#
# Per-session figures (model, session cost, context %) come straight from the
# stdin session JSON — always fresh, zero cost. ccusage is only consulted for
# the GLOBAL figures (today, burn rate): one cold run parses all of
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

# The block figure is deliberately not read: it cost 29 characters to say what
# the burn rate already implies.
global=$(sed $'s/\x1b\\[[0-9;]*m//g' "$gcache" 2>/dev/null)
today=$(printf '%s' "$global" | grep -o '\$[0-9.,]* today' | head -1 | cut -d' ' -f1)
burn=$(printf '%s' "$global" | grep -o '\$[0-9.,]*/hr' | head -1)

# ---- per-session figures straight from stdin ----
IFS=$'\t' read -r model cost pct dir < <(printf '%s' "$input" | jq -r '
  [ (.model.display_name // "?"),
    (.cost.total_cost_usd // 0),
    (.context_window.used_percentage // 0 | floor),
    (.workspace.current_dir // "") ] | @tsv' 2>/dev/null)

# ---- palette ----
C_GREEN=$'\033[32m'
C_YELLOW=$'\033[33m'
C_RED=$'\033[31m'
C_DIM=$'\033[2m'
C_ICON=$'\033[38;2;128;146;160m'
C_RST=$'\033[0m'

# ---- glyphs (LiterationMono Nerd Font, plane 15) ----
# The Font Awesome range renders blank in this terminal even though the font
# carries it, so every icon here is Material Design, U+F0000 and up. Written as
# literal UTF-8, not $'\U…' — macOS ships bash 3.2, which prints that escape
# verbatim rather than expanding it.
I_MODEL='󰚩'   # robot
I_COST='󰈸'    # fire — spend and the rate it is going out are one group,
              # so the rate needs no icon of its own, just a divider
I_CTX='󰆼'     # database
I_PATH='󰉋'    # folder
I_TREE='󰱊'    # source-branch
I_BRANCH='󰘬'  # git-branch

# Where personal repos live. Paths under it are shown relative, so the two
# segments that identify a checkout survive and the rest goes.
PROJECTS="${CLAUDE_SL_PROJECTS:-$HOME/projects}"

# Longest a branch name may be before it loses its middle.
BRANCH_MAX="${CLAUDE_SL_BRANCH_MAX:-30}"

# The space after the icon is not padding — it is the cell the glyph needs.
# These are drawn about two cells wide but advance only one, because plane-15
# is neutral-width to the terminal, so without a following space the glyph is
# painted over the first character of its value.
#
# Three gap sizes carry the structure: one space icon-to-value, two between
# items inside a group, and the rule between groups — which separates by being
# a mark rather than by being wide.
seg() { printf '%s%s%s %s' "$C_ICON" "$1" "$C_RST" "$2"; }

ellipsize() {
  local s=$1 max=$2 head
  if [ "${#s}" -le "$max" ]; then
    printf '%s' "$s"
    return
  fi

  head=$(( (max - 1) / 2 ))
  printf '%s…%s' "${s:0:head}" "${s: -$(( max - 1 - head ))}"
}

# How wide the pane actually is. Claude Code truncates a statusline that does
# not fit, and it cuts mid-string without closing the SGR sequence that was
# open — so a long line does not just lose its tail, it leaves a colour switched
# on and everything drawn afterwards inherits it. Building to fit is the only
# way to keep that from happening.
width=""
[ -n "$TMUX_PANE" ] && width=$(tmux display -p -t "$TMUX_PANE" '#{pane_width}' 2>/dev/null)
case "$width" in ''|*[!0-9]*) width=${COLUMNS:-0} ;; esac
case "$width" in ''|*[!0-9]*) width=0 ;; esac
[ "$width" -lt 20 ] && width=200

# Columns a styled string occupies. The icons are drawn wide but advance a
# single cell, so once the escapes are gone a character is a column.
vis() {
  local bare
  bare=$(printf '%s' "$1" | sed $'s/\x1b\\[[0-9;]*m//g')
  printf '%s' "${#bare}"
}

# ---- group 1: which model ----
# "Opus 5 (1M context)" says the same as "Opus 5 (1M)" in eight fewer columns.
model=${model/ (1M context)/ (1M)}
g_model=$(seg "$I_MODEL" "${C_DIM}${model}${C_RST}")

# ---- group 2: what it costs ----
p_session=$(printf '$%.2f' "${cost:-0}")
p_today=""
[ -n "$today" ] && p_today=" / ${today}"
p_burn=""
[ -n "$burn" ] && p_burn="${C_DIM} · ${burn}${C_RST}"

# ---- group 3: how much room is left ----
ctx_color=$C_GREEN
[ "${pct:-0}" -ge 50 ] && ctx_color=$C_YELLOW
[ "${pct:-0}" -ge 80 ] && ctx_color=$C_RED
g_ctx=$(seg "$I_CTX" "${ctx_color}${pct:-0}%${C_RST}")

# ---- group 4: where you are ----
w_path=""; w_tree=""; w_branch=""; w_stats=""
if [ -n "$dir" ] && [ -d "$dir" ]; then
  repo=$dir
  tree=""

  # A worktree under .claude/worktrees names its ticket in the directory. Show
  # the repository it belongs to, and carry the ticket once as its own badge.
  case "$dir" in
    */.claude/worktrees/*)
      repo=${dir%%/.claude/worktrees/*}
      tree=${dir##*/.claude/worktrees/}
      tree=${tree%%/*}
      ;;
  esac

  where=${repo#"$PROJECTS"/}
  [ "$where" = "$repo" ] && where=${repo/#$HOME/\~}
  w_path=$(seg "$I_PATH" "${C_DIM}${where}${C_RST}")

  if git -C "$dir" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    top=$(basename "$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null)")

    # A linked worktree outside .claude/worktrees is still a worktree, but if
    # its name is already the last thing in the path there is nothing to add.
    if [ -z "$tree" ]; then
      git_dir=$(git -C "$dir" rev-parse --git-dir 2>/dev/null)
      common=$(git -C "$dir" rev-parse --git-common-dir 2>/dev/null)
      [ "$git_dir" != "$common" ] && [ "${where##*/}" != "$top" ] && tree=$top
    fi
    [ -n "$tree" ] && w_tree="  $(seg "$I_TREE" "${C_DIM}${tree}${C_RST}")"

    branch=$(git -C "$dir" branch --show-current 2>/dev/null)
    [ -z "$branch" ] && branch=$(git -C "$dir" rev-parse --short HEAD 2>/dev/null)

    # Your own name in front of every branch carries no information.
    owner=$(git -C "$dir" config user.name 2>/dev/null | tr '[:upper:]' '[:lower:]')
    owner=${CLAUDE_SL_OWNER:-$owner}
    [ -n "$owner" ] && branch=${branch#"$owner"/}

    # The ticket is already on the worktree badge.
    if [ -n "$tree" ]; then
      lower=$(printf '%s' "$tree" | tr '[:upper:]' '[:lower:]')
      branch=${branch#"$lower"-}
    fi

    # A branch that repeats the directory it is checked out in says nothing.
    if [ -n "$branch" ] && [ "$branch" != "$top" ] && [ "$branch" != "${where##*/}" ]; then
      w_branch="  $(seg "$I_BRANCH" "${C_DIM}$(ellipsize "$branch" "$BRANCH_MAX")${C_RST}")"
    fi

    read -r files adds dels <<<"$(git -C "$dir" diff HEAD --shortstat 2>/dev/null | awk '
      { f=0; a=0; d=0
        for (i = 1; i <= NF; i++) {
          if ($(i+1) ~ /^files?,?$/)      f = $i
          if ($(i+1) ~ /^insertions?/)    a = $i
          if ($(i+1) ~ /^deletions?/)     d = $i
        }
        print f, a, d }')"
    untracked=$(git -C "$dir" ls-files --others --exclude-standard 2>/dev/null | head -100 | wc -l | tr -d ' ')

    stats=""
    [ -n "$files" ] && [ "$files" != "0" ] && stats="+${adds:-0}/-${dels:-0} ${files}f"
    if [ "${untracked:-0}" != "0" ]; then
      [ -n "$stats" ] && stats+=" "
      stats+="?${untracked}"
    fi
    [ -n "$stats" ] && w_stats="  ${C_DIM}${stats}${C_RST}"
  fi
fi

sep=" ${C_DIM}│${C_RST} "

compose() {
  local money out
  money=$(seg "$I_COST" "${C_DIM}${p_session}${p_today}${C_RST}")${p_burn}

  out=""
  [ -n "$g_model" ] && out="${g_model}${sep}"
  out+="${money}${sep}${g_ctx}"
  [ -n "$w_path" ] && out+="${sep}${w_path}${w_tree}${w_branch}${w_stats}"
  printf '%s' "$out"
}

# Sacrificed in this order until the line fits: the diff counts, the model, the
# branch, the burn rate, then today's total. Context and where you are never go
# — they are the two the line exists for.
line=$(compose)
for drop in w_stats g_model w_branch p_burn p_today; do
  [ "$(vis "$line")" -le "$width" ] && break
  eval "$drop=''"
  line=$(compose)
done

printf '%s%s\n' "$line" "$C_RST"
