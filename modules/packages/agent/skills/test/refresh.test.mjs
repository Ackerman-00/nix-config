// Refresh driver tests
// Offline: a local git remote and a local archive server stand in for GitHub.

import test from "node:test";
import assert from "node:assert/strict";
import { execFile, execFileSync } from "node:child_process";
import { promisify } from "node:util";
import { createServer } from "node:http";
import {
  existsSync,
  lstatSync,
  mkdirSync,
  mkdtempSync,
  readFileSync,
  readdirSync,
  rmSync,
  writeFileSync,
} from "node:fs";
import { dirname, join } from "node:path";
import { tmpdir } from "node:os";
import { fileURLToPath } from "node:url";

const driver = join(dirname(fileURLToPath(import.meta.url)), "..", "refresh.mjs");
const gitBin = execFileSync("sh", ["-c", "command -v git"], { encoding: "utf-8" }).trim();
const tarBin = execFileSync("sh", ["-c", "command -v tar"], { encoding: "utf-8" }).trim();

function write(path, content) {
  mkdirSync(dirname(path), { recursive: true });
  writeFileSync(path, content);
}

function json(path, value) {
  write(path, `${JSON.stringify(value, null, 2)}\n`);
}

function gitRepo(src, files) {
  mkdirSync(src, { recursive: true });
  execFileSync(gitBin, ["init", "-q", "-b", "main"], { cwd: src });
  execFileSync(gitBin, ["config", "user.email", "test@example.com"], { cwd: src });
  execFileSync(gitBin, ["config", "user.name", "test"], { cwd: src });
  for (const [path, content] of Object.entries(files)) write(join(src, path), content);
  execFileSync(gitBin, ["add", "-A"], { cwd: src });
  execFileSync(gitBin, ["commit", "-q", "-m", "upstream"], { cwd: src });
  return execFileSync(gitBin, ["rev-parse", "HEAD"], { cwd: src, encoding: "utf-8" }).trim();
}

function publish(work, repo, files, src = join(work, "src", repo)) {
  const head = gitRepo(src, files);
  const bare = join(work, "upstream", `${repo}.git`);
  rmSync(bare, { recursive: true, force: true });
  mkdirSync(dirname(bare), { recursive: true });
  execFileSync(gitBin, ["clone", "-q", "--bare", src, bare]);
  return { head, bare, src };
}

function archiveServer(bares, options = {}) {
  const counts = new Map();
  const server = createServer((request, response) => {
    const match = request.url.match(/^\/(.+)\/tar\.gz\/([0-9a-f]{40})$/);
    if (!match) {
      response.writeHead(404).end();
      return;
    }
    const repo = match[1];
    counts.set(repo, (counts.get(repo) ?? 0) + 1);
    const bare = bares.get(repo);
    const answer = () => {
      if (!bare) {
        response.writeHead(404).end();
        return;
      }
      try {
        const body = execFileSync(
          gitBin,
          ["--git-dir", bare, "archive", "--format=tar.gz", "--prefix=repo/", match[2]],
          { maxBuffer: 64 * 1024 * 1024 },
        );
        response.writeHead(200, { "content-type": "application/gzip" }).end(body);
      } catch {
        response.writeHead(404).end();
      }
    };
    if (options.delayMs) setTimeout(answer, options.delayMs);
    else answer();
  });
  return new Promise((resolve) => {
    server.listen(0, "127.0.0.1", () =>
      resolve({ server, counts, base: `http://127.0.0.1:${server.address().port}` }),
    );
  });
}

function envFor(work, skills, base, deadline) {
  json(
    join(work, "map.json"),
    Object.fromEntries(
      skills.map((skill) => [
        skill.name,
        {
          name: skill.name,
          repo: skill.repo,
          path: skill.path,
          tree: "agents",
          owner: "agent-skills",
          override: skill.override ?? false,
        },
      ]),
    ),
  );
  json(join(work, "seed.json"), { version: 1, repos: {} });
  for (const dir of ["agents", "opencode", "overrides"]) mkdirSync(join(work, dir), { recursive: true });
  return {
    SKILLS_MAP: join(work, "map.json"),
    SKILLS_SEED: join(work, "seed.json"),
    SKILLS_STATE: join(work, "state.json"),
    SKILLS_OVERRIDES: join(work, "overrides"),
    SKILLS_AGENTS_DIR: join(work, "agents"),
    SKILLS_OPENCODE_DIR: join(work, "opencode"),
    SKILLS_GIT: gitBin,
    SKILLS_TAR: tarBin,
    SKILLS_EXCLUDED: "",
    SKILLS_GIT_BASE: join(work, "upstream"),
    SKILLS_ARCHIVE_BASE: base,
    SKILLS_DEADLINE: String(deadline ?? 120),
    SKILLS_REFRESH: "1",
    SKILLS_RESTORE: "1",
    SKILLS_DRY_RUN: "0",
  };
}

