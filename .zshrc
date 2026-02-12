#!/bin/zsh

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
    source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

SCRIPT_PATH="${${(%):-%x}:A}"
REL_DIR=$(dirname "$SCRIPT_PATH")
IMPORTS="$REL_DIR/.custom"

[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

source "$IMPORTS/zsh_imports_zinit.sh"
source "$IMPORTS/start.sh"
