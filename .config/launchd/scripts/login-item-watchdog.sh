#!/usr/bin/env bash
# Watch apps that are supposed to open at login, prove whether they actually did,
# and put them back when they didn't.
#
# macOS silently drops Background Task Management registrations, so an app can
# sit checked in Login Items & Extensions and still never spawn. The system log
# says nothing about the app that was not launched, so the only reliable record
# is one we write ourselves.
#
# Every run appends one line per watched app to the log:
#
#   2026-08-11T08:12:03+0200  login     baRSS  missing  relaunched  boot+180s
#   2026-08-11T08:17:03+0200  periodic  baRSS  running  -           boot+485s
#
#   login     first check after boot, taken once login items have had their turn
#   periodic  every StartInterval afterwards
#
# A `login missing` line is the failure you are hunting. A `periodic missing`
# after an earlier `running` means the app died on its own, which is a different
# bug. Run with --report for the tally.

set -uo pipefail

# Apps to watch, one per line: <name shown in the log>|<path to the .app>
# The name must match CFBundleExecutable — that is what shows up in the process
# table, and the .app basename is not always the same string.
WATCHED=$(
    cat <<'EOF'
baRSS|/Applications/baRSS.app
EOF
)

LOG="${LOGIN_ITEM_WATCHDOG_LOG:-$HOME/.local/state/login-item-watchdog.log}"

# Login items are handed to launchd over the first minute or so of a session.
# Checking earlier than this measures our own impatience, not their failure.
LOGIN_GRACE_SECONDS=180

# Runs starting inside this window are treated as the post-login check.
LOGIN_WINDOW_SECONDS=$((LOGIN_GRACE_SECONDS + 120))

relaunch=1

usage() {
    cat <<'EOF'
Usage: login-item-watchdog.sh [--check] [--no-relaunch] [--report]

  --check         run one pass now, skipping the post-login grace sleep
  --no-relaunch   only record the verdict, leave a missing app missing
  --report        summarise the log instead of checking anything
EOF
}

seconds_since_boot() {
    local boot now
    # Anchor on the opening brace: a greedy match lands on `usec` instead.
    boot=$(sysctl -n kern.boottime | sed -n 's/^{ sec = \([0-9]*\).*/\1/p')
    now=$(date +%s)
    echo $((now - boot))
}

log_line() {
    local tag="$1" name="$2" state="$3" action="$4" uptime="$5"
    printf '%s\t%-8s\t%-12s\t%-7s\t%-16s\tboot+%ss\n' \
        "$(date +%Y-%m-%dT%H:%M:%S%z)" "$tag" "$name" "$state" "$action" "$uptime" >>"$LOG"
}

check_app() {
    local tag="$1" name="$2" path="$3" uptime="$4"
    if pgrep -x "$name" >/dev/null 2>&1; then
        log_line "$tag" "$name" running - "$uptime"
        return 0
    fi
    if [ ! -d "$path" ]; then
        log_line "$tag" "$name" missing not-installed "$uptime"
        return 1
    fi
    if [ "$relaunch" != 1 ]; then
        log_line "$tag" "$name" missing left-alone "$uptime"
        return 1
    fi
    if open -gj -a "$path" >/dev/null 2>&1; then
        log_line "$tag" "$name" missing relaunched "$uptime"
    else
        log_line "$tag" "$name" missing relaunch-failed "$uptime"
    fi
    return 1
}

report() {
    if [ ! -s "$LOG" ]; then
        echo "No log yet at $LOG"
        return 0
    fi
    echo "Log: $LOG"
    echo
    awk -F'\t' '
        {
            gsub(/^[ \t]+|[ \t]+$/, "", $2)
            gsub(/^[ \t]+|[ \t]+$/, "", $3)
            gsub(/^[ \t]+|[ \t]+$/, "", $4)
            key = $3 " " $2
            total[key]++
            if ($4 == "missing") missing[key]++
        }
        END {
            printf "%-14s %-10s %8s %8s %8s\n", "APP", "WHEN", "RUNS", "MISSING", "RATE"
            for (k in total) {
                split(k, p, " ")
                m = (k in missing) ? missing[k] : 0
                printf "%-14s %-10s %8d %8d %7.0f%%\n", p[1], p[2], total[k], m, 100 * m / total[k]
            }
        }
    ' "$LOG" | sort -k2,2 -k1,1
    echo
    echo "Most recent:"
    tail -5 "$LOG"
}

main() {
    local skip_grace=0 do_report=0
    while [ $# -gt 0 ]; do
        case "$1" in
            --check) skip_grace=1 ;;
            --no-relaunch) relaunch=0 ;;
            --report) do_report=1 ;;
            -h | --help)
                usage
                return 0
                ;;
            *)
                echo "Unknown option: $1" >&2
                usage >&2
                return 2
                ;;
        esac
        shift
    done

    mkdir -p "$(dirname "$LOG")"

    if [ "$do_report" = 1 ]; then
        report
        return 0
    fi

    local uptime tag
    uptime=$(seconds_since_boot)
    if [ "$uptime" -lt "$LOGIN_WINDOW_SECONDS" ]; then
        tag=login
        if [ "$skip_grace" != 1 ] && [ "$uptime" -lt "$LOGIN_GRACE_SECONDS" ]; then
            sleep $((LOGIN_GRACE_SECONDS - uptime))
            uptime=$(seconds_since_boot)
        fi
    else
        tag=periodic
    fi

    local rc=0
    while IFS='|' read -r name path; do
        [ -n "$name" ] || continue
        check_app "$tag" "$name" "$path" "$uptime" || rc=1
    done <<<"$WATCHED"
    return $rc
}

main "$@"
