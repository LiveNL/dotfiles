#!/usr/bin/env bash
# Read the snapshots written by tmux-snapshot.sh and put the windows back.
#
# What a snapshot cannot hold is the conversation itself — only the id of the
# Claude session that ran in the pane. The transcript for that id survives the
# crash under ~/.claude/projects, so restoring a window means: recreate it at
# the right cwd, then `claude --resume <id>` in it. Windows whose id was never
# recorded (opened before the SessionStart hook existed, or never running
# Claude) fall back to the newest transcript for that directory, which is how
# this reads anything from before it was installed.
#
#   list [--from FILE]                 what the snapshot holds
#   restore [workspace] [flags]        rebuild a whole workspace
#   popup <session> [tty]              fzf picker, restores single windows
#   hint                               one-shot post-reboot notice, for .zshrc
#   dismiss                            silence the hint for this boot
#
# restore flags: --into NAME  --from FILE  --dry-run  --no-run

set -uo pipefail

_self_src="${BASH_SOURCE[0]:-$0}"
SELF="$(cd "$(dirname "$_self_src")" && pwd)/$(basename "$_self_src")"
SCRIPT_DIR="$(dirname "$SELF")"
PARK="$SCRIPT_DIR/tmux-park.sh"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/tmux-restore"
PROJECTS="$HOME/.claude/projects"

# Resolved here, in your shell, rather than left to the tmux server's PATH — a
# server started from a login shell long ago can be missing half of it, and a
# restored window that cannot find claude looks like the restore failed.
CLAUDE_BIN=$(command -v claude 2>/dev/null || echo claude)

# Unit separator — see the note in tmux-snapshot.sh. Empty fields are the norm
# here (no park, no note, no Claude session), so this matters more than usual.
SEP=$'\037'

boot_time() {
    local sec
    # `{ sec = 1786357709, usec = 577484 }` — the brace matters: without it the
    # greedy match lands on usec and the boot "time" is six digits long.
    sec=$(sysctl -n kern.boottime 2>/dev/null | sed -n 's/.*{ *sec = \([0-9]*\).*/\1/p')
    if [ -z "$sec" ] && command -v uptime >/dev/null 2>&1; then
        sec=$(date -d "$(uptime -s 2>/dev/null)" +%s 2>/dev/null)
    fi
    printf '%s' "${sec:-0}"
}

stamp_of() {
    local f="$1" s
    [ -f "$f" ] || return 0
    s=$(head -1 "$f" | awk -F"$SEP" '{ print $2 }')
    case "$s" in ''|*[!0-9]*) s=0 ;; esac
    printf '%s' "$s"
}

human_gap() {
    local s="$1"
    if   [ "$s" -lt 90 ];    then printf '%ds' "$s"
    elif [ "$s" -lt 5400 ];  then printf '%dm' $(( s / 60 ))
    elif [ "$s" -lt 172800 ]; then printf '%dh' $(( s / 3600 ))
    else printf '%dd' $(( s / 86400 ))
    fi
}

# Which snapshot to read. The pre-boot copy wins whenever it exists and still
# holds something: after a crash that is the only file describing the layout you
# lost, while latest.tsv has already been overwritten by this boot's tmux.
resolve_source() {
    local explicit="${1:-}"
    if [ -n "$explicit" ]; then
        printf '%s' "$explicit"
        return 0
    fi

    local pre="$STATE_DIR/pre-boot-$(boot_time).tsv"
    if [ -s "$pre" ]; then
        printf '%s' "$pre"
        return 0
    fi

    [ -f "$STATE_DIR/latest.tsv" ] && printf '%s' "$STATE_DIR/latest.tsv"
}

# ------------------------------------------------------------------- reduction

# Snapshots are pane rows; almost everything here wants window rows. Emits
# session, index, name, park, note, pane count, cwd of the first pane, and the
# first Claude session id found in the window.
windows_of() {
    awk -F"$SEP" -v OFS="$SEP" -v SEP="$SEP" '
        /^#/ { next }
        {
            key = $1 SEP $2
            if (!(key in seen)) {
                seen[key] = 1
                order[++n] = key
                sess[key] = $1; idx[key] = $2; name[key] = $3
                park[key] = $5; note[key] = $6; cwd[key] = $9
            }
            panes[key]++
            if ($11 != "" && sid[key] == "") sid[key] = $11
        }
        END {
            for (i = 1; i <= n; i++) {
                k = order[i]
                print sess[k], idx[k], name[k], park[k], note[k], panes[k], cwd[k], sid[k]
            }
        }
    ' "$1"
}

