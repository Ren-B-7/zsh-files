#!/bin/bash

# Usage: ./uninstall_unlisted.sh packages.txt

if [ $# -eq 0 ]; then
    echo "Usage: $0 <package_list_file>"
    echo "Example: $0 packages.txt"
    exit 1
fi

PACKAGE_FILE="$1"

if [ ! -f "$PACKAGE_FILE" ]; then
    echo "Error: File '$PACKAGE_FILE' not found"
    exit 1
fi

# Get list of explicitly installed packages
installed_packages=$(pacman -Qq | awk '{print $1}')

# Read the whitelist file and store in array
mapfile -t whitelist < <(grep -v '^[[:space:]]*$' "$PACKAGE_FILE" | grep -v '^#')

# Find packages to remove
to_remove=()
for pkg in $installed_packages; do
    if ! printf '%s\n' "${whitelist[@]}" | grep -Fxq "$pkg"; then
        to_remove+=("$pkg")
    fi
done

if [ ${#to_remove[@]} -eq 0 ]; then
    echo "No packages to remove"
    exit 0
fi

echo "The following packages will be removed:"
printf '%s\n' "${to_remove[@]}"
echo ""
read -p "Continue? [y/N] " -n 1 -r
echo

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted"
    exit 0
fi

# Remove packages one by one, silently failing on dependency errors
echo "Removing packages..."
for pkg in "${to_remove[@]}"; do
    if pacman -Rns --noconfirm "$pkg"; then
        echo "✓ Removed: $pkg"
    fi
done

echo "Done!"
