# Workspace Files Reference

Each surface of the OpenCode v2 workspace, what it does, and how to keep it
correct. Paths are the defaults; confirm with `opencode debug paths`.

## AGENTS.md (global)

`~/.config/opencode/AGENTS.md`

Injected into the system prompt of every agent in every session. This is the
only file that behaves like OpenClaw's `AGENTS.md`, and it replaces the whole
family of persona files OpenClaw used (`SOUL.md`, `TOOLS.md`, `USER.md`,
`IDENTITY.md`, `MEMORY.md`, `HEARTBEAT.md`, `BOOT.md`).

Design principles:

- Every line is paid for on every request.
- One rule per line, imperative, verifiable.
- Machine facts (paths, hosts, package manager, hardware limits) belong here.
- No secrets. The file is injected into every request.
- No narrative, no session logs, no task state.

Anti-patterns:

- Restating what a skill already says.
- Two files saying the same rule with different wording.
- A rule that can never be checked ("write good code").
- History ("last time we tried X and it failed because...") — that belongs in
  the vault and is reachable with `memory_search`.

## AGENTS.md (project)

`AGENTS.md` in the project root of the session directory.

Overrides the global file. OpenCode walks up from the working directory to
the git worktree root when collecting project-scoped files, so a nested
`AGENTS.md` also applies to that subtree.

Project rules should be things a contributor could not guess: how to build,
how to test, what is generated, what must not be edited.

## opencode.json

`~/.config/opencode/opencode.json` (or `.jsonc`) and project
`opencode.json` / `.opencode/opencode.json`.

Keys worth knowing: `model`, `default_agent`, `permissions`, `agents`,
`commands`, `plugins`, `providers`, `mcp`, `skills`, `instructions`,
`formatter`, `lsp`, `disabled_providers`, `worktree`.

- `permissions`: ordered array of `{ action, resource, effect }` rules.
  `effect` is `allow`, `deny`, or `ask`. The last matching rule wins, so put
  wildcards first and specific rules after.
- `agents`: map of agent id to agent config. Per-agent `permissions` use the
  same rule shape.
- `mcp`: named server entries, `{"type": "local", "command": [...]}` or
  `{"type": "remote", "url": ..., "headers": {...}}`.
- `skills` / `instructions`: extra paths or URLs to discover skills and
  ambient instructions from.

Inspect the merged result with `opencode debug config`. It shows every
config source and the resolved value, which is the fastest way to find a
rule that is not taking effect.

## agents/*.md

`~/.config/opencode/agents/<id>.md`, project `.opencode/agents/<id>.md`.

The file name is the agent id. Frontmatter keys: `description` (required),
`mode` (`primary` | `subagent` | `all`), `model`, `variant`, `temperature`,
`top_p`, `steps`, `prompt`, `permission`, `tools` (deprecated), `disable`,
`hidden`, `color`, `options`.

`description` is the routing signal. Write it as "when to use me", not "who
I am": "Reviews code for best practices and potential issues" beats a
persona paragraph.

## commands/*.md

`~/.config/opencode/commands/<name>.md`, project `.opencode/commands/`.

Slash commands the user can invoke. A command file is markdown with an
optional frontmatter block for `description`, `agent`, `model`, and
`permission`.

Plugins can add commands at runtime with `ctx.command.transform`.

## plugins/*.js

`~/.config/opencode/plugins/*.js`, project `.opencode/plugins/`.

Auto-loaded at startup. Shape:

```js
export default {
  id: "my-plugin",
  setup: async (ctx) => {
    // ctx: app, location, storage, model, agent, session, command, tool,
    // permission, event, mcp, skill, provider, vcs, worktree, reference,
    // generate, websearch, config, instructions
    return () => {
      // optional cleanup
    }
  },
}
```

Hooks worth using:

| Hook | Surface | Notes |
|---|---|---|
| `ctx.session.hook("prompt", cb)` | `event.prompt.text`, `.files`, `.agents`, `.skills` | fires before the model sees the prompt |
| `ctx.session.hook("context", cb)` | `event.system.push({ type: "text", text })` | must mutate synchronously |
| `ctx.session.hook("compaction", cb)` | compaction | inject state that must survive a compaction |
| `ctx.permission.hook("evaluate", cb)` | `event.effect`, `.message`, `.action`, `.resources` | approve/deny tool calls |
| `ctx.shell.hook("create.before", cb)` | `event.command`, `.cwd`, `.timeout`, `.env` | rewrite shell invocations |
| `ctx.tool.hook("execute.before"/"execute.after", cb)` | `event.tool`, `.input`, `.result`, `.status` | wrap tool calls |

Plugins are plain ESM and can `fetch` over HTTP. `ctx.websearch.query({ query,
providerID })` returns `{ url, title, content, time }` results, and
`ctx.generate.text({ model, prompt })` runs a model call from inside a plugin.

Audit what is installed:

```bash
opencode plugin list
```

## skills/<name>/SKILL.md

Discovery paths:

```
~/.config/opencode/skills/    ~/.agents/skills/    ~/.claude/skills/
.opencode/skills/             .agents/skills/      .claude/skills/
```

Frontmatter: `name` (required), `description` (required), `license`,
`compatibility`, `metadata`.

- The id is the directory name. `name` must match it.
- `description` is what the model sees when choosing a skill. State what the
  skill does and when to use it, in one or two sentences.
- `metadata.opencode/autoinvoke: "false"` hides it from the model's
  auto-selection list; it stays loadable by exact name.
- `metadata.opencode/slash: "true"` exposes it as `/<name>`.

## NeuraKeep vault

`~/.local/share/neurakeep/vault`

Captured transcripts and extracted durable memory for every OpenCode session.
Exposed through the `neurakeep-global` MCP server:

- `memory_search({ query, limit, neighbors, space, project, include_secret })`
- `memory_read({ id })`
- `memory_explain_sources({ source_ids })` — file, line, hash, timestamp,
  snippet for each citation
- `memory_propose_update({ source_id })` — file a cited proposal
- `memory_apply_update({ proposal_id })` — force a proposal through; the
  extraction pipeline already applies proposals on its own, so do not call it

Capture plugin: `~/.config/opencode/plugins/neurakeep-memory.js`. Its config
is `~/.config/opencode/neurakeep-memory.json`. Log:
`~/.local/share/neurakeep/plugin.log`.

The vault is the right place for anything that is true but not always needed:
session history, past decisions, environment discoveries, recurring failures.
It is the wrong place for rules that must be obeyed every turn; those go in
`AGENTS.md`.

## Session database

`~/.local/share/opencode/opencode.db` (SQLite)

Tables: `session_v2`, `session_message`, `session_inbox`, `project`,
`project_directory`, `permission`, `kv`.

`session_message.type` values: `user`, `assistant`, `system`, `synthetic`,
`compaction`, `idle`, `shell`.

Read it read-only when a session-level question needs data the UI does not
surface:

```bash
sqlite3 ~/.local/share/opencode/opencode.db "select id, title, time_created from session_v2 order by time_created desc limit 10;"
```

Never write to it directly; OpenCode owns the schema and a concurrent write
can corrupt the session store.
