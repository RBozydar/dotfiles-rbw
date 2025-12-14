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

eval `ssh-agent -s`
ssh-add
eval $(keychain --eval --quiet id_ed25519 id_rsa)

# >>> conda initialize >>>
# !! Contents within this block are managed by 'conda init' !!
__conda_setup="$('/home/rbw/mambaforge/bin/conda' 'shell.zsh' 'hook' 2> /dev/null)"
if [ $? -eq 0 ]; then
    eval "$__conda_setup"
else
    if [ -f "/home/rbw/mambaforge/etc/profile.d/conda.sh" ]; then
        . "/home/rbw/mambaforge/etc/profile.d/conda.sh"
    else
        export PATH="/home/rbw/mambaforge/bin:$PATH"
    fi
fi
unset __conda_setup

if [ -f "/home/rbw/mambaforge/etc/profile.d/mamba.sh" ]; then
    . "/home/rbw/mambaforge/etc/profile.d/mamba.sh"
fi
# <<< conda initialize <<<


# fnm
FNM_PATH="/home/rbw/.local/share/fnm"
if [ -d "$FNM_PATH" ]; then
  export PATH="/home/rbw/.local/share/fnm:$PATH"
  eval "`fnm env`"
fi

fpath+=~/.zfunc; autoload -Uz compinit; compinit

zstyle ':completion:*' menu select
