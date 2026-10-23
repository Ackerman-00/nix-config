# Agent Templates for OpenCode

An agent is a named assistant profile: a system prompt, a model preference, a permission set, and display details. Subagents run in a child session with fresh context.

## Where agents live

| Scope | Path |
|-------|------|
| Global | `~/.config/opencode/agents/<name>.md` |
| Project | `.opencode/agents/<name>.md` |

A nested path becomes part of the agent ID: `.opencode/agents/team/reviewer.md` → `team/reviewer`.

The same fields work in JSONC under `agents` in `opencode.json`.

## Frontmatter fields

| Field | Meaning |
|-------|---------|
| `description` | What the agent is for. Shown to the model choosing an agent, so write it for that reader. |
| `mode` | `primary` (main agent), `subagent` (child session only), `all`. Defaults to `primary` for a new custom agent. |
| `model` | `provider/model#variant`. A subagent inherits the parent's model when unset. |
| `permissions` | Ordered rules; last match wins. |
| `steps` | Maximum number of model steps. |
| `hidden` | Removes the agent from listings and the subagent catalog. Visibility, not security. |
| `color` | UI colour, six-digit hex. |
| `disabled` | Removes a built-in agent at that point in the config load. |

The Markdown body is the agent's system prompt. In JSONC, put it in `system` instead.

## Templates

### code-reviewer

```markdown
---
description: Reviews changes for correctness and regressions. Use after a diff is written.
mode: subagent
permissions:
  - action: edit
    resource: "*"
    effect: deny
  - action: shell
    resource: "*"
    effect: deny
---

Review the current changes. Report findings in severity order with file and line
references. Do not modify files. State explicitly when you find nothing.
```

### security-reviewer

```markdown
---
description: Audits code for injection, auth, secret handling, and unsafe defaults.
mode: subagent
permissions:
  - action: edit
    resource: "*"
    effect: deny
---

Audit the given files for security defects. For each finding give the file, the
line, the exploit path, and the smallest fix. Skip style issues.
```

### api-documenter

```markdown
---
description: Documents HTTP endpoints as OpenAPI. Use when an API needs a spec.
mode: subagent
---

Read the route handlers and produce an OpenAPI document. Match the existing
schema names. Note any endpoint you could not document and why.
```

### ui-reviewer

```markdown
---
description: Reviews UI code for accessibility and layout problems.
mode: subagent
permissions:
  - action: edit
    resource: "*"
    effect: deny
---

Check the given UI files for missing labels, keyboard traps, focus problems, and
contrast failures. Report each as file:line with the failing criterion.
```

### test-writer

```markdown
---
description: Writes tests that match the project's existing test style.
mode: subagent
---

Read the nearest existing test for the target module, then write a test in the
same style. Cover the happy path and one failure path. Run the new test file
and report the result.
```

### performance-analyzer

```markdown
---
description: Profiles slow paths and proposes concrete optimisations.
mode: subagent
permissions:
  - action: edit
    resource: "*"
    effect: deny
---

Measure before suggesting. Profile the slow path, report the numbers, then list
optimisations ranked by expected gain.
```

## Built-in agents

| Agent | Mode | Purpose |
|-------|------|---------|
| `build` | primary | Default coding agent. Tools allowed; sensitive env reads and out-of-workspace access ask. |
| `plan` | primary | Explores and plans without editing normal project files. |
| `general` | subagent | Research and multi-step work with broad tool access; cannot launch subagents. |
| `explore` | subagent | Searches and reads code or web sources without editing. |

Override a built-in by using the same ID in `agents`.

## Restricting which subagents may run

The parent's `subagent` permissions control what it may launch:

```jsonc
{
  "agents": {
    "orchestrator": {
      "permissions": [
        { "action": "subagent", "resource": "*", "effect": "deny" },
        { "action": "subagent", "resource": "reviewer", "effect": "allow" },
      ],
    },
  },
}
```

A child uses its own configured permissions, not a subset of the parent's.

## Default agent

```jsonc
{
  "default_agent": "writer",
  "agents": { "writer": { "mode": "primary" } },
}
```

The default must exist, be visible, and support primary use. Otherwise OpenCode falls back to `build`.
