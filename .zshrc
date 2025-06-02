# exports
export OBJC_DISABLE_INITIALIZE_FORK_SAFETY=YES
export LC_ALL=en_US.UTF-8
export LANG=en_US.UTF-8
export N_PREFIX=/usr/local

export PATH="$PATH:/usr/local/bin"
export PATH="/Users/livenl/.local/bin:$PATH"

if [[ ! -z ${SSH_AGENT_PID+x} ]]
then
   echo "ssh-agent is already running"
   # Do something knowing the pid exists, i.e. the process with $PID is running
else
eval `ssh-agent -s`
fi

# list aliasses
diff_lists() {
    if [ "$#" -ne 3 ]; then
        echo "Usage: diff_lists <source_file> <exclude_file> <output_file>"
        echo "Description: Extracts line-separated items from <source_file> that are not present in <exclude_file> and writes them to <output_file>."
        return
    fi
    grep -Fvxf "$2" "$1" > "$3"
}

alias ll='ls -al'
alias l='ls -l -a'
alias ls="ls -G -F"
alias ag='Ag --width 100 --hidden'
alias ndiff='nvim -u None -d'
alias co="git checkout"
alias gb="git branch --sort committerdate | tail"
alias curl='noglob curl'
alias project_lines='git ls-files | xargs wc -l'
alias wallpapers='open /Library/Application\ Support/com.apple.idleassetsd/Customer/4KSDR240FPS'
alias 32key="uuidgen | tr -d '-' | tr '[:upper:]' '[:lower:]'"

# requires pip install git+https://github.com/jeffkaufman/icdiff.git
alias gdiff='git difftool --extcmd icdiff -y'
alias linesofcode="git ls-files | xargs wc -l"

function auto_pipenv_shell {
    if [ ! -n "${PIPENV_ACTIVE+1}" ]; then
        if [ -f "Pipfile" ] ; then
            pipenv shell
        fi
    fi
}

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


# colors for terminal and tmux
export TERM="xterm-256color"
export EDITOR="nvim"
alias tmux="tmux -2"

# vim key bindings
bindkey -v

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
export PYTHONPATH="$PWD"
export PYTHONPATH="$PYTHONPATH:$RESOLVE_SCRIPT_API/Modules/"
export MYPYPATH="$PYTHONPATH"

export ANTHROPIC_API_KEY=$(cat ~/.antropic_api_key)
export OPENAI_API_KEY=$(cat ~/.openai_api_key)

if command -v pyenv 1>/dev/null 2>&1; then
  eval "$(pyenv init -)"
fi

bindkey '^R' history-incremental-search-backward
eval "$(rbenv init - zsh)"
export PATH="/opt/homebrew/opt/make/libexec/gnubin:$PATH"

[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh
export PATH="/opt/homebrew/bin:$PATH"
export PATH="/opt/homebrew/opt/libpq/bin:$PATH"
export PATH="/opt/homebrew/opt/postgresql@16/bin:$PATH"

ulimit -n 4096
export PATH=~/.npm-global/bin:$PATH
alias dig="/opt/homebrew/bin/dig"
export PATH="$HOME/.npm-global/bin:$PATH"
alias claude="/Users/livenl/.claude/local/claude"
