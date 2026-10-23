---
name: openclaw-workspace
description: "Maintain the OpenCode v2 workspace: AGENTS.md instruction files (global ~/.config/opencode/AGENTS.md, project AGENTS.md), the ~/.config/opencode/{agents,commands,plugins,skills} layout, opencode.json config, and the NeuraKeep vault as the durable memory layer. Use for workspace setup, instruction auditing, memory distillation, and consistency checks."
---

# OpenCode Workspace

The "workspace" for OpenCode v2 is not a single folder of persona files like it
was in OpenClaw. It is a set of standard locations that OpenCode reads:

| Concern | Location | Loaded |
|---|---|---|
| Instructions | `~/.config/opencode/AGENTS.md` | every session, global |
| Instructions (project) | `AGENTS.md` in the project root | every session, overrides global |
| Config | `~/.config/opencode/opencode.json` (or `.jsonc`) | at startup |
| Config (project) | `opencode.json` or `.opencode/opencode.json` | at startup, overrides global |
| Agents | `~/.config/opencode/agents/*.md`, `.opencode/agents/*.md` | agent selection |
| Commands | `~/.config/opencode/commands/*.md`, `.opencode/commands/*.md` | slash commands |
| Plugins | `~/.config/opencode/plugins/*.js`, `.opencode/plugins/*.js` | auto-loaded at startup |
| Skills | `~/.config/opencode/skills/`, `~/.agents/skills/`, `~/.claude/skills/`, project equivalents | on demand via the `skill` tool |
| Sessions | `~/.local/share/opencode/opencode.db` (SQLite) | written continuously |
| Durable memory | `~/.local/share/neurakeep/vault` (NeuraKeep) | via the `neurakeep-global` MCP server |

Resolve the real paths for any install instead of assuming them:

```bash
opencode debug paths
opencode debug config      # resolved config, all sources merged
opencode debug agents      # every agent OpenCode resolved
```

**This skill ID stays `openclaw-workspace`** for compatibility with existing
installations. Everything below targets OpenCode v2. OpenClaw-only concepts
(SOUL.md, TOOLS.md, IDENTITY.md, HEARTBEAT.md, BOOT.md, MEMORY.md,
`~/.openclaw/workspace/`) have no OpenCode equivalent: there is one
instruction file, `AGENTS.md`, and durable memory lives in the NeuraKeep
vault.

## AGENTS.md

`AGENTS.md` is OpenCode's instruction file. Not `CLAUDE.md`, not
`SOUL.md`.

- Global: `~/.config/opencode/AGENTS.md`
- Project: `AGENTS.md` in the project root
- The project file overrides the global file.
- Other instruction sources can be added through the `instructions` config key
  (array of paths or URLs).

Keep it small. It is injected into every turn of every agent, so every
sentence is paid for on every request.

```markdown
# Project rules

- Build: `cargo test` must pass before any commit.
- Never edit files under `vendor/`.
- Use `rg`, not `grep -r`.
```

Rules for writing it:

- One rule per line, imperative, testable. "Never use `unwrap()` in library
  code" beats a paragraph about error handling philosophy.
- Put the build/test/lint commands in it; agents look there first.
- Put environment facts that are true for this machine in it (paths, hosts,
  device names).
- Do not put task state, session logs, or long narrative history in it.
- Do not duplicate what a skill's `SKILL.md` already says. Point at the skill
  instead.

## Config

Schema: `https://opencode.ai/config.json`.

Keys that matter for workspace maintenance: `model`, `default_agent`,
`permissions`, `agents`, `commands`, `plugins`, `providers`, `mcp`, `skills`,
`instructions`, `formatter`, `lsp`, `disabled_providers`, `worktree`.

`permissions` is an ordered ruleset; the last matching rule wins:

```json
{
  "$schema": "https://opencode.ai/config.json",
  "permissions": [
    { "action": "provider.use", "resource": "some-provider", "effect": "deny" },
    { "action": "bash", "resource": "git push*", "effect": "ask" }
  ],
  "default_agent": "build"
}
```

Per-agent overrides live under `agents.<id>.permissions` with the same rule
shape. MCP servers are `mcp.<name>` entries:

```json
{
  "mcp": {
    "neurakeep-global": {
      "type": "local",
      "command": ["node", "/path/to/cli.js", "mcp", "--root", "/path/to/vault"],
      "enabled": true,
      "timeout": 20000
    }
  }
}
```

