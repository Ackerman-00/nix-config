// Skills refresh
// Source: the git archive of the probed commit

import { createHash } from "node:crypto";
import { execFile, spawnSync } from "node:child_process";
import { get as httpGet } from "node:http";
import { get as httpsGet } from "node:https";
import { promisify } from "node:util";
import {
  cpSync,
  existsSync,
  lstatSync,
  mkdirSync,
  mkdtempSync,
  readFileSync,
  readdirSync,
  readlinkSync,
  realpathSync,
  renameSync,
  rmSync,
  statSync,
  symlinkSync,
  writeFileSync,
} from "node:fs";
import { dirname, join } from "node:path";
import { tmpdir } from "node:os";

const execFileAsync = promisify(execFile);

const GIT_BASE = process.env.SKILLS_GIT_BASE || "https://github.com";
const ARCHIVE_BASE = process.env.SKILLS_ARCHIVE_BASE || "https://codeload.github.com";
const SKIP_DIRS = new Set([".git", "node_modules", "__pycache__"]);
const SKIP_FILES = new Set(["metadata.json"]);

// Concurrency
const HEAD_CONCURRENCY = 16;

// Deadline
const DEFAULT_DEADLINE = 1200;

const config = {
  map: env("SKILLS_MAP"),
  seed: env("SKILLS_SEED"),
  state: env("SKILLS_STATE"),
  overrides: env("SKILLS_OVERRIDES"),
  agentsDir: env("SKILLS_AGENTS_DIR"),
  opencodeDir: env("SKILLS_OPENCODE_DIR"),
  git: env("SKILLS_GIT"),
  tar: env("SKILLS_TAR", "tar"),
  excluded: new Set(
    env("SKILLS_EXCLUDED", "")
      .split(/[\s,]+/)
      .filter(Boolean),
  ),
  deadline: Number(env("SKILLS_DEADLINE", String(DEFAULT_DEADLINE))),
  // Switches
  refresh: env("SKILLS_REFRESH", "1") !== "0",
  restore: env("SKILLS_RESTORE", "1") !== "0",
  dryRun: env("SKILLS_DRY_RUN", "0") === "1",
};

function env(name, fallback = null) {
  const value = process.env[name];
  if (!value) {
    if (fallback !== null) return fallback;
    throw new Error(`missing environment variable ${name}`);
  }
  return value;
}

function log(message) {
  process.stdout.write(`agent-skills: ${message}\n`);
}

// Deadline
const budget = Number.isFinite(config.deadline) && config.deadline > 0 ? config.deadline : DEFAULT_DEADLINE;
const deadlineAt = Date.now() + budget * 1000;

function timeLeft() {
  return deadlineAt - Date.now();
}

// Folder Hash

function folderHash(dir) {
  if (!existsSync(dir)) return null;
  const files = [];
  const walk = (base) => {
    for (const entry of readdirSync(base, { withFileTypes: true })) {
      const full = join(base, entry.name);
      if (entry.isDirectory()) {
        if (SKIP_DIRS.has(entry.name)) continue;
        walk(full);
      } else if (entry.isSymbolicLink()) {
        // Store symlink
        let target;
        try {
          target = statSync(full);
        } catch {
          continue;
        }
        if (target.isDirectory()) {
          walk(full);
        } else {
          files.push([full.slice(dir.length + 1).split("\\").join("/"), full]);
        }
      } else if (entry.isFile()) {
        if (SKIP_FILES.has(entry.name)) continue;
        files.push([full.slice(dir.length + 1).split("\\").join("/"), full]);
      }
    }
  };
  walk(dir);
  const hash = createHash("sha256");
  for (const [rel, full] of files.sort((a, b) => (a[0] < b[0] ? -1 : 1))) {
    hash.update(rel);
    hash.update(readFileSync(full));
  }
  return hash.digest("hex");
}

// Upstream

// Pinned commit
function pinnedRevision(skills) {
  for (const skill of skills) {
    if (skill.rev) return skill.rev;
  }
  return null;
}

