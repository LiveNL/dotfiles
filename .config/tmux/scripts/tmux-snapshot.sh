#!/usr/bin/env bash
#?tool restore  mirror the tmux layout to disk on a timer
# Mirror the tmux layout to disk, so a crash or a reboot leaves a record of what
# was open. Everything tmux knows about a window lives in server memory and dies
# with the server. The Claude conversations that lived in those windows do
# survive, as transcripts under ~/.claude/projects — but nothing on disk says
# which conversation sat in which window. That link is stamped onto the pane by
# the SessionStart hook (@claude-session) and captured here.
#
# Written on a timer and on the tmux hooks that change the layout, so the file
# is at most one interval behind reality.
#
# Files, under ~/.local/state/tmux-restore:
#   latest.tsv           current layout, rewritten every sweep
#   snap-<epoch>.tsv     history, one per layout change, newest @snapshot-keep kept
#   pre-boot-<boot>.tsv  last layout seen before this boot — the crash record
#
# The pre-boot copy exists because the first tmux started after a reboot would
# otherwise overwrite latest.tsv with an empty layout before you ever get to
# restore from it. An empty pre-boot file is a real answer: nothing was running.
#
# Tunables, global tmux options:
#   @snapshot-interval   seconds between sweeps   (default 60)
#   @snapshot-keep       history files to keep    (default 20)

set -uo pipefail

STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/tmux-restore"

# Scoped to the tmux socket, so a throwaway server started with -L for testing
# does not look like the daemon is already running.
SOCKET=$(basename "${TMUX%%,*}" 2>/dev/null)
PIDFILE="/tmp/tmux-snapshot-$(id -u)-${SOCKET:-default}.pid"

# Unit separator, not tab. Tab is an IFS whitespace character, so `IFS=$'\t'
# read` silently collapses runs of tabs — every empty field would shift the
# remaining columns left by one. A non-whitespace IFS preserves empty fields.
SEP=$'\037'

# Pane rows, not window rows: splits are part of the layout, and the Claude
# session id is a pane option. Window-level options resolve fine from a pane.
FIELDS="#{session_name}${SEP}#{window_index}${SEP}#{window_name}${SEP}#{window_active}${SEP}#{@park}${SEP}#{@park-note}${SEP}#{pane_index}${SEP}#{pane_active}${SEP}#{pane_current_path}${SEP}#{pane_current_command}${SEP}#{@claude-session}"

gopt() {
    local val
    val=$(tmux show-options -gqv "$1" 2>/dev/null)
    case "$val" in ''|*[!0-9]*) val="$2" ;; esac
    printf '%s' "$val"
}

boot_time() {
    local sec
    # `{ sec = 1786357709, usec = 577484 }` — the brace matters: without it the
    # greedy match lands on usec and the boot "time" is six digits long.
    sec=$(sysctl -n kern.boottime 2>/dev/null | sed -n 's/.*{ *sec = \([0-9]*\).*/\1/p')
    if [ -z "$sec" ] && command -v uptime >/dev/null 2>&1; then
        sec=$(date -d "$(uptime -s 2>/dev/null)" +%s 2>/dev/null)
    fi
    printf '%s' "${sec:-}"
}

# Keep the newest N files matching a glob, delete the rest. BSD head has no
# `-n -N`, so the count is done here rather than by trimming the tail.
prune_glob() {
    local pattern="$1" keep="$2" files n
    files=$(ls -1 $pattern 2>/dev/null | sort)
    [ -n "$files" ] || return 0
    n=$(printf '%s\n' "$files" | grep -c .)
    [ "$n" -gt "$keep" ] || return 0
    printf '%s\n' "$files" | head -n $(( n - keep )) | while IFS= read -r f; do
        rm -f "$f"
    done
}

