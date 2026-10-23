# quietcraft

NixOS flake for `quietcraft`: one x86_64-linux machine, Umbriel compositor,
Noctalia shell.

Host `quietcraft` · user `ackerman` · stateVersion `26.11`

## Install from a minimal ISO

The minimal ISO ships neither git nor flakes:

```sh
nix-shell -p git --extra-experimental-features 'nix-command flakes'
```

Replace the stock config with this repo (one command):

```sh
sudo rm -rf /etc/nixos && sudo git clone https://github.com/Ackerman-00/nix-config /etc/nixos && sudo chown -R "$USER" /etc/nixos
```

`hardware-configuration.nix` is gitignored — it holds this disk's UUIDs — so
generate it on the target machine:

```sh
sudo nixos-generate-config --show-hardware-config \
  | sudo tee /etc/nixos/hardware-configuration.nix
```

First switch. `path:` is required (see below); `accept-flake-config` is needed
once so `nixConfig` can add the Umbriel cache before the system settings exist:

```sh
sudo nixos-rebuild switch \
  --flake path:/etc/nixos#quietcraft \
  --extra-experimental-features 'nix-command flakes' \
  --option accept-flake-config true
```

The user is created without a password:

```sh
sudo passwd ackerman
```

`system.stateVersion` and `home.stateVersion` are the release of the ISO used
for the first install. Never change them.

## Daily

```sh
nh os switch      # rebuild
nh os test        # build + activate, no boot entry
nh clean all      # prune generations (also runs daily as a timer)
```

`nh` is configured for `path:/etc/nixos`. Plain fallback:

```sh
sudo nixos-rebuild switch --flake path:/etc/nixos#quietcraft
```

## Why `path:`

`hardware-configuration.nix` is untracked, and a git flake reference copies
only tracked files into the store. That silently drops the file and the build
dies with `The 'fileSystems' option does not specify your root file system`.
Use `path:` everywhere, checks included: `nix flake check path:.`.

## Layout

```
flake.nix                inputs, outputs, checks, cachix substituters
hosts/quietcraft/        root module (+ gitignored hardware-configuration.nix)
home.nix                 home-manager entry point
modules/
  system/                nix settings, boot, network, locale, users, maintenance
  desktop/               greeter, fonts, services, noctalia, umbriel
  browsers/              helium (vendored), firefox, brave-origin
  shell/                 zsh tooling, neovim
  home-manager/          shell (zsh, kitty, starship, fastfetch, git, direnv),
                         programs (noctalia, vesktop)
  packages/
    agent/               skills, opencode, neurakeep, openchamber,
                         freebuff, omnirush, ollama, cline
    media/               hyperframes, concat, craft-launcher, tts
    mcp/                 youtube transcript + playwright, concat, blender
    packages-*.nix       flat groups: apps, desktop, dev, gaming, kankan, utils
```

Every module is gated by `my.<name>.enable`. All default to on except
`my.firefox` (system Firefox is broken on this snapshot) and
`my.mcp.<server>.enable`, which only auto-connects an MCP server at OpenCode
startup. Turn anything off in `hosts/quietcraft/default.nix`.

## Inputs and versions

Helium, Concat and Craft Launcher are built from upstream prebuilt artifacts
pinned as flake inputs, so a rebuild picks up a new release with no formula
change. Those pins point at `releases/latest` style URLs and therefore drift;
on a `narHash` mismatch:

```sh
nix flake update craft-launcher-feed concat-manifest helium-pin
```

Freebuff and OmniRush are unfree Electron apps taken from the upstream `.deb`,
versioned by their feed inputs:

```sh
nix flake update freebuff-feed omnirush-feed
```

Umbriel and `xdg-desktop-portal-umbriel` come from
[`umbriel.cachix.org`](https://umbriel.cachix.org) instead of being compiled —
declared in `nixConfig` here and in `nix.settings` under `modules/system/`. The
input tracks the upstream `cachix` branch, which only advances to commits whose
CI published binaries, and deliberately does not `follows` nixpkgs: its store
paths only match the cache when built against its own pinned nixpkgs.

`opencode` and `opencode-desktop` come from nixpkgs. The CLI is installed by
the `programs.opencode` Home Manager module, which also writes the global
`opencode.json`, `AGENTS.md`, and the agent and command directories.

## Checks

```sh
nix flake check path:.    # nixfmt, statix, deadnix, noctalia toml
nix fmt
nix flake update umbriel  # bump one input
nix flake update          # bump everything
```

## Agent skills

`modules/packages/agent/skills/` owns `~/.agents/skills` and
`~/.config/opencode/skills`; the CLI's lockfile sits at
`~/.local/share/agent-skills/skill-lock.json`. Every rebuild restores the skills
committed under `overrides/`, re-fetches the upstream-tracked ones, then
restores the local copies again — a fetch cannot clobber a local edit.

`my.skills.refresh` controls the fetch, `my.skills.restore` the restore.
`my.skills.excluded` keeps retired skills from coming back: `heygen-avatar`,
`heygen-translate`, `heygen-video` (the service is paid), `best-practices`,
`web-quality-audit`.

An upstream change to an adapted skill needs a regeneration:

```sh
modules/packages/agent/skills/generate.sh
```