# ------------------------------------------------------------------ transcripts

# Resolves each window to the last thing you said in it. Given a session id the
# transcript is a direct glob; without one it falls back to the newest transcript
# recorded for that directory, which is what makes windows from before the hook
# existed recoverable at all.
#
# Reads `sid<TAB>cwd` lines, prints `key<TAB>flag<TAB>text`, where key is the sid
# when known and `cwd:<path>` otherwise, and flag is `!` when the conversation
# ended on your turn — an unanswered prompt, the one you most want back.
ANNOTATE_PY='
import sys, os, json, glob

PROJECTS = os.path.expanduser("~/.claude/projects")
BLOCK = 256 * 1024

def slugs(path):
    # Claude flattens the cwd into a directory name. Slashes and dots become
    # dashes; the treatment of underscores has never been observable here, so
    # both spellings are tried.
    a = "".join("-" if c in "/." else c for c in path)
    b = "".join("-" if c in "/._" else c for c in path)
    return [a] if a == b else [a, b]

def transcript(sid, cwd):
    if sid:
        hit = glob.glob(os.path.join(PROJECTS, "*", sid + ".jsonl"))
        if hit:
            return hit[0]
    if cwd:
        for s in slugs(cwd):
            files = glob.glob(os.path.join(PROJECTS, s, "*.jsonl"))
            if files:
                return max(files, key=os.path.getmtime)
    return None

def prompt_of(line):
    try:
        d = json.loads(line)
    except Exception:
        return None, None
    kind = d.get("type") if d.get("type") in ("user", "assistant") else None
    if d.get("type") != "user" or not isinstance(d.get("message"), dict):
        return kind, None
    c = d["message"].get("content")
    if isinstance(c, list):
        c = " ".join(p.get("text", "") for p in c if isinstance(p, dict))
    if not isinstance(c, str) or not c.strip():
        return kind, None
    # Hook output, slash-command envelopes and task notifications all arrive as
    # user turns. None of them is a thing you typed, so none of them identifies
    # the conversation on sight.
    if c.startswith(("<local-command", "Caveat:", "<task-notification",
                     "<command-message", "<command-name", "<system-reminder")):
        return kind, None
    return kind, " ".join(c.split())

def last_prompt(path):
    # Read backwards. A single tool-heavy exchange can be hundreds of kilobytes,
    # so a fixed tail off the end of a long transcript often contains no typed
    # message at all — the first attempt at this returned blanks for the busiest
    # windows, which are the ones worth recovering.
    text, role = "", ""
    try:
        size = os.path.getsize(path)
        with open(path, "rb") as fh:
            pos, held = size, b""
            while pos > 0 and not text:
                step = min(BLOCK, pos)
                pos -= step
                fh.seek(pos)
                chunk = fh.read(step) + held
                lines = chunk.split(b"\n")
                held = lines.pop(0) if pos > 0 else b""
                for raw in reversed(lines):
                    if not raw.strip():
                        continue
                    kind, txt = prompt_of(raw.decode("utf-8", "replace"))
                    if kind and not role:
                        role = kind
                    if txt:
                        text = txt
                        break
    except OSError:
        return "", ""
    return text, ("!" if role == "user" else "")

for line in sys.stdin:
    sid, _, cwd = line.rstrip("\n").partition("\t")
    key = sid if sid else "cwd:" + cwd
    path = transcript(sid, cwd)
    if not path:
        print("%s\t\t" % key)
        continue
    text, flag = last_prompt(path)
    print("%s\t%s\t%s" % (key, flag, text[:70]))
'

annotate() {
    local file="$1"
    windows_of "$file" \
        | awk -F"$SEP" '{ print $8 "\t" $7 }' \
        | sort -u \
        | python3 -c "$ANNOTATE_PY" 2>/dev/null
}

# ------------------------------------------------------------------------ list

