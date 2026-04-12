#auto cmd correction
ENABLE_CORRECTION="true"

# Display red dots whilst waiting for completion.
COMPLETION_WAITING_DOTS="true"

# History
HIST_STAMPS="yyyy-mm-dd"
HISTFILE=~/.histfile
HISTSIZE=10000000
SAVEHIST=10000000

# Keep the OMZ tmux plugin loaded for aliases/functions, but only auto-start
# tmux from the explicit SSH block below.
ZSH_TMUX_AUTOSTART=false

# Antidote static bundle
zsh_plugins=${ZDOTDIR:-$HOME}/.zsh_plugins
if [[ ! ${zsh_plugins}.zsh -nt ${zsh_plugins}.txt ]]; then
  (
    source ${ZDOTDIR:-$HOME}/.antidote/antidote.zsh
    antidote bundle <${zsh_plugins}.txt >${zsh_plugins}.zsh
  )
fi

# Source the bundle in an anonymous function so OMZ top-level `local`
# declarations do not leak during `source ~/.zshrc`.
() {
  source ${zsh_plugins}.zsh
}

# OMZ common-aliases defines a global `P` alias that expands to `pygmentize`.
# It breaks re-sourcing and is not worth keeping.
builtin unalias -- 'P' 2>/dev/null

source $HOME/.zsh_aliases
source $HOME/.zsh_exports
source $HOME/.zsh_utils_git-worktree

# agnoster hides user@host when DEFAULT_USER matches $USERNAME.
# Clear any inherited value so the context segment is always shown.
unset DEFAULT_USER

## The next line updates PATH for the Google Cloud SDK.
if [ -f "$HOME/google-cloud-sdk/path.zsh.inc" ]; then . "$HOME/google-cloud-sdk/path.zsh.inc"; fi

# The next line enables shell command completion for gcloud.
if [ -f "$HOME/google-cloud-sdk/completion.zsh.inc" ]; then . "$HOME/google-cloud-sdk/completion.zsh.inc"; fi

# >>> conda initialize >>>
# !! Contents within this block are managed by 'conda init' !!
export CONDA_CHANGEPS1=false
__conda_setup="$("$HOME/miniforge3/bin/conda" 'shell.zsh' 'hook' 2> /dev/null)"
if [ $? -eq 0 ]; then
    eval "$__conda_setup"
else
    if [ -f "$HOME/miniforge3/etc/profile.d/conda.sh" ]; then
        . "$HOME/miniforge3/etc/profile.d/conda.sh"
    else
        export PATH="$HOME/miniforge3/bin:$PATH"
    fi
fi
unset __conda_setup

if [ -f "$HOME/miniforge3/etc/profile.d/mamba.sh" ]; then
    export MAMBA_ROOT_PREFIX="$HOME/miniforge3"
    . "$HOME/miniforge3/etc/profile.d/mamba.sh"
fi
# <<< conda initialize <<<

# fnm
FNM_PATH="$HOME/.local/share/fnm"
if [ -d "$FNM_PATH" ]; then
  export PATH="$FNM_PATH:$PATH"
  eval "$(fnm env --use-on-cd --shell zsh)"
fi

if [ -x /home/linuxbrew/.linuxbrew/bin/brew ]; then
  eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
fi

# CUDA Configuration
if [ -d /opt/cuda ]; then
  export PATH=/opt/cuda/bin:$PATH
  export LD_LIBRARY_PATH=/opt/cuda/lib64:$LD_LIBRARY_PATH
elif [ -d /usr/local/cuda ]; then
  export PATH=/usr/local/cuda/bin:$PATH
  export LD_LIBRARY_PATH=/usr/local/cuda/lib64:$LD_LIBRARY_PATH
fi

fpath+=~/.zfunc

# fzf-tab completion styles
zstyle ':completion:*' menu no
zstyle ':completion:*:descriptions' format '[%d]'
zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}

if command -v zoxide >/dev/null 2>&1; then
  eval "$(zoxide init zsh --cmd cd)"
fi

# Auto-start tmux on SSH login
if [[ -z "$TMUX" ]] && [[ -n "$SSH_CONNECTION" ]]; then
  tmux attach-session -t ssh_tmux || tmux new-session -s ssh_tmux
fi

# bun completions
[ -s "$HOME/.bun/_bun" ] && source "$HOME/.bun/_bun"

# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"

# qlty
export QLTY_INSTALL="$HOME/.qlty"
export PATH="$QLTY_INSTALL/bin:$PATH"

# hf download
hfdl() { local repo="$1"; shift; hf download "$repo" --local-dir "./${repo##*/}" "$@"; }
export JAVA_HOME=$HOME/repo/ReasonIR/synthetic_data_generation/jdk-23.0.1
export JVM_PATH=$HOME/repo/ReasonIR/synthetic_data_generation/jdk-23.0.1/lib/server/libjvm.so
