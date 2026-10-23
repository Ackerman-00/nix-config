---
name: google-workspace
description: "Gmail, Calendar, Drive, Contacts, Sheets and Docs on Linux via the gws/gog CLI, a bundled Python client, or a Google Workspace MCP server configured in opencode.json. Covers OAuth setup, non-interactive search and send, and the rules for safe writes. Requires the CLI or an MCP server; none is installed by default."
---

# Google Workspace

Gmail, Calendar, Drive, Contacts, Sheets, and Docs.

**Prerequisite on this host:** nothing is installed yet. Pick a backend and
install or configure it before doing any work:

| Backend | Status here | Setup |
|---|---|---|
| `gws` CLI | not installed | see the `gog` skill |
| `gog` CLI | not installed | see the `gog` skill |
| bundled Python client | present in `scripts/` | needs Python deps and OAuth |
| MCP server | not configured | add a `mcp` entry to `opencode.json` |

```bash
command -v gws gog python3
opencode mcp list
```

## References

- `references/gmail-search-syntax.md` — Gmail search operators.
- `references/daily-brief.md` — morning brief: schedule, conflicts, meeting prep,
  urgent mail. Load it for "morning brief" or "what's on my calendar".

## Scripts

- `scripts/setup.py` — OAuth2 setup (run once to authorise).
- `scripts/google_api.py` — CLI wrapper. Prefers `gws` when it is on PATH and
  falls back to the bundled Python client. JSON output either way.
- `scripts/gws_bridge.py` — shim that points `gws` at the same token file.

## Setup

Short form:

```bash
GSETUP="python3 ~/.agents/skills/google-workspace/scripts/setup.py"
$GSETUP --check            # prints AUTHENTICATED when ready
```

Full OAuth, step by step. The setup is non-interactive so it works from a
terminal, an IDE, or a scheduled job.

### Step 1: ask what is needed

- **Email only** — skip this skill. Use an IMAP/Gmail App Password flow
  instead; it takes two minutes and needs no Cloud project.
- **Email + Calendar** — authorise with `--services email,calendar`.
- **Calendar/Drive/Sheets/Docs only** — `--services calendar,drive,sheets,docs`.
- **Everything** — `--services all`.

Also ask whether the account is enrolled in Advanced Protection (hardware
security keys required). If it is, the Workspace admin must add the OAuth
client ID to the allowed-apps list before authorisation succeeds.

### Step 2: create OAuth credentials (one-time, about 5 minutes)

Tell the user:

> 1. Create or select a project:
>    https://console.cloud.google.com/projectselector2/home/dashboard
> 2. Enable the APIs in the library:
>    https://console.cloud.google.com/apis/library
>    Gmail API, Google Calendar API, Google Drive API, Google Sheets API,
>    Google Docs API, People API
> 3. Create an OAuth client:
>    https://console.cloud.google.com/apis/credentials
>    Credentials -> Create Credentials -> OAuth 2.0 Client ID
> 4. Application type: "Desktop app" -> Create
> 5. If the app is in Testing, add the account as a test user:
>    https://console.cloud.google.com/auth/audience
> 6. Download the JSON file and tell me the path

### Step 3: get the authorisation URL

```bash
$GSETUP --auth-url --services email,calendar --format json
$GSETUP --auth-url --services calendar,drive,sheets,docs --format json
$GSETUP --auth-url --services all --format json
```

Send the `auth_url` from the JSON as one line. Tell the user the browser will
likely fail on `http://localhost:1` after approval and that is expected, and
that they should copy the entire redirected URL back.

`Error 403: access_denied` means the account is not a test user for the app.
Send them to the audience page.

### Step 4: exchange the code

```bash
$GSETUP --auth-code "THE_URL_OR_CODE_THE_USER_PASTED" --format json
```

If the code expired or was already used, the command returns a fresh
`fresh_auth_url`. Send the new URL and retry with the newest redirect only.

### Step 5: verify

```bash
$GSETUP --check     # AUTHENTICATED
```

Token file: `~/.config/opencode/google_token.json` (refreshes automatically).
Pending OAuth state: `~/.config/opencode/google_oauth_pending.json`, removed
once the exchange completes.

## Usage

```bash
GAPI="python3 ~/.agents/skills/google-workspace/scripts/google_api.py"
```

### Gmail

