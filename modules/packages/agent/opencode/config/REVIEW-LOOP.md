# Free-Model Review Loop

A writer model implements a task, a panel of independent reviewer models critiques it,
the writer applies the consolidated findings, and any provider error or rate limit
fails over to another free model automatically.

Five models run per round by default: one writer plus four reviewers.

## Files

| Path | What it is |
| --- | --- |
| `~/.local/bin/oc-review-loop` | The harness. Python 3, standard library only. |
| `~/.config/opencode/review-loop.json` | Panel, model pool, rounds, timeout. |
| `~/.config/opencode/agents/reviewer.md` | Read-only reviewer agent with skills attached. |
| `~/.config/opencode/agents/writer.md` | Writer agent with the superpowers skills attached. |
| `~/.config/opencode/commands/review-loop.md` | The `/review-loop` slash command. |
| `~/.config/opencode/plugins/review-panel.js` | Global plugin: runs the panel automatically on changed files. |
| `~/.config/opencode/opencode.json` | Carries the `superpowers` plugin entry. |

## Running it

From any project directory:

```sh
oc-review-loop "Add a truncate() helper and tests for it"
```

Useful flags:

| Flag | Effect |
| --- | --- |
| `--panel N` | Reviewer count. 4 by default, so 5 models run per round. |
| `--rounds N` | Maximum rounds. 2 by default. Stops early when the panel reports CLEAN or findings stop changing. |
| `--dir PATH` | Project directory. Defaults to the current one. |
| `--artifacts DIR` | Where to write transcripts. Defaults to outside the project. |
| `--writer-model ID` | Override the writer model. |
| `--timeout N` | Per-turn timeout in seconds. 900 by default. |
| `--stdin` | Read the task from stdin. |
| `--dry-run` | Print the plan, call no models. |
| `--list-models` | Print the panel and the failover pool. |
| `--no-auto` | Do not auto-approve permission prompts. |

Artifacts land in `~/.local/share/opencode/review-loop/<project>/<timestamp>/`: the writer's
output, each reviewer's transcript, the round consensus, and a `summary.md`. They are
deliberately written outside the project so they never show up in `git status` or in the
reviewers' changed-file list. Use `--artifacts DIR` to put them somewhere else.

The exit code is 0 on success and 1 when the writer failed or no reviewer produced
output, so it is safe to use in a script or a CI step.

## The slash command

In OpenCode or in an OpenChamber session, `/review-loop <task>` runs the same harness
through the `shell` tool and asks the agent to report which models ran, what the panel
found, what the writer changed, and where the artifacts are.

## Timing and convergence

Measured on a small Python project with the free tier, reviewers running in parallel:

| Run | Panel | Rounds | Wall time |
| --- | --- | --- | --- |
| A | 4 reviewers + writer | 2, both rounds used | 8m06s |
| B | 5 reviewers + writer | 2, stopped after round 2 | 2m30s |

The difference is the panel converging. Run B found one LOW finding in round 1, the
writer fixed it, and the panel came back 5/5 CLEAN, so the loop stopped early. Run A
kept finding new things, so it used both rounds.

The loop stops early in three cases: the whole panel says CLEAN, the findings are
identical to the previous round, or the round limit is reached. A round where every
reviewer says CLEAN is a real signal, not a failure.

Wall time is dominated by the slowest reviewer in a round, since the panel runs
concurrently. A model that hangs burns the turn's whole timeout before the harness
moves on, so `--timeout` is the knob for the worst case. One timeout covers the entire
turn including any failover, not each attempt separately.

The panel is deliberately slow rather than shallow. Each reviewer loads skills, reads
the code and sometimes spawns a helper, which is what turns the panel into a real
review instead of five shallow opinions.

## The automatic path

`~/.config/opencode/plugins/review-panel.js` is a global plugin. It needs no setup in
any project: OpenCode loads it for every location, in OpenCode and in OpenChamber
alike.

It hooks the agent loop. On each model call it checks the working copy, and when the
diff has changed since the last review it:

1. reads the diff with `ctx.vcs.diff`,
2. asks a panel of independent reviewer models to critique it,
3. merges their findings by severity and by how many reviewers agreed,
4. delivers the merged findings back into the session as a synthetic message.

