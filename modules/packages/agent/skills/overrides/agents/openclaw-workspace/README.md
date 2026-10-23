# openclaw-workspace

OpenCode v2 workspace management: `AGENTS.md`, `opencode.json`, agents,
commands, plugins, skills, and the NeuraKeep vault.

The skill id stays `openclaw-workspace` for compatibility with existing
installations. Its content targets OpenCode v2 on Linux.

## What this is

OpenCode's workspace is a set of standard locations rather than one folder of
persona files:

| Concern | Location |
|---|---|
| Instructions | `~/.config/opencode/AGENTS.md`, project `AGENTS.md` |
| Config | `~/.config/opencode/opencode.json`, project `opencode.json` |
| Agents | `~/.config/opencode/agents/*.md` |
| Commands | `~/.config/opencode/commands/*.md` |
| Plugins | `~/.config/opencode/plugins/*.js` |
| Skills | `~/.config/opencode/skills/`, `~/.agents/skills/` |
| Sessions | `~/.local/share/opencode/opencode.db` |
| Durable memory | `~/.local/share/neurakeep/vault` |

## What this skill does

1. **Audit** instruction files for size, redundancy, contradictions, secrets,
   and stale paths.
2. **Set up** a workspace from scratch: config, `AGENTS.md`, agents.
3. **Distil** memory: promote the right things into `AGENTS.md`, leave the rest
   in the vault.
4. **Cross-check** rules, paths, and commands that appear in more than one
   file.

## Install

OpenCode discovers skills in `~/.agents/skills/`, so this directory is
already live. To verify:

```bash
ls ~/.agents/skills/openclaw-workspace/SKILL.md
```

## Files

- `SKILL.md` — the skill.
- `references/workspace-files.md` — each workspace surface in detail.
- `references/optimization-guide.md` — context budget, audits, distillation.
