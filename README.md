# nix-config

NixOS flake configuration for `quietcraft` — single desktop, single user.
Umbriel compositor + Noctalia shell, home-manager user env, vendored Helium.

## Layout

```
flake.nix                 # inputs (nixpkgs, home-manager, umbriel) + quietcraft
configuration.nix         # thin host entry (imports, toggles, stateVersion)
home.nix                  # thin home entry (imports only)
modules/
  system/                 # nix-settings, boot, network, locale, users
  desktop/                # session, fonts, services, umbriel
  packages/               # role sets: desktop, apps, utils, gaming, dev
  browsers/               # helium (vendored tarball), firefox
  shell/                  # tooling, neovim
  hardware.nix programs.nix
home-manager/
  desktop/umbriel/        # compositor config fragments + shaders
  programs/               # noctalia (exported config), opencode
```

Toggle groups from `configuration.nix` without editing package lists:

```nix
my.gaming.enable = false;
```

## Prerequisites

NixOS with flakes enabled, git. On first install generate the hardware file:

```bash
sudo nixos-generate-config --show-hardware-config > hardware-configuration.nix
```

## Install

```bash
git clone https://github.com/Ackerman-00/nix-config.git ~/nix-config
sudo cp -r ~/nix-config/* /etc/nixos/
cd /etc/nixos && git add -A   # flakes ignore untracked files
```

## Rebuild

```bash
sudo nixos-rebuild switch --flake /etc/nixos#quietcraft
```

Safer first: `sudo nixos-rebuild test --flake /etc/nixos#quietcraft`.
Rollback: boot menu, or `sudo nixos-rebuild switch --rollback`.

## Update everything

```bash
cd /etc/nixos && sudo nix flake update && sudo nixos-rebuild switch --flake /etc/nixos#quietcraft
```

Then commit `flake.lock`.

## Verify (no rebuild)

```bash
nix flake check --no-build
nix run nixpkgs#statix -- check .
```

## Notes

* `programs.chromium` / `programs.firefox` write policy files only; verify live
  at `helium://policy` and `about:policies`.
* Umbriel + Noctalia configs live in `home-manager/`; Noctalia theming writes
  the live `noctalia.toml` itself (gitignore it in dotfiles).
* Greeter appearance sync needs one passwordless rule already configured;
  it activates once greeter >= 1.5.0 pairs with post-5.0.1 Noctalia.