The agent then sees the findings and can act on them. Change the code and the panel
runs again on the new diff. That is the whole A to B to A loop, with no human in it.

Verified end to end: a working copy with a silent division-by-zero and an unguarded
empty-list division was reviewed automatically, the agent fixed both, and the panel
reviewed the fix on the next round. In a separate run the agent applied a panel
finding that removed a `if x == 0: return 0` guard which changed a float result into
an int.

Turn it off with `"auto": { "enabled": false }` in `review-loop.json`, or narrow it
with `auto.models`, `auto.max_rounds`, `auto.cooldown_seconds` and
`auto.min_changed_lines`.

Every run is logged to `~/.local/share/opencode/review-panel.log`:

```
panel starting session=ses_... files=1 changed=9
panel session=ses_... models=opencode/minimax-m3.1-flash-free,opencode/deepseek-v4.1-flash-free files=1 changed=9 findings=delivered round=1/2
```

### What it will and will not review

The panel only reviews **what the current session changed**. The plugin captures the
diff as a baseline the first time it sees a session, and only runs the panel once the
diff differs from that baseline.

That matters: a tree that was already dirty when the session opened is your prior
work, not work done in this session. Without the baseline, asking "what does this file
do?" in a project with uncommitted changes would spend a panel on a question that
never asked for a review. With it, that question costs nothing, and the panel fires
only once the agent has actually edited something.

Set `"require_session_change": false` to review whatever is in the tree instead.

### Five constraints the implementation had to work around

All five were found by running it, not by reading the docs.

- **A system-prompt mutation made after an `await` never reaches the model.** The
  `context` hook snapshots the system prompt when it is entered, so pushing findings
  into `event.system` after awaiting the panel silently does nothing. The agent
  reported, verbatim, that it could not see a marker line that was demonstrably in
  the system prompt. A *synchronous* push arrives; an asynchronous one does not. The
  findings are therefore delivered as a synthetic message, which is the only
  asynchronous channel the model actually reads.
- **The free tier refuses a model call with no session.** `ctx.generate.text()` fails
  with a 403 `FreeTierError`, so each panel member gets a real server-minted session,
  is asked once, and is removed afterwards.
- **`ctx.session.wait()` can resolve before the prompt has been processed**, which
  reads back an empty transcript. The panel polls the transcript instead, with a hard
  timeout, so a stuck model cannot leak a session.
- **`ctx.vcs` resolves by plugin project, not by the session's directory.** Two
  directories under the same project share one repository view, so the panel was
  reviewing one project's diff and delivering it into another project's session. The
  plugin now runs `git` in the session's own directory, which is the only thing that
  is guaranteed to match.
- **A free model can be rate-limited at any moment.** Each slot walks the pool and
  takes the next free model, claiming it before it awaits so two slots cannot land on
  the same one. The panel has produced reviews from two different models in the same
  round.

## What runs in the background

Nothing that was installed here runs on its own. Measured, not assumed:

- **No cron, no systemd timer, no `at` job, no scheduled task.** The plugin contains
  no `setInterval` and no `setTimeout` outside the poll loop, and it has no scheduler.
- **The plugin does no work when idle.** It is a hook, and a hook only fires on a
  model call. With no session running it makes zero calls and costs nothing.
- **The plugin does no work on a session that did not change anything.** Every hook
  call checks the working copy first, and the baseline means it only fires for changes
  the session itself made.
- **The panel is bounded.** At most `auto.max_rounds` panel runs per session, at most
  `auto.models` model calls per run, and a `auto.cooldown_seconds` gap between runs.
  The session state map is capped at 200 entries and evicts the oldest.
- **The harness runs on demand and exits.** `oc-review-loop` is a one-shot process
  that ends when the loop ends. It is not a daemon.

The always-on processes on the machine are OpenCode's shared service and the
OpenChamber app, both of which predate this work. The plugin runs inside the
OpenCode service and adds no process of its own.

If you want zero automatic behaviour, set `"auto": { "enabled": false }` in
`review-loop.json`. The `/review-loop` command and the `oc-review-loop` harness keep
working; only the automatic trigger stops.

