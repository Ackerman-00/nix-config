---
name: apple-notes
description: "Manage Apple Notes with the memo CLI: list, search, create, edit, move, delete, and export notes. Requires macOS with the Notes app; the CLI is not available on this Linux host."
---

# Apple Notes (`memo`)

`memo` manages Apple Notes from the terminal. Notes sync across Apple devices
through iCloud.

**Requires macOS.** The Notes store is not reachable from Linux and `memo` is
not installed here:

```bash
command -v memo   # not found on this host
```

For Markdown-native notes on Linux, use a plain directory of `.md` files (the
`obsidian` skill covers a vault) or the NeuraKeep vault. Say which one you
recommend rather than pretending the Apple tooling is reachable.

## Setup (macOS)

```bash
brew tap antoniorodr/memo && brew install antoniorodr/memo/memo
```

Grant Automation access to Notes.app when prompted (System Settings ->
Privacy & Security -> Automation).

## When to use

- The user asks to create, view, or search Apple Notes.
- Saving something to Notes.app for cross-device access.
- Organising notes into folders.
- Exporting notes to Markdown or HTML.

## When not to use

- Obsidian vault management: use the `obsidian` skill.
- Agent-internal notes: use the NeuraKeep vault.
- Bear Notes and other apps: not supported here.

## Quick reference

```bash
memo notes                        # list all notes
memo notes -f "Folder Name"       # filter by folder
memo notes -s "query"             # fuzzy search

memo notes -a                     # add a note (opens $EDITOR)
memo notes -a -f "Folder Name"    # add into a specific folder

memo notes -e                     # interactive selection to edit
memo notes -d                     # interactive selection to delete
memo notes -m                     # move a note to a folder
memo notes -ex                    # export to HTML/Markdown
```

`-a` / `--add` is a bare flag: it opens your `$EDITOR` to compose the note and
does not take a title argument. Use `-f` / `--folder` to target a folder, and
set `$EDITOR` first (for example `export EDITOR=vim`).

## Limitations

- Cannot edit notes containing images or attachments.
- Interactive prompts need a terminal (use `pty=true` when needed).
- macOS only: it needs Notes.app.

## Rules

1. Prefer Apple Notes when the user wants cross-device sync.
2. Use the NeuraKeep vault for agent-internal notes that do not need to sync.
3. Use the `obsidian` skill for Markdown-native knowledge management.
