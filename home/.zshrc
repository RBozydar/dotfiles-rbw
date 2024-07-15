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

source $HOME/.zsh_aliases
source $HOME/.zsh_exports

#startx
if [[ ! $DISPLAY && $XDG_VTNR -eq 1 ]]; then
  exec startx
fi

# The next line updates PATH for the Google Cloud SDK.
if [ -f '/home/rbw/google-cloud-sdk/path.zsh.inc' ]; then . '/home/rbw/google-cloud-sdk/path.zsh.inc'; fi

# The next line enables shell command completion for gcloud.
if [ -f '/home/rbw/google-cloud-sdk/completion.zsh.inc' ]; then . '/home/rbw/google-cloud-sdk/completion.zsh.inc'; fi

if [ -z "$SSH_AUTH_SOCK" ] ; then
    eval `ssh-agent -s`
    ssh-add
fi
eval $(keychain --eval --quiet id_ed25519 id_rsa)
