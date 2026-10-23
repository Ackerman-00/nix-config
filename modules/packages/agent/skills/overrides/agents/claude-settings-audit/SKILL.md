---
name: claude-settings-audit
description: Analyze a repository and generate recommended OpenCode permissions rules for opencode.json. Use when setting up a new project, auditing existing permissions, or deciding which shell commands, skills, subagents, and web domains to allow, ask, or deny. Detects tech stack, build tools, and monorepo structure.
---

# OpenCode Permissions Audit

Analyze this repository and generate recommended OpenCode `permissions` rules for `opencode.json`.

OpenCode v2 uses a `permissions` array of `{action, resource, effect}` objects. Rules run in order and the last matching rule wins. There is no separate settings file: everything lives in `opencode.json` / `opencode.jsonc`.

## Phase 1: Detect Tech Stack

```bash
ls -la
find . -maxdepth 2 \( -name "*.toml" -o -name "*.json" -o -name "*.lock" -o -name "*.yaml" -o -name "*.yml" -o -name "Makefile" -o -name "Dockerfile" -o -name "*.tf" \) 2>/dev/null | head -50
```

| Category     | Files to Check                                                                        |
| ------------ | ------------------------------------------------------------------------------------- |
| **Python**   | `pyproject.toml`, `setup.py`, `requirements.txt`, `Pipfile`, `poetry.lock`, `uv.lock` |
| **Node.js**  | `package.json`, `package-lock.json`, `yarn.lock`, `pnpm-lock.yaml`                    |
| **Go**       | `go.mod`, `go.sum`                                                                    |
| **Rust**     | `Cargo.toml`, `Cargo.lock`                                                            |
| **Ruby**     | `Gemfile`, `Gemfile.lock`                                                             |
| **Java**     | `pom.xml`, `build.gradle`, `build.gradle.kts`                                         |
| **Build**    | `Makefile`, `Dockerfile`, `docker-compose.yml`                                        |
| **Infra**    | `*.tf` files, `kubernetes/`, `helm/`                                                  |
| **Monorepo** | `lerna.json`, `nx.json`, `turbo.json`, `pnpm-workspace.yaml`                          |

## Phase 2: Detect Services

| Service    | Detection                                                                       |
| ---------- | ------------------------------------------------------------------------------- |
| **Sentry** | `sentry-sdk` in deps, `@sentry/*` packages, `.sentryclirc`, `sentry.properties` |
| **Linear** | Linear config files, `.linear/` directory                                       |

Read dependency files to identify frameworks:

- `package.json` → `dependencies` and `devDependencies`
- `pyproject.toml` → `[project.dependencies]` or `[tool.poetry.dependencies]`
- `Gemfile` → gem names
- `Cargo.toml` → `[dependencies]`

## Phase 3: Check Existing Configuration

```bash
cat opencode.json 2>/dev/null || cat opencode.jsonc 2>/dev/null || echo "No project config"
cat ~/.config/opencode/opencode.json 2>/dev/null || echo "No global config"
```

Also check what already exists elsewhere:

```bash
ls .opencode/ 2>/dev/null                       # project plugins, skills, agents
ls ~/.config/opencode/ 2>/dev/null               # global equivalents
ls .opencode/skills/ .agents/skills/ 2>/dev/null  # skill IDs you may want to gate
```

## Phase 4: Generate the Permission Rules

### Action names

V2 action names differ from V1. Use these:

| Action               | Resource it matches                                              |
| -------------------- | ---------------------------------------------------------------- |
| `read`               | file path                                                       |
| `edit`               | target path for `edit`, `write`, `patch`                        |
| `glob`               | the glob pattern                                                |
| `grep`               | the search pattern                                              |
| `shell`              | the command string (a compound command may match several rules) |
| `subagent`           | target agent ID                                                 |
| `skill`              | skill ID                                                        |
| `question`           | `*`                                                             |
| `webfetch`           | the URL                                                         |
| `websearch`          | the query                                                       |
| `external_directory` | the external directory boundary                                 |
| `execute`            | `*` (Code Mode reach)                                           |

Do not write `bash`, `task`, or `permission` in a V2 config; those are V1 names.

### Baseline rules

```jsonc
{
  "$schema": "https://opencode.ai/config.json",
  "permissions": [
    { "action": "shell", "resource": "git status *", "effect": "allow" },
    { "action": "shell", "resource": "git diff *", "effect": "allow" },
    { "action": "shell", "resource": "git log *", "effect": "allow" },
    { "action": "shell", "resource": "git push *", "effect": "deny" },
  ]
}
```

A pattern that ends in ` *` also matches the bare command, so `git status *` covers `git status --short`. A pattern ending without ` *` does not cover arguments.

### Stack-specific shell rules

Only include tools the project actually uses.

#### Python

| Detected                         | Allow                                                    |
| -------------------------------- | -------------------------------------------------------- |
| Any Python                       | `python --version`, `python3 --version`                  |
| `poetry.lock`                    | `poetry show *`, `poetry env info`                      |
| `uv.lock`                        | `uv pip list *`, `uv tree *`                             |
| `Pipfile.lock`                   | `pipenv graph *`                                         |
| `requirements.txt` only          | `pip list *`, `pip show *`, `pip freeze`                 |

#### Node.js

| Detected                  | Allow                                                |
| -------------------------- | ---------------------------------------------------- |
| Any Node.js               | `node --version`                                     |
| `pnpm-lock.yaml`          | `pnpm list *`, `pnpm why *`                          |
| `yarn.lock`               | `yarn list *`, `yarn info *`, `yarn why *`           |
| `package-lock.json`       | `npm list *`, `npm view *`, `npm outdated *`         |
| `tsconfig.json`           | `tsc --version`, `tsc --noEmit *`                    |