function stop(server) {
  server.closeAllConnections();
  server.close();
}

const execFileAsync = promisify(execFile);

async function run(env) {
  try {
    const { stdout, stderr } = await execFileAsync(process.execPath, [driver], {
      env: { ...process.env, ...env },
      encoding: "utf-8",
      timeout: 60000,
    });
    return { status: 0, stdout, stderr };
  } catch (error) {
    return {
      status: error.code ?? 1,
      stdout: error.stdout ?? "",
      stderr: error.stderr ?? error.message,
    };
  }
}

function state(work) {
  const path = join(work, "state.json");
  return existsSync(path) ? JSON.parse(readFileSync(path, "utf-8")) : { version: 1, repos: {} };
}

function workdir(name) {
  return mkdtempSync(join(tmpdir(), `skills-${name}-`));
}

test("installs the upstream content and settles the state", async () => {
  const work = workdir("install");
  const upstream = publish(work, "acme/skills", { "skills/alpha/SKILL.md": "alpha\n" });
  const { server, base } = await archiveServer(new Map([["acme/skills", upstream.bare]]));
  try {
    const env = envFor(work, [{ name: "alpha", repo: "acme/skills", path: "skills/alpha" }], base);
    const result = await run(env);
    assert.equal(result.status, 0, result.stdout + result.stderr);
    assert.equal(readFileSync(join(work, "agents", "alpha", "SKILL.md"), "utf-8"), "alpha\n");
    const after = state(work);
    assert.equal(after.repos["acme/skills"].head, upstream.head);
    assert.ok(after.repos["acme/skills"].skills.alpha);
  } finally {
    stop(server);
  }
});

test("a moved head refreshes the installed copy", async () => {
  const work = workdir("moved");
  const first = publish(work, "acme/skills", { "skills/alpha/SKILL.md": "one\n" });
  const { server, base } = await archiveServer(new Map([["acme/skills", first.bare]]));
  try {
    const env = envFor(work, [{ name: "alpha", repo: "acme/skills", path: "skills/alpha" }], base);
    assert.equal((await run(env)).status, 0);
    const second = publish(work, "acme/skills", { "skills/alpha/SKILL.md": "two\n" });
    const result = await run(env);
    assert.equal(result.status, 0, result.stdout + result.stderr);
    assert.equal(readFileSync(join(work, "agents", "alpha", "SKILL.md"), "utf-8"), "two\n");
    assert.equal(state(work).repos["acme/skills"].head, second.head);
  } finally {
    stop(server);
  }
});

test("an archive 404 is skipped, kept uncached and probed again", async () => {
  const work = workdir("404");
  publish(work, "acme/skills", { "skills/alpha/SKILL.md": "alpha\n" });
  const { server, counts, base } = await archiveServer(new Map());
  try {
    const env = envFor(work, [{ name: "alpha", repo: "acme/skills", path: "skills/alpha" }], base);
    const first = await run(env);
    assert.equal(first.status, 0, first.stdout + first.stderr);
    assert.match(first.stdout, /skipped 1 repo/);
    assert.equal(state(work).repos["acme/skills"], undefined);
    const second = await run(env);
    assert.equal(second.status, 0, second.stdout + second.stderr);
    assert.equal(counts.get("acme/skills"), 2);
  } finally {
    stop(server);
  }
});

