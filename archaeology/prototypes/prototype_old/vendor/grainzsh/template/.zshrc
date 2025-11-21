# grainzsh: minimal shell configuration for grain network
# ========================================================
# teamprecision06 (Virgo ♍ / VI. The Lovers)
# Every configuration is a conscious choice.

# Prompt: λ (lambda - transformation through functions)
PROMPT='λ '

# History: remember your choices
HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000
setopt SHARE_HISTORY
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_SPACE
setopt HIST_REDUCE_BLANKS

# Completion: intelligent selection
autoload -Uz compinit
compinit

zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'
zstyle ':completion:*' menu select
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"

# Environment: grain network paths
export GRAIN_HOME="$HOME/kae3g/grainkae3g"
export GRAINSTORE="$GRAIN_HOME/grainstore"

# Editor: conscious choice
export EDITOR="vim"
export VISUAL="vim"

# Path: essential binaries
export PATH="$HOME/.local/bin:$PATH"

# Aliases: git essentials
alias g='git'
alias gs='git status'
alias ga='git add'
alias gc='git commit'
alias gp='git push'
alias gl='git log --oneline --graph --decorate'

# Aliases: grain navigation
alias cdg='cd $GRAIN_HOME'
alias cdstore='cd $GRAINSTORE'

# Aliases: system
alias ls='ls --color=auto'
alias ll='ls -lah'
alias grep='grep --color=auto'
alias ..='cd ..'
alias ...='cd ../..'

# Keybindings: emacs style
bindkey -e

# Colors: visual clarity
export LS_COLORS='di=34:ln=35:so=32:pi=33:ex=31'

# Personal: load if exists
PERSONAL_ZSHRC="$GRAINSTORE/personal/.zshrc"
if [ -f "$PERSONAL_ZSHRC" ]; then
    source "$PERSONAL_ZSHRC"
fi

