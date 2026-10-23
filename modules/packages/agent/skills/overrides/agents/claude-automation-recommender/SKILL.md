---
name: claude-automation-recommender
description: Analyze a codebase and recommend OpenCode automations (permissions, subagents, skills, plugins, hooks, MCP servers). Use when the user asks for automation recommendations, wants to tune their OpenCode setup, mentions improving OpenCode workflows, asks how to first set up OpenCode for a project, or wants to know which OpenCode extension points to use.
---

# OpenCode Automation Recommender

Analyze codebase patterns and recommend tailored OpenCode automations across every extension point.

**This skill is read-only.** It analyzes the codebase and outputs recommendations. It does not create or modify files. Users implement the recommendations themselves or ask for help building them.

## Output Guidelines

- **Recommend 1-2 of each type**: surface the top 1-2 most valuable automations per category.
- **If the user asks for a specific type**: focus only on that type and offer 3-5 options.
- **Go beyond the reference lists**: use web search for recommendations specific to the codebase's tools and frameworks.
- **Tell users they can ask for more**: end by noting they can request more options for any category.

## Extension Points Overview

| Type | What it is | Where it lives |
|------|------------|-----------------|
| **Permissions** | allow / ask / deny rules per action | `permissions` in `opencode.json` |
| **Agents** | named assistant profiles, primary or subagent | `.opencode/agents/<name>.md` or `agents` in config |
| **Skills** | reusable instructions loaded on demand | `.opencode/skills/<id>/SKILL.md` |
| **Plugins** | JavaScript modules that hook into the runtime | `.opencode/plugins/*.js` |
| **Hooks** | runtime callbacks registered by a plugin | plugin code: `ctx.session.hook`, `ctx.tool.hook`, `ctx.permission.hook` |
| **MCP servers** | external tool integrations | `mcp` in `opencode.json` |
| **Commands** | named prompt templates | `commands` in `opencode.json` |

There is no plugin marketplace and no separate settings file in OpenCode v2; configuration lives in `opencode.json` / `opencode.jsonc`.

## Workflow

### Phase 1: Codebase Analysis

```bash
# Detect project type and tools
ls -la package.json pyproject.toml Cargo.toml go.mod pom.xml 2>/dev/null
cat package.json 2>/dev/null | head -50

# Dependencies that point at MCP servers
cat package.json 2>/dev/null | grep -E '"(react|vue|angular|next|express|fastapi|django|prisma|supabase|convex|stripe)"'

# Existing OpenCode setup
ls -la .opencode/ AGENTS.md opencode.json opencode.jsonc 2>/dev/null
ls -la ~/.config/opencode/ 2>/dev/null

# Project structure
ls -la src/ app/ lib/ tests/ components/ pages/ api/ 2>/dev/null
```

**Key indicators to capture:**

| Category | What to look for | Informs |
|----------|------------------|----------|
| Language/Framework | package.json, pyproject.toml, import patterns | permissions, MCP servers |
| Frontend stack | React, Vue, Angular, Next.js | browser MCP, frontend skills |
| Backend stack | Express, FastAPI, Django | API doc skills |
| Database | Prisma, Supabase, Convex, raw SQL | database MCP servers |
| External APIs | Stripe, OpenAI, AWS SDKs | docs MCP servers |
| Testing | Jest, pytest, Playwright configs | test skills, reviewer agents |
| CI/CD | GitHub Actions, CircleCI | `gh` CLI, permissions |
| Issue tracking | Linear, Jira references | issue tracker MCP |
| Docs patterns | OpenAPI, JSDoc, docstrings | documentation skills |

### Phase 2: Generate Recommendations

#### A. MCP servers

See [references/mcp-servers.md](references/mcp-servers.md) for details.

| Codebase signal | Recommended server |
|-----------------|-------------------|
| Popular libraries in use | **context7** — live documentation lookup |
| Frontend needing UI testing | **Playwright** — browser automation and testing |
| Supabase | **Supabase MCP** — direct database operations |
| Convex | **Convex MCP** — live deployment introspection and queries |
| PostgreSQL/MySQL | **Database MCP** — query and schema tools |
| GitHub repository | **GitHub MCP** — issues, PRs, actions |
| Linear for issues | **Linear MCP** — issue management |
| AWS infrastructure | **AWS MCP** — cloud resources |
| Slack workspace | **Slack MCP** — notifications |
| Sentry error tracking | **Sentry MCP** — error investigation |
| Docker containers | **Docker MCP** — container management |

Servers go in the `mcp` key of `opencode.json`. Local servers use `type: "local"` plus a `command` array; remote servers use `type: "remote"` plus a `url`.

#### B. Skills

See [references/skills-reference.md](references/skills-reference.md).

Create skills in `.opencode/skills/<skill-id>/SKILL.md`. The ID is the directory name; the frontmatter `name` is only a display label.

