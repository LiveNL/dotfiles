#!/usr/bin/env bash
#?tool park  the park engine behind prefix + P/N/F/O
# Park tmux windows: mark a window as deferred, dim it, and push it right.
#
# State lives in window options, never in the window name. The name stays
# whatever automatic-rename made it, so parking survives renames and can be
# queried, sorted and filtered:
#
#   @park        1 = parked by hand, auto = detected stale, empty = active
#   @park-at     epoch seconds the window was parked
#   @park-seq    monotonic park counter, orders the parked block
#   @park-home   index it sat at before parking, so unparking puts it back
#   @park-note   optional free text, shown in the picker
#   @park-touch  epoch seconds the window last had your attention
#
# Rendering is owned by window-status-format in ~/.tmux.conf. This script owns
# the state, the ordering, and the on-disk mirror.

set -uo pipefail

_self_src="${BASH_SOURCE[0]:-$0}"
SELF="$(cd "$(dirname "$_self_src")" && pwd)/$(basename "$_self_src")"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/tmux-park"

# Unit separator, not tab. Tab is an IFS whitespace character, so `IFS=$'\t'
# read` silently collapses runs of tabs — every unset window option would shift
# the remaining columns left by one. A non-whitespace IFS preserves empty fields.
SEP=$'\037'

now() { date +%s; }

# Which session a popup is acting on. run-shell expands `#{session_name}` in the
# command it is handed; display-popup does not, so a popup started that way is
# passed the format string itself and every target built from it misses. Asking
# tmux directly works from either, and inside a popup — where $TMUX_PANE is not
# set — it is the only thing that does.
resolve_session() {
    local s="${1:-}"
    case "$s" in
        ''|*'#{'*) tmux display-message -p '#S' 2>/dev/null ;;
        *)         printf '%s' "$s" ;;
    esac
}

# tmux options are per-window; window ids (@43) are stable across renumbering,
# so every target here is an id, never an index.
opt() { tmux show-options -wqv -t "$2" "$1" 2>/dev/null; }

gopt() {
    local val
    val=$(tmux show-options -gqv "$1" 2>/dev/null)
    case "$val" in ''|*[!0-9]*) val="$2" ;; esac
    printf '%s' "$val"
}

set_opt() { tmux set-option -w -t "$2" "$1" "$3" 2>/dev/null; }

# Epoch seconds are too coarse: park two windows in the same second and the tie
# breaks on current index, which the previous sort already moved. A server-wide
# counter keeps the parked block in true park order.
#
# The counter is deliberately NOT called @park-seq: tmux resolves #{@name}
# window → session → global, so a global @park-seq would leak into every
# window that has none of its own and corrupt the ordering.
next_seq() {
    local seq
    seq=$(tmux show-options -gqv @park-seq-counter 2>/dev/null)
    case "$seq" in ''|*[!0-9]*) seq=0 ;; esac
    seq=$(( seq + 1 ))
    tmux set-option -g @park-seq-counter "$seq" 2>/dev/null
    printf '%s' "$seq"
}

human_age() {
    local secs="$1"
    if [ "$secs" -lt 60 ]; then
        printf 'now'
    elif [ "$secs" -lt 3600 ]; then
        printf '%dm' $(( secs / 60 ))
    elif [ "$secs" -lt 86400 ]; then
        printf '%dh%02dm' $(( secs / 3600 )) $(( (secs % 3600) / 60 ))
    else
        printf '%dd%02dh' $(( secs / 86400 )) $(( (secs % 86400) / 3600 ))
    fi
}

# ---------------------------------------------------------------- state mirror

# Parked windows are dumped to disk on every change so the set is readable from
# outside tmux and survives a config reload. A tmux server restart destroys the
# windows themselves, so `restore` re-applies by window name, best effort.
dump_state() {
    local session="$1"
    local safe
    safe=$(printf '%s' "$session" | tr '/ ' '__')

    mkdir -p "$STATE_DIR"
    tmux list-windows -t "$session" \
        -F '#{window_index}	#{window_name}	#{@park}	#{@park-at}	#{@park-home}	#{@park-note}' 2>/dev/null \
        | awk -F'\t' '$3 != ""' > "$STATE_DIR/${safe}.tsv"
}