list_cmd() {
    local file
    file=$(resolve_source "${1:-}")
    if [ -z "$file" ] || [ ! -s "$file" ]; then
        echo "no snapshot yet — is tmux-snapshot.sh running? (tmux-snapshot.sh status)"
        return 0
    fi

    local stamp age kind now
    now=$(date +%s)
    stamp=$(stamp_of "$file")
    age=$(human_gap $(( now - stamp )))
    case "$(basename "$file")" in
        pre-boot-*) kind="pre-boot" ;;
        latest.tsv) kind="live" ;;
        *)          kind="history" ;;
    esac

    printf '\n  snapshot %s · %s ago · %s\n\n' "$(date -r "$stamp" '+%d %b %H:%M')" "$age" "$kind"

    local annot
    annot=$(annotate "$file")

    # ANNOT is passed with -v, not as a trailing assignment: assignments in the
    # operand list are only applied when awk reaches them, which is after BEGIN.
    windows_of "$file" | awk -F"$SEP" -v HOME="$HOME" -v ANNOT=<(printf '%s\n' "$annot") '
        BEGIN {
            while ((getline line < ANNOT) > 0) {
                split(line, a, "\t")
                flag[a[1]] = a[2]; text[a[1]] = a[3]
            }
        }
        # Worktree and monorepo paths are told apart by their tail, so a long
        # one loses its head instead of its end.
        function elide(p,   s) {
            s = p
            sub("^" HOME, "~", s)
            if (length(s) > 30) s = "\342\200\246" substr(s, length(s) - 28)
            return s
        }
        {
            sess = $1; idx = $2; name = $3; park = $4; panes = $6; cwd = $7; sid = $8
            if (sess != last) { printf "  %s\n", sess; last = sess }

            key = (sid != "") ? sid : "cwd:" cwd

            # ⬢ the id was recorded for this pane; ⬡ it was inferred from the
            # newest transcript for the directory, which can be the wrong chat
            # when two windows sat in one repo. Park state outranks both.
            mark = (sid != "") ? "\342\254\242" : (text[key] != "" ? "\342\254\241" : " ")
            if (park == "1")    mark = "\342\217\270"
            if (park == "auto") mark = "\342\227\214"

            tail = text[key]
            if (length(tail) > 44) tail = substr(tail, 1, 43) "\342\200\246"
            if (tail != "" && flag[key] == "!") tail = tail "  <- your turn"
            if (panes > 1) name = name " (" panes ")"

            printf "  %s %-3s %-20.20s %-30s %s\n", mark, idx, name, elide(cwd), tail
        }
    '

    printf '\n  restore: tmux-restore restore <workspace>\n\n'
}

# --------------------------------------------------------------------- restore

# A pane that should come back with a conversation in it is created running that
# conversation, rather than created empty and typed into. send-keys races the
# shell's own startup: the first attempt here put half the command on the tty
# before zsh had claimed it, and a half-typed `claude --resume <uuid>` that then
# gets an Enter is worse than no restore at all. The trailing `exec $SHELL`
# keeps the window alive after you quit Claude.
#
# --no-run still types, because its whole point is that nothing runs by itself —
# it waits for the shell first.
resume_command() {
    local sid="$1"
    printf '%s --resume %s; exec "$SHELL"' "${CLAUDE_BIN:-claude}" "$sid"
}

# Waits for the pane's shell to own the tty before typing into it. Anything
# sent before that is echoed by the raw terminal and then partly swallowed.
type_when_ready() {
    local pid="$1" text="$2" i
    # Waiting for pane_current_command to read "zsh" is not enough: the shell is
    # exec'd immediately and only draws its prompt a few hundred milliseconds
    # later, once its rc files are through. Until then the raw tty echoes what
    # arrives, so the command shows up twice. Painted output is the real signal.
    for (( i = 0; i < 40; i++ )); do
        if [ -n "$(tmux capture-pane -p -t "$pid" 2>/dev/null | tr -d '[:space:]')" ]; then
            break
        fi
        sleep 0.1
    done
    tmux send-keys -t "$pid" "$text" 2>/dev/null
}

