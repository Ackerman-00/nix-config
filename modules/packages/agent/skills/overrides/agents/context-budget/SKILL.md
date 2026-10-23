---
name: context-budget
description: Answer OpenCode context-usage questions and audit installed context overhead. Use for requests about remaining capacity, current token usage, context breakdown, or how much the installed skills, plugins, MCP servers, and instruction files cost. Live context is not exposed to the model, so it reports the session record instead and only scans files when an audit is explicitly requested.
metadata:
  origin: ECC
---

# Context Budget

OpenCode does not expose a live context meter to the model. There is no `/context`-style command a skill can read, and a skill cannot inspect the provider's live window. This skill reports what is locally verifiable and refuses to invent a live number.

## Default: Live Context

Treat an invocation with no audit request as a live-context request: the current window, remaining capacity, headroom, token usage, or a context breakdown.

For this path:

- Do not scan files.
- Do not run shell commands, MCP calls, or debug logging.
- Say plainly that OpenCode does not expose live context usage to the model, then point at the two local signals below.

Local signals the user can read themselves:

| Signal | Where |
|--------|-------|
| Cumulative session tokens | `~/.local/share/opencode/opencode.db`, table `session_v2` (`tokens_input`, `tokens_output`, `tokens_reasoning`, `tokens_cache_read`, `tokens_cache_write`) |
| Compaction events | same database, table `session_message`, rows with `type = 'compaction'` |

Both are session totals, not live window occupancy. Never present them as remaining capacity.

If the user asks for a number you cannot produce, say so and give them the query to run themselves rather than estimating.

## Explicit Static Audit

Run an installation audit only when the user explicitly says `--audit`, "audit installed components", or equivalent unambiguous wording. `--verbose` changes report detail; it does not opt into an audit by itself.

If the audit scope is ambiguous, ask for the scope and the install root before reading anything. Keep every audit bounded and read-only:

1. Inspect only the named install root and the named configuration files.
2. Never recursively enumerate the workspace root, home directory, caches, transcripts, debug logs, or unrelated worktrees.
3. Never launch an MCP server, plugin, or debug session to count tools.
4. Cap inventory output at 50 entries per component class. Summarize the rest.
5. Do not write temporary logs or copy configuration content into the report.

Audit only the metadata that is loaded eagerly:

- skill IDs, names, and descriptions;
- agent IDs and descriptions;
- MCP tool schemas, when an existing bounded manifest exposes them;
- always-loaded instruction files in the explicitly named scope;
- the plugin count and their registered IDs.

Full skill, agent, and plugin bodies are on-demand content. Report their disk size separately from the estimated eager overhead instead of adding every body to the session baseline.

## What to inspect

| Component | Where | Eager cost |
|-----------|-------|-----------|
| Skills | `~/.config/opencode/skills`, `~/.agents/skills`, `.opencode/skills` | ID, name, description per skill |
| Agents | `~/.config/opencode/agents`, `.opencode/agents`, `agents` in config | ID and description per agent |
| Plugins | `~/.config/opencode/plugins`, `.opencode/plugins` | one line per registered plugin |
| MCP servers | `mcp` in config | tool schemas per server |
| Instructions | `~/.config/opencode/AGENTS.md`, project `AGENTS.md`, `instructions` entries | file size, read fully |
| Commands | `commands` in config | template length |

A skill with `metadata.opencode/autoinvoke: false` or `disable-model-invocation: true` is not advertised to the model. Count it as a hidden component, not as eager overhead.

## Audit Output

Return a compact report containing:

- scope and the exact paths inspected;
- estimated eager overhead by component class;
- installed counts and the heaviest metadata entries;
- assumptions, unavailable measurements, and up to three optimizations.

Every calculated token number is an estimate of static configuration overhead, not live session context. Do not claim that an estimate is provider-reported, current, exact, or evidence of realised savings.

## Optional Selected-Record Diagnostic

Inspect a persisted record only when the user explicitly selects that file for this diagnostic. This is separate from the live-context request and the installation audit.

For an OpenCode session record, use the SQLite database read-only and report aggregates only:

```sh
node -e '
const { DatabaseSync } = require("node:sqlite")
const db = new DatabaseSync(process.env.HOME + "/.local/share/opencode/opencode.db", { readOnly: true })
const row = db.prepare("select tokens_input, tokens_output, tokens_reasoning, tokens_cache_read, tokens_cache_write from session_v2 where id = ?").get(process.argv[1])
console.log(JSON.stringify(row))
' ses_xxxxxxxx
```

Requires Node with `node:sqlite` (Node 22.5+). The database is large; query it rather than copying it. Never open it read-write while OpenCode is running.
