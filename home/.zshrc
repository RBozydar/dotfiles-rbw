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
source $HOME/.zsh_utils_git-worktree

#startx
if [[ ! $DISPLAY && $XDG_VTNR -eq 1 ]]; then
  exec startx
fi

## The next line updates PATH for the Google Cloud SDK.
if [ -f '/home/rbw/google-cloud-sdk/path.zsh.inc' ]; then . '/home/rbw/google-cloud-sdk/path.zsh.inc'; fi

# The next line enables shell command completion for gcloud.
if [ -f '/home/rbw/google-cloud-sdk/completion.zsh.inc' ]; then . '/home/rbw/google-cloud-sdk/completion.zsh.inc'; fi

# Use keychain to manage ssh-agent across sessions
eval $(keychain --eval --quiet --agents ssh id_ed25519)

# >>> mamba initialize >>>
# !! Contents within this block are managed by 'mamba shell init' !!
export MAMBA_EXE='/home/rbw/miniforge3/bin/mamba';
export MAMBA_ROOT_PREFIX='/home/rbw/miniforge3';
__mamba_setup="$("$MAMBA_EXE" shell hook --shell zsh --root-prefix "$MAMBA_ROOT_PREFIX" 2> /dev/null)"
if [ $? -eq 0 ]; then
    eval "$__mamba_setup"
else
    alias mamba="$MAMBA_EXE"  # Fallback on help from mamba activate
fi
unset __mamba_setup
# <<< mamba initialize <<<


# fnm
FNM_PATH="/home/rbw/.local/share/fnm"
if [ -d "$FNM_PATH" ]; then
  export PATH="$FNM_PATH:$PATH"
  eval "`fnm env`"
fi

eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"

# CUDA Configuration
# export PATH=/usr/local/cuda-13.0/bin:$PATH
# export LD_LIBRARY_PATH=/usr/local/cuda-13.0/lib64:$LD_LIBRARY_PATH

fpath+=~/.zfunc; autoload -Uz compinit; compinit

zstyle ':completion:*' menu select

antigen bundle tmux
# Auto-start tmux on SSH login
if [[ -z "$TMUX" ]] && [[ -n "$SSH_CONNECTION" ]]; then
  tmux attach-session -t ssh_tmux || tmux new-session -s ssh_tmux
fi

# bun completions
[ -s "/home/rbw/.bun/_bun" ] && source "/home/rbw/.bun/_bun"

# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"

# qlty
export QLTY_INSTALL="$HOME/.qlty"
export PATH="$QLTY_INSTALL/bin:$PATH"


