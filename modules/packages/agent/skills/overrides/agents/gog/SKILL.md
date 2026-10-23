---
name: gog
description: "Drive Google Workspace (Gmail, Calendar, Drive, Contacts, Sheets, Docs) from the gog CLI on Linux or macOS. Covers OAuth setup, non-interactive search and send, calendar and Drive commands, and sheet/doc handling. Requires the gog binary; it is not installed on this Linux host."
---

# gog

`gog` is a Google Workspace CLI: Gmail, Calendar, Drive, Contacts, Sheets, and
Docs from the terminal.

**Not available on this host.** `gog` is not installed and no Google
Workspace MCP server is configured. Check before promising anything:

```bash
command -v gog gws
opencode mcp list
```

If the user is on macOS or has installed it elsewhere, the commands below
apply unchanged. Otherwise, point them at the `google-workspace` skill
(bundled Python client) or an MCP server.

## Setup

Prefer an already-authorised account: run the requested `gog` command first
and only enter setup after an authentication error. Never ask for passwords,
client secrets, or refresh tokens in chat.

```bash
gog auth credentials /path/to/client_secret.json
gog auth add you@gmail.com --services gmail,calendar,drive,contacts,docs,sheets
gog auth list
gog auth doctor
```

Inspect every entry `gog auth list --check` reports; its exit status does not
prove every stored token is valid. Read the status `gog auth doctor` prints
rather than only its exit code.

### Headless hosts

When the host has no browser:

1. Prefer a live callback listener on the host. From the machine with the
   browser, forward the callback port
   (`ssh -L <port>:127.0.0.1:<port> user@gateway-host`), open the URL `gog`
   prints, and let the redirect complete on that forwarded port.
2. Otherwise the operator picks one paste-mode path in a trusted shell:
   - `--manual`: the operator pastes the full redirect URL into `gog`'s
     interactive prompt.
   - `--remote --step 1`: prints `auth_url` (and `state_reused`) then exits.
     After consent, run `--remote --step 2 --auth-url <callback-url>` in the
     same trusted shell. A failed `localhost` page load after consent is
     expected.
3. Keep the resolved config context across the steps: `GOG_CONFIG_DIR` beats
   `--home`, which beats `GOG_HOME`. Preserve `--client`, services/scopes,
   redirect URI, and consent options.
4. If the desktop keyring is unavailable, use the file backend
   (`gog auth keyring file`) and set `GOG_KEYRING_PASSWORD` in the host
   environment so non-interactive runs can read the tokens. `gog auth doctor`
   reports a missing password.
5. A received callback is not a stored token. If the exchange or identity
   lookup fails behind a proxy, restart from step 1 after the operator
   approves scoped egress. Do not bypass host network policy or reuse failed
   or expired state.

## Commands

```bash
# Gmail
gog gmail search 'newer_than:7d' --max 10
gog gmail messages search "in:inbox from:ryanair.com" --max 20 --account you@example.com
gog gmail send --to a@b.com --subject "Hi" --body "Hello"
gog gmail send --to a@b.com --subject "Hi" --body-file ./message.txt
gog gmail send --to a@b.com --subject "Hi" --body-file -
gog gmail send --to a@b.com --subject "Hi" --body-html "<p>Hello</p>"
gog gmail drafts create --to a@b.com --subject "Hi" --body-file ./message.txt
gog gmail drafts send <draftId>
gog gmail send --to a@b.com --subject "Re: Hi" --body "Reply" --reply-to-message-id <msgId>

# Calendar
gog calendar events <calendarId> --from <iso> --to <iso>
gog calendar create <calendarId> --summary "Title" --from <iso> --to <iso>
gog calendar create <calendarId> --summary "Title" --from <iso> --to <iso> --event-color 7
gog calendar update <calendarId> <eventId> --summary "New Title" --event-color 4
gog calendar colors

# Drive, Contacts
gog drive search "query" --max 10
gog contacts list --max 20

# Sheets
gog sheets get <sheetId> "Tab!A1:D10" --json
gog sheets update <sheetId> "Tab!A1:B2" --values-json '[["A","B"],["1","2"]]' --input USER_ENTERED
gog sheets append <sheetId> "Tab!A:C" --values-json '[["x","y","z"]]' --insert INSERT_ROWS
gog sheets clear <sheetId> "Tab!A2:Z"
gog sheets metadata <sheetId> --json

# Docs
gog docs export <docId> --format txt --out /tmp/doc.txt
gog docs cat <docId>
```

## Calendar colors

`gog calendar colors` lists the available event colors (ids 1-11):

| id | hex | id | hex |
|---|---|---|---|
| 1 | #a4bdfc | 7 | #46d6db |
| 2 | #7ae7bf | 8 | #e1e1e1 |
| 3 | #dbadff | 9 | #5484ed |
| 4 | #ff887c | 10 | #51b749 |
| 5 | #fbd75b | 11 | #dc2127 |
| 6 | #ffb878 | | |

## Email formatting

- Prefer plain text. Use `--body-file` for multi-paragraph messages, or
  `--body-file -` to read stdin.
- `--body` does not unescape `\n`. For inline newlines use a heredoc or
  `$'Line 1\n\nLine 2'`.
- `--body-html` only when rich formatting is needed. Tags: `<p>`, `<br>`,
  `<strong>`, `<em>`, `<a href>`, `<ul>`/`<li>`.

Plain-text body from stdin:

```bash
gog gmail send --to recipient@example.com \
  --subject "Meeting Follow-up" \
  --body-file - <<'MAILBODY'
Hi Name,

Thanks for meeting today. Next steps:
- Item one
- Item two

Best regards,
Your Name
MAILBODY
```

## Notes

- Set `GOG_ACCOUNT=you@gmail.com` to avoid repeating `--account`.
- For scripting, prefer `--json` plus `--no-input`.
- Sheets values: `--values-json` (recommended) or inline rows.
- Docs supports export, cat, and copy. In-place edits need a Docs API client,
  not `gog`.
- `gog gmail search` returns one row per thread. Use `gog gmail messages
  search` when every individual email must be returned separately.
