# exports
export OBJC_DISABLE_INITIALIZE_FORK_SAFETY=YES
export LC_ALL=en_US.UTF-8
export LANG=en_US.UTF-8

export PATH="$PATH:/usr/local/bin"

if [[ ! -z ${SSH_AGENT_PID+x} ]]
then
   echo "ssh-agent is already running"
   # Do something knowing the pid exists, i.e. the process with $PID is running
else
eval `ssh-agent -s`
fi

# list aliasses
alias ll='ls -al'
alias l='ls -l -a'
alias ls="ls -G -F"
alias ag='Ag --width 100'
alias ndiff='nvim -u None -d'
alias co="git checkout"
alias gb="git branch --sort committerdate | tail"
alias curl='noglob curl'
alias project_lines='git ls-files | xargs wc -l'

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
export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/bin:$PATH"
export PYTHONPATH="$PWD"
export MYPYPATH="$PYTHONPATH"

if command -v pyenv 1>/dev/null 2>&1; then
  eval "$(pyenv init -)"
fi

bindkey '^R' history-incremental-search-backward
export PATH="/opt/homebrew/opt/ruby/bin:$PATH"
export PATH="/opt/homebrew/opt/make/libexec/gnubin:$PATH"
