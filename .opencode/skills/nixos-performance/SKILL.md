---
name: nixos-performance
description: Measure and improve NixOS build speed, evaluation time, closure size and runtime performance on AMD Ryzen 5 5600G / Vega 7. Use when editing nix.settings, kernel, hardware, boot, packages or when a build or switch is slow or large.
---

# NixOS performance

Measure first, change second, measure again. Put the before and after number in the commit message. No number, no change.

## Measure

- Closure: `nix path-info -Sh /run/current-system`. Per package: `nix-tree /run/current-system`. Why is X here: `nix why-depends /run/current-system nixpkgs#X`.
- Eval time: `time nix eval --raw .#nixosConfigurations.quietcraft.config.system.build.toplevel.drvPath`. Profile: `--eval-profiler flamegraph` (Nix 2.28+).
- Switch time and download size: read the `nixos-rebuild` output.

## Build and eval

- Binary first: `nix.settings.substituters` and `trusted-public-keys` for every cache that serves your inputs. Never compile what a cache has.
- `nix.settings.max-jobs = "auto"; nix.settings.cores = 0;`
- `nix.optimise.automatic = true;` and `nix.gc.automatic = true;` with `options = "--delete-older-than 14d";`
- One nixpkgs: every flake input that has a nixpkgs gets `inputs.nixpkgs.follows = "nixpkgs";`. No second `import nixpkgs {}` inside modules, use the `pkgs` argument.
- No import from derivation. No `<nixpkgs>` lookups.
- `nix.settings.lazy-trees = true;` only if the machine runs Determinate Nix. Check first.

## Closure

- Drop what nothing uses: `environment.defaultPackages = [ ];`, unused fonts, unused locales, unused services.
- Prefer a small package variant (`-minimal`, no GUI) when the feature is not needed.

## Runtime (Ryzen 5 5600G, Vega 7, desktop)

Add only if missing and confirmed in the docs this run:
- `hardware.graphics.enable`, `hardware.enableRedistributableFirmware`, `hardware.cpu.amd.updateMicrocode`
- `zramSwap.enable`, `services.fstrim.enable`
- Kernel params, governors and sysctl tuning: only with a source and a measured gain.

Never touch boot loader, filesystems or `system.stateVersion`.
