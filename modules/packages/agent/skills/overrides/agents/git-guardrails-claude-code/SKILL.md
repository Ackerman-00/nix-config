---
name: git-guardrails-claude-code
description: Block destructive git commands (push, reset --hard, clean, branch -D, checkout .) in OpenCode before they run. Use when the user wants to prevent destructive git operations, add git safety guardrails, or stop an agent from pushing, rewriting history, or deleting work.
---

# Git Guardrails for OpenCode

Two layers, both supported:

1. **Static rules** in `permissions` in `opencode.json` — the default, no code required.
2. **A plugin** that evaluates every shell permission dynamically — needed when a command hides the dangerous part inside a compound command or an unusual flag combination.

OpenCode has no hook configuration file. A hook is code in a plugin, registered with `ctx.permission.hook("evaluate", cb)`.

## What gets blocked

- `git push` (all variants, including `--force` and `--force-with-lease`)
- `git reset --hard`
- `git clean -f`, `git clean -fd`
- `git branch -D`
- `git checkout .`, `git restore .`

## Step 1: static rules (recommended first)

Ask the user: this project only (`opencode.json` in the project root) or every project (`~/.config/opencode/opencode.json`)?

```jsonc
{
  "$schema": "https://opencode.ai/config.json",
  "permissions": [
    { "action": "shell", "resource": "git push *", "effect": "deny" },
    { "action": "shell", "resource": "git reset --hard *", "effect": "deny" },
    { "action": "shell", "resource": "git clean *", "effect": "deny" },
    { "action": "shell", "resource": "git branch -D *", "effect": "deny" },
    { "action": "shell", "resource": "git checkout .", "effect": "deny" },
    { "action": "shell", "resource": "git restore .", "effect": "deny" },
  ],
}
```

Rules run in order and the last match wins. A pattern ending in ` *` also matches the bare command, so `git push *` covers `git push` and `git push origin main`. A configured `deny` is final: the user cannot approve it away, and saved approvals never override it.

Merge these rules into an existing `permissions` array rather than replacing it.

## Step 2: plugin guardrail (for compound commands)

Static patterns match the command text the scanner produced. A compound command such as `cd repo && git push --force` is handled by the plugin, which inspects every shell resource of the request.

Bundled files:

- `scripts/block-dangerous-git.js` — the OpenCode plugin
- `scripts/blocked-git-patterns.txt` — one regular expression per line, the single source of truth for what is blocked
- `scripts/block-dangerous-git.sh` — a standalone checker that uses the same pattern file, for pre-commit hooks and manual testing

Copy the plugin to the target location:

- **Project**: `.opencode/plugins/block-dangerous-git.js`
- **Global**: `~/.config/opencode/plugins/block-dangerous-git.js`

The plugin reads the pattern file next to itself, so copy both files into the same directory:

```bash
mkdir -p .opencode/plugins
cp scripts/block-dangerous-git.js scripts/blocked-git-patterns.txt .opencode/plugins/
```

The plugin then does this:

```js
await ctx.permission.hook("evaluate", async (event) => {
  if (event.action !== "shell") return
  const blocked = findBlockedCommand(event.resources)
  if (!blocked) return
  event.effect = "deny"
  event.message = `Blocked by git guardrails: ${blocked.pattern}`
})
```

Permission hooks run for `allow` and `ask` decisions. A `deny` already set in `permissions` never reaches the hook, so the two layers do not conflict.

## Step 3: customise the pattern list

Edit `scripts/blocked-git-patterns.txt`, one extended regular expression per line:

```
git\s+push
git\s+reset\s+--hard
git\s+clean\s+-[a-z]*f
git\s+branch\s+-D
git\s+checkout\s+\.
git\s+restore\s+\.
```

Blank lines and lines starting with `#` are ignored. The plugin and the shell checker both read this file, so the list stays in one place.

## Step 4: verify

Test the standalone checker first — it exits 2 and prints a message when a command is blocked:

```bash
bash scripts/block-dangerous-git.sh "git push origin main"; echo "exit=$?"
bash scripts/block-dangerous-git.sh "git status"; echo "exit=$?"
```

Expect `exit=2` for the first and `exit=0` for the second.

Then verify the plugin end to end: start OpenCode in the project, ask the agent to run `git push`, and confirm the command is refused with the guardrail message. Check `opencode --print-logs` if the plugin does not appear to load.

## Notes

- `opencode --auto` approves anything that resolves to `ask`, but it never overrides an explicit `deny`. Guardrails survive auto mode.
- If the user wants to push deliberately, they run the command themselves in a terminal, or remove the rule.
- Keep the deny list narrow. Blocking `git clean *` also blocks `git clean -n`, which is a dry run; add the exception explicitly if that annoys them.
