---
name: reflect
description: Spawn three parallel review subagents over the active transcript, surface learnings, and route each to a concrete edit on an existing skill. Use when the user says reflect.
disable-model-invocation: true
---

# Reflect

In OpenCode, transcripts live in the session store, not in a transcript directory. Read them through the local server.

Mine the current conversation for durable learnings, then route them into skill edits.

Invoke when the user says "reflect" or "/reflect". Skip when the conversation is trivial, off-topic, or already covered by an existing skill the parent followed correctly. One-offs are not learnings.

## 1. Locate the active transcript

Before you fan out, read this conversation's transcript from the OpenCode session store. Do not reach outside the current project: another project's sessions are private and unrelated.

```sh
opencode api get /api/session/<session-id>/message
```

The session id is in the session context. The response is JSON: one entry per message, each with a `content` array of text and tool parts. The first user message is the opening prompt. If the session id is not available, pass a tight digest of the session instead.

## 2. Spawn three reviewers in parallel

One message, three `subagent` calls, `agent: "general"`. Reviewers need MCP access to look up the tickets, chat threads, and observability traces the transcript references, so do not use the `explore` agent: it strips MCP access.

Each reviewer and the synthesizer takes a model from the panel in `~/.config/opencode/review-loop.json`, or its table default when there is no entry. Leave `model` unset to run it on the parent session's model. If the `subagent` tool rejects a model, use the default and say so. Pick each subagent's reasoning level and fast or standard speed for the job, per the Subagents section of the **poteto-mode** skill.

| Lens | Default `model` | Prompt template |
|---|---|---|
| Judgment | `opencode/deepseek-v4.1-flash-free` | `references/judgment-reviewer.md` |
| Tooling | `opencode/glm-5.3-flash-free` | `references/tooling-reviewer.md` |
| Divergent | `opencode/minimax-m3.1-flash-free` | `references/divergent-reviewer.md` |

Pass each template verbatim, substituting the transcript path or digest where marked. Reviewers return findings in the `subagent` response body.

## 3. Synthesize

One `subagent` call, `agent: "general"`, `model` from the panel or the Judgment default. It spot-verifies citations through MCP, so it needs agent mode, not explore mode. Pass `references/synthesizer.md` verbatim, with each reviewer's full output inlined where marked. It returns an Accepted / Rejected / Backlog list.

## 4. Structural enforcement check

Move any Accepted item that a lint rule, script, metadata flag, or runtime check would enforce more reliably to Backlog. The **skill-creator** skill covers the structural side of a skill edit.

## 5. Apply

Present the synthesizer's full Accepted / Rejected / Backlog output and wait for explicit approval before applying any Accepted edit. The user picks the subset and may redirect routings. Skill changes affect every future agent in the org. Do not auto-apply.

File each Backlog item to your team's devex or backlog tracker without waiting. Only the Accepted list waits for approval.

Follow each approved row's Routing exactly:

- Trivial existing-skill edit (a one-line bullet, a tightened sentence, a stale fact corrected): the parent does it directly.
- Substantive existing-skill edit (a new section, a new pattern table, more than ~10 lines): hand to the **skill-creator** skill and run its draft / test / iterate loop.
- `tune description: <skill path>` (the skill exists but didn't trigger when it should have): hand to **skill-creator** and run its description-optimization loop.
- `new skill via skill-creator: <kebab-name>`: hand creation to **skill-creator**. Do not invent the shape ad hoc.

If your environment ships a SKILL.md validator, run it on every touched skill before declaring done.

## 6. Summarize for the user

Short list, no preamble:

- Edits applied: `<skill path>`. What changed, one line each.
- New skills created: `<skill path>`. One line each (rare).
- Backlog filed to the devex tracker: `<issue title>` (`<tags>`). One line each.
- Dropped: one line per rejected finding + reason from the synthesizer.
