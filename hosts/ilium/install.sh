#!/bin/bash
# Ubuntu/KDE (ilium) restore script — copy-based, unlike quivira's symlink setup.
# KDE rewrites its rc files constantly, so live configs are plain files and this
# script copies the repo versions over them.

set -e

HOST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOME_DIR="$HOME"

echo "=== ilium dotfiles restore ==="
echo "Source: $HOST_DIR"
echo "Target: $HOME_DIR"
echo

echo "[1/4] Shell dotfiles..."
for file in .bashrc .profile .gitconfig; do
    if [ -f "$HOST_DIR/$file" ]; then
        cp "$HOST_DIR/$file" "$HOME_DIR/$file"
        echo "  Copied: $file"
    fi
done

echo "[2/4] Config files..."
mkdir -p "$HOME_DIR/.config"
cp -r "$HOST_DIR/.config/." "$HOME_DIR/.config/"
echo "  Copied .config tree (KDE, kitty, gtk, git, dictate vocab)"

echo "[3/4] Local bin scripts..."
mkdir -p "$HOME_DIR/.local/bin"
for script in "$HOST_DIR/.local/bin"/*; do
    if [ -f "$script" ]; then
        cp "$script" "$HOME_DIR/.local/bin/$(basename "$script")"
        chmod +x "$HOME_DIR/.local/bin/$(basename "$script")"
        echo "  Copied: $(basename "$script")"
    fi
done

echo "[4/4] Packages..."
echo "  To install the manually-selected package set:"
echo "    sudo apt update && xargs -a $HOST_DIR/packages-manual.txt sudo apt install -y"
echo
echo "NOTE: ~/.config/dictate/config (Groq API key) is NOT tracked — recreate it"
echo "per hosts/ilium/CLAUDE.md and chmod 600 it."
echo "Done. Log out/in for KDE settings to fully apply."
