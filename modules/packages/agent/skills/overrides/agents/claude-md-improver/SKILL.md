---
name: claude-md-improver
description: Audit and improve the AGENTS.md files OpenCode loads as project instructions. Use when the user asks to check, audit, update, improve, or fix AGENTS.md, or mentions project instruction or memory hygiene. Scans every AGENTS.md in the repo, scores it against a rubric, reports the gaps, then applies targeted edits after approval.
---

# AGENTS.md Improver

Audit, evaluate, and improve the `AGENTS.md` files in a codebase so OpenCode gets the project context it needs.

OpenCode reads `AGENTS.md` as its instruction file. Instruction files named for other assistants are not loaded, and there is no per-user local override file; use the `instructions` config key for extra files.

**This skill can write to `AGENTS.md` files.** Output the quality report first, get approval, then make targeted edits.

## Where OpenCode looks

| Scope | Path | Notes |
|-------|------|-------|
| Project root | `AGENTS.md` | Checked into git, shared with the team |
| Nested packages | `packages/*/AGENTS.md` | Module-level context in monorepos |
| Subdirectories | any nested `AGENTS.md` | Feature/domain-specific context |
| Global | `~/.config/opencode/AGENTS.md` | Defaults for every project |
| Extra files | `instructions` in `opencode.json` | Additional instruction files, e.g. a personal one |

Instruction files load from lower to higher precedence and project files override global ones. A project `AGENTS.md` does not replace the global file; both are read.

There is no `.local.md` style override. For personal notes that should not be committed, keep them in a separate file and register it:

```jsonc
// opencode.json
{
  "$schema": "https://opencode.ai/config.json",
  "instructions": ["./AGENTS.local.md"]
}
```

Add that path to `.gitignore` and keep the file out of the shared `AGENTS.md`.

## Workflow

### Phase 1: Discovery

Find every instruction file in the repository:

```bash
find . -name "AGENTS.md" -not -path "*/node_modules/*" -not -path "*/.git/*" 2>/dev/null | head -50
ls ~/.config/opencode/AGENTS.md 2>/dev/null
```

Also check what the project already registers:

```bash
grep -n '"instructions"' opencode.json opencode.jsonc 2>/dev/null
```

### Phase 2: Quality Assessment

Score each file against the rubric in [references/quality-criteria.md](references/quality-criteria.md).

| Criterion | Weight | Check |
|-----------|--------|-------|
| Commands/workflows documented | High | Are build/test/deploy commands present? |
| Architecture clarity | High | Can the agent understand the codebase layout? |
| Non-obvious patterns | Medium | Are gotchas and quirks written down? |
| Conciseness | Medium | No verbose explanations or obvious info? |
| Currency | High | Does it match the current codebase? |
| Actionability | High | Are instructions executable, not vague? |

**Grades:**
- **A (90-100)**: comprehensive, current, actionable
- **B (70-89)**: good coverage, minor gaps
- **C (50-69)**: basic info, missing key sections
- **D (30-49)**: sparse or outdated
- **F (0-29)**: missing or severely outdated

### Phase 3: Quality Report

**Always output the report before editing anything.**

```
## AGENTS.md Quality Report

### Summary
- Files found: X
- Average score: X/100
- Files needing update: X

### File-by-File Assessment

#### 1. ./AGENTS.md (project root)
**Score: XX/100 (Grade: X)**

| Criterion | Score | Notes |
|-----------|-------|-------|
| Commands/workflows | X/20 | ... |
| Architecture clarity | X/20 | ... |
| Non-obvious patterns | X/15 | ... |
| Conciseness | X/15 | ... |
| Currency | X/15 | ... |
| Actionability | X/15 | ... |

**Issues:**
- ...

**Recommended additions:**
- ...
```

### Phase 4: Targeted Updates

Get confirmation before editing.

1. **Propose only what pays for itself**: commands discovered while reading the repo, gotchas that are not obvious from the code, package relationships, the test command that actually works, config quirks.
2. **Keep it short**: no restating what the code already says, no generic advice, no one-off fixes.
3. **Show the diff** before applying it:

```markdown
### Update: ./AGENTS.md

**Why:** The build command was missing, so every session started by guessing.

```diff
+ ## Build
+
+ ```bash
+ cargo build --workspace
+ cargo test --workspace
+ ```
```
```

### Phase 5: Apply

Apply the approved edits with the Edit tool, preserving the existing structure and voice of the file.

## Templates

See [references/templates.md](references/templates.md) for `AGENTS.md` templates by project type, and [references/update-guidelines.md](references/update-guidelines.md) for edit rules.

## Common Issues to Flag

1. Stale commands that no longer run
2. Missing dependencies or toolchain versions
3. Outdated architecture after a refactor
4. Missing environment setup (required vars, services)
5. Broken test commands
6. Undocumented gotchas
7. Content that duplicates the README instead of adding to it

## What Makes a Great AGENTS.md

- Concise and human-readable
- Commands that can be pasted and run as-is
- Project-specific facts, not generic advice
- Gotchas and warnings the code cannot express

Useful sections (only the ones that apply): Commands, Architecture, Key files, Code style, Environment, Testing, Gotchas, Workflow.