// Probe results
async function repoHead(repo) {
  const left = timeLeft();
  if (left <= 0) return { ok: false, reason: "the deadline is spent", notReached: true };
  try {
    const { stdout } = await execFileAsync(
      config.git,
      ["ls-remote", `${GIT_BASE}/${repo}.git`, "HEAD"],
      { encoding: "utf-8", timeout: Math.min(120000, left), maxBuffer: 4 * 1024 * 1024 },
    );
    const head = stdout.trim().split(/\s+/)[0] ?? null;
    if (!head) return { ok: false, reason: "no HEAD in the ls-remote answer" };
    return { ok: true, head };
  } catch (error) {
    if (timeLeft() <= 0) return { ok: false, reason: "the deadline is spent", notReached: true };
    const reason = (error.stderr || error.message || "git ls-remote failed")
      .toString()
      .trim()
      .split("\n")
      .pop();
    return { ok: false, reason };
  }
}

// Git Fetch

// Archive download
// No keep-alive
function download(url, timeoutMs) {
  return new Promise((resolve, reject) => {
    const client = url.startsWith("https:") ? httpsGet : httpGet;
    const request = client(url, { agent: false, timeout: timeoutMs }, (response) => {
      if (response.statusCode !== 200) {
        response.resume();
        resolve({ ok: false, reason: `HTTP ${response.statusCode}` });
        return;
      }
      const chunks = [];
      response.on("data", (chunk) => chunks.push(chunk));
      response.on("error", reject);
      response.on("end", () => resolve({ ok: true, body: Buffer.concat(chunks) }));
    });
    request.on("timeout", () => {
      const error = new Error("the download timed out");
      error.name = "TimeoutError";
      request.destroy(error);
    });
    request.on("error", reject);
  });
}

// Repo archive
async function gitArchive(repo, head) {
  const left = timeLeft();
  if (left <= 0) return { ok: false, reason: "the deadline is spent", notReached: true };
  const url = `${ARCHIVE_BASE}/${repo}/tar.gz/${head}`;
  const dir = mkdtempSync(join(tmpdir(), "agent-skills-git-"));
  try {
    const answer = await download(url, Math.min(180000, left));
    if (!answer.ok) {
      rmSync(dir, { recursive: true, force: true });
      return { ok: false, reason: answer.reason };
    }
    const archive = join(dir, "repo.tar.gz");
    writeFileSync(archive, answer.body);
    const root = join(dir, "src");
    mkdirSync(root, { recursive: true });
    const result = spawnSync(config.tar, ["-xzf", archive, "-C", root], {
      encoding: "utf-8",
      timeout: Math.max(1, Math.min(180000, timeLeft())),
    });
    if (result.status !== 0) {
      rmSync(dir, { recursive: true, force: true });
      if (result.error?.code === "ETIMEDOUT") {
        return { ok: false, reason: "the deadline is spent", notReached: true };
      }
      return {
        ok: false,
        reason: (result.stderr || "the archive did not unpack").trim().split("\n").pop(),
      };
    }
    // Archive root
    const tops = readdirSync(root, { withFileTypes: true }).filter((entry) => entry.isDirectory());
    if (tops.length !== 1) {
      rmSync(dir, { recursive: true, force: true });
      return { ok: false, reason: `${tops.length} top level directories in the archive` };
    }
    return { ok: true, dir, root: join(root, tops[0].name) };
  } catch (error) {
    rmSync(dir, { recursive: true, force: true });
    if (timeLeft() <= 0 || error.name === "AbortError" || error.name === "TimeoutError") {
      return { ok: false, reason: "the deadline is spent", notReached: true };
    }
    return { ok: false, reason: error.message };
  }
}

