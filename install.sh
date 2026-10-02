#!/usr/bin/env bash
set -euo pipefail

OMATERM_BIN_DIR=/usr/local/bin
OMATERM_SRC="${OMATERM_SRC:-${XDG_DATA_HOME:-$HOME/.local/share}/omaterm/src}"

banner() {
  clear
  echo
  echo " ▄██████▄    ▄▄▄▄███▄▄▄▄      ▄████████     ███        ▄████████    ▄████████   ▄▄▄▄███▄▄▄▄  
███    ███ ▄██▀▀▀███▀▀▀██▄   ███    ███ ▀█████████▄   ███    ███   ███    ███ ▄██▀▀▀███▀▀▀██▄
███    ███ ███   ███   ███   ███    ███    ▀███▀▀██   ███    █▀    ███    ███ ███   ███   ███
███    ███ ███   ███   ███   ███    ███     ███   ▀  ▄███▄▄▄      ▄███▄▄▄▄██▀ ███   ███   ███
███    ███ ███   ███   ███ ▀███████████     ███     ▀▀███▀▀▀     ▀▀███▀▀▀▀▀   ███   ███   ███
███    ███ ███   ███   ███   ███    ███     ███       ███    █▄  ▀███████████ ███   ███   ███
███    ███ ███   ███   ███   ███    ███     ███       ███    ███   ███    ███ ███   ███   ███
 ▀██████▀   ▀█   ███   █▀    ███    █▀     ▄████▀     ██████████   ███    ███  ▀█   ███   █▀ 
                                                                   ███    ███                "
}

section() {
  echo -e "\n==> $1"
}

is_wsl() {
  grep -qi microsoft /proc/version 2>/dev/null
}

install_docker() {
  local target_user

  section "Installing Docker..."

  if is_wsl; then
    if docker info >/dev/null 2>&1; then
      return
    fi

    echo "Error: Docker is not available."
    echo "Install and start Docker Desktop for Windows with WSL integration enabled, then re-run this installer."
    exit 1
  fi

  if command -v docker &>/dev/null && systemctl cat docker.service &>/dev/null; then
    :
  elif [ -f /etc/arch-release ]; then
    sudo pacman -S --needed --noconfirm docker
  elif [ -f /etc/debian_version ]; then
    sudo apt-get update
    sudo apt-get install -y docker.io
  elif [ -f /etc/fedora-release ]; then
    sudo dnf install -y moby-engine
  else
    echo "Error: This OS is not supported by the installer."
    echo "Install Docker manually, then run this installer again."
    exit 1
  fi

  section "Enabling Docker..."
  sudo systemctl enable --now docker.service
  sudo groupadd -f docker
  target_user="${SUDO_USER:-${USER:-$(id -un)}}"
  sudo usermod -aG docker "$target_user"

  echo
  echo "✓ Docker"
}

install_gum() {
  command -v gum &>/dev/null && return

  section "Installing gum..."

  if [ -f /etc/arch-release ]; then
    sudo pacman -S --needed --noconfirm gum
  elif [ -f /etc/debian_version ]; then
    # gum isn't in the Debian/Ubuntu repos; add Charm's apt repo first.
    sudo mkdir -p /etc/apt/keyrings
    curl -fsSL https://repo.charm.sh/apt/gpg.key | sudo gpg --dearmor -o /etc/apt/keyrings/charm.gpg
    echo "deb [signed-by=/etc/apt/keyrings/charm.gpg] https://repo.charm.sh/apt/ * *" |
      sudo tee /etc/apt/sources.list.d/charm.list >/dev/null
    sudo apt-get update
    sudo apt-get install -y gum
  elif [ -f /etc/fedora-release ]; then
    sudo dnf install -y gum
  else
    echo "Error: This OS is not supported by the installer."
    echo "Install gum manually (https://github.com/charmbracelet/gum), then run this installer again."
    exit 1
  fi

  echo
  echo "✓ Gum"
}

install_omaterm_command() {
  local tarball extract_dir file tmp_file dest

  # Fetch the whole source checkout, not just the bin files: the image build
  # fallback in `omaterm` needs the Dockerfile and package lists at runtime.
  section "Fetching source..."
  tarball="https://github.com/${OMATERM_REPO:-okki-at-zero/omaterm}/archive/refs/heads/${OMATERM_REF:-master}.tar.gz"
  extract_dir="$(mktemp -d)"
  curl -fsSL "$tarball" | tar -xz -C "$extract_dir"
  rm -rf "$OMATERM_SRC"
  mkdir -p "$(dirname "$OMATERM_SRC")"
  # The tarball holds a single top-level directory; rename it into place.
  mv "$extract_dir"/* "$OMATERM_SRC"
  rm -rf "$extract_dir"

  # The host CLI is omaterm plus the libraries it sources; ship them side by
  # side so the dirname-based `source` in omaterm resolves them.
  for file in omaterm omaterm-limits omaterm-templates omaterm-op; do
    tmp_file="$(mktemp)"
    cp "$OMATERM_SRC/bin/host/$file" "$tmp_file"
    dest="$OMATERM_BIN_DIR/$file"

    if ((EUID == 0)); then
      install -D -m 0755 "$tmp_file" "$dest"
    else
      sudo install -D -m 0755 "$tmp_file" "$dest"
    fi

    rm -f "$tmp_file"
  done

  echo "✓ Command"
}

banner

install_docker
install_gum
install_omaterm_command

echo
echo "Starting omaterm..."
if is_wsl; then
  exec omaterm
elif docker info >/dev/null 2>&1; then
  # The docker group is already active (or we are root) — no re-exec needed.
  exec omaterm
elif command -v sg >/dev/null 2>&1; then
  exec sg docker -c omaterm
else
  # Arch ships no sg(1); setuid newgrp re-reads the docker group the installer
  # just added and runs the command through a shell fed on stdin.
  exec newgrp docker <<<"exec omaterm"
fi
