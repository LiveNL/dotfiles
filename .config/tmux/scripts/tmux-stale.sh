#!/usr/bin/env bash
# Auto-park tmux windows that have gone quiet, so the tab bar decays on its own
# instead of waiting for you to notice. Marks them @park=auto, which renders
# amber rather than the gray of a hand-park and clears itself once you settle
# back into the window (see the touch handler in tmux-park.sh).
#
# Idle is measured from the newest of:
#   @park-fp-at   when this window's own output fingerprint last changed
#   @park-touch   when you last dwelt in it, set by the session-window-changed hook
#
# NOT #{window_activity}. tmux bumps that for every window at once, several times
# an hour — measured over 54 minutes of real use: 7 bulk resets, largest gap 13
# minutes. Against a 45-minute threshold nothing could ever go stale.
#
# Tunables, all global tmux options:
#   @park-stale-mins      minutes of quiet before auto-parking   (default 45)
#   @park-stale-interval  seconds between sweeps                 (default 60)
#   @park-dwell-secs      seconds in a window before a visit counts (default 30)
#
# Opt a window out for good with:  tmux set -w @park-never 1

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARK="$SCRIPT_DIR/tmux-park.sh"
# Scoped to the tmux socket, so a second server (or a throwaway one started with
# -L for testing) does not look like the daemon is already running.
SOCKET=$(basename "${TMUX%%,*}" 2>/dev/null)
PIDFILE="/tmp/tmux-stale-$(id -u)-${SOCKET:-default}.pid"

# Unit separator, not tab. Tab is an IFS whitespace character, so `IFS=$'\t'
# read` silently collapses runs of tabs — every unset window option would shift
# the remaining columns left by one. A non-whitespace IFS preserves empty fields.
SEP=$'\037'

gopt() {
    local val
    val=$(tmux show-options -gqv "$1" 2>/dev/null)
    printf '%s' "${val:-$2}"
}

wopt() { tmux show-options -wqv -t "$2" "$1" 2>/dev/null; }

# Per-window output fingerprint, and the reason this script no longer trusts
# #{window_activity}: tmux bumps that for every window in the session at once,
# several times an hour. Measured over 54 minutes of real use — 7 bulk resets,
# largest gap 13 minutes — so a 45-minute threshold could never be reached and
# nothing ever went stale.
#
# These fields only move when that window's own panes change: history grows when
# a pane prints, and the command name changes when what is running changes. A
# resize or a status redraw cannot touch them. Alternate-screen apps (nvim, the
# Claude TUI) do not grow history, so a window left sitting in one reads as quiet
# — which is the intent: dwell is what marks a window you are actually using.
fingerprints() {
    local only="${1:-}"
    local fmt="#{window_id}${SEP}#{history_size}${SEP}#{history_bytes}${SEP}#{pane_current_command}"

    if [ -n "$only" ]; then
        tmux list-panes -s -t "$only" -F "$fmt" 2>/dev/null
    else
        tmux list-panes -a -F "$fmt" 2>/dev/null
    fi | awk -F"$SEP" '
        { fp[$1] = fp[$1] $2 ":" $3 ":" $4 "," }
        END { for (w in fp) print w "\t" fp[w] }'
}

