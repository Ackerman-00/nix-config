---
name: writing-hookify-rules
description: >-
  Write OpenCode plugin hooks that fire on runtime events: format after edits, lint after edits, block sensitive commands, inject context, or notify on session state. Use when the user wants automatic behaviour triggered by events rather than a static prompt or config rule.
---

# Writing Hook Rules

OpenCode has no separate rules file and no built-in hook events. A "rule that fires automatically" is a plugin that registers a hook.

## Pick the mechanism first

| You want | Use |
|----------|-----|
| Allow, ask, or deny a tool by path, command, or skill ID | `permissions` in `opencode.json` — no plugin needed |
| Fire only when the decision depends on runtime state | `ctx.permission.hook("evaluate", cb)` |
| React after a tool ran | `ctx.tool.hook("execute.after", cb)` |
| Inspect or rewrite tool input before it runs | `ctx.tool.hook("execute.before", cb)` |
| Change a shell command, cwd, timeout, or env | `ctx.shell.hook("create.before", cb)` |
| Add text to the system prompt for one model call | `ctx.session.hook("context", cb)` |
| Rewrite an incoming user prompt | `ctx.session.hook("prompt", cb)` |
| React to session lifecycle | `ctx.event.subscribe({ signal })` |

Static rules belong in `permissions`. Reach for a plugin only when the decision needs state that config cannot express.

## Skeleton

```js
// .opencode/plugins/format.js
export default {
  id: "format",
  async setup(ctx) {
    const registration = await ctx.tool.hook("execute.after", async (event) => {
      if (event.status !== "completed") return
      if (event.tool !== "edit" && event.tool !== "write") return
      const file = event.input?.filePath
      if (!file?.endsWith(".ts")) return
      // run the project formatter
    })
    return () => registration.dispose()
  },
}
```

## Event fields

| Hook | Fields |
|------|--------|
| `ctx.tool.hook("execute.before")` | `event.tool`, `event.input` |
| `ctx.tool.hook("execute.after")` | `event.tool`, `event.input`, `event.result`, `event.status` (`"completed"` or `"error"`), `event.error` |
| `ctx.shell.hook("create.before")` | `event.command`, `event.cwd`, `event.timeout`, `event.shell`, `event.env` |
| `ctx.permission.hook("evaluate")` | `event.sessionID`, `event.agent`, `event.action`, `event.resources`, `event.effect`, `event.message` |
| `ctx.session.hook("prompt")` | `event.prompt.text`, `event.prompt.files`, `event.prompt.agents`, `event.prompt.skills`, `event.metadata`, `event.delivery` |
| `ctx.session.hook("context")` | `event.system`, `event.tools`, `event.options` |

## Rule patterns

### Format after an edit

```js
await ctx.tool.hook("execute.after", async (event) => {
  if (event.tool !== "edit" && event.tool !== "write") return
  const file = event.input?.filePath ?? ""
  if (!/\.(ts|tsx|js|jsx)$/.test(file)) return
  await runFormatter(file)
})
```

### Type-check after an edit

Scope it to the files that matter. A full project type check on every keystroke-sized edit will dominate the session.

### Block a sensitive command

```js
await ctx.permission.hook("evaluate", async (event) => {
  if (event.action !== "shell") return
  if (event.resources.some((r) => r.includes("rm -rf /"))) {
    event.effect = "deny"
    event.message = "That command is blocked by policy."
  }
})
```

Hooks run for `allow` and `ask` decisions. A `deny` already configured in `permissions` is final and never reaches the hook, so the hook is for dynamic checks only.

### Guard the shell itself

```js
await ctx.shell.hook("create.before", (event) => {
  event.timeout = Math.min(event.timeout, 60_000)
  event.env.NO_COLOR = "1"
})
```

Use this to adjust execution, not to refuse it. To refuse a command, decide in the permission hook where an effect can be set.

### Inject context per model call

```js
await ctx.session.hook("context", (event) => {
  event.system.push({ type: "text", text: "Prefer the existing helper over a new one." })
})
```

Mutate `event.system` **synchronously**. The system prompt is snapshotted when the hook is entered, so a change made after an `await` never reaches the model.

### Rewrite a user prompt

```js
await ctx.session.hook("prompt", (event) => {
  event.prompt.text = event.prompt.text.replaceAll("company-secret", "[redacted]")
  event.delivery = "queue"
})
```

### Notify on session state

```js
const controller = new AbortController()
void (async () => {
  for await (const event of ctx.event.subscribe({ signal: controller.signal })) {
    if (event.type === "session.idle") notify("OpenCode is waiting")
  }
})()
return () => controller.abort()
```

Abort the stream in the cleanup function, or the plugin leaks a running loop.

## Writing a rule well

- One plugin per concern. Two unrelated behaviours in one file make it impossible to disable independently.
- Name the plugin ID after what it does (`format`, `guard-git`, `notify`).
- Keep hooks cheap. They run on every matching event, in every session that loads the plugin.
- Scope by tool, path, or action at the top of the callback and return early.
- Log once at setup when the plugin has no visible effect, so the user can tell it loaded.
- Dispose registrations and abort subscriptions on unload.

## Testing a rule

1. Put the plugin in `.opencode/plugins/` and restart the session.
2. Trigger the event deliberately: edit a file, run the command, send a prompt.
3. Check `opencode --print-logs` or `~/.local/share/opencode/log/` for errors.
4. Confirm the rule does nothing when it should not: a file outside the filter, a command that is allowed.
