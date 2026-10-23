// OpenCode plugin: ClawSec advisory guardian.
//
// Triggered on every user prompt. Loads the signed advisory feed, matches it
// against the skills installed in OpenCode's skill directories, and reports
// new matches. It never removes anything: removals require explicit user
// approval handled outside this plugin.

import fs from "node:fs/promises";
import os from "node:os";
import path from "node:path";

import { normalizeSkillName, uniqueStrings } from "./lib/utils.mjs";
import { versionMatches } from "./lib/version.mjs";
import {
  defaultChecksumsUrl,
  parseAffectedSpecifier,
  loadLocalFeed,
  loadRemoteFeed,
} from "./lib/feed.mjs";
import { loadAdvisorySuppression, isAdvisorySuppressed } from "./lib/suppression.mjs";

const DEFAULT_FEED_URL = "https://clawsec.prompt.security/advisories/feed.json";
const DEFAULT_SCAN_INTERVAL_SECONDS = 300;

const INSTALL_ROOTS = [
  path.join(os.homedir(), ".agents", "skills"),
  path.join(os.homedir(), ".config", "opencode", "skills"),
  path.join(os.homedir(), ".opencode", "skills"),
];

function suiteDir() {
  const explicit = process.env.CLAWSEC_SUITE_DIR;
  if (explicit && explicit.trim()) return explicit.trim();
  return path.join(os.homedir(), ".agents", "skills", "clawsec-suite");
}

function stateFile() {
  const explicit = process.env.CLAWSEC_SUITE_STATE_FILE;
  if (explicit && explicit.trim()) return explicit.trim();
  return path.join(os.homedir(), ".config", "opencode", "clawsec-suite-feed-state.json");
}

function advisoryAppliesHere(advisory) {
  const platforms = Array.isArray(advisory?.platforms) ? advisory.platforms : [];
  if (platforms.length === 0) return true;
  return platforms.some((entry) => {
    const value = String(entry).trim().toLowerCase();
    return value === "opencode" || value === "all" || value === "skills";
  });
}

async function discoverInstalledSkills() {
  const found = new Map();
  for (const root of INSTALL_ROOTS) {
    let entries;
    try {
      entries = await fs.readdir(root, { withFileTypes: true });
    } catch {
      continue;
    }
    for (const entry of entries) {
      if (!entry.isDirectory()) continue;
      const dir = path.join(root, entry.name);
      let name = entry.name;
      let version = "unknown";
      try {
        const raw = JSON.parse(await fs.readFile(path.join(dir, "skill.json"), "utf8"));
        if (typeof raw?.name === "string" && raw.name.trim()) name = raw.name.trim();
        if (typeof raw?.version === "string" && raw.version.trim()) version = raw.version.trim();
      } catch {
        // keep the directory name when skill.json is missing
      }
      if (!found.has(name)) found.set(name, { name, dirName: entry.name, version, dir });
    }
  }
  return [...found.values()];
}

function affectedMatches(rawSpecifier, skill) {
  const parsed = parseAffectedSpecifier(rawSpecifier);
  if (!parsed) return false;
  if (normalizeSkillName(parsed.name) !== normalizeSkillName(skill.name)) return false;
  return versionMatches(skill.version, parsed.versionSpec);
}

function findMatches(feed, skills) {
  const matches = [];
  for (const advisory of feed?.advisories ?? []) {
    if (!advisoryAppliesHere(advisory)) continue;
    const affected = Array.isArray(advisory.affected) ? advisory.affected : [];
    if (affected.length === 0) continue;
    for (const skill of skills) {
      const matched = affected.filter((spec) => affectedMatches(spec, skill));
      if (matched.length > 0) matches.push({ advisory, skill, matchedAffected: uniqueStrings(matched) });
    }
  }
  return matches;
}

function matchKey(match) {
  const advisoryId =
    match.advisory.id ??
    `${match.advisory.title ?? "untitled"}::${match.advisory.published ?? match.advisory.updated ?? "unknown"}`;
  return `${advisoryId}::${normalizeSkillName(match.skill.name)}@${match.skill.version ?? "unknown"}`;
}

function buildAlert(matches) {
  const lines = ["CLAWSEC ALERT: advisory feed matches an installed skill."];
  for (const match of matches.slice(0, 8)) {
    const severity = String(match.advisory.severity ?? "unknown").toUpperCase();
    lines.push(
      `- [${severity}] ${match.advisory.id ?? "unknown-id"} -> ${match.skill.name}@${match.skill.version ?? "unknown"}` +
        (match.matchedAffected.length ? ` (matched: ${match.matchedAffected.join(", ")})` : ""),
    );
    if (match.advisory.action) lines.push(`  Action: ${match.advisory.action}`);
  }
  lines.push("");
  lines.push(
    "Do not remove or disable anything without explicit user approval. " +
      "Report the advisory, the affected skill, and the remediation, then ask.",
  );
  return lines.join("\n");
}

