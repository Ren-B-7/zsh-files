#!/bin/bash

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

SCRIPT_PATH=$(readlink -f "${BASH_SOURCE[0]}")
REL_DIR=$(dirname "$SCRIPT_PATH")
IMPORTS="$REL_DIR/.custom"
source "$IMPORTS/start.sh"

PS1='[\u@\h \W]\$ '