test("a missing skill path is soft and the repo stays uncached", async () => {
  const work = workdir("soft");
  const upstream = publish(work, "acme/skills", { "skills/alpha/SKILL.md": "alpha\n" });
  const { server, counts, base } = await archiveServer(new Map([["acme/skills", upstream.bare]]));
  try {
    const env = envFor(work, [{ name: "alpha", repo: "acme/skills", path: "skills/missing" }], base);
    const first = await run(env);
    assert.equal(first.status, 0, first.stdout + first.stderr);
    assert.match(first.stdout, /skills\/missing is not in the archive/);
    assert.equal(state(work).repos["acme/skills"], undefined);
    const second = await run(env);
    assert.equal(second.status, 0, second.stdout + second.stderr);
    assert.equal(counts.get("acme/skills"), 2);
  } finally {
    stop(server);
  }
});

test("a skill path that is a file is soft and the repo stays uncached", async () => {
  const work = workdir("file");
  const upstream = publish(work, "acme/skills", { "skills/alpha": "not a dir\n" });
  const { server, counts, base } = await archiveServer(new Map([["acme/skills", upstream.bare]]));
  try {
    const env = envFor(work, [{ name: "alpha", repo: "acme/skills", path: "skills/alpha" }], base);
    const first = await run(env);
    assert.equal(first.status, 0, first.stdout + first.stderr);
    assert.match(first.stdout, /not a directory/);
    assert.equal(state(work).repos["acme/skills"], undefined);
    const second = await run(env);
    assert.equal(second.status, 0, second.stdout + second.stderr);
    assert.equal(counts.get("acme/skills"), 2);
  } finally {
    stop(server);
  }
});

test("a local edit is backed up before the refresh replaces it", async () => {
  const work = workdir("backup");
  publish(work, "acme/skills", { "skills/alpha/SKILL.md": "alpha\n" });
  const { server, base } = await archiveServer(
    new Map([["acme/skills", join(work, "upstream", "acme/skills.git")]]),
  );
  try {
    const env = envFor(work, [{ name: "alpha", repo: "acme/skills", path: "skills/alpha" }], base);
    assert.equal((await run(env)).status, 0);
    write(join(work, "agents", "alpha", "SKILL.md"), "edited\n");
    const result = await run(env);
    assert.equal(result.status, 0, result.stdout + result.stderr);
    assert.equal(readFileSync(join(work, "agents", "alpha", "SKILL.md"), "utf-8"), "alpha\n");
    const backups = join(work, "backups", "agents", "alpha");
    assert.ok(existsSync(backups));
    const [stamp] = readdirSync(backups);
    assert.equal(readFileSync(join(backups, stamp, "SKILL.md"), "utf-8"), "edited\n");
  } finally {
    stop(server);
  }
});

test("an override replaces the live copy and keeps the edited one", async () => {
  const work = workdir("override");
  const { server, base } = await archiveServer(new Map());
  try {
    write(join(work, "overrides", "agents", "alpha", "SKILL.md"), "pinned\n");
    const env = envFor(work, [{ name: "alpha", repo: "acme/skills", path: "skills/alpha", override: true }], base);
    write(join(work, "agents", "alpha", "SKILL.md"), "local\n");
    const result = await run(env);
    assert.equal(result.status, 0, result.stdout + result.stderr);
    const live = join(work, "agents", "alpha");
    assert.ok(lstatSync(live).isSymbolicLink());
    assert.equal(readFileSync(join(live, "SKILL.md"), "utf-8"), "pinned\n");
    const backups = join(work, "backups", "agents", "alpha");
    const [stamp] = readdirSync(backups);
    assert.equal(readFileSync(join(backups, stamp, "SKILL.md"), "utf-8"), "local\n");
  } finally {
    stop(server);
  }
});

test("the deadline stops the run and leaves the repo uncached", async () => {
  const work = workdir("deadline");
  publish(work, "acme/skills", { "skills/alpha/SKILL.md": "alpha\n" });
  const { server, base } = await archiveServer(
    new Map([["acme/skills", join(work, "upstream", "acme/skills.git")]]),
    { delayMs: 5000 },
  );
  try {
    const env = envFor(work, [{ name: "alpha", repo: "acme/skills", path: "skills/alpha" }], base, 1);
    const result = await run(env);
    assert.equal(result.status, 0, result.stdout + result.stderr);
    assert.match(result.stdout, /deadline/);
    assert.equal(state(work).repos["acme/skills"], undefined);
  } finally {
    stop(server);
  }
});
