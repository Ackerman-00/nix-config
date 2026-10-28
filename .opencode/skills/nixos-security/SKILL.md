---
name: nixos-security
description: Harden the quietcraft NixOS host - firewall, secrets, systemd units, kernel, sudo and CI credentials. Use when touching services, network, kernel, users, workflows or anything that grants privilege.
---

# NixOS security

Harden one thing per commit, with a source. A hardening that breaks the owner's desktop or forces a reboot loop is a regression, not a fix.

## Order of value

1. Remove an exposure: an open port, an enabled service nobody uses, a token in a file.
2. Restrict a privilege: `nix.settings.allowed-users`, `trusted-users`, sudo rules, group membership.
3. Sandbox a unit: `systemd.services.<name>.serviceConfig` with `NoNewPrivileges`, `ProtectSystem = "strict"`, `PrivateTmp`, `ProtectHome`.
4. Kernel or sysctl: only when the option's cost is understood. `security.lockKernelModules` and `security.protectKernelImage` break module loading and hibernation.

## Rules

- Confirm the option exists in this nixpkgs before using it: `nix eval .#nixosConfigurations.quietcraft.options.<path>.type` in the container, or read the module source with `gh api` on NixOS/nixpkgs.
- `networking.firewall` is on by default. `networking.firewall.allowedTCPPorts` is a decision: name the service that needs it in the message.
- `boot.initrd.systemd` is the default stage 1. Do not weaken it back to scripted stage 1.
- Turn a service off through its own option (`services.speechd.enable = false`), which drops the unit and its socket; `systemd.services.<name>.enable = false` leaves socket, path and D-Bus activation able to start it.
- Never widen `nix.settings.trusted-users`: a trusted user can build with `sandbox = false` and write to the store.
- Secrets never enter the repo, a commit body, a log line or `.opencode-relay.md`. A workflow reads `${{ secrets.* }}` into the environment and nothing else prints it.
- Never add a CI permission scope to pass a step; `tools/workflow-valid.py` is the authority on what GitHub accepts.
- Never remove a boot, filesystem or `system.stateVersion` setting to "clean up".
- A hardening without a testable result in `nixos-rebuild switch` is not done: verify, then state what changed.
