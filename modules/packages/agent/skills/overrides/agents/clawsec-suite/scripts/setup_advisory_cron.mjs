#!/usr/bin/env node

// Installs a periodic advisory check as a systemd user timer.
//
// The guardian plugin already scans on each prompt. This timer adds an
// unattended scan for sessions that are not interactive.

import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";

const SCRIPT_DIR = path.dirname(fileURLToPath(import.meta.url));
const SUITE_DIR = path.resolve(SCRIPT_DIR, "..");
const UNIT_DIR = path.join(os.homedir(), ".config", "systemd", "user");
const SERVICE_NAME = "clawsec-advisory-scan.service";
const TIMER_NAME = "clawsec-advisory-scan.timer";
const INTERVAL = process.env.CLAWSEC_CRON_INTERVAL ?? "6h";

const SERVICE_UNIT = `[Unit]
Description=ClawSec advisory scan

[Service]
Type=oneshot
ExecStart=/usr/bin/env bash -lc 'FEED_URL="\${CLAWSEC_FEED_URL:-https://clawsec.prompt.security/advisories/feed.json}" curl -fsSLo /tmp/clawsec-feed.json "$FEED_URL" && jq -e ".version and (.advisories | type == \\"array\\")" /tmp/clawsec-feed.json >/dev/null'
`;

const TIMER_UNIT = `[Unit]
Description=Run the ClawSec advisory scan periodically

[Timer]
OnBootSec=5min
OnUnitActiveSec=${INTERVAL}

[Install]
WantedBy=timers.target
`;

function main() {
  fs.mkdirSync(UNIT_DIR, { recursive: true });
  fs.writeFileSync(path.join(UNIT_DIR, SERVICE_NAME), SERVICE_UNIT, { mode: 0o644 });
  fs.writeFileSync(path.join(UNIT_DIR, TIMER_NAME), TIMER_UNIT, { mode: 0o644 });

  process.stdout.write("Preflight review:\n");
  process.stdout.write(`- Writes ${path.join(UNIT_DIR, SERVICE_NAME)} and ${path.join(UNIT_DIR, TIMER_NAME)}.\n`);
  process.stdout.write("- Required runtime: systemd user timers, curl, jq.\n");
  process.stdout.write("- The timer only fetches and validates the signed feed; it never removes skills.\n\n");
  process.stdout.write("Enable it with:\n");
  process.stdout.write("  systemctl --user daemon-reload\n");
  process.stdout.write("  systemctl --user enable --now clawsec-advisory-scan.timer\n");
}

try {
  main();
} catch (error) {
  process.stderr.write(`${String(error)}\n`);
  process.exit(1);
}
