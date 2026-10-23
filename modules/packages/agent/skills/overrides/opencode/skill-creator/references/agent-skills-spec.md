# Agent Skills specification

Condensed from the canonical spec at <https://agentskills.io/specification>. This is the
format every `SKILL.md` must satisfy, whatever harness loads it.

## Directory structure

```
skill-name/
├── SKILL.md          # Required: metadata + instructions
├── scripts/          # Optional: executable code
├── references/       # Optional: documentation
├── assets/           # Optional: templates, resources
```

`SKILL.md` is the only required file. A skill may be a single `SKILL.md` with no
subdirectories.

## Frontmatter

YAML frontmatter followed by the Markdown body. All fields are optional at runtime, but
a skill without `name` or `description` is not discoverable and will not be advertised
to the model.

| Field | Required | Constraints |
| --- | --- | --- |
| `name` | Yes | 1-64 characters. Lowercase letters, numbers and hyphens only. No leading, trailing or doubled hyphen. Must match the parent directory name. |
| `description` | Yes | 1-1024 characters. Must describe both what the skill does and when to use it. Include the keywords that let a model recognise the trigger. |
| `license` | No | A license name, or a path to a bundled license file. |
| `compatibility` | No | Max 500 characters. Only when the skill has environment requirements. |
| `metadata` | No | Arbitrary key-value map for client-specific data. Use namespaced keys to avoid collisions. |
| `allowed-tools` | No | Space-separated pre-approved tools. Experimental; support varies by client. |

A `name` that differs from the directory name is a spec violation even when the loader
tolerates it. A `description` that only says what the skill does, and not when to reach
for it, will not trigger.

## Body

No format restrictions. Recommended sections: step-by-step instructions, examples of
inputs and outputs, common edge cases.

The body is loaded in full once the skill activates. Move detail into `references/` and
link to it, so the body stays small.

## Progressive disclosure

| Layer | Budget |
| --- | --- |
| Metadata (`name`, `description`) | ~100 tokens, loaded at startup for every skill |
| Instructions (the `SKILL.md` body) | under 5000 tokens recommended |
| Resources (`references/`, `scripts/`, `assets/`) | loaded only when the skill needs them |

Keep `SKILL.md` under 500 lines. Split longer content into referenced files.

## File references

Use paths relative to the skill root, and keep references one level deep. Avoid chains
of nested reference links.

```markdown
See [the reference guide](references/REFERENCE.md) for details.
```

## Validation

```bash
skills-ref validate ./my-skill
```

This checks the frontmatter is valid and that the naming conventions hold. Run it on
every skill you author or edit.
