#!/usr/bin/env bash

log_info() {
    echo "++=++ [INFO] $(date '+%Y-%m-%d %H:%M:%S') ++=++ $1"
    sleep 0.2
}

log_error() {
    echo "++=++ [ERROR] $(date '+%Y-%m-%d %H:%M:%S') ++=++ : $1" >&2
    sleep 1
}

log_header() {
    echo "\n========== \t $1 \t ==========\n"
}

log_subheading() {
    echo "\n----- \t $1 \t -----\n"
}

ask_yes_no() {
    local prompt="$1" default="${2:-N}" answer

    while true; do
        read -r "answer?++=++ $prompt ($default): "
        answer="${answer:-$default}"  # Use default if empty

        case "$answer" in
            [Yy]|[Yy][Ee]|[Yy][Ee][Ss]) return 0 ;;
            [Nn]|[Nn][Oo]) return 1 ;;
            *) log_error "Invalid input. Please enter Yes or No." ;;
        esac
    done
}

function FullUpgrade() {
    if ask_yes_no "Revert mirrorlists from .bak files" "N"; then
        # Find all .bak files in the mirror list directory
        MIRROR_LIST_DIR="/etc/pacman.d"
        for file in "$MIRROR_LIST_DIR"/*.bak; do
            if [ -f "$file" ]; then
                if sudo mv "$file" "${file%.bak}"; then
                    sudo chmod 644 "${file%.bak}"
                    log_info "Reverted: $file"
                else
                    log_error "Could not revert the $file"
                fi
            fi
        done
        log_info "All .bak files reverted."
    else
        log_info "No action taken."
    fi

    if ask_yes_no "Rerank the mirrors?" "N"; then
        echo "---------- \t reflector \t ----------"
        if ! command -v reflector >/dev/null 2>&1; then
            log_error "reflector not installed"
        else
            sudo reflector --protocol https,ftp,rsync --connection-timeout 10 --download-timeout 10 --latest 40 --fastest 30 --sort score --number 30 --threads 8 --save /etc/pacman.d/mirrorlist.pacnew;
            echo "\n"
            cat /etc/pacman.d/mirrorlist.pacnew;
            echo "\n"
        fi

        log_header "eos-rankmirrors"
        if ! command -v eos-rankmirrors >/dev/null 2>&1; then
            log_error "eos-rankmirrors not installed"
        else
            sudo eos-rankmirrors --verbose -t 15 --sort age || log_error "eos-rankmirrors failed"; true
        fi

        log_header "mirrorlist cleanup"
        # Place .pacnew files into the original mirror list
        files=("/etc/pacman.d/mirrorlist" "/etc/pacman.d/endeavouros-mirrorlist" "/etc/fwupd/remotes.d")

        for file in "${files[@]}"; do
            pacnew_file="${file}.pacnew"
            backup_file="${file}.bak"

            if [[ -f "$pacnew_file" ]]; then
                log_info "Found .pacnew file: $pacnew_file"
                log_info "Backing up current mirrorlist ($file) to $backup_file (overwriting if exists)"
                if sudo mv "$file" "$backup_file"; then
                    log_info "Backup successful."
                else
                    log_error "Backup failed for $file"
                fi
                log_info "Replacing $file with $pacnew_file"
                if sudo mv "$pacnew_file" "$file"; then
                    sudo chmod 644 "$file"
                    log_info "Mirrorlist updated and permissions set."
                else
                    log_error "Failed to update mirrorlist from $pacnew_file"
                fi
            fi

            if [[ -f "$backup_file" ]]; then
                log_info "Backup file exists: $backup_file"
                if ask_yes_no "Remove the backup file $backup_file?" "N"; then
                    if sudo rm "$backup_file"; then
                        log_info "Backup file removed."
                    else
                        log_error "Failed to remove backup file."
                    fi
                else
                    log_info "Backup file retained."
                fi
            fi
        done
    else
        log_info "No action taken."
    fi

    # Firmware update section
    log_header "Firmware update (fwupdmgr)"
    if ! command -v fwupdmgr >/dev/null 2>&1; then
        log_error "fwupdmgr not installed"
    else
        if ask_yes_no "Update firmware with fwupdmgr" "N"; then
            if ask_yes_no "Revert mirrorlists from .bak files" "N"; then
                # Find all .bak files in the mirror list directory
                MIRROR_LIST_DIR="/etc/fwupd/remotes.d"
                for file in "$MIRROR_LIST_DIR"/*.bak; do
                    if [ -f "$file" ]; then
                        if sudo mv "$file" "${file%.bak}"; then
                            sudo chmod 644 "${file%.bak}"
                            log_info "Reverted: $file"
                        else
                            log_error "Could not revert the $file"
                        fi
                    fi
                done
                log_info "All .bak files reverted."
            else
                log_info "No action taken."
            fi

            log_subheading "Refreshing firmware databases"
            sudo fwupdmgr refresh || log_error "fwupdmgr refresh failed"; true
            log_subheading "Syncing firmware configurations"
            sudo fwupdmgr sync || log_error "fwupdmgr sync failed"; true
            log_subheading "Updating firmware devices"
            sudo fwupdmgr update || log_error "fwupdmgr update failed"; true
        else
            log_info "No action taken."
        fi
    fi

    # Pacman package manager section
    log_header "Pacman package manager"
    if ! command -v pacman >/dev/null 2>&1; then
        log_error "pacman not installed"
    else
        log_subheading "Updating pacman database"
        sudo pacman -Syy || log_error "Database update failed"; true
        log_subheading "Checking database integrity"
        if ! sudo pacman -Dk | tee /tmp/pacman_integrity.log | grep -qE "missing|not found"; then
            log_info "Passed integrity check"
            log_subheading "Upgrading packages"
            sudo pacman -Su || log_error "Package upgrade failed"; true
        else
            log_error "Database integrity check failed. Skipping updates."
            cat /tmp/pacman_integrity.log
            pacman_running=$(ps aux | grep "pacman" | grep -v "grep")
            if ask_yes_no "Check database lock" "Y"; then
                if [ -n "pacman_running" ]; then
                    log_info "Removing database lock"
                    sudo rm /var/lib/pacman/db.lck || log_error "Could not remove database lock"; true
                else
                    log_error "Pacman process is running"
                    return 1
                fi
            fi
            if ask_yes_no "Check missing or broken database/ packages" "Y"; then
                sudo pacman -Qk | awk '/missing files/ && $4 != "0"' > missing_files_report.txt || log_error "Could not complete missing files check"; true
                rm missing_files_report.txt
            fi
            if ask_yes_no "Checking missing dependencies" "Y"; then
                sudo pacman -Syu --needed || log_error "Failed dependencies"; true
            fi
            return 1
        fi
    fi

    # yay package manager section
    log_header "yay package manager"
    if ! command -v yay >/dev/null 2>&1; then
        log_error "yay not installed"
    else
        log_subheading "Upgrading AUR packages"
        yay -Sua || log_error "yay upgrade encountered an error"; true
        log_subheading "Cleaning up yay/ pacman cache"
        if ask_yes_no "Remove orphaned packages?" "Y"; then
            orphan_list=$(pacman -Qdtq)
            if [[ -n "$orphan_list" ]]; then
                log_info "Removing orphaned packages:"
                log_info "$orphan_list"
                sudo pacman -Rns $orphan_list || log_error "Failed to remove orphaned pacman packages"; true
                yay -Yc || log_error "Failed to remove orphaned yay packages"; true
                log_info "Note: /home files and configuration caches remain unaffected."
            else
                log_info "No orphaned packages found."
            fi
        else
            log_info "Skipping removal of orphaned packages."
        fi
        sudo paccache -ruk1 || log_error "Failed to prune pacman cache"; true
        yay -Scc || log_error "yay cache cleanup failed"; true
    fi

    # Flatpak package manager section
    log_header "Flatpak package manager"
    if ! command -v flatpak >/dev/null 2>&1; then
        log_error "flatpak not installed"
    else
        if ask_yes_no "Remove unused flatpak packages?" "Y"; then
            log_info "Uninstalling unused flatpaks..."
            flatpak uninstall --unused || log_error "Failed to remove unused flatpaks"; true
        else
            log_info "Skipping unused flatpak removal."
        fi
        log_subheading "Updating flatpak packages"
        flatpak update || log_error "Flatpak update failed"; true
        log_subheading "Checking flatpak checksums"
        if ask_yes_no "Check flatpak checksums?" "N"; then
            log_info "Checking flatpaks..."
            sudo flatpak repair || log_error "Flatpak check and repair failed"; true
        else
            log_info "Skipping flatpaks check."
        fi
    fi

    #Log files prompt
    log_header "Log files"
    if ! command -v journalctl >/dev/null 2>&1; then
        log_error "journalctl not installed (No systemd?)"
    else
        if ask_yes_no "Vacuum journalctl down?" "N"; then
            log_info "Shrinking journalctl total size"
            sudo journalctl --vacuum-size=100M || log_error "Could not vacuum-size to 100M"; true
        else
            log_info "Skipping journalctl vacuum"
        fi
        if ask_yes_no "Delete old log files?" "N"; then
            log_info "Removing rotated log files"
            sudo find /var/log -type f -name "*.log.*" -delete || log_error "Could not remove rotated log files"; true
        else
            log_info "Skipping removal of old log files"
        fi
        if ask_yes_no "Shorten CURRENT log files?" "N" && ask_yes_no "Are you SURE you want to remove ALL DATA from log files?" "N"; then
            log_info "Emptying current log files"
            sudo truncate -s 0 /var/log/*.log || log_error "Could not shrink current log files"; true
        else
            log_info "Skipping removal of current log files"
        fi
    fi

    # Reboot prompt
    log_header "Reboot system"
    if ! command -v reboot >/dev/null 2>&1; then
        log_error "reboot command not found"
    else
        if ask_yes_no "Reboot now?" "N"; then
            log_info "Rebooting system in 10 seconds..."
            sleep 10
            sudo reboot -p now
        else
            log_info "Reboot skipped."
        fi
    fi
}
