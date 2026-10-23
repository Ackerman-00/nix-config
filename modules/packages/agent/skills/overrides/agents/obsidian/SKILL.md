---
name: obsidian
description: "Read, search, create, and edit notes in an Obsidian vault from OpenCode using the read, write, and edit tools on the vault directory. Works headless on Linux; the Obsidian app itself is not required."
---

# Obsidian vault

Filesystem-first Obsidian work: read notes, list them, search them, create
them, append, and add wikilinks. The vault is a directory of Markdown, so the
Obsidian desktop app is not needed and nothing here requires a GUI.

## Vault path

Resolve the vault before touching files. Convention: the `OBSIDIAN_VAULT_PATH`
environment variable, for example from `~/.config/opencode/AGENTS.md` or the
shell environment.

```bash
echo "${OBSIDIAN_VAULT_PATH:-$HOME/Documents/Obsidian Vault}"
```

If it is unset, use `~/Documents/Obsidian Vault` when that directory exists.
Otherwise ask the user for the path.

Resolve to a concrete absolute path before calling file tools: they do not
expand shell variables, and vault paths often contain spaces.

## Read a note

Use the `read` tool with the resolved absolute path. It gives line numbers
and pagination, which `cat` does not.

## List notes

Use `glob` with the resolved vault path.

```text
glob(pattern="**/*.md", path="/abs/path/to/vault")
```

For one folder, point `path` at that folder.

## Search

Use `grep` (content) and `glob` (filenames).

```text
grep(pattern="transformer", path="/abs/path/to/vault", include="*.md")
glob(pattern="**/inbox/*.md", path="/abs/path/to/vault")
```

`rg` from the shell works too when you need context lines:

```bash
rg -n "transformer" "$OBSIDIAN_VAULT_PATH" --glob '*.md'
```

## Create a note

Use the `write` tool with the resolved absolute path and the full Markdown
content. It avoids shell quoting problems with paths that contain spaces.

## Append to a note

Read the note first, then use `edit` with a stable anchor (a known heading or
trailing block) to append. Use `write` when rewriting the whole note is
clearer than constructing a patch.

## Targeted edits

Use `edit` when the current content gives you stable context. Fall back to
`write` for a full rewrite.

## Wikilinks

Obsidian links notes with `[[Note Name]]`. Use them when creating notes so
the graph stays connected. Path form for notes in subfolders:
`[[folder/Note Name]]`.

## Vault conventions worth respecting

- Frontmatter with `title`, `created`, `updated`, and `tags`.
- Attachments in a folder such as `assets/`, referenced with `![[image.png]]`.
- Filenames that match the note title, so `[[Title]]` resolves.
- Links between notes rather than duplication of content.

## Relationship to other skills

- `llm-wiki` builds a curated, interlinked knowledge base (a wiki with
  schema, index, and log) and can live in an Obsidian vault.
- The NeuraKeep vault (`~/.local/share/neurakeep/vault`) is the agent's own
  memory store. It is not the user's Obsidian vault; do not mix them.