// Archive hash
function archiveHash(root, skill) {
  if (!skill.path) {
    return { ok: false, reason: "the skill has no path in the repo" };
  }
  const from = join(root, skill.path);
  if (!existsSync(from)) {
    return { ok: false, reason: `${skill.path} is not in the archive` };
  }
  if (!isDirectory(from)) {
    return { ok: false, reason: `${skill.path} is not a directory` };
  }
  return { ok: true, hash: folderHash(from) };
}

function isDirectory(path) {
  try {
    return statSync(path).isDirectory();
  } catch {
    return false;
  }
}

// Install

// Staging: outside the live tree
function stageDir(target) {
  const parent = dirname(dirname(target));
  mkdirSync(parent, { recursive: true });
  return mkdtempSync(join(parent, ".agent-skills-stage-"));
}

// Archive install
// Stage all, then swap
function installFromArchive(root, skills) {
  const prepared = [];
  try {
    for (const skill of skills) {
      const from = join(root, skill.path);
      if (!existsSync(from)) {
        return { ok: false, reason: `${skill.path} is not in the archive` };
      }
      if (!isDirectory(from)) {
        return { ok: false, reason: `${skill.path} is not a directory` };
      }
      const to = targetOf(skill, skill.name);
      const stage = stageDir(to);
      const content = join(stage, "skill");
      prepared.push({ stage, to, content });
      cpSync(from, content, { recursive: true });
      if (folderHash(content) !== skill.upstream) {
        return { ok: false, reason: `${skill.name}: the staged copy is not the upstream content` };
      }
    }
    const swapped = [];
    try {
      for (const item of prepared) {
        const old = join(item.stage, "old");
        const hadOld = existsSync(item.to) || isLink(item.to);
        if (hadOld) renameSync(item.to, old);
        try {
          renameSync(item.content, item.to);
        } catch (error) {
          if (hadOld) renameSync(old, item.to);
          throw error;
        }
        swapped.push(item);
      }
    } catch (error) {
      for (const item of swapped.reverse()) {
        rmSync(item.to, { recursive: true, force: true });
        const old = join(item.stage, "old");
        if (existsSync(old)) renameSync(old, item.to);
      }
      return { ok: false, reason: error.message };
    }
    return { ok: true };
  } finally {
    for (const item of prepared) rmSync(item.stage, { recursive: true, force: true });
  }
}

// Overrides

function targetOf(entry, name) {
  return join(entry.tree === "opencode" ? config.opencodeDir : config.agentsDir, name);
}

function isLink(path) {
  try {
    return lstatSync(path).isSymbolicLink();
  } catch {
    return false;
  }
}

// Link target: raw, then resolved
function sameLink(target, source) {
  try {
    if (readlinkSync(target) === source) return true;
  } catch {
    return false;
  }
  try {
    return realpathSync(target) === realpathSync(source);
  } catch {
    return false;
  }
}

function restoreOverrides(map) {
  let restored = 0;
  for (const entry of Object.values(map)) {
    if (entry.owner !== "agent-skills" || !entry.override) continue;
    const source = join(config.overrides, entry.tree, entry.name);
    if (!existsSync(source)) continue;
    const target = targetOf(entry, entry.name);
    if (isLink(target) && sameLink(target, source)) continue;
    if (config.dryRun) {
      log(`would restore ${entry.tree}/${entry.name}`);
      restored += 1;
      continue;
    }
    if (!isLink(target) && existsSync(target)) {
      const dest = backupLocalEdit(entry);
      if (dest) log(`the local copy of ${entry.tree}/${entry.name} is kept at ${dest}`);
    }
    rmSync(target, { recursive: true, force: true });
    mkdirSync(dirname(target), { recursive: true });
    symlinkSync(source, target);
    restored += 1;
  }
  return restored;
}

// Backups

// Stale backups
function sweepBackups(dir) {
  let removed = 0;
  if (!existsSync(dir)) return 0;
  for (const entry of readdirSync(dir, { withFileTypes: true })) {
    if (!entry.isDirectory() || !entry.name.endsWith(".hm-backup")) continue;
    const path = join(dir, entry.name);
    rmSync(path, { recursive: true, force: true });
    log(`removed the stale skill backup ${path}`);
    removed += 1;
  }
  return removed;
}

