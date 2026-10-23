---
name: healthcheck
description: "Audit and harden an OpenCode v2 host on Linux: config and permission rules, plugin trust, MCP server surface, agent/command/tool registry, exposed network ports, SSH, firewall, updates, and backups. Read-only checks first, then staged reversible hardening."
---

# OpenCode host healthcheck

Goal: assess risk on this machine, run read-only checks, then propose staged
hardening without breaking access.

## Rules

- Ask before any state-changing action.
- Never print secrets.
- Do not change SSH, firewall, or remote access until the access path is
  confirmed.
- Prefer reversible steps and state the rollback for each one.
- Offer choices as a short numbered list.
- OpenCode manages its own config, plugins, skills, agents, and MCP servers.
  It does not manage the OS firewall, SSH, or system updates.

## Context to infer first

- OS and version, host vs container.
- Privilege level.
- Access path: local session, SSH, RDP, tailnet.
- Network exposure: public IP, reverse proxy, tunnel, LAN only.
- Whether OpenCode runs as a background service or per-session.
- Backup status, disk encryption, automatic security updates.
- Usage mode: personal workstation, local assistant box, remote server.

Ask only for what is missing.

## Read-only OpenCode checks

```bash
opencode debug paths        # where config, data, db, logs live
opencode debug config       # every config source, merged and resolved
opencode debug agents       # every agent OpenCode resolved
opencode plugin list        # plugins and their source
opencode mcp list           # MCP servers and connection status
opencode session list       # recent sessions in this project
```

What to look for in the output:

- `opencode plugin list`: a plugin from an unexpected source (npm package with
  no version pin, a local `.js` you do not recognise). Every plugin runs with
  the agent's privileges.
- `opencode mcp list`: a server that is `local` and launches a binary from a
  writable path, or a `remote` server with no auth headers.
- `opencode debug config`: `permissions` rules that `allow` broad shell
  patterns, `providers` pointing at an unknown base URL, `plugins` entries
  with unpinned git refs, `mcp` servers with `enabled: true` that the user
  does not remember adding.
- `opencode debug agents`: an agent whose `permission` block allows edits or
  shell where the name suggests read-only work.

Inspect the config file directly for secrets-in-config risk:

```bash
ls -l ~/.config/opencode/opencode.json
rg -n '"(apiKey|token|secret|password)"' ~/.config/opencode/opencode.json
```

The config should hold references, not live credentials. Credentials belong in
the environment or the provider's own auth store (`opencode auth`).

Session store and logs:

```bash
ls -l ~/.local/share/opencode/opencode.db
ls -lt ~/.local/share/opencode/log | head
```

`opencode.db` holds every session's transcript. If the machine is shared or
the sessions are sensitive, that file's permissions matter.

## Read-only host checks (Linux)

```bash
cat /etc/os-release
ss -ltnup || ss -ltnp
ufw status || firewall-cmd --state || nft list ruleset
systemctl status ssh sshd
lsblk -f
```

Also useful:

```bash
ss -ltnp | grep -i opencode   # is OpenCode listening on a public interface?
```

OpenCode's own service is local by default. A v2 server exposed on
`0.0.0.0` without auth is the highest-risk finding in this audit.

## Risk profile

After the context is known, offer three postures and let the user pick:

1. Convenience: local only, minimal prompts.
2. Balanced: secure defaults, low friction.
3. Strict: any network exposure or sensitive data, more lock-down.

## Report shape

- Current posture: one paragraph.
- Findings: severity, evidence, why it matters.
- Recommended plan: staged and reversible, each step with its rollback.
- Commands: read-only first; write actions only after approval.
- Gaps: what could not be checked.

## Hardening menu

Offer only the relevant items, and confirm the exact action before applying:

- Bind the OpenCode server to loopback or a specific interface.
- Put an auth layer in front of it if it must be reachable from elsewhere.
- Close or firewall public ports.
- Tighten `permissions` rules in `opencode.json`: deny-by-default for shell
  writes, `ask` for `git push`, `rm`, and package installs.
- Remove or disable plugins the user did not install.
- Disable MCP servers that are not in use (`"enabled": false`).
- Restrict who can read `~/.config/opencode/opencode.json` and
  `~/.local/share/opencode/opencode.db`.
- Enable OS security updates.
- Enable disk encryption.
- Verify backups and a restore path.

## Pitfalls

- Recommending an OpenCode flag that does not exist. Check `opencode --help`
  and the schema at <https://opencode.ai/config.json>.
- Editing `opencode.json` by hand without checking the resolved result.
  Follow the edit with `opencode debug config`.
- Assuming a permission rule fires when an earlier, broader rule overrides
  it. The last matching rule wins.
- Reporting "secure" from the absence of findings in the checks that ran.
  State the gaps instead.
