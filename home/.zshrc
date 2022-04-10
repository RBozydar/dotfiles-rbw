source ~/.antigenrc

ZSH_THEME="agnoster"

#auto cmd correction
ENABLE_CORRECTION="true"

# Display red dots whilst waiting for completion.
COMPLETION_WAITING_DOTS="true"

# History
HIST_STAMPS="yyyy-mm-dd"
HISTFILE=~/.histfile
HISTSIZE=1000000
SAVEHIST=1000000

source $HOME/.zsh_aliases
source $HOME/.zsh_exports

#startx
if [[ ! $DISPLAY && $XDG_VTNR -eq 1 ]]; then
  exec startx
fi
