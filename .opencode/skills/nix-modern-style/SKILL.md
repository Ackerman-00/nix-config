---
name: nix-modern-style
description: Modern, minimal Nix style for this NixOS flake - simplify like a kernel developer, newer syntax, no dead code, safe AMD hardware optimization. Use when editing or reviewing any .nix file.
---

# Modern minimal Nix

Kernel-developer rules: small modules, one concern each, explicit over clever, no abstraction without two users, delete dead code.

## Syntax

- `stdenv.mkDerivation (finalAttrs: { ... })` instead of `rec`.
- `inherit (pkgs) a b;` instead of `a = pkgs.a;`.
- `lib.getExe pkg` instead of `"${pkg}/bin/name"`.
- No `with pkgs;` at file level. No `rec`. No `lib.mdDoc`.
- `lib.mkIf`, `lib.mkMerge`, `lib.mkDefault`. Use `lib.mkForce` only with a reason.
- Use `lib.mkEnableOption` and typed options for anything reused.
- Run `nix fmt`, `deadnix`, `statix`. Fix what they report.
- Comments: none, except one short `# title` above a block.

## Safe AMD optimization (Ryzen 5 5600G, Vega 7)

Add one only if it is missing and you checked the NixOS manual or kernel docs this run:
- `hardware.cpu.amd.updateMicrocode`, `hardware.enableRedistributableFirmware`
- `hardware.graphics.enable` (replaces `hardware.opengl`)
- `services.fstrim.enable`, `zramSwap.enable`
- `nix.settings`: `auto-optimise-store`, trusted binary caches
- Kernel params or scheduler tweaks: only with a source that shows a gain. Default kernel otherwise.

Never remove boot, filesystem or `system.stateVersion` settings.