# An optional session argument narrows the sweep — handy for trying a threshold
# out on a scratch session without touching everything else.
sweep() {
    local only="${1:-}"
    local mins threshold t
    # PARK_STALE_SECS is a seconds-level override, so a sweep can be exercised
    # without waiting out the real threshold. @park-stale-mins 0 disables.
    if [ -n "${PARK_STALE_SECS:-}" ]; then
        threshold="$PARK_STALE_SECS"
    else
        mins=$(gopt @park-stale-mins 45)
        case "$mins" in ''|*[!0-9]*) mins=45 ;; esac
        [ "$mins" -eq 0 ] && return 0
        threshold=$(( mins * 60 ))
    fi
    t=$(date +%s)

    local marked=0 touched=""
    local fmt
    fmt="#{session_name}${SEP}#{window_id}${SEP}#{window_active}${SEP}#{@park}${SEP}#{@park-never}${SEP}#{@park-touch}${SEP}#{@claude-state}${SEP}#{@park-fp}${SEP}#{@park-fp-at}"

    local rows
    if [ -n "$only" ]; then
        rows=$(tmux list-windows -t "$only" -F "$fmt" 2>/dev/null) || return 0
    else
        rows=$(tmux list-windows -a -F "$fmt" 2>/dev/null) || return 0
    fi

    local fps
    fps=$(fingerprints "$only")

    while IFS="$SEP" read -r session id active park never touch claude oldfp fpat; do
        [ -n "${id:-}" ] || continue

        # Fingerprints are refreshed for EVERY window, including the current one,
        # parked ones and mid-run ones. Skipping them would leave a stale
        # fingerprint behind, and the window would read as quiet the instant it
        # became eligible again.
        local fp
        fp=$(awk -F'\t' -v w="$id" '$1 == w { print $2; exit }' <<<"$fps")

        if [ "$fp" != "$oldfp" ]; then
            tmux set-option -w -t "$id" @park-fp "$fp" 2>/dev/null
            tmux set-option -w -t "$id" @park-fp-at "$t" 2>/dev/null
            fpat="$t"
        elif [ -z "${fpat:-}" ]; then
            tmux set-option -w -t "$id" @park-fp-at "$t" 2>/dev/null
            fpat="$t"
        fi

        # An auto-park asserts "nothing happened here for 45 minutes". The moment
        # the window produces output again that assertion is false, so release it.
        # Without this a window Claude has resumed working in keeps wearing an
        # amber badge while it is visibly busy. A hand-park is a decision, not an
        # inference, so output never clears one.
        if [ "$park" = "auto" ] && [ "$fp" != "$oldfp" ]; then
            PARK_DEFER_SORT=1 "$PARK" unpark "$session" "$id"
            marked=$(( marked + 1 ))
            touched="${touched}${session}
"
            continue
        fi

        [ "$active" = "1" ] && continue
        [ -n "${park:-}" ] && continue
        [ -n "${never:-}" ] && continue
        [ "${claude:-}" = "running" ] && continue

        local last="${fpat:-0}"
        [ -n "${touch:-}" ] && [ "$touch" -gt "$last" ] 2>/dev/null && last="$touch"
        [ "$last" -gt 0 ] 2>/dev/null || continue
        [ $(( t - last )) -ge "$threshold" ] || continue

        # Dated from when it actually went quiet, not from when we noticed.
        # Going through tmux-park.sh keeps the park sequence and the on-disk
        # mirror in one place. Sorting is deferred so a sweep that touches several
        # windows produces one reorder rather than one per window.
        PARK_DEFER_SORT=1 "$PARK" auto "$session" "$id" "$last"
        marked=$(( marked + 1 ))
        touched="${touched}${session}
"
    done <<<"$rows"

    if [ -n "$touched" ]; then
        while IFS= read -r s; do
            [ -n "$s" ] || continue
            "$PARK" sort "$s"
        done < <(printf '%s' "$touched" | sort -u)
        tmux refresh-client -S 2>/dev/null
    fi

    # The mirror records each parked window's index, which drifts whenever any
    # other window is created or closed. Park/unpark alone cannot keep it honest,
    # so refresh it here — one list-windows per session per sweep.
    while IFS= read -r s; do
        [ -n "$s" ] || continue
        "$PARK" dump "$s"
    done < <(if [ -n "$only" ]; then printf '%s\n' "$only"; else tmux list-sessions -F '#{session_name}' 2>/dev/null; fi)

    return 0
}

daemon() {
    trap 'rm -f "$PIDFILE"' EXIT

    while true; do
        tmux has-session 2>/dev/null || exit 0
        sweep
        local interval
        interval=$(gopt @park-stale-interval 60)
        case "$interval" in ''|*[!0-9]*) interval=60 ;; esac
        sleep "$interval"
    done
}

case "${1:-start}" in
    start)
        if [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE" 2>/dev/null)" 2>/dev/null; then
            exit 0
        fi
        nohup "$0" daemon >/dev/null 2>&1 &
        echo $! > "$PIDFILE"
        disown 2>/dev/null
        ;;
    stop)
        if [ -f "$PIDFILE" ]; then
            kill "$(cat "$PIDFILE")" 2>/dev/null
            rm -f "$PIDFILE"
        fi
        ;;
    restart)
        "$0" stop
        "$0" start
        ;;
    daemon)
        daemon
        ;;
    run)
        sweep "${2:-}"
        ;;
    status)
        if [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE" 2>/dev/null)" 2>/dev/null; then
            echo "running (pid $(cat "$PIDFILE"), threshold $(gopt @park-stale-mins 45)m, interval $(gopt @park-stale-interval 60)s)"
        else
            echo "not running"
        fi
        ;;
    *)
        echo "usage: tmux-stale.sh {start|stop|restart|run|status|daemon}" >&2
        exit 2
        ;;
esac
