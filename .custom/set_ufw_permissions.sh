#!/usr/bin/env bash

function ufwSet() {

    if ! command -v ufw >/dev/null 2>&1; then
        echo "UFW not installed"
        exit 1
    fi

    items=("Public" "Home" "Work" "Clear backups")
    environment=$(printf "%s\n" "${items[@]}" | fzf --prompt="Firewall settings " --height=~50% --layout=reverse --border --exit-0)

    if [ -z "$environment" ]; then
        echo "No environment selected. Exiting."
        return 1
    elif [[ $environment == "Public" ]]; then
        echo "Switching to Public Environment..."
        source "$HOME/.custom_shell_scripts/set_ufw/public.sh"
    elif [[ $environment == "Home" ]]; then
        echo "Switching to Home Environment..."
        source "$HOME/.custom_shell_scripts/set_ufw/home.sh"
    elif [[ $environment == "Work" ]]; then
        echo "Switching to Work Environment..."
        source "$HOME/.custom_shell_scripts/set_ufw/work.sh"
    elif [[ $environment == "Clear backups" ]]; then
        sudo "$HOME/.custom_shell_scripts/set_ufw/clear.sh"
    fi
}
