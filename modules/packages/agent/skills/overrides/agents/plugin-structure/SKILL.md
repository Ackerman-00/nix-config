---
name: plugin-structure
description: >-
  Reference for the structure of an OpenCode plugin: file layout, default export shape, the setup lifecycle, and the plugin context API. Use when writing a new plugin, reviewing one, or figuring out which context method to reach for.
---

# Plugin Structure

An OpenCode plugin is a JavaScript or TypeScript module that default-exports an object with an `id` and a `setup` function.

## Minimal plugin

```js
// .opencode/plugins/example.js
export default {
  id: "example",
  async setup(ctx) {
    console.log(`loaded in OpenCode ${ctx.app.version}`)
    return () => console.log("unloaded")
  },
}
```

For TypeScript, `Plugin.define` from `@opencode/plugin` adds types:

```ts
import { Plugin } from "@opencode/plugin"

export default Plugin.define({
  id: "example",
  async setup(ctx) {
    await ctx.storage.set("loaded", true)
  },
})
```

## Layout

```
.opencode/plugins/
├── concise.js              # a single-file plugin
├── reviewer/
│   └── index.js            # a plugin package directory
└── acme/
    ├── package.json        # own dependencies
    └── src/index.ts
```

Add dependencies with a `package.json` in the config directory; OpenCode runs `bun install` at startup.

## Lifecycle

1. The module is imported and the default export is read.
2. `setup(ctx)` runs once. It may be async.
3. Registrations made during setup stay active.
4. If `setup` returns a function, it runs when the plugin unloads. Use it to abort event streams, clear timers, and dispose registrations.

## Plugin context

| Member | What it gives you |
|--------|-------------------|
| `ctx.app` | app version |
| `ctx.location` | `directory`, `workspaceID`, `project` metadata |
| `ctx.options` | options passed from the `plugins` config entry |
| `ctx.storage` | `get`, `set`, `remove`, `scan` — plugin-scoped JSON |
| `ctx.model` | `list`, `default`; `transform` to edit models |
| `ctx.provider` | `list`, `get`; `transform` to edit providers |
| `ctx.agent` | `list`, `get`; `transform` to edit agents |
| `ctx.session` | session CRUD, prompts, and `hook` |
| `ctx.command` | `list`; `transform` to add commands |
| `ctx.tool` | `list`; `transform` to add tools; `hook` for tool events |
| `ctx.permission` | `assert`, `list`, `get`, `reply`; `hook` to evaluate decisions |
| `ctx.shell` | `hook` for shell command creation |
| `ctx.event` | `subscribe({ signal })` — async iterable of runtime events |
| `ctx.mcp` | `list`; `transform` to add or update MCP servers |
| `ctx.skill` | `list`; `transform` to add or update skills |
| `ctx.reference` | `list`; `transform` to manage references |
| `ctx.vcs` | repository info, branches, status, diff |
| `ctx.worktree` | worktree create/remove/list |
| `ctx.generate` | `text({ model, prompt })` — one-shot model call, no session |
| `ctx.websearch` | `providers`, `query` |
| `ctx.config` | resolved configuration |
| `ctx.instructions` | resolved instruction files |

## Hooks

```js
const registration = await ctx.session.hook("context", (event) => {
  event.system.push({ type: "text", text: "Keep the review focused on correctness." })
})
await registration.dispose()
```

| Hook | Signature |
|------|-----------|
| `ctx.session.hook("prompt", cb)` | `event.prompt.text`, `event.prompt.files`, `event.prompt.agents`, `event.prompt.skills`, `event.metadata`, `event.delivery` |
| `ctx.session.hook("context", cb)` | `event.system`, `event.tools`, `event.options` — mutate synchronously |
| `ctx.session.hook("compaction", cb)` | `event.messages`, `event.result` |
| `ctx.session.hook("generate", cb)` | transient generation calls |
| `ctx.session.hook("title", cb)` | title generation |
| `ctx.session.hook("model.request", cb)` | `event.headers` |
| `ctx.session.hook("http.request", cb)` / `("http.response", cb)` | native provider traffic |
| `ctx.permission.hook("evaluate", cb)` | `event.effect`, `event.message`, `event.action`, `event.resources` |
| `ctx.shell.hook("create.before", cb)` | `event.command`, `event.cwd`, `event.timeout`, `event.env` |
| `ctx.tool.hook("execute.before", cb)` | `event.tool`, `event.input` |
| `ctx.tool.hook("execute.after", cb)` | `event.result`, `event.status`, `event.error` |

Session hooks accept a third argument to scope by provider: `{ providerID: "openai" }`.

## Transforms

```js
await ctx.command.transform((editor) => {
  editor.add({
    name: "security-review",
    description: "Review changes for security issues",
    execute: async ({ sessionID, prompt, delivery }) => {
      await ctx.session.prompt({
        ...prompt,
        sessionID,
        text: `Review these changes for security issues.\n\n${prompt.text}`,
        delivery,
      })
    },
  })
})

await ctx.tool.transform((editor) => {
  editor.add({
    name: "greeting",
    description: "Greet the user by name",
    input: {
      type: "object",
      properties: { name: { type: "string" } },
      required: ["name"],
      additionalProperties: false,
    },
    execute: async (input, context) => ({ content: `Hello ${input.name}!` }),
  })
})
```

Other transforms follow the same shape: `ctx.skill.transform`, `ctx.agent.transform`, `ctx.mcp.transform`, `ctx.model.transform`, `ctx.provider.transform`.

## Events

```js
const controller = new AbortController()
void (async () => {
  for await (const event of ctx.event.subscribe({ signal: controller.signal })) {
    if (event.type === "session.idle") console.log("idle")
  }
})()
return () => controller.abort()
```

Event objects carry `type` and fields such as `sessionID`, `agent`, `properties`. Observed types include `session.step.ended`, `session.execution.started`, `session.message.updated`, `session.idle`, `message.updated`, `message.part.updated`, `session.created`, `session.deleted`, `session.error`, `file.edited`, `project.updated`.

## Rules that keep plugins healthy

- Register hooks inside `setup`; dispose them in the cleanup function.
- Mutate `event.system` in the `context` hook synchronously. The prompt is snapshotted when the hook is entered, so a mutation after an `await` never reaches the model.
- Load external data before a transform callback, then call the matching `reload()` when the source changes.
- Transforms are replayed on every rebuild; keep them cheap and side-effect free.
- Give the plugin a stable, unique ID. It is how users disable it and how config entries refer to it.
