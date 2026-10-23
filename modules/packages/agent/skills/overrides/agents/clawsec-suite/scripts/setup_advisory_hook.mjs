#!/usr/bin/env node

// Installs the ClawSec advisory guardian as an OpenCode plugin.
//
// OpenCode auto-loads every .js file in ~/.config/opencode/plugins, so the
// guardian is installed there rather than as a hook file.

import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";

const PLUGIN_NAME = "clawsec-advisory-guardian.js";
const SCRIPT_DIR = path.dirname(fileURLToPath(import.meta.url));
const SUITE_DIR = path.resolve(SCRIPT_DIR, "..");
const SOURCE_PLUGIN = path.join(SUITE_DIR, "hooks", "clawsec-advisory-guardian", "opencode-plugin.js");
const PLUGINS_ROOT = path.join(os.homedir(), ".config", "opencode", "plugins");
const TARGET_PLUGIN = path.join(PLUGINS_ROOT, PLUGIN_NAME);

function printPreflightSummary() {
  const lines = [
    "Preflight review:",
    `- This installs a persistent OpenCode plugin at ${TARGET_PLUGIN}.`,
    "- Required runtime: node (OpenCode loads plugins with Bun), node, curl, jq.",
    "- The plugin fetches signed advisory feed data and may recommend removal of risky skills, but destructive actions remain approval-gated.",
    `- Source plugin: ${SOURCE_PLUGIN}`,
    "- Restart OpenCode (or run `opencode reload`) so the plugin loads.",
  ];
  process.stdout.write(lines.join("\n") + "\n\n");
}

function main() {
  if (!fs.existsSync(SOURCE_PLUGIN)) {
    throw new Error(`Missing source plugin: ${SOURCE_PLUGIN}`);
  }
  printPreflightSummary();

  fs.mkdirSync(PLUGINS_ROOT, { recursive: true });
  fs.copyFileSync(SOURCE_PLUGIN, TARGET_PLUGIN);
  fs.chmodSync(TARGET_PLUGIN, 0o644);

  process.stdout.write(`Installed plugin: ${TARGET_PLUGIN}\n`);
  process.stdout.write("Verify with: opencode plugin list\n");
  process.stdout.write("Restart OpenCode (or run `opencode reload`) so the plugin loads.\n");
}

try {
  main();
} catch (error) {
  process.stderr.write(`${String(error)}\n`);
  process.exit(1);
}