## The reviewer panel

Each reviewer gets its own session, its own model, and the read-only `reviewer` agent.
They run concurrently and never see each other's output, so the consensus is real
agreement rather than anchoring.

Findings are merged on `file:line`, ranked by severity and then by how many reviewers
agreed, so the writer sees `3/4` next to a finding four times and `1/4` next to one
reviewer raised alone. A finding without a line number is merged on `file` plus its
normalised summary, and a line range such as `file.py:17-19` is merged on its start
line.

## Failover

The free tier rate-limits **per model**, not per account, so switching models is
genuinely effective. A model that errors is recorded, put in a 90 second cooldown, and
replaced by the least-failed model nobody else is using. A member keeps its session
when it swaps, so it keeps its context.

Errors seen in the wild, all handled by the same path:

| Error | Meaning |
| --- | --- |
| `provider.quota` | Free tier rate limit for that model. |
| `provider.no-route` | Model unavailable right now. |
| `provider.auth` | Free tier refused the request. |
| `timeout` | Turn exceeded the timeout. |

## The reviewer agent

`reviewer.md` is read-only: `edit`, `write` and `patch` are denied outright, and shell
is limited to an allowlist of inspection commands (`git diff/log/show/blame/status/grep`,
`rg`, `cat`, `ls`, `wc`). `.env` files are denied on both `read` and `shell`. Only the
`general` and `explore` subagents may be spawned, at most two per review.

Without that shell restriction a reviewer denied the write tool simply falls back to
`echo > file`, so the restriction is on the command, not just the tool.

### Skills attached to the reviewer

`using-superpowers` is loaded on every review. The rest load on demand:
`requesting-code-review`, `code-review`, `deslop`, `security-best-practices`,
`test-driven-development`, `systematic-debugging`, `verification-before-completion`,
`codebase-design`, `define-goal`, `brainstorming`, `dispatching-parallel-agents`, plus
`how`, `why` and `research` for the heavier cases.

The reviewer's own output format is fixed and overrides whatever format a loaded skill
asks for: one block per finding, first line `- [SEVERITY] path:line — summary`, and a
single closing `VERDICT: ISSUES` or `VERDICT: CLEAN` line. The harness parses exactly
that, so the format is part of the contract.

The parser is deliberately tolerant, because models do not always obey a format
perfectly. It accepts:

- a path with or without a line number, relative or absolute
- a line range, `file.py:17-19`, merged on the start line
- a path wrapped in backticks
- a severity-less bullet, `file.py:12 — summary`, but only when that reviewer
  reported ISSUES. In a CLEAN review the same bullet shape is usually praise, and
  turning praise into findings would be worse than losing one.

When a reviewer reports ISSUES but no finding can be parsed, the loop says so in its
output and in `summary.md`, rather than silently treating the round as clean. That
usually means the reviewer drifted from the format, and the finding is in its
transcript.

### Skills attached to the writer

`using-superpowers`, `brainstorming`, `define-goal`, `writing-plans`,
`test-driven-development`, `systematic-debugging`, `verification-before-completion`,
`receiving-code-review`, `deslop`.

`receiving-code-review` matters: the writer is told to check each finding against the
code and skip the ones that are wrong, rather than applying feedback blindly.

## Superpowers

Installed as a plugin, pinned to a tag so the config is reproducible:

```jsonc
{
  "plugins": ["superpowers@git+https://github.com/obra/superpowers.git#v7.0.0"]
}
```

It adds `brainstorming`, `writing-plans`, `test-driven-development`,
`systematic-debugging`, `verification-before-completion`, `requesting-code-review`,
`receiving-code-review`, `dispatching-parallel-agents`, `subagent-driven-development`,
`executing-plans`, `using-git-worktrees`, `finishing-a-development-branch`,
`brainstorming`, `writing-skills`, `using-superpowers` and `diagnosing-superpowers`.

The shared OpenCode service hot-reloads the plugin, so no restart is needed.

### The `how` and `why` skills

