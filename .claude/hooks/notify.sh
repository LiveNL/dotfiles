#!/bin/bash

NOTIFIER_INPUT=$(cat)
MESSAGE=$(echo "$NOTIFIER_INPUT" | jq -r '.message // empty')
EVENT=$(echo "$NOTIFIER_INPUT" | jq -r '.hook_event_name // empty')
LAST_MSG=$(echo "$NOTIFIER_INPUT" | jq -r '.last_assistant_message // empty')

TMUX_WINDOW=""
IS_ACTIVE="0"
if [ -n "$TMUX" ]; then
    TMUX_WINDOW=$(tmux display-message -t "$TMUX_PANE" -p '#W')
    IS_ACTIVE=$(tmux display-message -t "$TMUX_PANE" -p '#{window_active}')
fi

REPO_NAME=$(basename "$(pwd)")
SUBTITLE="${TMUX_WINDOW:+$TMUX_WINDOW · }$REPO_NAME"

set_state() {
    if [ -n "$TMUX" ]; then
        tmux set-option -w -t "$TMUX_PANE" @claude-state "$1"
        tmux refresh-client -S
    fi
}

notify_macos() {
    local title="$1" msg="$2" sound="$3"
    osascript -e "display notification \"$(echo "$msg" | head -c 100)\" with title \"$title\" subtitle \"$SUBTITLE\" sound name \"$sound\""
}

if [ "$EVENT" = "Stop" ]; then
    # If last message ends with '?' Claude is asking for input, otherwise it's done
    PREVIEW=$(echo "$LAST_MSG" | tr '\n' ' ' | tail -c 120)
    if echo "$LAST_MSG" | grep -q '?$'; then
        set_state "input"
        if [ "$IS_ACTIVE" != "1" ]; then
            notify_macos "❓ Question" "${PREVIEW:-Claude needs your input}" "Pop"
        fi
    else
        set_state "done"
        if [ "$IS_ACTIVE" != "1" ]; then
            notify_macos "✅ Done" "${PREVIEW:-Ready for review}" "Glass"
        fi
    fi
elif [ "$EVENT" = "Notification" ]; then
    if echo "$MESSAGE" | grep -qi "permission"; then
        set_state "permission"
        CMD=$(echo "$MESSAGE" | sed 's/.*run: //' | head -c 80)
        notify_macos "🔑 Approval needed" "${CMD:-Needs your approval}" "Sosumi"
    else
        set_state "input"
        if [ "$IS_ACTIVE" != "1" ]; then
            notify_macos "💬 Input needed" "${MESSAGE:-Claude needs your attention}" "Pop"
        fi
    fi
fi
