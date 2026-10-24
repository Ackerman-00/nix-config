---
name: nix-package-update
description: Update personal Nix packages (package.nix pinned to an upstream release) to the latest release - new version, new hash, build, commit. Use for helium, openchamber, craft-launcher and any app packaged in this repo, and whenever nix flake update does not move a package.
---

# Update personal Nix packages

`nix flake update` only moves `flake.lock` inputs. A `package.nix` with a fixed `version` and `hash` never changes by itself. You must edit `version` and `hash` yourself. This is possible. Never report "cannot".

## 0. Where Nix runs

The runner has no Nix. Run every nix command inside the NixOS docker container:

`docker exec <name> bash -lc 'cd /etc/nixos && <command>'`

- After container edits run `sudo chown -R "$(id -u):$(id -g)" .` on the host so git can commit.
- API rate limits: add `-e GITHUB_TOKEN` to docker exec (the read-only runner token). Never pass `REPO_FULL_ACCESS_TOKEN` into the container.
- Tools: `nix shell nixpkgs#jq nixpkgs#gh nixpkgs#nix-update -c <command>`.

## 1. Find the packages

- `grep -rlE 'fetchurl|fetchFromGitHub|fetchzip|fetchgit' --include='*.nix' .` and look at every `package.nix`, `default.nix` under `pkgs/`, `packages/`, `overlays/`.
- Write a list: name, file, upstream repo, current version.
- Skip packages that come from nixpkgs or from a flake input.
- Known examples: helium (imputnet/helium-linux), craft-launcher (storytold/craft-launcher), openchamber.

## 2. Update each package. Use the first method that works

A. If the flake has an `update-user-apps` app: `nix run .#update-user-apps`, then read `git diff`.

B. nix-update (finds the latest stable release, rewrites version and hashes):
- `nix-update --flake <attr> --commit`  (attr = `packages.x86_64-linux.<attr>` in the flake)
- Prefixed tags: add `--version-regex 'v(.*)'`
- Only refresh hashes: `--version=skip`
- Package file outside flake packages: `nix-update --override-filename <file> --url <github url> <attr>`

C. Manual. Always works:
1. Latest stable tag, on the host: `gh api repos/OWNER/REPO/releases/latest --jq .tag_name`. Ignore drafts and prereleases.
2. Same as current version: stop, nothing to do.
3. Build the new asset URL from the pattern already in the file.
4. Hash in the container: `nix store prefetch-file --json <url>` and take `.hash` (it is already `sha256-...` SRI).
   For `fetchFromGitHub`: set `hash = lib.fakeHash;`, run `nix build .#<attr> --no-link`, copy the `got: sha256-...` line into `hash`.
5. For `vendorHash`, `cargoHash`, `npmDepsHash`, `pnpmDepsHash`: set one to `lib.fakeHash`, build, copy `got:`. Repeat per hash.
6. Edit `version` and `hash` with str_replace. Never guess a hash. Never invent a version.

## 3. Verify

- `nix build .#<attr> --no-link` for every package you changed. Binary release packages need no compile.
- If cheap, run the binary with `--version`.

## 4. Commit

One commit per package: `chore(pkgs): <name> <old> -> <new>`.

## 5. Failure

- 3 tries per package. Then `git checkout -- <file>`, add `skipped: <name> <short reason>` to `.opencode-relay.md`, go on with the next package. One broken package never blocks the others.
- Upstream renamed its release asset: read the release assets with `gh api repos/OWNER/REPO/releases/latest --jq '.assets[].name'` and fix the URL pattern.

## 6. Report

Add `updated: <name> <old> -> <new>` per package to `.opencode-relay.md`.
