#!/bin/bash

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

REL_DIR=$(dirname "$(realpath -P '.bashrc')")
IMPORTS="$REL_DIR/.custom"
source "$IMPORTS/start.sh"

PS1='[\u@\h \W]\$ '