#### Other languages

| Detected    | Allow                                                             |
| ------------ | ----------------------------------------------------------------- |
| `go.mod`     | `go version`, `go list *`, `go mod graph`, `go env`              |
| `Cargo.toml` | `cargo --version`, `cargo tree *`, `cargo metadata *`            |
| `Gemfile`    | `ruby --version`, `bundle list *`, `bundle show *`                |
| `pom.xml`    | `mvn --version`, `mvn dependency:tree`                            |
| `build.gradle` | `gradle --version`, `gradle dependencies`                       |

#### Build tools

| Detected            | Allow                                                       |
| -------------------- | ----------------------------------------------------------- |
| `Dockerfile`         | `docker --version`, `docker ps *`, `docker images *`         |
| `docker-compose.yml` | `docker compose ps *`, `docker compose config *`             |
| `*.tf` files         | `terraform --version`, `terraform providers`, `terraform state list` |
| `Makefile`           | `make --version`, `make -n *`                               |

### Skill rules

Skill IDs are the path-derived directory names, so they are lowercase kebab-case. Gate them when a skill carries side effects:

```jsonc
{
  "permissions": [
    { "action": "skill", "resource": "*", "effect": "allow" },
    { "action": "skill", "resource": "internal-*", "effect": "deny" },
    { "action": "skill", "resource": "deploy-*", "effect": "ask" },
  ]
}
```

A `deny` hides the skill from the model and rejects loading it.

### Subagent rules

```jsonc
{
  "permissions": [
    { "action": "subagent", "resource": "*", "effect": "allow" },
    { "action": "subagent", "resource": "explore", "effect": "allow" },
  ]
}
```

### Web rules

```jsonc
{
  "permissions": [
    { "action": "webfetch", "resource": "*", "effect": "ask" },
    { "action": "webfetch", "resource": "https://docs.sentry.io/*", "effect": "allow" },
    { "action": "webfetch", "resource": "https://docs.github.com/*", "effect": "allow" },
  ]
}
```

Framework docs worth allowing once detected: `docs.djangoproject.com`, `flask.palletsprojects.com`, `fastapi.tiangolo.com`, `react.dev`, `nextjs.org`, `vuejs.org`, `expressjs.com`, `guides.rubyonrails.org`, `pkg.go.dev`, `docs.rs`, `doc.rust-lang.org`, `docs.docker.com`, `kubernetes.io`, `registry.terraform.io`.

### Per-agent overrides

Agent rules are appended after global rules, so a narrower agent rule wins. Put shared rules at the top level:

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

## Phase 5: MCP Server Suggestions

MCP servers live in the `mcp` key of `opencode.json`, not in a separate file.

**Sentry MCP** (if the Sentry SDK is detected):

```jsonc
{
  "mcp": {
    "sentry": {
      "type": "remote",
      "url": "https://mcp.sentry.dev/mcp/{org-slug}/{project-slug}",
    }
  }
}
```

**Linear MCP** (if Linear is used):

```jsonc
{
  "mcp": {
    "linear": {
      "type": "local",
      "command": ["npx", "-y", "@linear/mcp-server"],
      "environment": { "LINEAR_API_KEY": "${LINEAR_API_KEY}" },
    }
  }
}
```

A local server needs `type: "local"` and `command` as an array; a remote server needs `type: "remote"` and a `url`. Check the current key with `opencode mcp list`.

Use the `gh` CLI for GitHub rather than adding a GitHub MCP server.

## Output Format

1. **Summary table** of what was detected
2. **Recommended `permissions`** block, ready to paste
3. **Per-agent overrides**, if the project defines agents
4. **MCP suggestions**, if applicable
5. **Merge instructions** when a config already exists

```markdown
## Detected Tech Stack

| Category        | Found          |
| --------------- | -------------- |
| Languages       | Python 3.x     |
| Package Manager | poetry         |
| Frameworks      | Django, Celery |
| Services        | Sentry         |
| Build Tools     | Docker, Make   |

## Recommended permissions

```jsonc
{
  "$schema": "https://opencode.ai/config.json",
  "permissions": [
    { "action": "shell", "resource": "poetry show *", "effect": "allow" },
    { "action": "shell", "resource": "docker compose ps *", "effect": "allow" },
    { "action": "shell", "resource": "git push *", "effect": "deny" },
  ],
}
```
```

## Important Rules

### What to Include

- Read-only commands that cannot change state
- Only tools the project actually uses (detected via lock files)
- System inspection commands (`ls`, `find`, `wc`, `stat`, `file`)
- Narrow `deny` rules for destructive operations

### What to NEVER Include

- Absolute user paths such as `/home/user/scripts/foo`
- Project scripts with side effects (`./scripts/deploy.sh`)
- Alternative package managers the project does not use
- Commands that modify state (install, build, run, write, delete) unless the user asks for them

### Package manager rules

Only include the manager the project uses:

| Detected         | Include   | Do NOT include    |
| ---------------- | --------- | ----------------- |
| `pnpm-lock.yaml` | pnpm      | npm, yarn         |
| `yarn.lock`      | yarn      | npm, pnpm         |
| `package-lock.json` | npm    | yarn, pnpm        |
| `poetry.lock`    | poetry    | pip (unless also `requirements.txt`) |
| `uv.lock`        | uv        | pip, poetry       |
| `Pipfile.lock`   | pipenv    | pip, poetry       |

### Defaults to keep in mind

If nothing matches a rule the effect is `ask`, so a narrow allowlist is usually better than a broad one. The shipped base policy allows almost everything, asks for `*.env` reads, and lets `external_directory` through unless you add a rule. Add one when the user wants a prompt for paths outside the project:

```jsonc
{ "action": "external_directory", "resource": "*", "effect": "ask" }
```
