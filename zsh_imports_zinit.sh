#!/usr/bin/env zsh

ZINIT_HOME="$HOME/.zinit"
if [[ ! -d $ZINIT_HOME ]]; then
    echo "Installing Zinit..."
    mkdir -p "$(dirname "$ZINIT_HOME")"
    git clone https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME"
fi
source "$ZINIT_HOME/zinit.zsh"

autoload -Uz compinit
compinit

setopt COMBINING_CHARS

# Oh My Zsh base and theme
zinit load romkatv/powerlevel10k

zinit ice wait lucid
zinit light ohmyzsh/ohmyzsh

# Oh My Zsh plugins
zinit ice wait lucid
zinit snippet OMZP::colored-man-pages
zinit ice wait lucid
zinit snippet OMZP::cp
zinit ice wait lucid
zinit snippet OMZP::copyfile
zinit ice wait lucid
zinit snippet OMZP::zoxide
zinit ice wait lucid
zinit snippet OMZP::archlinux

# External plugins
zinit ice wait lucid
zinit light zsh-users/zsh-autosuggestions
zinit ice wait lucid
zinit light zsh-users/zsh-completions
zinit ice wait lucid
zinit light zsh-users/zsh-syntax-highlighting

# History setup
HISTFILE="$HOME/.custom_shell_scripts/.zhistory"
SAVEHIST=500
HISTSIZE=500
setopt share_history
setopt hist_expire_dups_first
setopt hist_ignore_dups
setopt hist_verify

export _ZO_MAXAGE=100

eval "$(zoxide init zsh)"