Remote servers use `{ "type": "remote", "url": ..., "headers": {...} }`.

## Plugins

Global `~/.config/opencode/plugins/*.js` and project `.opencode/plugins/` are
auto-loaded. A plugin exports a default object with an id and an async
`setup`:

```js
export default {
  id: "my-plugin",
  setup: async (ctx) => {
    const cleanup = ctx.session.hook("prompt", async (event) => {
      console.log(event.prompt.text)
    })
    return () => cleanup.dispose()
  },
}
```

`ctx` exposes `app`, `location` (`directory`, `workspaceID`, `project`),
`storage`, `model`, `agent`, `session`, `command`, `tool`, `permission`,
`event`, `mcp`, `skill`, `provider`, `vcs`, `worktree`, `reference`,
`generate`, `websearch`, `config`, `instructions`.

Session hooks: `ctx.session.hook(name, cb)` with `name` in `"prompt"`,
`"context"`, `"compaction"`, `"generate"`, `"title"`, `"model.request"`,
`"http.request"`, `"http.response"`, `"retry"`. Each returns a registration
with `.dispose()`.

```js
await ctx.session.hook("context", (event) => {
  event.system.push({ type: "text", text: "Remember: never force push." })
})
```

The `"context"` hook must mutate `event.system` **synchronously**. A change
made after an `await` never reaches the model.

Other hook surfaces: `ctx.permission.hook("evaluate", cb)` (`event.effect`,
`event.message`, `event.action`, `event.resources`), `ctx.shell.hook(
"create.before", cb)` (`event.command`, `event.cwd`, `event.timeout`,
`event.env`), `ctx.tool.hook("execute.before" | "execute.after", cb)`
(`event.tool`, `event.input`, `event.result`, `event.status`).

Commands and tools are added by transforming the editor:

```js
await ctx.command.transform((editor) => {
  editor.add({
    name: "my-command",
    description: "What it does",
    execute: async () => {
      await ctx.session.synthetic({ text: "done" })
    },
  })
})
```

`ctx.event.subscribe({ signal })` is an async-iterable of event objects
(`session.idle`, `session.step.ended`, `file.edited`, `project.updated`, ...).

## Skills

Skill directories OpenCode discovers:

```
~/.config/opencode/skills/<name>/SKILL.md     # native
~/.agents/skills/<name>/SKILL.md              # agent-compatible
~/.claude/skills/<name>/SKILL.md               # claude-compatible
.opencode/skills/<name>/SKILL.md              # project native
.agents/skills/<name>/SKILL.md                # project agent-compatible
.claude/skills/<name>/SKILL.md                 # project claude-compatible
```

Rules that trip people up:

- **The skill ID is the directory name**, not the frontmatter `name`.
- `name` must match the directory name and be lowercase alphanumeric with
  single hyphens (`^[a-z0-9]+(-[a-z0-9]+)*$`).
- Frontmatter must have `name` and `description`. `description` is what the
  model sees when choosing a skill, so it must state what the skill does and
  when to use it.
- `metadata.opencode/autoinvoke: "false"` hides a skill from the model's
  auto-selection list; it stays loadable by exact name.
- `metadata.opencode/slash: "true"` exposes the skill as a `/name` command.

## Agents

`~/.config/opencode/agents/<id>.md` (global) or `.opencode/agents/<id>.md`
(project). The file name becomes the agent id.

```markdown
---
description: Reviews code for best practices and potential issues
mode: subagent
model: anthropic/claude-sonnet-4-20250514
permission:
  edit: deny
  bash: ask
---

Only analyze code and suggest changes.
```

- `mode` is `primary`, `subagent`, or `all` (default `all`).
- `description` is required; the model uses it to decide when to delegate.
- `default_agent` in `opencode.json` sets the primary agent when no session
  agent is selected.
- Omit `model` to inherit the parent session's model.

## Memory layer (NeuraKeep)

Every OpenCode session on this machine is captured into the NeuraKeep vault at
`~/.local/share/neurakeep/vault`. The `neurakeep-global` MCP server exposes it:

| Tool | Use |
|---|---|
| `memory_search` | find prior sessions, facts, failures |
| `memory_read` | open a source, section, fact, event, failure, or proposal by id |
| `memory_explain_sources` | show where a memory came from: file, line, hash, timestamp |
| `memory_propose_update` | file a cited proposal from an ingested source |
| `memory_apply_update` | force a proposal into durable memory — **do not call this** |

