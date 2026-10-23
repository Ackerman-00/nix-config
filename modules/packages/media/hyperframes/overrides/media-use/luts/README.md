# LUT library (authoring)

`index.json` is the agent-consumed catalog of color-grade looks. Each entry resolves
on demand — no `.cube` bodies are committed to the repo.

Each look has:

- `id`, `description`, `tags`, `intensity` — matching + application metadata.
- `params` — a deterministic `buildCube` spec used to build the `.cube` offline.
- `url` (optional) — a hosted `.cube` downloaded, validated, and frozen at resolve
  time, exactly like bgm/image assets.

An entry needs at least one of `url` or `params`; prefer both (CDN url with a params
fallback) so resolution is never blocked on the network. Every look shipped here
resolves from `params` alone, so no host is required.

## Hosting a new look (operators)

1. Generate the `.cube` (e.g. `resolve -t lut --params '{...}'` or a graded export).
2. Upload it to a public static origin of your own, then add an entry to
   `index.json` with that `url` (and ideally a `params` fallback).
