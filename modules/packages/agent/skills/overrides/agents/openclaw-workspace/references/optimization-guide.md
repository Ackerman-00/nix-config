# Workspace Optimization Guide

Keeping the OpenCode workspace lean, non-redundant, and cheap in context.

## Audit file sizes

```bash
wc -c ~/.config/opencode/AGENTS.md
wc -c AGENTS.md 2>/dev/null
wc -c ~/.config/opencode/agents/*.md ~/.config/opencode/commands/*.md
```

Thresholds for `AGENTS.md`:

| Size | Status |
|------|--------|
| under 5,000 chars | healthy |
| 5,000-10,000 chars | acceptable, monitor growth |
| 10,000-15,000 chars | review for trimming |
| over 15,000 chars | trim now |

Only `AGENTS.md` is auto-injected every turn. Agent, command, and skill files
are read on demand, so they are cheap in context but still need to stay
readable.

## Move content out of AGENTS.md

Move to a skill or a reference file when content is:

- only needed for one task type
- long explanation rather than a rule
- historical context
- the same for every project (belongs in the global file, not the project one)

Keep in `AGENTS.md` when content:

- changes what the agent does on every turn
- is under ~200 chars
- cannot be discovered by reading the repo

## Reference-on-demand pattern

1. `AGENTS.md` holds a routing line: "Deploy steps: `.opencode/checklists/deploy.md`".
2. The checklist file lives next to the project, not in the instruction file.
3. The agent reads it only when the task matches.

The OpenCode equivalent of the old OpenClaw `checklists/` directory is a
folder of markdown files referenced from `AGENTS.md`. Keep each one under ~50
lines of actionable steps; anything longer is documentation, and documentation
belongs in a doc file the agent reads on demand.

## Redundancy audit

Search for the same rule living in two places:

```bash
rg -n "cargo (test|clippy|fmt)" ~/.config/opencode/AGENTS.md AGENTS.md ~/.agents/skills ~/.config/opencode/skills
rg -n "never|prompt injection" ~/.config/opencode/AGENTS.md AGENTS.md
```

When the same rule appears twice, remove one copy. Do not add "unless..." to
one side to reconcile them.

Also check for a skill that duplicates an `AGENTS.md` rule. The skill is the
right home for anything with a procedure; the instruction file is the right
home for anything that is always true.

## Vault instead of MEMORY.md

OpenCode has no `MEMORY.md`. Durable memory lives in the NeuraKeep vault and
is reached with `memory_search` / `memory_read`, not by reading a file every
turn.

```bash
# what the extraction pipeline has been doing
tail -50 ~/.local/share/neurakeep/plugin.log
```

Promotion rule:

| Content | Destination |
|---|---|
| must hold on every turn | `AGENTS.md` |
| true for this repo only | project `AGENTS.md` |
| procedure with steps | a skill's `SKILL.md` |
| history, past decisions, one-off detail | vault (leave it there) |

When promoting, write the rule as an imperative line, not a paragraph about
the incident that produced it.

## Consistency sweep

Check that every path and command mentioned in the instruction files exists.

```bash
rg -o '`[^`]+`' ~/.config/opencode/AGENTS.md | tr -d '`' | sort -u
```

For each path that looks like a file, verify it. A stale path in
`AGENTS.md` causes a failed tool call on every session that needs it.

## Plugin and command inventory

```bash
opencode plugin list
opencode debug agents
ls ~/.config/opencode/plugins ~/.config/opencode/commands ~/.config/opencode/agents
```

Every plugin runs with the agent's privileges. For each one, know: what it
hooks, what it reads, what it writes, and whether the user asked for it.
Unknown plugins are the most common source of unexpected behaviour.

## Quick wins

- Delete `AGENTS.md` sections that duplicate a skill.
- Move environment facts into the global file, project facts into the project
  file.
- Replace prose rules with single imperative lines.
- Remove rules that have not been relevant in months.
- Remove stale skill directories: an unused skill still costs the model a
  line in the skill list.
- Keep `opencode.json` keys you actually use; an empty `{}` section is noise.
