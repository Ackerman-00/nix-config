---
name: imessage
description: "Send and read iMessages and SMS with the imsg CLI on macOS. The CLI is not available on this Linux host; use an MCP server or a different channel instead."
---

# iMessage (`imsg`)

`imsg` reads and sends iMessage and SMS through macOS Messages.app.

**Requires macOS.** Messages.app is not on Linux and `imsg` is not installed
here:

```bash
command -v imsg   # not found on this host
```

Do not try to send iMessages from Linux. Say plainly that the capability is
macOS-only, and offer what does work here: an MCP server for a messaging
provider (Signal, Telegram, Matrix) configured under `mcp` in
`opencode.json`, or a webhook into a chat service the user already runs.

## Setup (macOS)

```bash
brew install steipete/tap/imsg
```

Grant Full Disk Access for the terminal (System Settings -> Privacy & Security
-> Full Disk Access) and Automation permission for Messages.app when
prompted. Messages.app must be signed in.

## When to use

- The user asks to send an iMessage or a text.
- Reading iMessage conversation history.
- Checking recent Messages.app chats.
- Sending to a phone number or an Apple ID.

## When not to use

- Telegram, Discord, Slack, WhatsApp: use the matching channel or MCP server.
- Group chat management (adding or removing members): not supported.
- Bulk or mass messaging: always confirm with the user first.

## Commands

```bash
imsg chats --limit 10 --json

imsg history --chat-id 1 --limit 20 --json
imsg history --chat-id 1 --limit 20 --attachments --json

imsg send --to "+14155551212" --text "Hello!"
imsg send --to "+14155551212" --text "Check this out" --file /path/to/image.jpg
imsg send --to "+14155551212" --text "Hi" --service imessage
imsg send --to "+14155551212" --text "Hi" --service sms

imsg watch --chat-id 1 --attachments
```

Service options: `--service imessage` forces iMessage (the recipient needs
it), `--service sms` forces SMS, `--service auto` lets Messages.app decide
(the default).

## Rules

1. Always confirm the recipient and the message content before sending.
2. Never send to an unknown number without explicit approval.
3. Verify attachment paths exist before sending.
4. Do not spam. Rate-limit yourself.

## Example workflow

```bash
# 1. find the chat
imsg chats --limit 20 --json | jq '.[] | select(.displayName | contains("Mom"))'

# 2. confirm with the user
#    "Found Mom at +1555123456. Send 'I'll be late' via iMessage?"

# 3. send after confirmation
imsg send --to "+1555123456" --text "I'll be late"
```