These two were written for Claude Code and referenced models that do not exist in this
install (`grok-4.7-xhigh-fast`, `claude-opus-5-5-xhigh`), plus tools that do not exist
here (`task`, `subagent_type: generalPurpose`, `readonly`). They were rewritten to use
OpenCode's `subagent` tool with `agent: "explore"` or `agent: "general"`, and to leave
`model` unset so a subagent inherits the parent session's model. Their
`disable-model-invocation: true` was removed so they are advertised and can trigger on
their own.

Other skills from the same family (`poteto-mode`, `interrogate`, `reflect`, `architect`,
`teach`, `in-your-own-words`, `chief-of-staff`, `automate-me`, `advisor`, `unslop`,
`maintain-verification-skill`) still carry the Claude Code tool names and the same
unavailable model slugs. They are left hidden and unattached. The same rewrite would
make them work.

## OpenChamber

OpenChamber sessions are OpenCode sessions, so everything above applies: the global
agents, the global command, the skill registry and the superpowers bootstrap are all
present in an OpenChamber session.

To pin a model per session, use the `openchamber` tool:

```jsonc
{ "action": "session.create", "model": "opencode/glm-5.3-flash-free", "prompt": "..." }
```

A session created this way is pinned to that model, and a rate-limited model fails the
session outright. For work that must not fail on a single model, run the harness
instead: it fails over internally.

## The rest of the skill pack

The local skill set came from a Cursor and Claude Code pack. Most of it ran on tool
names and model slugs that do not exist in OpenCode, so the whole pack was ported:

| Was | Now |
| --- | --- |
| `task` tool, `subagent_type: generalPurpose` | `subagent` tool, `agent: "general"` |
| `readonly: true` for a read-only reviewer | `agent: "explore"`, which is read-only here |
| `run_in_background: true` | `background: true` |
| `resume: <agent id>` | `sessionID: <session id>` |
| `AskQuestion` | the `question` tool |
| a todolist | a markdown plan file, since V2 has no todo tool |
| `~/.cursor/skills/`, `.cursor/skills/` | `~/.config/opencode/skills/`, `.opencode/skills/` |
| `agent-transcripts/` | the session store, via `opencode api get /api/session/<id>/message` |
| `grok-4.7-xhigh-fast`, `claude-opus-5-5-xhigh` | the free panel in `review-loop.json` |
| `pstack-models.mdc` role lines | the same panel |
| `WebFetch` | `webfetch` |
| `cursor-team-kit` `control-ui` / `control-cli` | the `playwright` skill, or `shell` for CLIs |
| `create-skill` | the `skill-creator` skill |
| `arena`, `swarm` | `interrogate`, `dispatching-parallel-agents` |
| the `principle-*` skill family | the one-line definitions already in poteto-mode, with the installed leaf used when there is one |

The principle leaves are not installed here, so poteto-mode now treats its own
one-line definition as the principle when the leaf is missing. That is what makes
`architect` and `poteto-mode` usable at all: roughly twenty of their dependencies
were principle skills that simply are not on this machine.

Two agents were added so the ported skills have somewhere to spawn:

- `advisor-subagent` — read-only second opinion, emits `VERDICT: proceed`,
  `proceed with changes` or `stop`. The `advisor` skill writes its state to
  `.opencode/advisor/state.json` and resumes the advisor by `sessionID`.
- `poteto-agent` — the focused implementer that poteto-mode's playbooks delegate to.

Both were tested by spawning them for real. The advisor returned a correct verdict
on a change it could read for itself, and the poteto agent implemented a function,
verified it with the real test command, and left code the brief marked out of scope
byte-for-byte untouched.

`how` and `why` are the two skills left visible to the model rather than
explicit-invocation-only, because the reviewer is meant to reach for them on its own.
The rest keep their original `disable-model-invocation: true`: a skill like
`poteto-mode` changes how every agent behaves, and that should be a deliberate
request, not something that fires on its own.

## Where the skills came from

The review skills are the reference-grade ones, not improvised:

| Skill | Source | Stars |
| --- | --- | --- |
| superpowers (16 skills) | `obra/superpowers` | 302k |
| `skill-creator` | `anthropics/skills` | 182k |
| `mcp-builder` | `anthropics/skills` | 182k |
| `test-gap-audit` | `github/awesome-copilot` | 40k |
| `security-review` | `github/awesome-copilot` | 40k |
| `bug-receipt` | `github/awesome-copilot` | 40k |
| `api-breaking-change-detector` | `github/awesome-copilot` | 40k |

