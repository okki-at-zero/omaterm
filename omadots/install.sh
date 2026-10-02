#!/usr/bin/env bash
# Vendored from omacom/omadots (archived upstream). Upstream's installer
# cloned omacom-io/omadots and copied its config/; we ship that config/ beside
# this script so the image build does not reach the retired repository.
# LazyVim is still cloned from its own upstream.
set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

section() {
  echo -e "\n==> $1"
}

section "Installing LazyVim..."
rm -rf ~/.config/nvim
git clone https://github.com/LazyVim/starter ~/.config/nvim
rm -rf ~/.config/nvim/.git

section "Copying dots to ~/.config..."
mkdir -p "$HOME/.config"
cp -rf "$SRC/config/." "$HOME/.config/"
for dir in "$SRC/config"/*/; do
  echo "✓ $(basename "$dir")"
done

section "Configuring shell..."
case "$(basename "$SHELL")" in
zsh)
  cat >"$HOME/.zshrc" <<'EOF'
# If not running interactively, don't do anything (leave this at the top of this file)
[[ $- != *i* ]] && return

# Load zsh options, keybindings, and completion
source ~/.config/shell/zoptions

# Load shared shell configuration (aliases, functions, environment, tool init)
source ~/.config/shell/all
EOF
  echo '. ~/.zshrc' >"$HOME/.zprofile"
  echo "✓ Zsh"
  ;;
bash)
  cat >"$HOME/.bashrc" <<'EOF'
# If not running interactively, don't do anything (leave this at the top of this file)
[[ $- != *i* ]] && return

# Load bash options, keybindings, and completion
source ~/.config/shell/all
EOF
  echo '. ~/.bashrc' >"$HOME/.bash_profile"
  ln -snf "$HOME/.config/shell/inputrc" "$HOME/.inputrc"
  echo "✓ Bash"
  ;;
esac
