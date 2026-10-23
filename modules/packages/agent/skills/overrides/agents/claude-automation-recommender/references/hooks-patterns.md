# Hook Patterns for OpenCode

OpenCode has no separate hook configuration file. Hooks are code inside a plugin, registered on a domain object. The plugin lives in `.opencode/plugins/*.js` (project) or `~/.config/opencode/plugins/*.js` (global).

## Where each behaviour goes

| Behaviour | Mechanism |
|-----------|-----------|
| Run a formatter after a file edit | `ctx.tool.hook("execute.after")` |
| Rewrite or block a tool call | `ctx.permission.hook("evaluate")` |
| Change a shell command, cwd, timeout, env | `ctx.shell.hook("create.before")` |
| Add text to the system prompt | `ctx.session.hook("context")` |
| Rewrite an incoming user prompt | `ctx.session.hook("prompt")` |
| React to lifecycle events | `ctx.event.subscribe({ signal })` |
| Register a custom tool | `ctx.tool.transform` |
| Register a named command | `ctx.command.transform` |

Static allow/deny rules belong in `permissions` in `opencode.json`, not in a plugin. Use a plugin when the decision depends on runtime state.

## Formatting and linting after edits

Detection → recommendation:

| If you see | Recommend |
|------------|-----------|
| `.prettierrc`, `prettier.config.js` | run `prettier --write` after an edit |
| `eslint.config.js`, `.eslintrc*` | run `eslint --fix` after an edit |
| `ruff.toml`, `[tool.ruff]` in `pyproject.toml` | run `ruff format` + `ruff check --fix` |
| `black`/`isort` in `pyproject.toml` | run `black` + `isort` |
| `go.mod` | run `gofmt -w` |
| `Cargo.toml` | run `cargo fmt` |
| `tsconfig.json` | run `tsc --noEmit` |

Plugin shape:

```js
// .opencode/plugins/format.js
export default {
  id: "format",
  async setup(ctx) {
    await ctx.tool.hook("execute.after", async (event) => {
      if (event.tool !== "edit" && event.tool !== "write") return
      const file = event.input?.filePath
      if (!file || !file.endsWith(".ts")) return
      // run the project formatter here
    })
  },
}
```

`execute.after` exposes `event.tool`, `event.input`, `event.result`, `event.status` and `event.error`. `event.status` is `"completed"` or `"error"`.

## Type checking

Detection: `tsconfig.json`, `mypy.ini`, `pyrightconfig.json`, `pyproject.toml` with mypy.

Use `execute.after` to run the type checker, or let the model run it as part of its normal workflow. Type checks are slow; a hook that runs on every edit can dominate the session.

## Protection rules

Sensitive paths and lock files:

| Detection | Paths |
|-----------|-------|
| `.env`, `.env.local`, `.env.production` | environment files |
| `credentials.json`, `secrets.yaml` | secret files |
| `.git/` | git internals |
| `package-lock.json`, `Cargo.lock`, `poetry.lock` | lock files |

Static protection is a permission rule:

```jsonc
{
  "permissions": [
    { "action": "read", "resource": "*.env", "effect": "deny" },
    { "action": "edit", "resource": "*.lock", "effect": "deny" },
  ],
}
```

Dynamic protection is a permission hook. Hooks run for `allow` and `ask` decisions; a configured `deny` is final and never reaches the hook:

```js
await ctx.permission.hook("evaluate", async (event) => {
  if (event.action !== "edit") return
  if (event.resources.some((r) => r.includes("/secrets/"))) {
    event.effect = "deny"
    event.message = "Secrets are not editable from a session."
  }
})
```

## Test runners

Detection: `jest.config.js`, `pytest.ini`, `tests/`, `*_test.go`, `#[cfg(test)]`.

Running the whole suite on every edit is wasteful. Either skip the hook or scope it to the touched package.

## Notifications and lifecycle

Use `ctx.event.subscribe` for session-level notifications:

```js
const controller = new AbortController()
void (async () => {
  for await (const event of ctx.event.subscribe({ signal: controller.signal })) {
    if (event.type === "session.idle") notify("OpenCode is idle")
    if (event.type === "session.error") notify(event.properties?.error?.name ?? "error")
  }
})()
return () => controller.abort()
```

Observed event types include `session.step.ended`, `session.execution.started`, `session.message.updated`, `session.idle`, `message.updated`, `message.part.updated`, `session.created`, `session.deleted`, `session.error`, `file.edited`, `project.updated`.

Abort the stream during cleanup so the plugin does not leak a running loop.

## Injecting context into the model

```js
await ctx.session.hook("context", (event) => {
  event.system.push({ type: "text", text: "Keep the review focused on correctness." })
})
```

Mutate `event.system` **synchronously**. The system prompt is snapshotted when the hook is entered, so a mutation made after an `await` never reaches the model.

## Rules of thumb

- Prefer `permissions` for static rules; plugins only where the decision needs runtime state.
- Keep hooks cheap. They run on every matching event.
- Dispose registrations you no longer need: `await registration.dispose()`.
- Scope provider-specific behaviour with the third argument: `ctx.session.hook("context", cb, { providerID: "openai" })`.