restore() {
    local session="$1"
    local safe
    safe=$(printf '%s' "$session" | tr '/ ' '__')
    local file="$STATE_DIR/${safe}.tsv"

    [ -f "$file" ] || { echo "no saved park state for $session"; return 0; }

    # The file stays tab-separated so it reads cleanly by eye; awk re-emits it
    # with the unit separator so empty fields survive the read.
    while IFS="$SEP" read -r _ name kind at home note; do
        [ -n "${name:-}" ] || continue

        # Files written before @park-home existed have the note in that column.
        case "${home:-}" in
            ''|*[!0-9]*) note="${home:-}${note:+ $note}"; home="" ;;
        esac

        local id
        id=$(tmux list-windows -t "$session" -F '#{window_name}	#{window_id}' 2>/dev/null \
            | awk -F'\t' -v n="$name" '$1 == n { print $2; exit }')
        [ -n "$id" ] || continue
        set_opt @park "$id" "${kind:-1}"
        set_opt @park-at "$id" "${at:-$(now)}"
        set_opt @park-seq "$id" "$(next_seq)"
        set_opt @park-home "$id" "${home:-}"
        set_opt @park-note "$id" "${note:-}"
    done < <(awk -F'\t' -v OFS="$SEP" '{ $1 = $1; print }' "$file")

    sort_session "$session"
    tmux refresh-client -S 2>/dev/null
}

# -------------------------------------------------------------------- ordering

