---
name: senior-review
description: Peak-quality, no-slop engineering rules for every change in this repo - smallest correct diff, no invented options, no comments except a short title, self-review before commit. Use on every change, before every commit.
---

# Senior review, no slop

## Before writing

- Read the module you change and its neighbours. Match the existing structure.
- Never invent an option. Confirm it exists in this nixpkgs: `nix eval .#nixosConfigurations.quietcraft.options.<path>.type` in the container, or read the module source with `gh api` on NixOS/nixpkgs. Check for renames in the release notes.

## The change

- Smallest diff that fixes the root cause. One concern per commit.
- No feature nobody asked for. No wrapper with one caller. No option with one value. No dead code. No TODO.
- Names say what the code does. That is the documentation.
- Comments: none. The only allowed comment is one short `# title` above a block.
- Sorted lists, `inherit` over repeated names, `lib.getExe`, `finalAttrs`, no `rec`, no `with pkgs;` at file level.

## Self-review before commit

1. `git diff` and read it as a stranger. Cut everything that is not needed.
2. `nix fmt $(git ls-files '*.nix')`, `deadnix`, `statix` clean.
3. Does the change do exactly what the commit message says, nothing more?
4. Did I leave any comment, debug line, commented-out code or unused argument? Remove it.
5. Is a secret, token or private path in the diff? Remove it.

## Commit

`type(scope): what and why`, imperative, under 72 characters. Body only for non-trivial changes: one `source:` URL.
