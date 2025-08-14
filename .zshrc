#!/bin/zsh

if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
    source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

IMPORTS="$HOME/.custom_shell_scripts"


[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

source "$IMPORTS/zsh_imports_zinit.sh"
source "$IMPORTS/start.sh"
