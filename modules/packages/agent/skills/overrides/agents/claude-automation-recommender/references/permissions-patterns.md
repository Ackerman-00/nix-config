# Permission Patterns for OpenCode

OpenCode v2 configures permissions with a `permissions` array of rules:

```jsonc
{
  "$schema": "https://opencode.ai/config.json",
  "permissions": [
    { "action": "shell", "resource": "*", "effect": "ask" },
    { "action": "shell", "resource": "git status *", "effect": "allow" },
    { "action": "shell", "resource": "git push *", "effect": "deny" },
  ],
}
```

Rules run in order and the **last match wins**, so put the broad rule first and the exceptions after it. If no rule matches, the effect is `ask`.

## Actions

| Action | Resource |
|--------|----------|
| `read` | file path |
| `edit` | target path for `edit`, `write`, `patch` |
| `glob` | glob pattern |
| `grep` | search pattern |
| `shell` | command string |
| `subagent` | agent ID |
| `skill` | skill ID |
| `question` | `*` |
| `webfetch` | URL |
| `websearch` | query |
| `external_directory` | external directory boundary |
| `execute` | `*` (Code Mode) |
| `<server>_<tool>` | `*` for an MCP tool |

## Matching

- `*` matches zero or more characters, including `/`.
- `?` matches exactly one character.
- Everything else is literal.
- A shell pattern ending in ` *` also matches the bare command: `git status *` matches `git status` and `git status --short`.
- `~` and `$HOME` expand for `read`, `edit`, and `external_directory` resources. Shell resources stay raw command text.

## Per-agent rules

Agent rules are appended after global rules, so a narrower agent rule wins:

```jsonc
{
  "permissions": [
    { "action": "shell", "resource": "*", "effect": "ask" },
    { "action": "shell", "resource": "git status *", "effect": "allow" },
  ],
  "agents": {
    "reviewer": {
      "description": "Reviews changes without editing files",
      "mode": "subagent",
      "permissions": [
        { "action": "edit", "resource": "*", "effect": "deny" },
        { "action": "shell", "resource": "git push *", "effect": "deny" },
      ],
    },
  },
}
```

A subagent uses its own permissions, not a subset of its parent's.

## Common recipes

Ask before any shell command, allow inspection:

```jsonc
[
  { "action": "shell", "resource": "*", "effect": "ask" },
  { "action": "shell", "resource": "git status *", "effect": "allow" },
  { "action": "shell", "resource": "git diff *", "effect": "allow" },
  { "action": "shell", "resource": "git log *", "effect": "allow" },
]
```

Never allow publishing or history rewrites:

```jsonc
[
  { "action": "shell", "resource": "git push *", "effect": "deny" },
  { "action": "shell", "resource": "git reset --hard *", "effect": "deny" },
  { "action": "shell", "resource": "git clean *", "effect": "deny" },
  { "action": "shell", "resource": "git branch -D *", "effect": "deny" },
]
```

Protect secrets and lock files:

```jsonc
[
  { "action": "read", "resource": "*.env", "effect": "deny" },
  { "action": "read", "resource": "*.env.*", "effect": "deny" },
  { "action": "read", "resource": "*.env.example", "effect": "allow" },
  { "action": "edit", "resource": "*.lock", "effect": "deny" },
]
```

Allow only one skill, hide the rest:

```jsonc
[
  { "action": "skill", "resource": "*", "effect": "deny" },
  { "action": "skill", "resource": "security-review", "effect": "allow" },
]
```

Restrict which subagents can be launched:

```jsonc
[
  { "action": "subagent", "resource": "*", "effect": "deny" },
  { "action": "subagent", "resource": "explore", "effect": "allow" },
]
```

Ask before touching anything outside the project:

```jsonc
[
  { "action": "external_directory", "resource": "*", "effect": "ask" },
  { "action": "external_directory", "resource": "~/reference/*", "effect": "allow" },
]
```

## Defaults to know

The shipped base policy allows almost everything, asks for `*.env` reads, and lets `external_directory` through unless a rule says otherwise. `opencode --auto` approves anything that resolves to `ask`; it never overrides an explicit `deny`.

Saved approvals from the TUI ("allow always") become durable project-scoped allow rules. They never override a configured `deny`.

## V1 vs V2

V1 used a `permission` object keyed by tool name (`bash`, `task`). V2 uses the `permissions` array with the actions above (`shell`, `subagent`). Do not mix the two in one config file.
