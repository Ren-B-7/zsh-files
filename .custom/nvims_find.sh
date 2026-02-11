#!/usr/bin/env bash

function nvims() {
    items=("no-config" "Tiny.nvim" "Simplicity.nvim" "Simplexity.nvim" "Complexity.nvim")
    config=$(printf "%s\n" "${items[@]}" | fzf --prompt=" Neovim Config  " --height=~50% --layout=reverse --border --exit-0)

    if [[ -z $config ]]; then
        echo "Nothing selected"
        return 0
    fi

    if [[ $config == "no-config" ]]; then
        nvim --noplugin
    else
        NVIM_APPNAME=$config nvim "$@"
    fi

}
