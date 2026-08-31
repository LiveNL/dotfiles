# exports
export OBJC_DISABLE_INITIALIZE_FORK_SAFETY=YES
export LC_ALL=en_US.UTF-8
export LANG=en_US.UTF-8
export N_PREFIX=/usr/local

# keep PATH entries unique — .zshrc and .zprofile both prepend the same dirs
typeset -U path PATH

export PATH="$PATH:/usr/local/bin"
export PATH="$HOME/.local/bin:$PATH"

# one shared agent at a fixed socket, reused by every shell.
# the old `eval $(ssh-agent -s)` spawned a fresh agent per terminal window.
export SSH_AUTH_SOCK="$HOME/.ssh/agent.sock"
if ! ssh-add -l >/dev/null 2>&1; then
  rm -f "$SSH_AUTH_SOCK"
  eval "$(ssh-agent -a "$SSH_AUTH_SOCK" -s)" >/dev/null
  ssh-add --apple-load-keychain 2>/dev/null
fi

# list aliasses
#? shell  lines in A that are not in B
diff_lists() {
    if [ "$#" -ne 3 ]; then
        echo "Usage: diff_lists <source_file> <exclude_file> <output_file>"
        echo "Description: Extracts line-separated items from <source_file> that are not present in <exclude_file> and writes them to <output_file>."
        return
    fi
    grep -Fvxf "$2" "$1" > "$3"
}

alias ll='ls -al'   #? shell  long listing
alias l='ls -l -a'
alias ls="ls -G -F"
alias ag='Ag --width 100 --hidden'   #? search  Ag, 100 cols, hidden files included
alias ndiff='nvim -u None -d'   #? diff  nvim side-by-side, no config
alias co="git checkout"   #? git  checkout
alias gb="git branch --sort committerdate | tail"   #? git  branches by last commit date
alias curl='noglob curl'
alias project_lines='git ls-files | xargs wc -l'   #? git  line count over tracked files
alias wallpapers='open /Library/Application\ Support/com.apple.idleassetsd/Customer/4KSDR240FPS'   #? macos  open the 4K aerial wallpaper folder
alias 32key="uuidgen | tr -d '-' | tr '[:upper:]' '[:lower:]'"   #? shell  32-char hex key

# PTY wrapper (~/.local/bin/claude-color) recolors bold/italic/underline in the
# transcript; colors live in ~/.config/claude-color.conf, live-reloaded
#? claude  wrapper that recolors the transcript
alias claude='claude-color'

# requires pip install git+https://github.com/jeffkaufman/icdiff.git
alias gdiff='git difftool --extcmd icdiff -y'   #? diff  git diff through icdiff
alias linesofcode="git ls-files | xargs wc -l"   #? git  line count over tracked files
alias dotfiles='cd ~/projects/dotfiles'   #? nav  cd to the dotfiles repo
alias app='cd ~/projects/tsl/app'   #? nav  cd to tsl/app
alias lf='op run --env-file=$HOME/.langfuse.env --no-masking -- langfuse'   #? tools  langfuse with 1Password env

#? python  enter the pipenv shell when a Pipfile is here
function auto_pipenv_shell {
    if [ ! -n "${PIPENV_ACTIVE+1}" ]; then
        if [ -f "Pipfile" ] ; then
            pipenv shell
        fi
    fi
}

#? shell  ag + sed rename across the tree
function find_replace() {
    if [ "$#" -ne 2 ]; then
        echo "Usage: find_replace <input> <output>"
        return 1
    fi

    local input=$1
    local output=$2

    ag -l "$input" | xargs sed -i "s/$input/$output/g"
}

alias find_replace=find_replace


# colors outside tmux only — inside, tmux sets tmux-256color and clobbering it
# misreports capabilities to apps (claude code's renderer among them)
[[ -z $TMUX ]] && export TERM="xterm-256color"
export EDITOR="nvim"
# BROWSER unset on purpose: with it exported, every cli that resolves a url —
# claude code included — sent clicks into terminal-browser. Links now go to the
# system default (Arc); prefix + u picks a url and opens it in terminal-browser,
# which tmux-urls calls by path and does not need $BROWSER for.
# Per command when you do want it: BROWSER="$HOME/.local/bin/tb-open" gh browse

# terminal-browser guesses the device pixel ratio from the display under the
# mouse cursor, not the display ghostty is on (session.tsx hostDisplayScale).
# With a 1x external plus two retina screens that guess flips between 1 and 2:
# at 2 the page gets half the CSS width, so wide pages overflow the pane and
# pointer coordinates land at half position, which breaks scrolling too.
# 1 is right for the 2560x1440 external; set 2 when ghostty runs on a retina screen.
export TERMINAL_BROWSER_DISPLAY_SCALE=1   #? browser  pin terminal-browser dpi, cursor-screen guess flips
alias tmux="tmux -2"   #? tmux  tmux with 256 colours forced

# vim key bindings
bindkey -v   #? shell:Esc  vi mode on the command line, then hjkl / w / b / ciw

# prompt theme
source ~/projects/dotfiles/minimal.zsh

