---
name: apple-reminders
description: "List, add, edit, complete, or delete Apple Reminders and reminder lists with the remindctl CLI. Requires macOS with the Reminders app; the CLI is not available on this Linux host."
---

# Apple Reminders (remindctl)

`remindctl` manages Apple Reminders from the terminal.

**Requires macOS.** The Reminders database is not reachable from Linux and
`remindctl` is not installed here:

```bash
command -v remindctl   # not found on this host
```

Say so plainly and offer the alternatives: a local task file the user syncs
with their phone, or a scheduled OpenCode reminder (a systemd timer or a
scheduled task) instead of a Reminders entry.

## Setup (macOS)

```bash
brew install steipete/tap/remindctl
remindctl status
remindctl authorize      # grant Reminders permission when prompted
```

## When to use

- The user explicitly mentions "reminder" or the Reminders app.
- Personal to-dos with due dates that should sync to iOS.
- Managing Reminders lists.

## When not to use

- Scheduling an OpenCode-side job or alert: use a systemd timer or a
  scheduled task, not a Reminders entry.
- Calendar events or appointments.
- Project or work task tracking: use GitHub Issues or a real task queue.
- A one-off notification: use a scheduled task.

## Commands

```bash
remindctl                    # today's reminders
remindctl today
remindctl tomorrow
remindctl week
remindctl overdue
remindctl all
remindctl 2026-01-04         # specific date

remindctl list               # all lists
remindctl list Work          # one list
remindctl list Projects --create
remindctl list Work --delete

remindctl add "Buy milk"
remindctl add --title "Call mom" --list Personal --due tomorrow
remindctl add --title "Meeting prep" --due "2026-02-15 09:00"

remindctl complete 1 2 3
remindctl delete 4A83 --force

remindctl today --json       # machine readable
remindctl today --plain      # TSV
remindctl today --quiet      # counts only
```

## Date formats

Accepted by `--due` and the date filters: `today`, `tomorrow`, `yesterday`,
`YYYY-MM-DD`, `YYYY-MM-DD HH:mm`, ISO 8601 (`2026-01-04T12:34:56Z`).

## Clarifying intent

"Remind me to check on the deploy in 2 hours" is ambiguous. Ask: should this
be a Reminders entry that syncs to the phone, or an alert from OpenCode that
messages the user here? Reminders entry: use this skill. Alert: use a
scheduled task.