| Codebase signal | Skill to create |
|-----------------|-----------------|
| API routes | **api-doc** with an OpenAPI template |
| Database project | **create-migration** with a validation script |
| Test suite | **gen-test** with example tests |
| Component library | **new-component** with templates |
| PR workflow | **pr-check** with a checklist |
| Releases | **release-notes** that read git context |
| Code style | **project-conventions** |
| Onboarding | **setup-dev** with a prerequisite script |

#### C. Permissions

See [references/permissions-patterns.md](references/permissions-patterns.md).

| Codebase signal | Recommended rule |
|-----------------|-------------------|
| Prettier or ruff configured | allow the formatter command for `shell` |
| ESLint configured | allow the lint command for `shell` |
| Tests directory exists | allow the test command for `shell` |
| `.env` files present | `deny` reads of `*.env` |
| Lock files present | `deny` edits to lock files |
| Deployment scripts | `deny` the deploy command, `ask` for the rest |

#### D. Agents

See [references/subagent-templates.md](references/subagent-templates.md).

| Codebase signal | Recommended agent |
|-----------------|-------------------|
| Large codebase | **code-reviewer** — parallel code review |
| Auth or payments code | **security-reviewer** — security audits |
| API project | **api-documenter** — OpenAPI generation |
| Frontend heavy | **ui-reviewer** — accessibility review |
| Needs more tests | **test-writer** — test generation |

#### E. Plugins and hooks

See [references/hooks-patterns.md](references/hooks-patterns.md) and [references/plugins-reference.md](references/plugins-reference.md).

| Codebase signal | Recommended plugin or hook |
|-----------------|---------------------------|
| Formatter configured | `ctx.tool.hook("execute.after")` — format after an edit |
| Linter configured | `ctx.tool.hook("execute.after")` — lint after an edit |
| Sensitive files | `ctx.permission.hook("evaluate")` — deny writes to secrets |
| Session lifecycle | `ctx.event.subscribe` — notify on `session.idle` |
| Repeated manual command | `ctx.command.transform` — add a named command |

#### F. Commands

Commands are named prompt templates in the `commands` key of `opencode.json`:

```jsonc
{
  "commands": {
    "security-review": {
      "template": "Review the current changes for security issues.",
      "description": "Security review of the working tree"
    }
  }
}
```

| Codebase signal | Recommended command |
|-----------------|---------------------|
| Standard review flow | **review** |
| Release preparation | **release-notes** |
| Issue triage | **triage** |

### Phase 3: Output Recommendations Report

```markdown
## OpenCode Automation Recommendations

I analyzed the codebase and picked the top automations per category.

### Codebase Profile
- **Type**: [detected language/runtime]
- **Framework**: [detected framework]
- **Key Libraries**: [relevant libraries]

---

### MCP servers

#### context7
**Why**: [specific reason based on detected libraries]
**Config**: add to the `mcp` key in `opencode.json`

---

### Skills

#### [skill id]
**Why**: [specific reason]
**Path**: `.opencode/skills/[id]/SKILL.md`

---

### Permissions

#### [rule group]
**Why**: [specific reason based on detected config]
**Config**: `permissions` in `opencode.json`

---

### Agents

#### [agent id]
**Why**: [specific reason based on codebase patterns]
**Path**: `.opencode/agents/[id].md`

---

### Plugins

#### [plugin id]
**Why**: [specific reason]
**Path**: `.opencode/plugins/[name].js`

---

**Want more?** Ask for additional recommendations for any specific category.

**Want help implementing any of these?** Just ask and I can help you set any of them up.
```

## Decision Framework

### When to recommend MCP servers

External service integration, documentation lookup, browser automation, team tool integration, cloud management.

### When to recommend skills

Repeated prompts or workflows, project-specific tasks with arguments, templates and scripts that should be bundled, procedures that should run in a fresh context.

Use `metadata.opencode/autoinvoke: false` (or `disable-model-invocation: true`) to keep a skill out of the model's advertised list while leaving it loadable by ID.

### When to recommend permissions

Repetitive post-edit actions, protection rules for sensitive files, validation checks, commands with side effects.

### When to recommend agents

Specialized expertise, parallel review workflows, background quality checks, read-only roles.

### When to recommend plugins

Runtime behaviour that config cannot express: reacting to events, intercepting tool calls, rewriting prompts, registering custom tools.

## Configuration Tips

### MCP servers

Check the current list with `opencode mcp list`. Team sharing works by committing `opencode.json` to the repo.

### Headless runs

```bash
opencode run "fix lint errors in src/"
opencode run --format json "summarize the diff" > result.json
opencode run --agent reviewer "check this module"
```

### Hooks live in plugins

OpenCode has no separate hook configuration file. A hook is code in a plugin, registered with `ctx.session.hook`, `ctx.tool.hook`, `ctx.permission.hook`, or `ctx.shell.hook`. See [references/hooks-patterns.md](references/hooks-patterns.md).
