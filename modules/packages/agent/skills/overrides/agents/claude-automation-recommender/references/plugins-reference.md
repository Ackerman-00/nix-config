# Plugins for OpenCode

An OpenCode plugin is a JavaScript or TypeScript module that default-exports an object with an `id` and a `setup` function. Plugins register hooks, commands, tools, and transforms.

## Where plugins live

| Scope | Path | Loaded |
|-------|------|--------|
| Global | `~/.config/opencode/plugins/` | automatically |
| Project | `.opencode/plugins/` | automatically |

A `plugins/` directory beside the project-root `opencode.json` is **not** discovered automatically. Move it under `.opencode/` or register it explicitly.

## Installing a packaged plugin

```jsonc
{
  "$schema": "https://opencode.ai/config.json",
  "plugins": [
    "opencode-acme-plugin",
    "opencode-acme-plugin@1.2.0",
    "@acme/opencode-plugin",
    "./plugins/local",
    {
      "package": "@acme/opencode-plugin",
      "options": { "agent": "reviewer", "strict": true },
    },
  ],
}
```

Options passed here arrive as `ctx.options` in `setup`.

CLI management:

```bash
opencode plugin add opencode-acme-plugin@1.2.0
opencode plugin list
opencode plugin check
opencode plugin update
opencode plugin remove opencode-acme-plugin@1.2.0
```

Entries are processed in order. Prefix an ID with `-` to disable it, `*` matches every plugin, `.*` matches an ID prefix. Two built-ins ignore removals: `opencode.config.policy` and `opencode.provider.opencode`.

## What a plugin can do

| Capability | API |
|------------|-----|
| React to runtime events | `ctx.event.subscribe({ signal })` |
| Adjust a prompt before admission | `ctx.session.hook("prompt", cb)` |
| Add text to the system prompt | `ctx.session.hook("context", cb)` |
| React to a permission decision | `ctx.permission.hook("evaluate", cb)` |
| Inspect or block tool input | `ctx.tool.hook("execute.before", cb)` |
| Watch tool results | `ctx.tool.hook("execute.after", cb)` |
| Change shell command, cwd, timeout, env | `ctx.shell.hook("create.before", cb)` |
| Add a named command | `ctx.command.transform` |
| Add a custom tool | `ctx.tool.transform` |
| Add or override a skill | `ctx.skill.transform` |
| Add or override an agent | `ctx.agent.transform` |
| Add or override an MCP server | `ctx.mcp.transform` |
| Add a model or provider | `ctx.provider.transform`, `ctx.model.transform` |
| Persist plugin settings | `ctx.storage.get/set/remove/scan` |
| Read config and instructions | `ctx.config`, `ctx.instructions` |

## When to recommend a plugin

- The behaviour depends on runtime state that config cannot express.
- You need to react to events (session idle, file edited, session error).
- You need to intercept tool calls or permission decisions.
- You want a custom tool with domain-specific behaviour.
- You want to inject or rewrite prompts per session.

Prefer plain configuration when the rule is static. `permissions` and `agents` in `opencode.json` cover most allow/deny and role needs without running code.

## Plugin examples worth knowing

| Plugin | Purpose |
|--------|---------|
| **Notification** | Desktop or terminal notification when a session goes idle |
| **Environment protection** | Deny reads of `.env` files before they reach the model |
| **Environment injection** | Add variables to every shell command |
| **Custom tools** | Register a tool with its own schema and executor |
| **Compaction context** | Add domain state to the compaction prompt so it survives summarisation |

## Guidance

- Keep `setup` cheap. It runs on every startup.
- Return a cleanup function when you register listeners, timers, or event subscriptions.
- Dispose registrations you no longer need: `await registration.dispose()`.
- Load external data before a transform callback, then call `reload()` when the source changes.
- A plugin runs with the user's own authority. Review one before installing it.