# Transcript for a session id, if it still exists. A resume against a deleted
# transcript fails in a fresh window and reads as a broken restore, so the
# window comes back without it instead.
has_transcript() {
    ls -1 "$PROJECTS"/*/"$1".jsonl >/dev/null 2>&1
}

# Everything a window needs, replayed in the order tmux wants it. Panes are
# recreated with `split-window`, not by replaying a layout string — a snapshot
# taken at a different terminal size puts such a layout back wrong, and pane
# sizes are the one part nobody misses.
restore_window() {
    local file="$1" sess="$2" widx="$3" wname="$4" park="$5" note="$6" target="$7"
    local dry="$8" run="$9"

    local rows first_cwd first_sid wid cmd
    rows=$(awk -F"$SEP" -v s="$sess" -v i="$widx" '$1 == s && $2 == i' "$file" | sort -t"$SEP" -k7,7n)
    [ -n "$rows" ] || return 0
    first_cwd=$(head -1 <<<"$rows" | awk -F"$SEP" '{ print $9 }')
    first_sid=$(head -1 <<<"$rows" | awk -F"$SEP" '{ print $11 }')

    cmd=""
    if [ -n "$run" ] && [ -n "$first_sid" ] && has_transcript "$first_sid"; then
        cmd=$(resume_command "$first_sid")
    fi

    if [ -n "$dry" ]; then
        printf '  would create %s:%s %s (%s)\n' "$target" "$widx" "$wname" "$first_cwd"
    elif tmux has-session -t "=$target" 2>/dev/null; then
        wid=$(tmux new-window -d -P -F '#{window_id}' -t "$target:" -n "$wname" -c "$first_cwd" ${cmd:+"$cmd"} 2>/dev/null)
    else
        wid=$(tmux new-session -d -P -F '#{window_id}' -s "$target" -n "$wname" -c "$first_cwd" ${cmd:+"$cmd"} 2>/dev/null)
    fi

    local n=0
    while IFS="$SEP" read -r _ _ _ _ _ _ _ _ cwd _ sid; do
        [ -n "${cwd:-}" ] || continue
        n=$(( n + 1 ))

        local resume=""
        if [ -n "${sid:-}" ] && has_transcript "$sid"; then
            resume=1
        fi

        if [ -n "$dry" ]; then
            [ -n "$resume" ] && printf '    would resume %s in pane %s\n' "${sid:0:8}" "$n"
            continue
        fi
        [ -n "$wid" ] || continue

        local pid=""
        if [ "$n" -eq 1 ]; then
            pid=$(tmux list-panes -t "$wid" -F '#{pane_id}' 2>/dev/null | head -1)
        elif [ -n "$resume" ] && [ -n "$run" ]; then
            pid=$(tmux split-window -d -P -F '#{pane_id}' -t "$wid" -c "$cwd" "$(resume_command "$sid")" 2>/dev/null)
        else
            pid=$(tmux split-window -d -P -F '#{pane_id}' -t "$wid" -c "$cwd" 2>/dev/null)
        fi

        # Only the typed path is left to do here: the running path was handled
        # at creation.
        [ -n "$resume" ] && [ -z "$run" ] && [ -n "$pid" ] && type_when_ready "$pid" "${CLAUDE_BIN:-claude} --resume $sid"
    done <<<"$rows"

    [ -n "$dry" ] && return 0
    [ -n "$wid" ] || return 0

    [ "$n" -gt 1 ] && tmux select-layout -t "$wid" tiled >/dev/null 2>&1

    # Park state is carried over so a workspace comes back with the same windows
    # dimmed and pushed right, rather than presenting twelve equal tabs.
    if [ -n "${park:-}" ]; then
        tmux set-option -w -t "$wid" @park "$park" 2>/dev/null
        tmux set-option -w -t "$wid" @park-at "$(date +%s)" 2>/dev/null
        tmux set-option -w -t "$wid" @park-note "${note:-}" 2>/dev/null
    fi
}

restore_cmd() {
    local workspace="" file="" into="" dry="" run=1

    while [ $# -gt 0 ]; do
        case "$1" in
            --from)    file="${2:-}"; shift ;;
            --into)    into="${2:-}"; shift ;;
            --dry-run) dry=1 ;;
            --no-run)  run="" ;;
            -*)        echo "unknown flag: $1" >&2; return 2 ;;
            *)         workspace="$1" ;;
        esac
        shift
    done

    file=$(resolve_source "$file")
    if [ -z "$file" ] || [ ! -s "$file" ]; then
        echo "no snapshot to restore from"
        return 1
    fi

    local sessions
    sessions=$(windows_of "$file" | awk -F"$SEP" '{ print $1 }' | awk '!seen[$0]++')

    if [ -z "$workspace" ]; then
        if [ "$(printf '%s\n' "$sessions" | grep -c .)" = "1" ]; then
            workspace="$sessions"
        else
            echo "which workspace? snapshot holds:"
            printf '%s\n' "$sessions" | sed 's/^/  /'
            return 2
        fi
    fi

    if ! grep -qx "$workspace" <<<"$sessions"; then
        echo "no workspace '$workspace' in $(basename "$file")"
        return 1
    fi

    # Restoring never merges into a live session of the same name: a half-built
    # workspace landing on top of one you are working in cannot be undone.
    local target="${into:-$workspace}" n=1
    while tmux has-session -t "=$target" 2>/dev/null; do
        n=$(( n + 1 ))
        target="${into:-$workspace}-$n"
    done

    [ -n "$dry" ] && printf 'dry run — would restore %s as %s\n' "$workspace" "$target"

    while IFS="$SEP" read -r sess widx wname park note _ _ _; do
        [ "$sess" = "$workspace" ] || continue
        restore_window "$file" "$sess" "$widx" "$wname" "$park" "$note" "$target" "$dry" "$run"
    done < <(windows_of "$file")

    [ -n "$dry" ] && return 0

    tmux has-session -t "=$target" 2>/dev/null || { echo "nothing restored"; return 1; }

    [ -x "$PARK" ] && "$PARK" sort "$target" >/dev/null 2>&1
    touch "$STATE_DIR/restored-$(boot_time)" 2>/dev/null

    local count
    count=$(tmux list-windows -t "=$target" 2>/dev/null | grep -c .)
    printf 'restored %s windows into %s\n' "$count" "$target"

    if [ -z "${TMUX:-}" ] && [ -t 1 ]; then
        tmux attach -t "=$target"
    else
        printf 'switch with: tmux switch-client -t %s\n' "$target"
    fi
}

# ---------------------------------------------------------------------- picker

# Every snapshot on disk, newest first, so the most recent version of a window
# wins the dedupe below. The pre-boot record leads: those are the windows the
# crash took, which is the whole reason any of this exists.
snapshot_files() {
    local pre="$STATE_DIR/pre-boot-$(boot_time).tsv"
    [ -s "$pre" ] && printf '%s\n' "$pre"
    ls -1t "$STATE_DIR"/snap-*.tsv 2>/dev/null
    [ -f "$STATE_DIR/latest.tsv" ] && printf '%s\n' "$STATE_DIR/latest.tsv"
    return 0
}

# Windows the snapshots know about and the server does not — closed, or lost
# with a dead session. Offering the ones already on screen made the picker a
# list of what you are looking at.
#
# Emits pane rows in snapshot format, so everything downstream reads it like any
# other snapshot; window indices are renumbered because two source files can
# both hold a window 3 and restore_window addresses rows by session and index.
candidates() {
    local out="$1" seen="$2" live n=0 f

    live=$(tmux list-panes -a -F "#{session_name}${SEP}#{window_name}${SEP}#{pane_current_path}" 2>/dev/null)
    printf '#tmux-snapshot%s%s\n' "$SEP" "$(date +%s)" > "$out"
    : > "$seen"

    while IFS= read -r f; do
        [ -s "$f" ] || continue
        while IFS="$SEP" read -r sess widx wname park note panes cwd sid; do
            [ -n "${wname:-}" ] || continue

            local key="${sess}${SEP}${wname}${SEP}${cwd}"
            grep -qxF "$key" "$seen" 2>/dev/null && continue
            printf '%s\n' "$key" >> "$seen"
            grep -qxF "$key" <<<"$live" 2>/dev/null && continue

            n=$(( n + 1 ))
            awk -F"$SEP" -v OFS="$SEP" -v s="$sess" -v i="$widx" -v n="$n" \
                '$1 == s && $2 == i { $2 = n; print }' "$f" >> "$out"
        done < <(windows_of "$f")
    done < <(snapshot_files)

    [ "$n" -gt 0 ]
}

# Single windows, pulled into the session you are in — the "I closed the wrong
# tab" case, which wants none of the workspace machinery above.
popup() {
    local session="${1:-}"
    local file seen

    file=$(mktemp "${TMPDIR:-/tmp}/tmux-restore.XXXXXX")
    seen=$(mktemp "${TMPDIR:-/tmp}/tmux-restore-seen.XXXXXX")
    trap 'rm -f "$file" "$seen"' RETURN

    if ! candidates "$file" "$seen"; then
        if [ -z "$(snapshot_files)" ]; then
            printf 'No snapshot yet — is the daemon running? (tmux-snapshot.sh status)\n'
        else
            printf 'Nothing to bring back: every window on record is already open.\n'
        fi
        read -r -n 1 -s
        return 0
    fi

    if ! command -v fzf >/dev/null 2>&1; then
        printf 'fzf is not on the PATH this popup was given:\n\n  %s\n' "$PATH"
        read -r -n 1 -s
        return 0
    fi

    local annot lines
    annot=$(annotate "$file")
    lines=$(windows_of "$file" | awk -F"$SEP" -v HOME="$HOME" -v ANNOT=<(printf '%s\n' "$annot") '
        BEGIN {
            while ((getline line < ANNOT) > 0) {
                split(line, a, "\t")
                text[a[1]] = a[3]
            }
        }
        function elide(p,   s) {
            s = p
            sub("^" HOME, "~", s)
            if (length(s) > 30) s = "\342\200\246" substr(s, length(s) - 28)
            return s
        }
        {
            key = ($8 != "") ? $8 : "cwd:" $7
            tail = text[key]
            if (length(tail) > 44) tail = substr(tail, 1, 43) "\342\200\246"
            # Session and index lead the row as lookup keys, cut away before the
            # line reaches fzf.
            printf "%s\t%s\t%-12.12s %-3s %-18.18s %-30s %s\n", $1, $2, $1, $2, $3, elide($7), tail
        }
    ')

    [ -n "$lines" ] || { printf 'Snapshot is empty.\n'; read -r -n 1 -s; return 0; }

    # --no-mouse: with `mouse on` and `focus-events on`, tmux forwards mouse and
    # focus escapes into the popup and fzf reads them as movement plus accept.
    local pick rc
    pick=$(cut -f3- <<<"$lines" | fzf --no-mouse --reverse --no-sort --multi \
        --prompt='closed > ' \
        --header='windows not open right now · tab select · enter restore here · esc cancel')
    rc=$?
    case "$rc" in
        0)     ;;
        1|130) return 0 ;;
        *)     printf 'fzf exited %s\n' "$rc"; read -r -n 1 -s; return 0 ;;
    esac

    while IFS= read -r row; do
        [ -n "$row" ] || continue
        local sess widx wname park note
        sess=$(awk -F'\t' -v r="$row" '$3 == r { print $1; exit }' <<<"$lines")
        widx=$(awk -F'\t' -v r="$row" '$3 == r { print $2; exit }' <<<"$lines")
        [ -n "$sess" ] || continue

        IFS="$SEP" read -r _ _ wname park note _ _ _ < <(windows_of "$file" | awk -F"$SEP" -v s="$sess" -v i="$widx" '$1 == s && $2 == i')
        restore_window "$file" "$sess" "$widx" "$wname" "$park" "$note" "$session" "" 1
    done <<<"$pick"

    tmux refresh-client -S 2>/dev/null
}

# ------------------------------------------------------------------------ hint

# Printed by .zshrc on the first shell after a reboot, so the recovery finds you
# rather than the other way round — after a crash there is no tmux running yet,
# which is exactly when the key binding cannot help. awk only, no python: this
# sits in shell startup.
hint() {
    local boot pre marker
    boot=$(boot_time)
    pre="$STATE_DIR/pre-boot-$boot.tsv"
    marker="$STATE_DIR/hinted-$boot"

    [ -s "$pre" ] || return 0
    [ -e "$marker" ] && return 0
    [ -e "$STATE_DIR/restored-$boot" ] && return 0

    touch "$marker" 2>/dev/null

    local stamp gap when
    stamp=$(stamp_of "$pre")
    gap=$(( boot - stamp ))
    when="snapshot $(date -r "$stamp" '+%d %b %H:%M')"
    # A snapshot can carry a timestamp from after the recorded boot when the
    # clock moved or the file was seeded by hand; saying "-24h before reboot"
    # would just look broken.
    [ "$gap" -gt 0 ] && when="$when, $(human_gap "$gap") before reboot"

    printf '\n  \033[1mcrash recovery\033[0m  %s\n\n' "$when"

    windows_of "$pre" | awk -F"$SEP" '
        { win[$1]++; if ($8 != "") chat[$1]++ }
        END {
            for (s in win)
                printf "  %-14s %d windows   %d chats\n", s, win[s], chat[s] + 0
        }
    ' | sort

    printf '\n  tmux-restore list      what was open\n'
    printf '  tmux-restore restore   put it back\n'
    printf '  tmux-restore dismiss   never mind\n\n'
}

case "${1:-list}" in
    list)    shift; list_cmd "${1:-}" ;;
    restore) shift; restore_cmd "$@" ;;
    popup)   shift; popup "$@" ;;
    hint)    hint ;;
    dismiss) touch "$STATE_DIR/restored-$(boot_time)" 2>/dev/null ;;
    source)  resolve_source "" ; echo ;;
    *)
        echo "usage: tmux-restore.sh {list|restore|popup|hint|dismiss} [args]" >&2
        exit 2
        ;;
esac