# Desired order, three bands: unparked windows keep their relative order at the
# low indices, then auto-parked (gone stale on their own), then hand-parked.
# Within each parked band, oldest park first.
#
# Stale before hand-parked because the two mean different things: a stale window
# is one you were using and drifted away from, so it is the more likely thing to
# come back to; a hand-park is a deliberate "not now" and belongs furthest out.
#
# Applied in two passes through a scratch index range so no move ever lands on an
# occupied index.
sort_session() {
    local session="$1"
    local rows
    rows=$(tmux list-windows -t "$session" \
        -F '#{window_index}	#{window_id}	#{@park}	#{@park-seq}' 2>/dev/null) || return 0
    [ -n "$rows" ] || return 0

    local want
    want=$(
        awk -F'\t' '$3 == "" { printf "%08d\t%s\n", $1, $2 }' <<<"$rows" | sort -k1,1
        awk -F'\t' '{ if ($3 == "auto") { seq = ($4 == "" ? 0 : $4); printf "%019d\t%08d\t%s\n", seq, $1, $2 } }' <<<"$rows" \
            | sort -k1,1 -k2,2
        awk -F'\t' '{ if ($3 != "" && $3 != "auto") { seq = ($4 == "" ? 0 : $4); printf "%019d\t%08d\t%s\n", seq, $1, $2 } }' <<<"$rows" \
            | sort -k1,1 -k2,2
    )
    want=$(awk -F'\t' '{ print $NF }' <<<"$want")

    local have
    have=$(awk -F'\t' '{ print $1 "\t" $2 }' <<<"$rows" | sort -k1,1n | cut -f2)

    local first
    first=$(tmux show-options -gqv base-index 2>/dev/null)
    first=${first:-0}

    # Order alone is not enough to skip the work. renumber-windows only fires
    # when a window closes, so a `move-window -b` insert leaves a hole in the
    # index sequence — bailing out on matching order would leave that hole.
    local packed=1 expect="$first" idx
    while read -r idx; do
        [ -n "$idx" ] || continue
        [ "$idx" = "$expect" ] || { packed=0; break; }
        expect=$(( expect + 1 ))
    done < <(awk -F'\t' '{ print $1 }' <<<"$rows" | sort -n)

    [ "$want" = "$have" ] && [ "$packed" = "1" ] && return 0

    # Reordering must not move you. `move-window -d` alone is not enough: with
    # renumber-windows on, a move can still leave a different window current, so
    # the active window is captured and re-selected at the end.
    local current
    current=$(tmux display-message -p -t "$session" '#{window_id}' 2>/dev/null)

    # Suppresses the attention hook while indices churn, so the select-window
    # below cannot bounce back into touch → unpark → sort.
    tmux set-option -g @park-busy 1 2>/dev/null

    local max base i
    max=$(tmux list-windows -t "$session" -F '#{window_index}' 2>/dev/null | sort -n | tail -1)
    base=$(( max + 100 ))

    # Every move is queued into ONE tmux command list rather than issued as its
    # own invocation. Reordering 10 windows needs 20 moves through the scratch
    # index range, and 20 separate invocations meant 20 client round trips and 20
    # status redraws — you could watch the tabs march out to index 105+ and back
    # one step at a time. As a single list the server applies them all before the
    # client repaints, so the reorder lands in one frame.
    local cmd=()

    i=0
    while read -r id; do
        [ -n "$id" ] || continue
        [ ${#cmd[@]} -gt 0 ] && cmd+=(";")
        cmd+=(move-window -d -s "$id" -t "$session:$(( base + i ))")
        i=$(( i + 1 ))
    done <<<"$want"

    i=0
    while read -r id; do
        [ -n "$id" ] || continue
        cmd+=(";" move-window -d -s "$id" -t "$session:$(( first + i ))")
        i=$(( i + 1 ))
    done <<<"$want"

    # Focus restore belongs in the same list, or it is one more visible frame.
    [ -n "$current" ] && cmd+=(";" select-window -t "$current")

    [ ${#cmd[@]} -gt 0 ] && tmux "${cmd[@]}" 2>/dev/null

    tmux set-option -g @park-busy 0 2>/dev/null
}

# --------------------------------------------------------------------- actions

# `at` is overridable so the stale detector can date a window from when it
# actually went quiet, not from when the sweep noticed.
park() {
    local session="$1" id="$2" kind="${3:-1}" note="${4:-}" at="${5:-}"

    local home
    home=$(tmux display-message -p -t "$id" '#{window_index}' 2>/dev/null)

    # Clearing the watch token first (same atomic command list) kills any live
    # dwell watcher: a park must not be released by attention that predates it,
    # or parking the window you are sitting in would undo itself on the
    # watcher's next tick. A release needs a fresh visit after the park.
    tmux \
        set-option -w -t "$id" @park-watch "" ";" \
        set-option -w -t "$id" @park "$kind" ";" \
        set-option -w -t "$id" @park-at "${at:-$(now)}" ";" \
        set-option -w -t "$id" @park-seq "$(next_seq)" ";" \
        set-option -w -t "$id" @park-home "$home" ";" \
        set-option -w -t "$id" @park-note "$note" 2>/dev/null

    # PARK_DEFER_SORT lets a caller mark several windows and reorder once. A sweep
    # that parks three windows would otherwise run three full reorders back to
    # back, which is three visible shuffles instead of one.
    [ -n "${PARK_DEFER_SORT:-}" ] && return 0

    sort_session "$session"
    dump_state "$session"
    tmux refresh-client -S 2>/dev/null
}

unpark() {
    local session="$1" id="$2"

    local home current
    home=$(opt @park-home "$id")
    current=$(tmux display-message -p -t "$session" '#{window_id}' 2>/dev/null)

    tmux \
        set-option -w -t "$id" @park "" ";" \
        set-option -w -t "$id" @park-at "" ";" \
        set-option -w -t "$id" @park-seq "" ";" \
        set-option -w -t "$id" @park-home "" ";" \
        set-option -w -t "$id" @park-note "" ";" \
        set-option -w -t "$id" @park-touch "$(now)" 2>/dev/null

    # Slot it back where it was rather than dropping it at the end of the active
    # block. -b inserts before the window currently at that index and shifts the
    # rest right, which is what the reorder below then compacts into place. Both
    # the move and the focus restore go in one command list so the insert is not a
    # separate visible frame.
    if [ -n "$home" ]; then
        tmux set-option -g @park-busy 1 2>/dev/null
        if [ -n "$current" ]; then
            tmux move-window -b -d -s "$id" -t "$session:$home" ";" select-window -t "$current" 2>/dev/null
        else
            tmux move-window -b -d -s "$id" -t "$session:$home" 2>/dev/null
        fi
        tmux set-option -g @park-busy 0 2>/dev/null
    fi

    [ -n "${PARK_DEFER_SORT:-}" ] && return 0

    sort_session "$session"
    dump_state "$session"
    tmux refresh-client -S 2>/dev/null
}

# Deliberately silent: message-style here is a light background, so a
# display-message on every park flashes the whole status line white. The badge
# appearing and the window sliding right is the confirmation.
toggle() {
    local session="$1" id="$2" note="${3:-}"

    if [ -n "$(opt @park "$id")" ]; then
        unpark "$session" "$id"
    else
        park "$session" "$id" 1 "$note"
    fi
}

# Fired from the session-window-changed hook. Stamps attention so the stale
# detector has a second signal, and releases a park — staying in a window is
# the same as resuming it, hand-park and auto-park alike. Peeking stays safe:
# release requires dwell, and park() invalidates the live watcher token, so a
# window parked while current cannot release itself — only a visit that starts
# after the park counts.
#
# Attention requires dwell, it is not granted on arrival. Cycling sideways
# through ten windows would otherwise reset all ten idle clocks, so auto-stale
# could never fire — and passing over an auto-parked window would yank it back
# left mid-cycle. A detached watcher waits @park-dwell-secs, checks the window is
# still current, and only then counts the visit. It re-stamps while you stay and
# exits as soon as you leave, so at most one watcher is ever doing work.
touch_window() {
    local session="$1" id="$2"

    [ "$(tmux show-options -gqv @park-busy 2>/dev/null)" = "1" ] && return 0

    local dwell
    dwell=$(gopt @park-dwell-secs 30)

    if [ "$dwell" -le 0 ]; then
        set_opt @park-touch "$id" "$(now)"
        [ -n "$(opt @park "$id")" ] && unpark "$session" "$id"
        return 0
    fi

    # One watcher per window. Every window change spawns one, so without a token
    # a few minutes of switching back and forth leaves a handful of them looping
    # over the same window. The newest claims @park-watch; older ones see a token
    # that is no longer theirs and exit.
    local tok
    tok="$(now).$$"
    set_opt @park-watch "$id" "$tok"

    (
        while true; do
            sleep "$dwell"
            [ "$(opt @park-watch "$id")" = "$tok" ] || exit 0
            [ "$(tmux display-message -p -t "$session" '#{window_id}' 2>/dev/null)" = "$id" ] || exit 0

            set_opt @park-touch "$id" "$(now)"

            if [ -n "$(opt @park "$id")" ]; then
                unpark "$session" "$id"
            fi
        done
    ) </dev/null >/dev/null 2>&1 &

    disown 2>/dev/null
    return 0
}

note() {
    local session="$1" id="$2" text="${3:-}"

    set_opt @park-note "$id" "$text"
    [ -n "$(opt @park "$id")" ] || park "$session" "$id" 1 "$text"

    dump_state "$session"
    tmux refresh-client -S 2>/dev/null
}

# ------------------------------------------------------------------ tmux menu

# The primary picker. Native display-menu rather than fzf in a popup: tmux draws
# the menu and consumes the keystrokes itself, so nothing the terminal emits —
# mouse tracking, focus reporting, stray escapes — can reach it. The fzf popup
# below is kept for fuzzy matching over a long list.
PARK_MENU_KEYS="123456789abcdefgijklmnoprstvwxyz"

# Prints one "label|key|command" triple per parked window on stdout.
menu_items() {
    local session="$1" action="$2"
    local t n=0
    t=$(now)

    local rows
    rows=$(tmux list-windows -t "$session" \
        -F "#{window_index}${SEP}#{window_id}${SEP}#{window_name}${SEP}#{@park}${SEP}#{@park-at}${SEP}#{@park-note}" 2>/dev/null \
        | awk -F"$SEP" '$4 != ""')
    [ -n "$rows" ] || return 0

    while IFS="$SEP" read -r idx id name kind at note; do
        local glyph age label key cmd
        [ "$kind" = "auto" ] && glyph="◌" || glyph="⏸"
        age=$(human_age $(( t - ${at:-$t} )))

        # Menu labels are tmux command arguments; # and " would be reparsed.
        name=${name//\"/}
        name=${name//\#/}
        note=${note//\"/}
        note=${note//\#/}

        label=$(printf '%s %-3s %-22s %6s  %s' "$glyph" "$idx" "$name" "$age" "$note")
        key=${PARK_MENU_KEYS:$n:1}
        [ -n "$key" ] || key=""

        case "$action" in
            jump)   cmd="select-window -t $id" ;;
            unpark) cmd="run-shell \"$SELF unpark '$session' '$id'\"" ;;
        esac

        printf '%s|%s|%s\n' "$label" "$key" "$cmd"
        n=$(( n + 1 ))
    done <<<"$rows"
}

menu() {
    local session="$1" client="${2:-}" action="${3:-jump}"

    local args=()
    [ -n "$client" ] && args+=(-c "$client")

    local title
    case "$action" in
        jump)   title="#[align=centre] parked · $session " ;;
        unpark) title="#[align=centre] unpark · $session " ;;
    esac
    args+=(-T "$title" -x C -y C)

    local items count=0
    items=$(menu_items "$session" "$action")

    if [ -z "$items" ]; then
        # A leading dash makes a menu entry inert, which beats a status-line
        # message: message-style here is a light background and flashes.
        args+=("-no parked windows" "" "")
    else
        while IFS='|' read -r label key cmd; do
            [ -n "$label" ] || continue
            args+=("$label" "$key" "$cmd")
            count=$(( count + 1 ))
        done <<<"$items"

        args+=("")
        if [ "$action" = "jump" ]; then
            args+=("unpark one…" "u" "run-shell \"$SELF menu '$session' '$client' unpark\"")
            # Confirmed: unparking everything throws away notes and home slots.
            args+=("unpark all ($count)" "U" "confirm-before -p 'unpark all $count windows? (y/n) ' \"run-shell \\\"$SELF unpark-all '$session'\\\"\"")
        fi
    fi

    tmux display-menu "${args[@]}"
}

unpark_all() {
    local session="$1"

    while IFS= read -r id; do
        [ -n "$id" ] || continue
        set_opt @park "$id" ""
        set_opt @park-at "$id" ""
        set_opt @park-seq "$id" ""
        set_opt @park-home "$id" ""
        set_opt @park-note "$id" ""
        set_opt @park-touch "$id" "$(now)"
    done < <(tmux list-windows -t "$session" \
        -F "#{window_id}${SEP}#{@park}" 2>/dev/null | awk -F"$SEP" '$2 != "" { print $1 }')

    sort_session "$session"
    dump_state "$session"
    tmux refresh-client -S 2>/dev/null
}

# ---------------------------------------------------------------------- picker

# Keeps the popup on screen long enough to read something. A popup whose command
# exits immediately just vanishes, which is indistinguishable from a crash.
pause() {
    printf '\n%s' "${1:-press any key}"
    read -r -n 1 _ </dev/tty 2>/dev/null || sleep 3
}

# Rows are built here rather than in the format string so ages stay human and
# the note is visible. Runs inside display-popup, where $TMUX is still set.
picker() {
    local session
    session=$(resolve_session "${1:-}")

    # PARK_DEBUG=1 traces a popup that dies too fast to read.
    if [ -n "${PARK_DEBUG:-}" ]; then
        exec 2>>"${TMPDIR:-/tmp}/tmux-park-picker.log"
        echo "=== picker session=$session pid=$$ tty=$(tty 2>&1) ===" >&2
        set -x
    fi

    local t
    t=$(now)

    local rows
    rows=$(tmux list-windows -t "$session" \
        -F "#{window_index}${SEP}#{window_id}${SEP}#{window_name}${SEP}#{@park}${SEP}#{@park-at}${SEP}#{@park-note}" 2>/dev/null \
        | awk -F"$SEP" '$4 != ""')

    if [ -z "$rows" ]; then
        printf 'No parked windows in %s.' "$session"
        pause
        return 0
    fi

    local lines=""
    while IFS="$SEP" read -r idx id name kind at note; do
        local glyph age
        [ "$kind" = "auto" ] && glyph="◌" || glyph="⏸"
        age=$(human_age $(( t - ${at:-$t} )))
        lines+=$(printf '%s\t%s %-3s %-24s %-7s %s' "$id" "$glyph" "$idx" "$name" "$age" "${note:-}")
        lines+=$'\n'
    done <<<"$rows"

    if ! command -v fzf >/dev/null 2>&1; then
        printf 'fzf is not on the PATH this popup was given:\n\n  %s\n' "$PATH"
        pause
        return 0
    fi

    local pick rc
    # --no-mouse matters: `mouse on` and `focus-events on` mean tmux forwards
    # mouse and focus escape sequences into the popup, and fzf reads them as
    # cursor movement plus an accept — the popup appeared to close instantly and
    # jumped to a window nobody picked.
    pick=$(cut -f2- <<<"$lines" | fzf \
        --no-mouse \
        --reverse \
        --no-sort \
        --no-multi \
        --prompt='parked > ' \
        --header='enter jump · ctrl-u unpark · ctrl-o unpark+jump · esc cancel' \
        --expect=ctrl-u,ctrl-o)
    rc=$?

    # 0 picked, 1 no match, 130 cancelled. Anything else is fzf itself failing,
    # which must not look like a cancel.
    case "$rc" in
        0)        ;;
        1|130)    return 0 ;;
        *)        printf 'fzf exited %s\n' "$rc"; pause; return 0 ;;
    esac

    local key row
    key=$(head -1 <<<"$pick")
    row=$(sed -n '2p' <<<"$pick")
    [ -n "$row" ] || return 0

    local id
    id=$(awk -F'\t' -v r="$row" '$2 == r { print $1; exit }' <<<"$lines")
    [ -n "$id" ] || return 0

    case "$key" in
        ctrl-u) unpark "$session" "$id" ;;
        ctrl-o) unpark "$session" "$id"; tmux select-window -t "$id" 2>/dev/null ;;
        *)      tmux select-window -t "$id" 2>/dev/null ;;
    esac
}