Your local `skill-creator` was already byte-identical to Anthropic's official copy, so
nothing was replaced there. The Agent Skills specification is kept as
`skill-creator/references/agent-skills-spec.md`.

All four new skills were checked for host assumptions before installing: no
`allowed-tools`, no `task` tool, no `subagent_type`, no `WebFetch`. Their scripts are
standard-library-only Python and plain Node ESM.

Each one gained a **Weak models** section, because the upstream versions assume a
model that can hold a long structured report in its head. A flash model gets the short
version instead: a bounded number of findings, one line each, a fixed shape, and an
explicit "never invent a path or a line number". `bug-receipt` also had its mandatory
receipt format made conditional, because "return the receipt even if the user asked
for something concise" fights this house style.

`bug-receipt`'s validator was ported from Node to Python
(`scripts/validate_receipt.py`), because there is no `node` or `bun` on this machine.
The upstream `.mjs` is kept for hosts that have Node.

## Runtimes on this machine

The review loop itself needs no JS runtime: the harness is Python, and the plugin is
JavaScript executed by OpenCode's own bundled runtime, not by a system `node`.

The wider skill pack does need one, and it is now installed:

| Tool | Version | From | Why |
| --- | --- | --- | --- |
| node | 24.21.0 | `apt` (`nodejs`) | runs the `.mjs` scripts |
| npm / npx | 12.2.0 | `apt` (`npm`) | `npx` for the playwright CLI and `rea-agents` |
| bun | 1.4.3 | `bun.sh` installer, user-level `~/.bun` | the `bun:test` imports and `bun scripts/...` calls |
| chromium | 1247 | `playwright install-browser chromium` | the playwright CLI's browser |

Two details that are easy to get wrong:

- **Bun lives in `~/.bun/bin`, and `.zshrc` is not enough.** OpenCode's shell tool
  spawns `zsh -c`, which is non-interactive and reads `~/.zshenv`, not `~/.zshrc`. The
  bun path therefore lives in `~/.zshenv` (plus `~/.bashrc` and `~/.profile`), so
  agents can actually reach `bun`.
- **The playwright CLI defaults to the `chrome` channel**, Google Chrome at
  `/opt/google/chrome/chrome`, which is not installed here. The wrapper now passes
  `--browser chromium` by default, so the skill's own examples work unchanged. Set
  `PLAYWRIGHT_CLI_BROWSER=chrome` to switch back.

The installed bun binary was verified against the release's published
`SHASUMS256.txt`: the download matches the official sum and the extracted payload
matches the installed binary byte for byte.

Poteto-mode's own test suite runs with it:

```
$ cd ~/.config/opencode/skills/poteto-mode/scripts && bun test orch watch-pr check-plan.test.ts
 68 pass
 0 fail
```

## Free tier behaviour worth knowing

- **The server must mint the session id.** `opencode run --session <new-id>` is refused
  with `provider.auth` and a 403 `FreeTierError`. Continuing an existing session with
  `--session <id>` is fine. The harness therefore creates each session by running a
  first turn without `--session` and reading the id back from the event stream.
- **Exit code is always 0**, even when the provider errored. The harness detects
  failures by parsing the JSONL event stream for `type: "error"`, never from `$?`.
- **Rate limits are per model.** One model being limited says nothing about the others.

## Troubleshooting

| Symptom | Cause | Fix |
| --- | --- | --- |
| `provider.auth` / `FreeTierError` | Session id was supplied by the client | Let the server mint it |
| `provider.quota` on every model | Free tier exhausted for now | Wait; the cooldown is 90s |
| Panel reports CLEAN immediately | Reviewers found nothing | Expected, not a bug |
| A reviewer timed out | Model too slow for the task | Raise `--timeout` or drop that model from the panel |
| Reviewer mutated the tree | Should not happen | `reviewer.md` denies `edit` and restricts `shell`; check the file was not edited |