# The first sweep after a reboot is the last chance to keep the pre-crash
# layout: every later sweep overwrites latest.tsv with windows from this boot.
preserve_pre_boot() {
    local boot keep stamp
    boot=$(boot_time)
    [ -n "$boot" ] || return 0

    keep="$STATE_DIR/pre-boot-$boot.tsv"
    [ -e "$keep" ] && return 0

    if [ ! -f "$STATE_DIR/latest.tsv" ]; then
        : > "$keep"
        return 0
    fi

    stamp=$(head -1 "$STATE_DIR/latest.tsv" | awk -F"$SEP" '{ print $2 }')
    case "$stamp" in ''|*[!0-9]*) stamp=0 ;; esac

    if [ "$stamp" -lt "$boot" ]; then
        cp "$STATE_DIR/latest.tsv" "$keep"
    else
        # Nothing predates this boot. Recorded as empty so the check does not
        # run again for the rest of the uptime.
        : > "$keep"
    fi
}

# What counts as the layout, for the purpose of deciding a snapshot is new:
# everything except window_active, pane_active and pane_current_command.
signature() {
    awk -F"$SEP" -v OFS="$SEP" '!/^#/ { $4 = ""; $8 = ""; $10 = ""; print }'
}

snap() {
    tmux has-session 2>/dev/null || return 0

    local rows
    rows=$(tmux list-panes -a -F "$FIELDS" 2>/dev/null) || return 0
    [ -n "$rows" ] || return 0

    mkdir -p "$STATE_DIR"
    preserve_pre_boot

    local now tmp
    now=$(date +%s)
    tmp="$STATE_DIR/.latest.$$"

    # Written to a temp file and moved into place. This file is the one thing a
    # crash leaves behind, and a reader catching a half-finished write would see
    # a truncated layout — mv is atomic within the directory.
    {
        printf '#tmux-snapshot%s%s\n' "$SEP" "$now"
        printf '%s\n' "$rows"
    } > "$tmp" || return 0
    mv -f "$tmp" "$STATE_DIR/latest.tsv"

    # History only grows when the layout actually changed. A 60s timer over a
    # day of the same five windows would otherwise bury the interesting ones —
    # and comparing the rows verbatim did exactly that: which window is current,
    # which pane is focused and what command is in the foreground all flip on
    # their own, so every single sweep counted as a change and 20 history files
    # covered 40 minutes.
    local last
    last=$(ls -1 "$STATE_DIR"/snap-*.tsv 2>/dev/null | sort | tail -1)
    if [ -n "$last" ] && [ "$(signature < "$last")" = "$(printf '%s\n' "$rows" | signature)" ]; then
        return 0
    fi

    cp "$STATE_DIR/latest.tsv" "$STATE_DIR/snap-$now.tsv"
    prune_glob "$STATE_DIR/snap-*.tsv" "$(gopt @snapshot-keep 20)"
    # Boot records are tiny and are the only thing that survives a crash, so
    # they outlive the ordinary history.
    prune_glob "$STATE_DIR/pre-boot-*.tsv" 5
}

daemon() {
    trap 'rm -f "$PIDFILE"' EXIT

    while true; do
        tmux has-session 2>/dev/null || exit 0
        snap
        sleep "$(gopt @snapshot-interval 60)"
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
    snap|run)
        snap
        ;;
    status)
        if [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE" 2>/dev/null)" 2>/dev/null; then
            echo "running (pid $(cat "$PIDFILE"), interval $(gopt @snapshot-interval 60)s, keep $(gopt @snapshot-keep 20))"
        else
            echo "not running"
        fi
        if [ -f "$STATE_DIR/latest.tsv" ]; then
            echo "latest: $(date -r "$STATE_DIR/latest.tsv" '+%d %b %H:%M'), $(( $(grep -c . "$STATE_DIR/latest.tsv") - 1 )) panes"
        fi
        ;;
    *)
        echo "usage: tmux-snapshot.sh {start|stop|restart|snap|status|daemon}" >&2
        exit 2
        ;;
esac