# auto-suggestions
source ~/.zsh/zsh-autosuggestions/zsh-autosuggestions.zsh
export ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=6'

plugins=(git ssh-agent)

# pyenv
export RESOLVE_SCRIPT_API="/Library/Application\ Support/Blackmagic\ Design/DaVinci\ Resolve/Developer/Scripting/"
export RESOLVE_SCRIPT_LIB="/Applications/DaVinci\ Resolve/DaVinci\ Resolve.app/Contents/Libraries/Fusion/fusionscript.so"
export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/bin:$PATH"

# per-project entries belong in a direnv .envrc — $PWD here freezes the shell's launch dir
export PYTHONPATH="$RESOLVE_SCRIPT_API/Modules/"
export MYPYPATH="$PYTHONPATH"

[ -f ~/.openai_api_key ] && export OPENAI_API_KEY=$(<~/.openai_api_key)
[ -f ~/.anthropic_api_key ] && export ANTHROPIC_API_KEY=$(<~/.anthropic_api_key)

# --no-rehash: `pyenv init -` otherwise emits a blocking `pyenv rehash` that
# every new shell runs. Rehash takes a lock on ~/.pyenv/shims/.pyenv-shim, and a
# rehash killed mid-run leaves that file behind — after which every new shell
# waits out PYENV_REHASH_TIMEOUT (60s) on a blank screen before its prompt
# appears. Shims only need rebuilding after installing a python or a package
# with an entry point, so run `pyenv rehash` by hand there.
if command -v pyenv 1>/dev/null 2>&1; then
  eval "$(pyenv init - --no-rehash)"
fi

bindkey '^R' history-incremental-search-backward   #? shell:C-R  incremental history search
eval "$(rbenv init - zsh)"
export PATH="/opt/homebrew/opt/make/libexec/gnubin:$PATH"

[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh
export PATH="/opt/homebrew/bin:$PATH"
export PATH="/opt/homebrew/opt/libpq/bin:$PATH"
export PATH="/opt/homebrew/opt/postgresql@16/bin:$PATH"
set rtp+=/opt/homebrew/opt/fzf

ulimit -n 4096
alias dig="/opt/homebrew/bin/dig"
export PATH="$HOME/.npm-global/bin:$PATH"

# Added by Antigravity
export PATH="$HOME/.antigravity/antigravity/bin:$PATH"

#? git  drop a stale index.lock before running git
git() {
  local git_dir
  git_dir=$(command git rev-parse --git-dir 2>/dev/null)
  if [[ -n "$git_dir" && -f "$git_dir/index.lock" ]]; then
    if ! lsof "$git_dir/index.lock" > /dev/null 2>&1; then
      rm -f "$git_dir/index.lock"
    fi
  fi
  command git "$@"
}

# Claude Code account switching
alias claude-work="CLAUDE_CONFIG_DIR=~/.claude-work command claude"   #? claude  run Claude on the work account
alias claude-personal="CLAUDE_CONFIG_DIR=~/.claude-personal command claude"   #? claude  run Claude on the personal account

# Remote Control needs feature-flag evaluation, which DISABLE_TELEMETRY in
# ~/.claude/settings.json kills. Shell env and project settings both lose to the
# user settings file, and `rc` rejects --settings, so the only lever is dropping
# the key for the lifetime of the run and putting it back on exit.
# A nested run also inherits the variable from the parent Claude process, hence
# the unset next to the settings rewrite. The trap is double quoted on purpose:
# the paths have to be baked in, since the locals are gone once it fires.
claude-nt() {   #? claude  run Claude with telemetry on, so Remote Control works
  local settings=~/.claude/settings.json backup
  backup=$(mktemp) || return 1
  cp "$settings" "$backup" || return 1
  trap "cp '$backup' '$settings'; rm -f '$backup'" EXIT INT TERM
  jq 'del(.env.DISABLE_TELEMETRY)' "$backup" > "$settings"
  (unset DISABLE_TELEMETRY; claude-color "$@")
  trap - EXIT INT TERM
  cp "$backup" "$settings"
  rm -f "$backup"
}

# After a crash or a restart, say what tmux was holding — see
# .config/tmux/scripts/tmux-restore.sh. Prints once per boot and only when a
# pre-boot snapshot exists, so an ordinary shell pays one file test.
if [[ -z "$TMUX" && -o interactive ]]; then
  "$HOME/.config/tmux/scripts/tmux-restore.sh" hint 2>/dev/null
  # What you annotated in the last fortnight, from a cache the same shell
  # refreshes in the background — the greeting itself is one `cat`.
  cheat --greet 2>/dev/null
fi

# bun completions
[ -s "$HOME/.bun/_bun" ] && source "$HOME/.bun/_bun"

# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"

envsync() {
  local main=$(dirname "$(git rev-parse --path-format=absolute --git-common-dir)") &&
  local root=$(git rev-parse --show-toplevel) &&
  [[ "$main" != "$root" ]] &&
  cp "$main"/config/.env "$main"/config/.{development,staging,production}.env "$root"/config/ &&
  cp "$main"/backend/config/eu-west-3-bundle.pem "$root"/backend/config/ &&
  echo "envs copied from $main"
}