// Local edit
function backupLocalEdit(skill) {
  if (config.dryRun) return null;
  const target = targetOf(skill, skill.name);
  if (!existsSync(target)) return null;
  const root = join(dirname(config.state), "backups", skill.tree, skill.name);
  const hash = folderHash(target);
  if (existsSync(root)) {
    // Same content
    const newest = readdirSync(root)
      .filter((name) => statSync(join(root, name)).isDirectory())
      .sort()
      .pop();
    if (newest && folderHash(join(root, newest)) === hash) return join(root, newest);
  }
  const stamp = new Date().toISOString().replace(/[:.]/g, "-");
  const dest = join(root, stamp);
  mkdirSync(dest, { recursive: true });
  cpSync(target, dest, { recursive: true, dereference: true });
  return dest;
}

// Main

async function main() {
  const map = JSON.parse(readFileSync(config.map, "utf-8"));
  const seed = JSON.parse(readFileSync(config.seed, "utf-8"));
  const state = existsSync(config.state)
    ? JSON.parse(readFileSync(config.state, "utf-8"))
    : { version: 1, repos: {} };
  for (const [repo, value] of Object.entries(seed.repos ?? {})) {
    if (!state.repos[repo]) state.repos[repo] = value;
  }

  // Tracked skills
  const tracked = Object.entries(map).filter(
    ([key, entry]) =>
      entry.owner === "agent-skills" &&
      entry.repo &&
      !entry.override &&
      !config.excluded.has(entry.name),
  );

  const failures = [];
  const skipped = new Map();
  const skippedSkills = [];
  const notReached = [];

  if (config.restore) {
    const restored = restoreOverrides(map);
    if (restored) log(`restored ${restored} local skills`);
  }

  const byRepo = new Map();
  for (const [key, entry] of tracked) {
    const list = byRepo.get(entry.repo) ?? [];
    list.push({ key, ...entry });
    byRepo.set(entry.repo, list);
  }

  // Incremental state
  function settleRepo(repo, skills, ok, head) {
    if (config.dryRun) return;
    if (ok && head) {
      const hashes = {};
      for (const skill of skills) {
        hashes[skill.key] = folderHash(targetOf(skill, skill.name));
      }
      state.repos[repo] = { head, skills: hashes };
    }
    mkdirSync(dirname(config.state), { recursive: true });
    writeFileSync(config.state, `${JSON.stringify(state, null, 2)}\n`);
  }

  if (config.refresh) {
    const repos = [...byRepo].sort((a, b) => (a[0] < b[0] ? -1 : 1));
    const probes = await mapLimit(repos, HEAD_CONCURRENCY, async ([repo, skills]) => [
      repo,
      // Pinned repo
      pinnedRevision(skills)
        ? { ok: true, head: pinnedRevision(skills) }
        : await repoHead(repo),
    ]);
    let checked = 0;
    let updated = 0;
    for (const [repo, probe] of probes) {
      const skills = byRepo.get(repo);
      const previous = state.repos[repo];
      // Deadline
      if (probe.notReached || timeLeft() <= 0) {
        notReached.push(repo);
        continue;
      }
      // Unreachable repo: keep cached head
      if (!probe.ok) {
        skipped.set(repo, probe.reason);
        continue;
      }
      const head = probe.head;
      const local = new Map();
      for (const skill of skills) {
        local.set(skill.key, folderHash(targetOf(skill, skill.name)));
      }
      const unchanged =
        previous &&
        previous.head &&
        previous.head === head &&
        skills.every(
          (skill) =>
            previous.skills?.[skill.key] &&
            previous.skills[skill.key] === local.get(skill.key) &&
            // Live symlink
            !isLink(targetOf(skill, skill.name)),
        );
      if (unchanged) {
        settleRepo(repo, skills, true, head);
        continue;
      }
      checked += skills.length;
      const archive = await gitArchive(repo, head);
      if (!archive.ok) {
        if (archive.notReached) notReached.push(repo);
        else skipped.set(repo, archive.reason);
        continue;
      }
      log(`fetched ${repo} at ${head}`);
      const stale = [];
      let soft = false;
      for (const skill of skills) {
        const answer = archiveHash(archive.root, skill);
        if (!answer.ok) {
          skippedSkills.push(`${repo}/${skill.name}: ${answer.reason}`);
          soft = true;
          continue;
        }
        const current = local.get(skill.key);
        // Live symlink
        const linked = isLink(targetOf(skill, skill.name));
        if (answer.hash === current && !linked) continue;
        const expected = previous?.skills?.[skill.key] ?? null;
        if (expected && current !== expected && current !== answer.hash) {
          const dest = backupLocalEdit(skill);
          if (dest) {
            log(`your edit of ${skill.key} is not upstream, kept at ${dest}`);
          }
        }
        stale.push({ ...skill, upstream: answer.hash });
      }
      let ok = true;
      if (stale.length > 0) {
        if (config.dryRun) {
          log(`would refresh ${stale.map((skill) => skill.name).join(", ")}`);
        } else {
          let result;
          try {
            result = installFromArchive(archive.root, stale);
          } catch (error) {
            result = { ok: false, reason: error.message };
          }
          if (!result.ok) {
            ok = false;
            failures.push(`${repo}: ${result.reason}`);
          } else {
            updated += stale.length;
            log(`refreshed ${stale.map((skill) => skill.name).join(", ")}`);
          }
        }
      }
      rmSync(archive.dir, { recursive: true, force: true });
      // Soft skip: keep cached head
      if (ok && !soft) settleRepo(repo, skills, true, head);
    }
    log(
      config.dryRun
        ? `dry run: ${checked} skills checked`
        : `checked ${checked} skills, refreshed ${updated}`,
    );
  }

  if (config.restore) {
    const restoredAgain = restoreOverrides(map);
    if (restoredAgain) log(`restored ${restoredAgain} local skills after refresh`);
  }

  if (notReached.length > 0) {
    log(
      `the deadline stopped the run: ${notReached.length} repo(s) were not reached, they stay uncached`,
    );
    for (const repo of notReached.slice(0, 20)) log(`  ${repo}`);
    if (notReached.length > 20) log(`  ... and ${notReached.length - 20} more`);
  }

  if (skipped.size > 0 || skippedSkills.length > 0) {
    log(
      `skipped ${skipped.size} repo(s) and ${skippedSkills.length} skill(s), ` +
        "they keep their cached head and the next run retries",
    );
    for (const [repo, reason] of [...skipped].slice(0, 20)) log(`  ${repo}: ${reason}`);
    for (const skill of skippedSkills.slice(0, 20)) log(`  ${skill}`);
    const rest = skippedSkills.length - 20;
    if (rest > 0) log(`  ... and ${rest} more skill(s)`);
  }

  if (failures.length > 0) {
    log(`failed: ${failures.length} upstream problem(s), those repos were not cached`);
    for (const failure of failures.slice(0, 20)) log(`  ${failure}`);
    if (failures.length > 20) log(`  ... and ${failures.length - 20} more`);
    process.exitCode = 1;
    return;
  }

  if (config.dryRun) return;

  const removed = sweepBackups(config.agentsDir) + sweepBackups(config.opencodeDir);
  if (removed) log(`swept ${removed} stale skill backups`);
}

async function mapLimit(items, limit, worker) {
  const results = new Array(items.length);
  let index = 0;
  const runners = Array.from({ length: Math.min(limit, items.length) }, async () => {
    while (index < items.length) {
      const current = index++;
      results[current] = await worker(items[current], current);
    }
  });
  await Promise.all(runners);
  return results;
}

main().catch((error) => {
  log(`failed: ${error.stack || error.message}`);
  process.exitCode = 1;
});
