---
name: hermes-agent
description: "Configure and extend OpenCode v2's agent system: create agents in ~/.config/opencode/agents/*.md or opencode.json, set mode/description/model/permissions per agent, control default_agent, restrict which subagents may call the Task tool, and delegate work to subagents. Use when adding or tuning an agent, fixing agent routing, or tightening per-agent permissions."
---

# OpenCode agents

The skill id stays `hermes-agent` for compatibility with existing installs.
The subject is OpenCode v2's agent system: primary agents you chat with, and
subagents you delegate to.

Hermes-specific concepts have no OpenCode equivalent: Hermes profiles,
skins, TUI widgets, pet mascots, desktop plugins, bot mode, and the Hermes
gateway. OpenCode's equivalents are listed below.

## Agent kinds

| Kind | What it is | How it is invoked |
|---|---|---|
| primary | the assistant you talk to | Tab to switch, or `default_agent` in config |
| subagent | a specialised worker | the model calls it via the Task tool, or `@name` |
| hidden system | compaction, title, summary | automatic, not selectable |

Built-in primaries: **build** (full tools) and **plan** (writes and shell
set to `ask`). Built-in subagents: **general**, **explore**, **scout**.

## Where agents live

- Global: `~/.config/opencode/agents/<id>.md`
- Project: `.opencode/agents/<id>.md`

The file name becomes the agent id. `reviewer.md` is the `reviewer` agent.

```markdown
---
description: Reviews code for best practices and potential issues
mode: subagent
model: opencode/deepseek-v4.1-flash-free
temperature: 0.1
permission:
  edit: deny
  bash:
    "*": ask
    "git diff*": allow
    "git log*": allow
---

Only analyze code and suggest changes. Do not modify files.
```

Frontmatter keys: `description` (required), `mode`, `model`, `variant`,
`temperature`, `top_p`, `steps`, `prompt`, `permission`, `disable`, `hidden`,
`color`, `options`.

- `mode`: `primary`, `subagent`, or `all` (default `all`).
- `description` is the routing signal the model reads. Write "when to use
  me", not a persona.
- `model` format is `provider/model-id`. Omit it to inherit the parent
  session's model.
- `hidden: true` removes the agent from the `@` autocomplete list while
  keeping it callable by the model.
- `steps` caps agentic iterations before the agent must answer in text.

`opencode agent create` scaffolds one interactively.

## The same agent in opencode.json

```json
{
  "$schema": "https://opencode.ai/config.json",
  "default_agent": "build",
  "agents": {
    "reviewer": {
      "description": "Reviews code for best practices and potential issues",
      "mode": "subagent",
      "model": "anthropic/claude-sonnet-4-20250514",
      "permissions": [
        { "action": "bash", "resource": "git diff*", "effect": "allow" },
        { "action": "edit", "resource": "*", "effect": "deny" }
      ]
    }
  }
}
```

The `agents` map holds built-in overrides and custom definitions. The
`permissions` array uses the `{ action, resource, effect }` rule shape; the
last matching rule wins.

Verify what OpenCode actually resolved:

```bash
opencode debug agents
opencode debug config
```

## Permissions

Two layers, same rule shape:

- global: `permissions` in `opencode.json`
- per agent: `agents.<id>.permissions`, or `permission:` in the agent's
  markdown frontmatter

```json
{
  "permissions": [
    { "action": "bash", "resource": "*", "effect": "ask" },
    { "action": "bash", "resource": "git status*", "effect": "allow" },
    { "action": "edit", "resource": "*", "effect": "ask" },
    { "action": "skill", "resource": "internal-*", "effect": "deny" }
  ]
}
```

Put the broad rule first and the specific rule after it. Rules are matched in
order and the last match wins.

Permission actions include `read`, `edit`, `glob`, `grep`, `list`, `bash`,
`task`, `external_directory`, `webfetch`, `websearch`, `lsp`, `skill`,
`question`. They are matched as wildcard patterns against the tool name, so
`mymcp_*` covers every tool of an MCP server.

## Restricting which subagents an agent may call

```json
{
  "agents": {
    "orchestrator": {
      "description": "Coordinates specialist agents",
      "mode": "primary",
      "permissions": [
        { "action": "task", "resource": "*", "effect": "deny" },
        { "action": "task", "resource": "explore-*", "effect": "allow" }
      ]
    }
  }
}
```

`deny` on `task` removes the subagents from the Task tool description, so the
model will not attempt them. The user can still reach any subagent with `@`.

## Delegating work

The Task tool is the whole interface: `agent`, `prompt`, and optionally
`model`. Leave `model` unset to inherit the parent's model.

- Read-only exploration: `explore`.
- General multi-step work: `general`.
- External docs and dependency research: `scout`.

Write the subagent prompt as a complete brief: goal, paths, constraints,
return format. A subagent starts with fresh context and does not see your
conversation.

For work that must not touch the user's tree, use a worktree
(`opencode` worktree support, or `git worktree add`) rather than relying on
subagent discipline.

## Hermes concepts and their OpenCode equivalents

| Hermes | OpenCode |
|---|---|
| profile (`~/.hermes/profiles/`) | separate config dir or `--standalone` |
| skin / theme | TUI theme, `color` per agent |
| TUI widget | plugin (`ctx.command.transform`) or plugin tool |
| desktop plugin | plugin |
| bot mode / gateway | OpenCode server (`opencode serve`) + MCP or HTTP |
| `hermes mcp` | `mcp` in `opencode.json`, `opencode mcp add` |
| cron job | `opencode schedule` equivalent via the scheduler, or a systemd timer |
| skills | skills, same discovery directories |
| memory backends | NeuraKeep vault via the `neurakeep-global` MCP server |

## Common problems

### The model never picks the agent
The `description` is the routing signal. "Reviews code" is weaker than
"Use when reviewing a diff for correctness bugs before merging".

### The agent ignores its permission
A later rule overrode an earlier one, or the agent was created in
`opencode.json` while a markdown file with the same id also exists. Check
`opencode debug agents`.

### The subagent cannot call another subagent
`task` permission denies it, or `permission.task` is set to `deny` for that
pattern. Put `*` first and the specific agent after.

### Changes collide between agents
Two agents editing the same worktree will overwrite each other. Give each a
separate worktree.

## References

The `references/` directory holds the previous Hermes documentation for
people comparing the two systems. The OpenCode-native material is all in
this file plus `opencode debug agents` and
<https://opencode.ai/docs/agents>.
