#!/usr/bin/env bash
set -euo pipefail
export PATH="$HOME/.opencode/bin:$PATH"
if [ "$(pwd -P)" != /etc/nixos ]; then
  sudo rm -rf /etc/nixos
  sudo mkdir -p /etc/nixos
  sudo cp -a . /etc/nixos
  sudo chown -R "$(id -u):$(id -g)" /etc/nixos
fi
cd /etc/nixos
sudo nixos-rebuild switch --flake /etc/nixos#quietcraft
