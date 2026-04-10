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

source "$HOME/.zsh_aliases"
source "$HOME/.zsh_exports"
source "$HOME/.zsh_utils_git-worktree"

# Host-specific paths and secrets live outside the repo.
[ -f "$HOME/.zsh_local" ] && source "$HOME/.zsh_local"
[ -f "$HOME/.zsh_secrets" ] && source "$HOME/.zsh_secrets"

# agnoster hides user@host when DEFAULT_USER matches $USERNAME.
# Clear any inherited value so the context segment is always shown.
unset DEFAULT_USER

GCLOUD_SDK_HOME="${GCLOUD_SDK_HOME:-$HOME/google-cloud-sdk}"

## The next line updates PATH for the Google Cloud SDK.
if [ -f "$GCLOUD_SDK_HOME/path.zsh.inc" ]; then . "$GCLOUD_SDK_HOME/path.zsh.inc"; fi

# The next line enables shell command completion for gcloud.
if [ -f "$GCLOUD_SDK_HOME/completion.zsh.inc" ]; then . "$GCLOUD_SDK_HOME/completion.zsh.inc"; fi

CONDA_HOME="${CONDA_HOME:-$HOME/miniforge3}"
if [ ! -x "$CONDA_HOME/bin/conda" ] && [ -x "$HOME/mambaforge/bin/conda" ]; then
  CONDA_HOME="$HOME/mambaforge"
fi

# >>> conda initialize >>>
# !! Contents within this block are managed by 'conda init' !!
export CONDA_CHANGEPS1=false
if [ -x "$CONDA_HOME/bin/conda" ]; then
  __conda_setup="$("$CONDA_HOME/bin/conda" 'shell.zsh' 'hook' 2> /dev/null)"
  if [ $? -eq 0 ]; then
    eval "$__conda_setup"
  else
    if [ -f "$CONDA_HOME/etc/profile.d/conda.sh" ]; then
      . "$CONDA_HOME/etc/profile.d/conda.sh"
    else
      export PATH="$CONDA_HOME/bin:$PATH"
    fi
  fi
  unset __conda_setup
fi

if [ -f "$CONDA_HOME/etc/profile.d/mamba.sh" ]; then
  export MAMBA_ROOT_PREFIX="$CONDA_HOME"
  . "$CONDA_HOME/etc/profile.d/mamba.sh"
fi
# <<< conda initialize <<<

# fnm
FNM_PATH="${FNM_PATH:-$HOME/.local/share/fnm}"
if [ -d "$FNM_PATH" ]; then
  export PATH="$FNM_PATH:$PATH"
  eval "$(fnm env --use-on-cd --shell zsh)"
fi

if command -v brew >/dev/null 2>&1; then
  eval "$(brew shellenv)"
fi

if [ -d /opt/cuda ]; then
  export PATH="/opt/cuda/bin:$PATH"
  export LD_LIBRARY_PATH="/opt/cuda/lib64:$LD_LIBRARY_PATH"
elif [ -d /usr/local/cuda ]; then
  export PATH="/usr/local/cuda/bin:$PATH"
  export LD_LIBRARY_PATH="/usr/local/cuda/lib64:$LD_LIBRARY_PATH"
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
if [[ -n "$ZSH_TMUX_AUTOSTART" ]] && [[ -z "$TMUX" ]] && [[ -n "$SSH_CONNECTION" ]]; then
  tmux attach-session -t ssh_tmux || tmux new-session -s ssh_tmux
fi

# bun completions
[ -s "$HOME/.bun/_bun" ] && source "$HOME/.bun/_bun"

# hf download
hfdl() { local repo="$1"; shift; hf download "$repo" --local-dir "./${repo##*/}" "$@"; }
