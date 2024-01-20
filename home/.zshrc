source ~/.antigenrc

ZSH_THEME="agnoster"

#auto cmd correction
ENABLE_CORRECTION="true"

# Display red dots whilst waiting for completion.
COMPLETION_WAITING_DOTS="true"

# History
HIST_STAMPS="yyyy-mm-dd"
HISTFILE=~/.histfile
HISTSIZE=10000000
SAVEHIST=10000000

source $HOME/.zsh_exports
source $HOME/.zsh_aliases
#startx
if [[ ! $DISPLAY && $XDG_VTNR -eq 1 ]]; then
  exec startx
fi

eval $(keychain --eval --quiet id_ed25519 id_rsa)