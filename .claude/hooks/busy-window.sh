#!/bin/bash
if [ -n "$TMUX" ]; then
    tmux set-option -w -t "$TMUX_PANE" @claude-state "running"
    tmux refresh-client -S
fi