async function loadState(file) {
  try {
    return JSON.parse(await fs.readFile(file, "utf8"));
  } catch {
    return { known_advisories: [], notified_matches: {} };
  }
}

async function persistState(file, state) {
  await fs.mkdir(path.dirname(file), { recursive: true });
  const tmp = `${file}.tmp-${process.pid}`;
  await fs.writeFile(tmp, `${JSON.stringify(state, null, 2)}\n`, { encoding: "utf8", mode: 0o600 });
  await fs.rename(tmp, file);
}

export default {
  id: "clawsec-advisory-guardian",
  setup: async (ctx) => {
    const file = stateFile();
    const interval = Number.parseInt(process.env.CLAWSEC_HOOK_INTERVAL_SECONDS ?? "", 10);
    const minIntervalMs = (Number.isFinite(interval) && interval > 0 ? interval : DEFAULT_SCAN_INTERVAL_SECONDS) * 1000;

    await ctx.session.hook("prompt", async () => {
      const state = await loadState(file);
      const last = Date.parse(state.last_scan ?? "");
      if (Number.isFinite(last) && Date.now() - last < minIntervalMs) return;

      const dir = suiteDir();
      const feedUrl = process.env.CLAWSEC_FEED_URL || DEFAULT_FEED_URL;
      const localFeed = path.join(dir, "advisories", "feed.json");
      const publicKeyPath = path.join(dir, "advisories", "feed-signing-public.pem");

      let feed = null;
      try {
        const publicKeyPem = process.env.CLAWSEC_ALLOW_UNSIGNED_FEED === "1"
          ? ""
          : await fs.readFile(publicKeyPath, "utf8");
        feed = await loadRemoteFeed(feedUrl, {
          signatureUrl: process.env.CLAWSEC_FEED_SIG_URL || `${feedUrl}.sig`,
          checksumsUrl: process.env.CLAWSEC_FEED_CHECKSUMS_URL || defaultChecksumsUrl(feedUrl),
          checksumsSignatureUrl:
            process.env.CLAWSEC_FEED_CHECKSUMS_SIG_URL || `${defaultChecksumsUrl(feedUrl)}.sig`,
          publicKeyPem,
          checksumsPublicKeyPem: publicKeyPem,
          allowUnsigned: process.env.CLAWSEC_ALLOW_UNSIGNED_FEED === "1",
          verifyChecksumManifest: process.env.CLAWSEC_VERIFY_CHECKSUM_MANIFEST !== "0",
        });
        if (!feed) {
          feed = await loadLocalFeed(localFeed, {
            signaturePath: process.env.CLAWSEC_LOCAL_FEED_SIG || `${localFeed}.sig`,
            checksumsPath: process.env.CLAWSEC_LOCAL_FEED_CHECKSUMS || path.join(dir, "advisories", "checksums.json"),
            checksumsSignaturePath:
              process.env.CLAWSEC_LOCAL_FEED_CHECKSUMS_SIG || path.join(dir, "advisories", "checksums.json.sig"),
            publicKeyPem,
            checksumsPublicKeyPem: publicKeyPem,
            allowUnsigned: process.env.CLAWSEC_ALLOW_UNSIGNED_FEED === "1",
            verifyChecksumManifest: process.env.CLAWSEC_VERIFY_CHECKSUM_MANIFEST !== "0",
            checksumPublicKeyEntry: path.basename(publicKeyPath),
          });
        }
      } catch {
        return;
      }
      if (!feed) return;

      const now = new Date().toISOString();
      state.last_scan = now;
      state.last_feed_check = now;
      state.known_advisories = uniqueStrings([
        ...(state.known_advisories ?? []),
        ...feed.advisories.map((entry) => entry.id).filter(Boolean),
      ]);

      const skills = await discoverInstalledSkills();
      const matches = findMatches(feed, skills);
      if (matches.length === 0) {
        await persistState(file, state);
        return;
      }

      let suppression = { suppressions: [], enabledFor: [] };
      try {
        suppression = await loadAdvisorySuppression();
      } catch {
        suppression = { suppressions: [], enabledFor: [] };
      }

      const active = matches.filter((match) => !isAdvisorySuppressed(match, suppression.suppressions));
      const unseen = active.filter((match) => !state.notified_matches?.[matchKey(match)]);
      for (const match of unseen) state.notified_matches[matchKey(match)] = now;

      await persistState(file, state);
      if (unseen.length === 0) return;

      await ctx.session.synthetic({ text: buildAlert(unseen) });
    });
  },
};
