# quietcraft

NixOS flake for `quietcraft`, a single-user x86_64-linux machine running the
Umbriel compositor with Noctalia as the desktop shell.

Host `quietcraft` · user `ackerman` · stateVersion `26.11`

## Repo layout

```
flake.nix                    inputs, outputs, cachix substituters
configuration.nix            root module: hardware-config + ./modules
hardware-configuration.nix   gitignored — generated per machine
home.nix                     home-manager entry point
modules/
  system/                    nix settings, boot, network, locale, users, maintenance
  desktop/                   greeter, fonts, services, noctalia, umbriel
  packages/                  vendored debs/AppImages, python env, MCP registry
  browsers/                  helium (vendored), firefox
  shell/                     zsh tooling, neovim
home-manager/
  shell/                     zsh, kitty, starship, fastfetch, git, direnv
  desktop/                   niri, umbriel
  programs/                  noctalia, vesktop, opencode
```

## Installing on a fresh minimal system

A minimal NixOS install has no `git` and no flakes enabled, so bootstrap both
before anything else:

```sh
nix-shell -p git --extra-experimental-features 'nix-command flakes'
```

Clone the dotfiles and drop them in place:

```sh
git clone https://github.com/<you>/dotfiles ~/dotfiles

sudo rm -rf /etc/nixos
sudo cp -r ~/dotfiles /etc/nixos
```

`hardware-configuration.nix` is gitignored, so it never ships in the clone.
Generate it on the target machine:

```sh
sudo nixos-generate-config --show-hardware-config \
  | sudo tee /etc/nixos/hardware-configuration.nix
```

First switch. The `path:` prefix is required, not cosmetic, and
`accept-flake-config` is needed once so `nixConfig` can apply the umbriel cache
before the system nix settings exist:

```sh
sudo nixos-rebuild switch \
  --flake path:/etc/nixos#quietcraft \
  --extra-experimental-features 'nix-command flakes' \
  --option accept-flake-config true
```

The user has no password by default — set one after the first switch:

```sh
sudo passwd ackerman
```

## Rebuilding

```sh
nh os switch      # normal rebuild
nh os test        # build + activate without adding a boot entry
nh clean all      # prune old generations (runs daily as a timer already)
```

Or without `nh`:

```sh
sudo nixos-rebuild switch --flake path:/etc/nixos#quietcraft
```

## The `path:` prefix

`hardware-configuration.nix` is gitignored, so it is not in git. A git flake
reference (`--flake /etc/nixos#quietcraft`) only copies *tracked* files into the
store, which silently omits it and fails the build with:

```
The 'fileSystems' option does not specify your root file system.
```

Use `path:` everywhere so the directory is copied verbatim. `nh` is already
configured for this.

This applies to `nix flake check` as well, so the check command below uses
`path:.`. On a checkout without the file — a fresh clone, or CI — the check
fails with that same assertion.

## Binary cache

Umbriel and `xdg-desktop-portal-umbriel` come from
[`umbriel.cachix.org`](https://umbriel.cachix.org) instead of being compiled,
declared in both `flake.nix` (`nixConfig`) and `modules/system/nix-settings.nix`
(`nix.settings`). The input is pinned to the upstream `cachix` branch, which
only advances to commits whose CI has published binaries.

The input deliberately sets no `follows` on nixpkgs — its store paths only match
the cache when built against the nixpkgs its own lockfile pins.

## Lint and checks

```sh
nix flake check path:.               # nixfmt, statix, deadnix, noctalia toml
nix fmt                               # format
nix flake update umbriel              # bump umbriel
nix flake update                      # bump everything (includes nixpkgs)
```

## Vendored packages

`opencode`, `helium`, and `concat` are built from upstream prebuilt artifacts
pinned via flake inputs, so a rebuild picks up new versions without a formula
change. `opencode-feed` and `concat-manifest` point at `releases/latest` style
URLs, which drift; if evaluation fails on a `narHash` mismatch, run
`nix flake update`.
