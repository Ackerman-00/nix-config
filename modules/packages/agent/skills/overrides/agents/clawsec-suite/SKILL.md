---
name: clawsec-suite
description: "Supply-chain vetting for agent skills in OpenCode: signed advisory-feed monitoring, cryptographic signature and checksum verification, a guarded install that blocks advisory matches until a second explicit confirmation, and approval-gated removal of a flagged skill. Targets OpenCode's skill directories and MCP surface."
---

# ClawSec suite

Watches the installed agent-skill surface against a signed advisory feed and
gates risky installs behind a second, explicit confirmation.

OpenCode's skill directories are the attack surface this suite guards:

```
~/.agents/skills/          # agent-compatible skills (what the skills CLI installs)
~/.config/opencode/skills/ # native OpenCode skills
.opencode/skills/          # project-local skills
```

A skill is Markdown that the model follows. Installing one is equivalent to
granting it instructions.

## What ships in this directory

| Path | Purpose |
|---|---|
| `advisories/feed.json`, `feed.json.sig` | embedded advisory feed plus detached signature |
| `advisories/feed-signing-public.pem` | pinned feed signing key |
| `scripts/` | feed verification, catalog discovery, guarded install |
| `hooks/clawsec-advisory-guardian/opencode-plugin.js` | OpenCode plugin that scans on each prompt |
| `hooks/clawsec-advisory-guardian/handler.ts` | guardian for the previous harness's hook API; not used by OpenCode |

## Install

```bash
npx skills add prompt-security/clawsec -s clawsec-suite -g -a opencode -y --copy
```

That installs into `~/.agents/skills/clawsec-suite`.

## Install the advisory guardian as an OpenCode plugin

The guardian is a plugin, not a hook file: OpenCode plugins live in
`~/.config/opencode/plugins/` and are auto-loaded.

```bash
mkdir -p ~/.config/opencode/plugins
cp hooks/clawsec-advisory-guardian/opencode-plugin.js ~/.config/opencode/plugins/clawsec-advisory-guardian.js
```

Then verify it loaded:

```bash
opencode plugin list
```

The plugin hooks `ctx.session.hook("prompt", ...)`. On each prompt it:

1. loads the remote feed (or the embedded local fallback),
2. verifies the detached signature and the checksum manifest,
3. discovers the skills installed in the directories listed above,
4. matches advisories against installed skill names and versions,
5. posts a synthetic message when a new match appears.

It never deletes or modifies a skill. It only reports.

## Advisory feed verification

Defaults:

| Item | Value |
|---|---|
| Remote feed | `https://clawsec.prompt.security/advisories/feed.json` |
| Remote signature | `${CLAWSEC_FEED_URL}.sig` |
| Remote checksums | sibling `checksums.json` |
| Local seed feed | `<suite>/advisories/feed.json` |
| Pinned public key | `<suite>/advisories/feed-signing-public.pem` |
| State file | `~/.config/opencode/clawsec-suite-feed-state.json` |
| Scan interval | `CLAWSEC_HOOK_INTERVAL_SECONDS`, default 300 |

Signature verification is **fail-closed**: the feed signature is required.
`CLAWSEC_ALLOW_UNSIGNED_FEED=1` is a temporary migration bypass only.
`CLAWSEC_VERIFY_CHECKSUM_MANIFEST=0` disables checksum verification and
should stay off.

Manual feed check:

```bash
FEED_URL="${CLAWSEC_FEED_URL:-https://clawsec.prompt.security/advisories/feed.json}"
STATE_FILE="${CLAWSEC_SUITE_STATE_FILE:-$HOME/.config/opencode/clawsec-suite-feed-state.json}"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

curl -fsSLo "$TMP/feed.json" "$FEED_URL"
jq -e '.version and (.advisories | type == "array")' "$TMP/feed.json" >/dev/null \
  || { echo "ERROR: invalid advisory feed format" >&2; exit 1; }

mkdir -p "$(dirname "$STATE_FILE")"
[ -f "$STATE_FILE" ] || echo '{"schema_version":"1.0","known_advisories":[],"last_feed_check":null}' > "$STATE_FILE"

jq -r --slurpfile state "$STATE_FILE" \
  '($state[0].known_advisories // []) as $known | [.advisories[]?.id | select(. != null and ($known | index(.) | not))] | .[]?' \
  "$TMP/feed.json" > "$TMP/new_ids.txt"

if [ -s "$TMP/new_ids.txt" ]; then
  echo "New advisories detected:"
  while IFS= read -r id; do
    [ -z "$id" ] && continue
    jq -r --arg id "$id" '.advisories[] | select(.id == $id) | "- [\(.severity | ascii_upcase)] \(.id): \(.title)"' "$TMP/feed.json"
  done < "$TMP/new_ids.txt"
else
  echo "FEED_OK - no new advisories"
fi
```

### Scope note

Advisories carry a `platforms` array. The embedded feed's entries currently
target the `openclaw` platform and affected ids like `openclaw@*`; the
OpenCode plugin only acts on advisories whose `platforms` include
`opencode`, `all`, or `skills`, or that carry no `platforms` field. Expect
no matches until the feed publishes OpenCode-scoped advisories. That is the
correct behaviour, not a broken plugin.

## Guarded install (double confirmation)

```bash
SUITE_DIR="${INSTALL_ROOT:-$HOME/.agents/skills}/clawsec-suite"

# first attempt: advisory check only
node "$SUITE_DIR/scripts/guarded_skill_install.mjs" --skill helper-plus --source owner/repo

# second attempt, only after the user approves with the advisory in hand
node "$SUITE_DIR/scripts/guarded_skill_install.mjs" --skill helper-plus --source owner/repo --confirm-advisory
```

- Exit code 42 means an advisory matched: the install has not happened.
- `--source` is the `owner/repo` on the skills.sh registry. It is required
  because the `skills` CLI installs from a repository, not from a bare name.
- Without `--version`, matching is conservative: any advisory referencing the
  skill name counts.
- `--dry-run` performs the advisory check and stops before installing.

The install itself runs:

```bash
npx skills add <owner>/<repo> -s <skill> -g -a opencode -y --copy
```

## Approval-gated response

If an advisory indicates a malicious or removal-recommended skill and that
skill is installed:

1. Tell the user immediately: advisory id, severity, title, and the affected
   skill with its path.
2. Recommend removal or disabling the skill.
3. Treat the original install request as first intent only.
4. Require an explicit second confirmation before deleting or disabling.
5. Only then act, and report exactly what was removed.

The suite never deletes on its own. Neither should the agent.

## Advisory suppression

Reviewed advisories can be suppressed for a deployment.

Resolution order:

1. explicit `--config <path>`
2. `OPENCODE_AUDIT_CONFIG` environment variable
3. `~/.config/opencode/security-audit.json`
4. `.clawsec/allowlist.json` in the working directory

```json
{
  "enabledFor": ["advisory"],
  "suppressions": [
    {
      "checkId": "CVE-2026-25593",
      "skill": "clawsec-suite",
      "reason": "First-party security tooling, reviewed by the security team",
      "suppressedAt": "2026-02-15"
    }
  ]
}
```

The `enabledFor` array is the gate. If it does not contain `"advisory"`,
nothing is suppressed. Matching requires both the advisory id to equal
`checkId` and the skill name to match case-insensitively.

## Exploitability context

Feed entries may carry `exploitability_score` (`high`, `medium`, `low`,
`unknown`) and `exploitability_rationale`. Prioritise by exploitability as
well as severity: a HIGH severity advisory with LOW exploitability is less
urgent than a CRITICAL one with HIGH exploitability.

## Security notes

- Verify the checksum manifest signature before trusting any URL or hash in
  it, then verify each file checksum.
- Keep polling rate-limited to at least 5 minutes between checks.
- Treat `critical` and `high` advisories against installed skills as
  immediate action items.
- Pin and verify public key fingerprints out of band on first use.
- Do not enable `CLAWSEC_ALLOW_UNSIGNED_FEED` outside a short migration
  window.
