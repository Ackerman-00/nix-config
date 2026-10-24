# quietcraft

NixOS flake for `quietcraft`: one x86_64-linux machine, Umbriel compositor,
Noctalia shell.

Host `quietcraft` · user `ackerman` · stateVersion `26.11`

## Install

```sh
nix-shell -p git --extra-experimental-features 'nix-command flakes'

sudo git clone https://github.com/Ackerman-00/nix-config /etc/nixos/.clone \
  && sudo cp -a /etc/nixos/.clone/. /etc/nixos/ \
  && sudo rm -rf /etc/nixos/.clone /etc/nixos/configuration.nix

sudo nix --extra-experimental-features 'nix-command flakes' \
  --option accept-flake-config true flake update local-hardware --flake /etc/nixos

sudo nixos-rebuild switch --flake /etc/nixos#quietcraft \
  --extra-experimental-features 'nix-command flakes' \
  --option accept-flake-config true

sudo passwd ackerman
```

`hardware-configuration.nix` stays where the installer put it and is not
tracked. `stateVersion` is the ISO release of the first install and never
changes. `/etc/nixos#quietcraft` reads the committed tree, so commit before a
rebuild.

## Daily

```sh
nh os switch      # rebuild
nh os test        # build + activate, no boot entry
nh clean all      # prune generations
```

## Layout

```
flake.nix                inputs, outputs, checks, cachix substituters
hosts/quietcraft/        root module
home.nix                 home-manager entry point
modules/
  system/                nix settings, boot, network, locale, users, maintenance
  desktop/               greeter, fonts, services, noctalia, umbriel
  browsers/              helium (vendored), firefox, brave-origin
  shell/                 zsh tooling, neovim
  home-manager/          shell, programs
  packages/
    agent/               skills, opencode, neurakeep, openchamber, freebuff,
                         omnirush, ollama, cline
    media/               hyperframes, concat, craft-launcher, tts
    mcp/                 youtube transcript + playwright, blender
    packages-*.nix       flat groups: apps, desktop, dev, gaming, kankan, utils
```

Every module is gated by `my.<name>.enable` and defaults to on, except
`my.firefox`, `my.cline` and `my.mcp.<server>.enable` (opt-in MCP servers).

## Checks

```sh
nix flake check
nix fmt
nix flake update          # bump every input
```
