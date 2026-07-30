# tmux park

Defer a window instead of renaming it. Replaces the habit of typing `X ` in front
of a window name and hand-swapping it to the right of the bar.

## Why not the window name

Encoding state in the name fights `automatic-rename`, cannot be filtered or
sorted, and is lost the moment the window is renamed. Park state lives in window
options instead, exactly like the `@claude-state` indicators:

| Option | Meaning |
| --- | --- |
| `@park` | `1` parked by hand, `auto` detected stale, empty active |
| `@park-at` | epoch seconds it was parked, drives the age column |
| `@park-seq` | monotonic counter, orders the parked block |
| `@park-home` | index it sat at before parking, so unparking puts it back |
| `@park-note` | optional "why", shown in the menu |
| `@park-touch` | epoch seconds it last had your attention |
| `@park-never` | set to `1` to exempt a window from auto-parking |

## Keys

| Key | Action |
| --- | --- |
| `prefix + P` | toggle park on the current window |
| `prefix + N` | prompt for a note, parking the window if needed |
| `prefix + F` | menu of parked windows — number key jumps, `u` unpark one, `U` unpark all |
| `prefix + C-f` | same list as an fzf popup, for fuzzy matching a long list |
| `prefix + O` | re-sort (parked windows to the right) |

`prefix + F` is a native `display-menu`, not fzf in a popup. tmux draws it and
consumes the keystrokes itself, so nothing the terminal emits can reach it — see
the gotchas below for why that matters here.

## Behaviour

- Parked windows render dim gray with a `⏸` badge and sort to the highest indices, oldest park first.
- Auto-stale windows render amber with a `◌` badge and clear themselves the moment you select the window.
- A hand-park never clears itself, so peeking at one does not reshuffle the bar.
- Unparking returns the window to the index it was parked from, not the end of the active block.
- Re-ordering pins the active window, so sorting never moves your focus.
- Parking is silent on purpose — `message-style` here is a light background, so a
  status-line confirmation flashes the whole bar white on every park.
- Park state beats `@claude-state` in the status bar: a deferred window stays visually quiet.

Unparking one window restores its slot exactly. Unparking several in a row is
approximate: `@park-home` is an index, and each restore shifts the ones after it.

## Auto-stale detection

`tmux-stale.sh` runs as a background daemon started from `.tmux.conf`. Each sweep
parks any window that is not current, not already parked, not `@park-never`, and
not mid-Claude-run, whose quiet time exceeds the threshold. Quiet time is the
newer of `@park-fp-at` (its own output fingerprint last changed) and `@park-touch`.

### Why not `#{window_activity}`

It was the obvious signal and it does not work. tmux bumps `window_activity` for
every window at once, several times an hour. Measured over 54 minutes of ordinary
use: **7 bulk resets, largest gap 13 minutes**, against a 45-minute threshold —
nothing ever went stale, and the failure was silent.

The fingerprint is built per window from `history_size`, `history_bytes` and
`pane_current_command` across its panes, stored in `@park-fp` with the timestamp
of its last change in `@park-fp-at`. Those only move when that window's own panes
do something; a resize or status redraw cannot touch them.

Fingerprints are refreshed for *every* window each sweep, including the current
one, parked ones and mid-run ones — skipping them would leave a stale fingerprint
that reads as instantly-quiet the moment the window became eligible again.

Alternate-screen apps (nvim, the Claude TUI) do not grow history, so a window
left sitting in one reads as quiet. That is intended: dwell is what marks a
window you are actually using.

```bash
set -g @park-stale-mins 45       # 0 disables auto-parking entirely
set -g @park-stale-interval 60   # seconds between sweeps
set -g @park-dwell-secs 30       # how long a visit must last to count
```

### Attention needs dwell, not arrival

`@park-touch` is not stamped when you enter a window, only once you have stayed
`@park-dwell-secs` in it. Cycling sideways through windows with `S-Left` /
`S-Right` would otherwise reset every idle clock it passed, so nothing would ever
go stale — and passing over an auto-parked window would release it and slide it
back left mid-cycle.

A detached watcher does the waiting: it sleeps, checks the window is still
current, then stamps. It re-stamps while you stay and exits as soon as you leave,
so at most one watcher is ever doing work and a stale one lives at most
`@park-dwell-secs`. Set the option to `0` for the old count-every-visit behaviour.

```bash
~/.config/tmux/scripts/tmux-stale.sh status     # is the daemon alive
~/.config/tmux/scripts/tmux-stale.sh restart    # after changing the threshold
PARK_STALE_SECS=1 ~/.config/tmux/scripts/tmux-stale.sh run   # force a sweep, seconds threshold
```

## State on disk

Parked windows are mirrored to `~/.local/state/tmux-park/<session>.tsv` on every
change, so the set is readable outside tmux. A tmux server restart destroys the
windows themselves; `tmux-park.sh restore <session>` re-applies the mirror to
whatever windows came back with matching names.

## Gotchas worth remembering

- Shell parsing of tmux formats uses `\037`, not tab: tab is IFS whitespace, so
  `IFS=$'\t' read` collapses runs of tabs and every unset option shifts the
  columns left by one.
- The park counter is `@park-seq-counter`, not `@park-seq`. tmux resolves
  `#{@name}` window → session → global, so a global `@park-seq` would leak into
  every window that has none of its own.
- `next-window` / `previous-window` have no `after-*` hooks, so attention is
  tracked via `session-window-changed`, which fires however the window changed.
- `move-window -d` is not enough to keep focus put; the active window is captured
  and re-selected explicitly.
- Every move in a reorder goes into ONE tmux command list. Reordering 10 windows
  takes 20 moves through the scratch index range, and issuing them as 20 separate
  invocations meant 20 client round trips and 20 status redraws — the tabs visibly
  marched out to index 105+ and back. One list, one repaint.
- Callers that touch several windows set `PARK_DEFER_SORT=1` and reorder once at
  the end, so a sweep parking three windows is one shuffle, not three.
- `renumber-windows on` only fires when a window closes, so a `move-window -b`
  insert leaves a hole in the index sequence. The sort therefore checks index
  contiguity as well as order before deciding it has nothing to do.
- fzf inside `display-popup` is fragile here: with `mouse on` and
  `focus-events on`, terminal escape sequences reach fzf as cursor movement and
  an accept, so the popup looked like it closed instantly and jumped to a window
  nobody picked. `--no-mouse` fixes the phantom accept; a stray ESC can still
  cancel it. That is why the default binding is a native menu.