```bash
$GAPI gmail search "is:unread" --max 10
$GAPI gmail search "from:boss@company.com newer_than:1d"
$GAPI gmail search "has:attachment filename:pdf newer_than:7d"
$GAPI gmail get MESSAGE_ID
$GAPI gmail send --to user@example.com --subject "Hello" --body "Message text"
$GAPI gmail send --to user@example.com --subject "Report" --body "<p>Q4</p>" --html
$GAPI gmail reply MESSAGE_ID --body "Thanks, that works for me."
$GAPI gmail labels
$GAPI gmail modify MESSAGE_ID --add-labels LABEL_ID
$GAPI gmail modify MESSAGE_ID --remove-labels UNREAD
```

### Calendar

```bash
$GAPI calendar list
$GAPI calendar list --start 2026-03-01T00:00:00Z --end 2026-03-07T23:59:59Z
$GAPI calendar create --summary "Team Standup" --start 2026-03-01T10:00:00-06:00 --end 2026-03-01T10:30:00-06:00
$GAPI calendar create --summary "Review" --start 2026-03-01T14:00:00Z --end 2026-03-01T15:00:00Z --attendees "alice@co.com,bob@co.com"
$GAPI calendar delete EVENT_ID
```

### Drive

```bash
$GAPI drive search "quarterly report" --max 10
$GAPI drive get FILE_ID
$GAPI drive upload /path/to/report.pdf
$GAPI drive download DOC_ID --export-mime text/plain --output ~/doc.txt
$GAPI drive create-folder "Reports"
$GAPI drive share FILE_ID --email alice@example.com --role reader
$GAPI drive delete FILE_ID              # trashes by default
$GAPI drive delete FILE_ID --permanent  # skips the trash
```

### Contacts, Sheets, Docs

```bash
$GAPI contacts list --max 20
$GAPI sheets create --title "Q4 Budget"
$GAPI sheets get SHEET_ID "Sheet1!A1:D10"
$GAPI sheets update SHEET_ID "Sheet1!A1:B2" --values '[["Name","Score"],["Alice","95"]]'
$GAPI sheets append SHEET_ID "Sheet1!A:C" --values '[["new","row","data"]]'
$GAPI docs get DOC_ID
$GAPI docs create --title "Meeting Notes"
$GAPI docs append DOC_ID --text "Additional content"
```

## Output format

All commands return JSON. Key fields:

- Gmail search: `[{id, threadId, from, to, subject, date, snippet, labels}]`
- Gmail get: `{id, threadId, from, to, subject, date, labels, body}`
- Gmail send/reply: `{status: "sent", id, threadId}`
- Calendar list: `[{id, summary, start, end, location, description, htmlLink}]`
- Calendar create: `{status: "created", id, summary, htmlLink}`
- Drive search: `[{id, name, mimeType, modifiedTime, webViewLink}]`
- Drive upload: `{status: "uploaded", id, name, mimeType, webViewLink}`
- Drive download: `{status: "downloaded", id, name, path, mimeType}`
- Drive share: `{status: "shared", permissionId, fileId, role, type}`
- Drive delete: `{status: "trashed" | "deleted", fileId, permanent}`
- Contacts list: `[{name, emails: [...], phones: [...]}]`
- Sheets get: `[[cell, ...], ...]`
- Sheets create: `{status: "created", spreadsheetId, title, spreadsheetUrl}`
- Docs create: `{status: "created", documentId, title, url}`
- Docs append: `{status: "appended", documentId, inserted_at, characters}`

## Rules

1. **Never send mail, create or delete calendar events, delete Drive files,
   share files, or edit Docs and Sheets without confirming first.** Show the
   recipients, IDs, content, and share role, then ask. For Drive deletes,
   prefer the default trash.
2. **Check auth before first use.** Run `setup.py --check`.
3. **Use the Gmail search reference** for complex queries.
4. **Calendar times must include a timezone.** ISO 8601 with an offset
   (`2026-03-01T10:00:00-06:00`) or `Z`.
5. **Respect rate limits.** Batch reads; do not fire rapid sequential calls.
6. **Never ask for a client secret, refresh token, or password in chat.**

## Troubleshooting

| Problem | Fix |
|---|---|
| `NOT_AUTHENTICATED` | run setup steps 2-5 |
| `REFRESH_FAILED` | token revoked or expired; redo steps 3-5 |
| `HttpError 403: Insufficient Permission` | missing scope; `$GSETUP --revoke` then redo 3-5 |
| `AUTHENTICATED (partial)` | new write scopes need re-authorisation; revoke and redo |
| `HttpError 403: Access Not Configured` | the API is not enabled in the Cloud project |
| `ModuleNotFoundError` | install the Python dependencies the script needs |
| Advanced Protection blocks auth | admin must allowlist the OAuth client ID |

## Revoking access

```bash
$GSETUP --revoke
```
