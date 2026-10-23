---
name: clawsec-advisory-guardian
description: Detect advisory matches for installed skills and require explicit user approval before any removal action.
---

# ClawSec advisory guardian (OpenCode plugin)

OpenCode loads this package as a plugin, not as a hook file. Install it with:

```bash
node scripts/setup_advisory_hook.mjs
```

which copies `opencode-plugin.js` into `~/.config/opencode/plugins/`.

Trigger: `ctx.session.hook("prompt", ...)`, rate-limited by
`CLAWSEC_HOOK_INTERVAL_SECONDS` (default 300).

What it does on each prompt:

- loads the signed advisory feed (remote, falling back to the embedded copy),
- verifies the detached signature and the checksum manifest,
- discovers the skills installed under `~/.agents/skills`,
  `~/.config/opencode/skills`, and `~/.opencode/skills`,
- matches advisories against installed skill names and versions,
- posts a synthetic message for matches it has not reported before.

Safety contract:

- The plugin never deletes or modifies a skill.
- It only reports findings and asks for approval.
- Alerts are deduplicated using
  `~/.config/opencode/clawsec-suite-feed-state.json`.

Optional environment variables:

- `CLAWSEC_FEED_URL`: override the remote feed URL.
- `CLAWSEC_FEED_SIG_URL`: override the detached remote signature URL.
- `CLAWSEC_FEED_CHECKSUMS_URL`: override the checksum manifest URL.
- `CLAWSEC_FEED_CHECKSUMS_SIG_URL`: override the manifest signature URL.
- `CLAWSEC_FEED_PUBLIC_KEY`: path to the pinned feed signing key PEM.
- `CLAWSEC_LOCAL_FEED`, `CLAWSEC_LOCAL_FEED_SIG`,
  `CLAWSEC_LOCAL_FEED_CHECKSUMS`, `CLAWSEC_LOCAL_FEED_CHECKSUMS_SIG`: local
  fallback paths.
- `CLAWSEC_VERIFY_CHECKSUM_MANIFEST`: set to `0` only for troubleshooting.
- `CLAWSEC_ALLOW_UNSIGNED_FEED`: set to `1` only for a short migration window.
- `CLAWSEC_SUITE_STATE_FILE`: override the state file path.
- `CLAWSEC_SUITE_DIR`: override the suite install path.
- `CLAWSEC_HOOK_INTERVAL_SECONDS`: minimum interval between scans (default 300).
- `OPENCODE_AUDIT_CONFIG`: path to the suppression config.
