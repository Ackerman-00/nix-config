---
name: plugin-settings
description: >-
  Configure OpenCode plugins: where they live, how to install them, how to pass options, and how to persist plugin state. Use when setting up a plugin for a project or globally, tuning its options, debugging a plugin that does not load, or storing plugin preferences.
---

# Plugin Settings

OpenCode plugins are JavaScript or TypeScript modules. There is no settings file for plugins and no separate hook file: configuration lives in `opencode.json`, and everything else is code inside the plugin.

## Where plugins are discovered

| Scope | Path | Loaded |
|-------|------|--------|
| Global | `~/.config/opencode/plugins/` | automatically at startup |
| Project | `.opencode/plugins/` | automatically at startup |

Files in those directories are loaded directly. A `plugins/` directory next to the project-root `opencode.json` is **not** discovered; move it under `.opencode/` or register it explicitly.

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
      "options": {
        "agent": "reviewer",
        "strict": true,
      },
    },
  ],
}
```

Accepted entries: a package name, a name with a version, a scoped name, a local path, or an object with `package` and `options`.

CLI:

```bash
opencode plugin add opencode-acme-plugin@1.2.0
opencode plugin list
opencode plugin check
opencode plugin update
opencode plugin remove opencode-acme-plugin@1.2.0
```

npm plugins are installed with Bun at startup and cached in `~/.cache/opencode/node_modules/`. Local plugin files are loaded from disk with no install step.

## Controlling which plugins load

Entries are processed in order.

| Entry | Effect |
|-------|--------|
| `"*"` | enable every plugin |
| `".*"` | match an ID prefix |
| `"-acme.reviewer"` | disable a plugin |
| `"acme.reviewer"` | re-enable a plugin |

Two built-ins ignore removals, so a repository cannot switch them off: `opencode.config.policy` and `opencode.provider.opencode`.

## Passing options

Options come from the object form of the entry and arrive as `ctx.options` during `setup`:

```js
// .opencode/plugins/company/index.js
export default {
  id: "company",
  async setup(ctx) {
    const strict = ctx.options.strict === true
    const agent = ctx.options.agent ?? "build"
  },
}
```

Read `ctx.options` defensively: a plugin may also be loaded from a directory where no options were given.

## Persisting plugin state

`ctx.storage` stores JSON values scoped to the plugin:

```js
const settings = (await ctx.storage.get("settings")) ?? { strict: false }
await ctx.storage.set("settings", { ...settings, strict: true })
await ctx.storage.remove("settings")

const page = await ctx.storage.scan({ prefix: "cache/", limit: 100 })
```

Use storage for state that must survive restarts: last-used project, cached API responses, per-project toggles. Use `ctx.options` for configuration the user sets in `opencode.json`.

## Per-project versus global

- Global plugin in `~/.config/opencode/plugins/` applies to every project.
- Project plugin in `.opencode/plugins/` applies to that project and overrides a global plugin with the same ID.
- Config arrays from every applicable config file are combined, lowest precedence first, rather than replacing each other.

## Verifying a plugin

1. `opencode plugin list` shows whether the package resolved.
2. Start OpenCode and check the log: `opencode --print-logs`, or look at `~/.local/share/opencode/log/`.
3. Add a one-line log in `setup` if the plugin produces no visible effect:
   ```js
   console.log(`[company] loaded in OpenCode ${ctx.app.version}`)
   ```
4. Watch for reloads. Changes under watched config directories reload automatically; other dependency changes may need `opencode service restart`.

## Common problems

| Symptom | Cause |
|---------|-------|
| Plugin never runs | File is outside `.opencode/plugins/` or `~/.config/opencode/plugins/`, or the plugin ID was disabled with a `-` entry |
| `ctx.options` empty | The plugin was loaded from a directory, not the object form in the config |
| Plugin works in one project only | It lives in a project `.opencode/plugins/` directory |
| Changes not picked up | A watched dependency changed; restart the service |
| Duplicate behaviour | A global and a project plugin share an ID and both register the same hook |

## Rules of thumb

- One plugin, one responsibility. Split unrelated behaviour into separate plugins with distinct IDs.
- Keep `setup` fast; it runs at every startup.
- Return a cleanup function when the plugin holds a listener, timer, or event subscription.
- A plugin runs with the user's own authority. Review one before installing it, and prefer narrow permissions.
