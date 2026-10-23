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
  browsers/                  helium (vendored), firefox
  shell/                     zsh tooling, neovim
  home-manager/              home-manager modules
    programs/                noctalia, vesktop
    shell/                   zsh, kitty, starship, fastfetch, git, direnv
  packages/                  products, one group per role
    agent/                   the agent runtime
      skills/                skill subsystem, auto-update from upstream
      opencode/              the app and its global config
      neurakeep/             memory runtime
      openchamber/           desktop shell
    media/                   media & video production tooling
      hyperframes/           HyperFrames CLI, skills, local voice, transcription
      concat/                the video editor, vendored
      craft-launcher/        the Craft launcher, the official prebuilt tarball
      tts/                   TTS python packages for AI video editing workflows
    mcp/                     local MCP servers
      servers/               youtube transcript, playwright
      concat/                the concat bridge
      blender/               the blender bridge
```

## Installing on a fresh minimal system

A minimal NixOS install has no `git` and no flakes enabled, so bootstrap both
before anything else:

```sh
nix-shell -p git --extra-experimental-features 'nix-command flakes'
```

Clone straight into `/etc/nixos`. Do not keep a second copy in `$HOME`: `/etc/nixos`
is the one every rebuild reads, so a copy elsewhere silently never applies.

`/etc` is root-owned, so git cannot create the directory itself — make it first and
hand it to your user, then clone into the empty dir (git refuses a non-empty one).

```sh
sudo rm -rf /etc/nixos
sudo mkdir -p /etc/nixos
sudo chown "$USER" /etc/nixos
git clone https://github.com/Ackerman-00/nix-config /etc/nixos
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
  --option accept-flake-config true   # bootstrap only
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

## Agent skills

Every skill OpenCode reads lives under `~/.agents/skills` and
`~/.config/opencode/skills`. The lockfile the `skills` CLI wrote, kept at
`~/.agents/.skill-lock.json`, records per skill the GitHub upstream it came
from.

`modules/packages/agent/skills/` owns that tree. On every rebuild its
activation step:

1. restores the locally authored and locally adapted skills (committed under
   `overrides/`) so a fetch can never clobber them;
2. re-fetches the upstream-tracked skills whose repo moved;
3. restores the local copies again.

Skills that must never come back are listed in `my.skills.excluded` —
`heygen-avatar`, `heygen-translate`, `heygen-video` (the HeyGen service is
paid), plus `best-practices` and `web-quality-audit`.

`my.skills.refresh` controls the upstream fetch; `my.skills.restore` controls
the local-copy restore. They are separate on purpose.

Locally adapted skills are pinned to the copy in `overrides/`. To pick up an
upstream change to one of them, re-run the generator and commit the result:

```sh
modules/packages/agent/skills/generate.sh
```

`helium` and `concat` are built from upstream prebuilt artifacts pinned via
flake inputs, so a rebuild picks up new versions without a formula change.
`craft-launcher-feed` and `concat-manifest` point at `releases/latest` style
URLs, which drift; if evaluation fails on a `narHash` mismatch, run
`nix flake update craft-launcher-feed`.

`opencode` and `opencode-desktop` come from nixpkgs. The CLI is installed by
the `programs.opencode` Home Manager module, which also writes the global
`opencode.json`, the `AGENTS.md` and the agent and command directories. The
desktop app is a nixpkgs system package.
