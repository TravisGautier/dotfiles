#!/bin/bash
# Hyprland/Arch System Restore Script
# Symlinks dotfiles and installs packages

set -e

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOME_DIR="$HOME"

echo "=== Dotfiles Restore Script ==="
echo "Source: $DOTFILES_DIR"
echo "Target: $HOME_DIR"
echo

# Symlink shell dotfiles
echo "[1/5] Linking shell dotfiles..."
for file in .bashrc .bash_profile .bash_logout .zshrc .zshenv .profile .gitconfig .nanorc; do
    if [ -f "$DOTFILES_DIR/$file" ]; then
        ln -sf "$DOTFILES_DIR/$file" "$HOME_DIR/$file"
        echo "  Linked: $file"
    fi
done

# Symlink config directories
echo "[2/5] Linking config directories..."
mkdir -p "$HOME_DIR/.config"
for dir in "$DOTFILES_DIR/.config"/*/; do
    dirname=$(basename "$dir")
    ln -sfn "$dir" "$HOME_DIR/.config/$dirname"
    echo "  Linked: .config/$dirname"
done

# Symlink local bin scripts
echo "[3/5] Linking local bin scripts..."
mkdir -p "$HOME_DIR/.local/bin"
for script in "$DOTFILES_DIR/.local/bin"/*; do
    if [ -f "$script" ]; then
        scriptname=$(basename "$script")
        ln -sf "$script" "$HOME_DIR/.local/bin/$scriptname"
        chmod +x "$HOME_DIR/.local/bin/$scriptname"
        echo "  Linked: .local/bin/$scriptname"
    fi
done

# Copy system configs (requires sudo)
echo "[4/5] System configs (/etc/)..."
if [ -d "$DOTFILES_DIR/etc" ]; then
    echo "  Found etc/ - these require sudo to install:"
    for item in "$DOTFILES_DIR/etc"/*/; do
        if [ -d "$item" ]; then
            dirname=$(basename "$item")
            echo "    sudo cp -r $DOTFILES_DIR/etc/$dirname /etc/"
        fi
    done
    echo "  Run with sudo to apply, or copy manually."
else
    echo "  No etc/ directory found, skipping."
fi

# Install packages
echo "[5/5] Package installation..."
echo "  To install official packages:"
echo "    sudo pacman -S --needed - < $DOTFILES_DIR/packages-official.txt"
echo "  To install AUR packages (requires yay):"
echo "    yay -S --needed - < $DOTFILES_DIR/packages-aur.txt"

echo
echo "Done! Restart your shell or run: source ~/.bashrc"
