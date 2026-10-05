#
# ~/.bashrc
#

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

alias ls='eza --color=auto --group-directories-first'
alias ll='eza -la --color=auto --group-directories-first'
alias lt='eza --tree --color=auto'
alias grep='rg'
alias cat='bat --paging=never'
alias find='fd'
alias htop='btop'
alias vim='nvim'

export PATH="$PATH:/home/tk/.cargo/bin"
export PATH="$HOME/.local/bin:$PATH"

# starship prompt
eval "$(starship init bash)"

# zoxide (smarter cd — use 'z' instead of 'cd')
eval "$(zoxide init bash)"

export SSH_AUTH_SOCK="$XDG_RUNTIME_DIR/ssh-agent.socket"
