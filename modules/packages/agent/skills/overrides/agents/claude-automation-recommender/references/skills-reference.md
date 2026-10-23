# Skills for OpenCode

A skill is packaged expertise: instructions plus optional scripts, references, and templates. OpenCode advertises skills by ID, name, and description; the model loads the body only when the skill is relevant.

## Where skills live

| Scope | Path |
|-------|------|
| Global | `~/.config/opencode/skills/<id>/SKILL.md` |
| Global (shared) | `~/.agents/skills/<id>/SKILL.md` |
| Project | `.opencode/skills/<id>/SKILL.md` |
| Project (shared) | `.agents/skills/<id>/SKILL.md` |

OpenCode also discovers skills from a legacy Claude-compatible directory at the user and project level. The paths above are the ones to create skills in.

The **skill ID is the path-derived directory name**, not the frontmatter `name`. The model loads a skill by calling the `skill` tool with the exact ID, or by mentioning `@skill-id` in a prompt.

## Layout

```
.opencode/skills/
└── api-doc/
    ├── SKILL.md           # required
    ├── openapi-template.yaml
    └── scripts/
        └── validate.sh
```

Paths written inside a skill are relative to the directory holding `SKILL.md`.

## Frontmatter

```yaml
---
name: api-doc
description: Generate OpenAPI documentation for an endpoint. Use when documenting API routes.
metadata:
  opencode/autoinvoke: false
---
```

| Field | Effect |
|-------|--------|
| `name` | Display label. Defaults to the path-derived ID. |
| `description` | What the model sees when deciding whether to load the skill. |
| `metadata.opencode/autoinvoke: false` | Hide the skill from the model's available list. |
| `disable-model-invocation: true` | Same effect. `opencode/autoinvoke` wins when both are set. |
| `license`, `compatibility` | Accepted, ignored by OpenCode. |

## Invocation control

| Setting | User can load | Model can load | Use for |
|---------|---------------|----------------|---------|
| default | yes | yes | general-purpose skills |
| `opencode/autoinvoke: false` | yes | no | side effects: deploy, commit, send |
| `disable-model-invocation: true` | yes | no | same, older spelling |

A hidden skill stays registered and can still be loaded explicitly by ID.

## Permission control

Skill access is gated with the `skill` action and the skill ID as the resource:

```jsonc
{
  "permissions": [
    { "action": "skill", "resource": "*", "effect": "allow" },
    { "action": "skill", "resource": "deploy-*", "effect": "ask" },
    { "action": "skill", "resource": "internal-*", "effect": "deny" },
  ],
}
```

A `deny` hides the skill from the model and rejects loading it.

## Example skills to build for a project

| Codebase signal | Skill ID | Bundles |
|-----------------|----------|---------|
| API routes | `api-doc` | OpenAPI template |
| Database project | `create-migration` | validation script |
| Test suite | `gen-test` | example tests |
| Component library | `new-component` | component templates |
| PR workflow | `pr-check` | checklist |
| Releases | `release-notes` | git context script |
| Code style | `project-conventions` | style rules |
| Onboarding | `setup-dev` | prerequisite script |

### api-doc

```
.opencode/skills/api-doc/
├── SKILL.md
└── openapi-template.yaml
```

```markdown
---
name: api-doc
description: Generate OpenAPI documentation for an endpoint. Use when documenting API routes.
---

Generate OpenAPI documentation for the endpoint the user names.

1. Read the endpoint code.
2. Extract path, method, parameters, request and response schemas.
3. Fill in [openapi-template.yaml](openapi-template.yaml).
4. Output the completed YAML.
```

### create-migration

```
.opencode/skills/create-migration/
├── SKILL.md
└── scripts/validate-migration.sh
```

```markdown
---
name: create-migration
description: Create a database migration file for this project.
metadata:
  opencode/autoinvoke: false
---

1. Create the migration file in `migrations/` with a timestamp prefix.
2. Include up and down functions.
3. Run `bash scripts/validate-migration.sh` and report any findings.
```

### gen-test

```
.opencode/skills/gen-test/
├── SKILL.md
└── examples/
```

```markdown
---
name: gen-test
description: Write a test that matches the project's existing test style.
---

1. Read the closest existing test for the target module.
2. Copy its structure, naming, and assertion style.
3. Cover the happy path plus one failure case.
4. Run the single test file and report the result.
```

### pr-check

```
.opencode/skills/pr-check/
└── SKILL.md
```

```markdown
---
name: pr-check
description: Prepare a pull request for review. Use before opening a PR.
metadata:
  opencode/autoinvoke: false
---

1. Run the project test command.
2. Run the formatter and linter.
3. Summarise the diff in three lines: what changed, why, how it was verified.
4. List anything you could not verify.
```

## Writing guidance

- Put all "when to use this" information in the `description`. The body is only read after the skill is chosen.
- Keep `SKILL.md` under roughly 500 lines; move detail into `references/` and point to it.
- Reference bundled files by relative path so the agent can find them.
- Prefer imperative instructions over prose.
- Explain why a step matters; it survives contact with a different codebase.
- Never put secrets in a skill. Keep destructive operations behind `opencode/autoinvoke: false`.