Durable memory is applied by the extraction pipeline on its own. Proposals are
for review. If a search returns nothing, say so; the vault holds real
transcripts, so a miss usually means the topic was never discussed.

The capture plugin lives at `~/.config/opencode/plugins/neurakeep-memory.js`
and its config at `~/.config/opencode/neurakeep-memory.json`. The global
`AGENTS.md` documents the same thing.

Do not mirror vault contents into `AGENTS.md`. The vault is searchable and
grows; `AGENTS.md` is injected every turn. Keep only stable rules in
`AGENTS.md` and let `memory_search` handle history.

## Workflow: audit the workspace

1. Resolve the real paths: `opencode debug paths`, `opencode debug config`.
2. Size the instruction files:
   ```bash
   wc -c ~/.config/opencode/AGENTS.md
   wc -c AGENTS.md 2>/dev/null
   ```
3. Flag anything over ~10,000 characters. Move detail into a skill, a
   reference file, or the vault.
4. Look for contradictions between global and project `AGENTS.md`. The project
   file wins, so a stale global rule is a trap.
5. Check for secrets in `AGENTS.md` and in `opencode.json`. They belong in the
   environment, not in a file the model reads every turn.
6. Check the skill set for duplicates across `~/.config/opencode/skills`,
   `~/.agents/skills`, and `~/.claude/skills`. Same id in two places is
   ambiguous; one shadows the other.
7. Check every plugin in `~/.config/opencode/plugins/` for what it does and
   whether it is trusted:
   ```bash
   opencode plugin list
   ```

## Workflow: set up a new workspace

1. Create `~/.config/opencode/opencode.json` with `$schema` and the keys you
   actually use. Do not copy a template with empty sections.
2. Write `~/.config/opencode/AGENTS.md` with the machine-specific rules:
   build commands, package manager, hardware limits, communication style.
3. Write a project `AGENTS.md` with only the project-specific rules.
4. Add agents under `~/.config/opencode/agents/` only when a distinct role is
   genuinely needed.
5. Verify:
   ```bash
   opencode debug paths
   opencode debug agents
   opencode debug config
   ```

## Workflow: distill memory

1. Search the vault for the topic area:
   - `memory_search` with a query and a `limit`.
2. Read the relevant sources with `memory_read`.
3. Promote only what should be in context on every turn:
   - rules violated more than once
   - hard-won environment facts
   - decisions that would otherwise be re-litigated
4. Put promoted rules in `AGENTS.md` (global for machine facts, project for
   repo facts). Keep it under ~10,000 characters.
5. Everything else stays in the vault, reachable by search. Do not promote
   session narratives, task-specific detail, or anything already covered by a
   skill.

## Workflow: cross-file consistency

When a rule, command, or path appears in more than one place, check all
copies:

```bash
rg -n "cargo test" ~/.config/opencode/AGENTS.md AGENTS.md ~/.agents/skills
rg -n "release|deploy" ~/.config/opencode/AGENTS.md AGENTS.md
```

Report every location that disagrees. Fix by removing the duplicate, not by
adding a caveat to one copy.

## Common issues

### Instructions not taking effect
The project `AGENTS.md` overrides the global one entirely for overlapping
rules. Confirm which file OpenCode is reading: `opencode debug paths` shows
the config root, and the project file must sit in the project root of the
session directory.

### A skill never loads
Check the directory name matches the id, the frontmatter has `name` and
`description`, the name matches `^[a-z0-9]+(-[a-z0-9]+)*$`, and no permission
rule denies it. `metadata.opencode/autoinvoke: "false"` also removes it from
the model's list.

### Plugin changes ignored
Plugins are loaded at startup. Run `opencode reload` or start a new session.
`opencode plugin list` shows what loaded and from where.

### A permission rule does not fire
Rules are ordered and the last match wins. Put the wildcard rule first and
the specific rule after it.

### Memory search returns nothing
The vault indexes real transcripts. A miss means the topic was not discussed
in a captured session, not that the memory is broken. Check
`~/.local/share/neurakeep/plugin.log` for capture errors.

## Reference files

| Reference | Coverage |
|---|---|
| [references/workspace-files.md](references/workspace-files.md) | Each workspace surface: AGENTS.md, config, agents, commands, plugins, skills, vault |
| [references/optimization-guide.md](references/optimization-guide.md) | Context budget, audit commands, distillation, consistency sweeps |
