# nix-config

My NixOS flake config for `quietcraft`.

## Install on a fresh NixOS machine

```bash
# 1. Clone the repo
git clone https://github.com/Ackerman-00/nix-config /home/ackerman/nix-config

# 2. Back up stock config (keeps your hardware-configuration.nix safe)
sudo cp -r /etc/nixos /etc/nixos.bak

# 3. Replace /etc/nixos contents with this repo
sudo rm -r /etc/nixos
sudo mkdir -p /etc/nixos
sudo cp -r /home/ackerman/nix-config/. /etc/nixos/

# 4. Restore machine-specific hardware config (not tracked in git)
sudo cp /etc/nixos.bak/hardware-configuration.nix /etc/nixos/
# Or regenerate it instead:
# sudo nixos-generate-config --show-hardware-config > /home/ackerman/nix-config/hardware-configuration.nix
# sudo cp /home/ackerman/nix-config/hardware-configuration.nix /etc/nixos/

# 5. Rebuild
sudo nixos-rebuild switch --flake /etc/nixos#quietcraft
```

