# nix-config

NixOS flake configuration for `quietcraft`.

## Prerequisites

NixOS with flakes enabled and git installed.

## Installation

```bash
git clone https://github.com/Ackerman-00/nix-config.git ~/nix-config
```

```bash
sudo nixos-generate-config --show-hardware-config > ~/nix-config/hardware-configuration.nix
sudo rm -rf /etc/nixos
sudo cp -r ~/nix-config /etc/nixos
```

## Rebuild

```bash
sudo nixos-rebuild switch --flake /etc/nixos#quietcraft
```

