#!/bin/bash
if [ -n "$TMUX" ]; then
    tmux set-option -w -t "$TMUX_PANE" @claude-state ""
    tmux refresh-client -S
fi