list() {
    local session="${1:-}"
    local t
    t=$(now)

    local fmt
    fmt="#{session_name}${SEP}#{window_index}${SEP}#{window_name}${SEP}#{@park}${SEP}#{@park-at}${SEP}#{@park-note}"

    local rows
    if [ -n "$session" ]; then
        rows=$(tmux list-windows -t "$session" -F "$fmt" 2>/dev/null)
    else
        rows=$(tmux list-windows -a -F "$fmt" 2>/dev/null)
    fi

    while IFS="$SEP" read -r sess idx name kind at note; do
        [ -n "${kind:-}" ] || continue
        printf '%-14s %-3s %-24s %-6s %-8s %s\n' \
            "$sess" "$idx" "$name" "$kind" "$(human_age $(( t - ${at:-$t} )))" "${note:-}"
    done <<<"$rows"
}

# ------------------------------------------------------------------ entrypoint

cmd="${1:-list}"
shift || true

case "$cmd" in
    toggle)  toggle "$@" ;;
    park)    park "$1" "$2" 1 "${3:-}" ;;
    auto)    park "$1" "$2" auto "" "${3:-}" ;;
    unpark)  unpark "$@" ;;
    touch)   touch_window "$@" ;;
    note)    note "$@" ;;
    sort)    sort_session "$1"; dump_state "$1" ;;
    menu)    menu "$@" ;;
    unpark-all) unpark_all "$1" ;;
    picker)  picker "$@" ;;
    list)    list "${1:-}" ;;
    dump)    dump_state "$1" ;;
    restore) restore "$1" ;;
    *)
        cat >&2 <<EOF
usage: tmux-park.sh <command> [args]

  toggle  <session> <window-id> [note]   park if active, unpark if parked
  park    <session> <window-id> [note]   park by hand
  auto    <session> <window-id> [at]     park as detected-stale, dated at <at>
  unpark  <session> <window-id>          clear park state
  touch   <session> <window-id>          stamp attention, release auto-stale
  note    <session> <window-id> <text>   set/replace the park note
  sort    <session>                      re-order parked windows to the right
  menu    <session> [client] [jump|unpark]  native tmux menu of parked windows
  unpark-all <session>                   clear park state on every window
  picker  <session>                      fzf popup alternative to menu
  list    [session]                      plain-text list (all sessions if omitted)
  dump    <session>                      write the on-disk mirror
  restore <session>                      re-apply the mirror, matching by name
EOF
        exit 2
        ;;
esac
