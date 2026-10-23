import { readFileSync, appendFileSync, mkdirSync } from "node:fs"
import { execFile } from "node:child_process"
import { promisify } from "node:util"
import { homedir } from "node:os"
import { join } from "node:path"

const CONFIG_PATH = join(homedir(), ".config", "opencode", "review-loop.json")
const LOG_DIR = join(homedir(), ".local", "share", "opencode")
const LOG_PATH = join(LOG_DIR, "review-panel.log")
const execFileAsync = promisify(execFile)

// Agents that must never trigger the panel: the review harness drives these
// itself, and letting them trigger it would recurse.
const EXCLUDED_AGENTS = new Set([
  "reviewer",
  "writer",
  "poteto-agent",
  "advisor-subagent",
  "explore",
  "general",
])

const REVIEWER_PROMPT = `You are an independent code reviewer. You are read-only and you do not run commands. Review the diff below.

Report each actionable finding as its own block. The first line of a block must match exactly:

- [SEVERITY] path/to/file.ext:LINE — one-line summary

SEVERITY is one of CRITICAL, HIGH, MEDIUM, LOW. Follow the first line with detail lines if you need to explain the fix. Use real paths and real line numbers, never invented ones.

End your reply with exactly one line: VERDICT: ISSUES if you have at least one actionable finding, otherwise VERDICT: CLEAN. Nothing may follow that line.

Look for correctness bugs, security issues, unmet requirements, broken builds or tests, and regressions. Do not praise the code and do not restate what the diff does.`

function log(line) {
  try {
    mkdirSync(LOG_DIR, { recursive: true })
    appendFileSync(LOG_PATH, `${new Date().toISOString()} ${line}\n`)
  } catch {
    // Logging must never break the plugin.
  }
}

function loadConfig() {
  try {
    return JSON.parse(readFileSync(CONFIG_PATH, "utf8"))
  } catch {
    return null
  }
}

function hashString(value) {
  let h1 = 0x811c9dc5
  let h2 = 0x01000193
  for (let i = 0; i < value.length; i++) {
    const c = value.charCodeAt(i)
    h1 = Math.imul(h1 ^ c, 16777619) >>> 0
    h2 = Math.imul(h2 + c, 0x85ebca6b) >>> 0
  }
  return h1.toString(16) + "-" + h2.toString(16)
}

const FINDING_RE =
  /^\s*[-*+]?\s*\[(CRITICAL|HIGH|MEDIUM|LOW)\]\s*`?((?:\/)?(?:[\w@.-]+\/)*[\w@.-]+\.[\w]+)`?(?::(\d+))?\s*[—\-:]?\s*(.*)$/i
const SEVERITY_ORDER = { CRITICAL: 0, HIGH: 1, MEDIUM: 2, LOW: 3 }

function parseFindings(text) {
  const findings = []
  for (const line of String(text).split("\n")) {
    const match = FINDING_RE.exec(line)
    if (!match) continue
    findings.push({
      severity: match[1].toUpperCase(),
      path: match[2],
      line: match[3] ? Number(match[3]) : null,
      summary: (match[4] || "").trim(),
    })
  }
  return findings
}

function buildReport(results) {
  const merged = new Map()
  for (const result of results) {
    for (const finding of parseFindings(result.text)) {
      const key = finding.line ? `${finding.path}:${finding.line}` : finding.path
      const existing = merged.get(key)
      if (!existing) {
        merged.set(key, { ...finding, voters: [result.model] })
        continue
      }
      existing.voters.push(result.model)
      if (SEVERITY_ORDER[finding.severity] < SEVERITY_ORDER[existing.severity]) {
        existing.severity = finding.severity
      }
    }
  }
  const ordered = [...merged.values()].sort(
    (a, b) =>
      SEVERITY_ORDER[a.severity] - SEVERITY_ORDER[b.severity] ||
      b.voters.length - a.voters.length ||
      a.path.localeCompare(b.path),
  )
  if (!ordered.length) return null

  const lines = [
    "An independent review panel reviewed the changes you just made and raised the findings below.",
    "Verify each finding against the code before acting on it. Fix the real ones, skip the wrong ones with a one-line reason, and do not treat this as a request to rewrite working code.",
    "",
  ]
  ordered.forEach((finding, index) => {
    const where = finding.line ? `${finding.path}:${finding.line}` : finding.path
    lines.push(
      `${index + 1}. [${finding.severity}] ${where} — ${finding.summary}  (flagged by ${finding.voters.length}/${results.length} reviewers)`,
    )
  })
  return lines.join("\n")
}

// ctx.vcs resolves by plugin project, which can be a different repository than
// the session's own directory. Run git in the session's directory instead.
async function gitIn(directory, args) {
  const { stdout } = await execFileAsync("git", ["-C", directory, ...args], {
    maxBuffer: 32 * 1024 * 1024,
  })
  return stdout
}

async function readWorkingTree(directory) {
  const status = await gitIn(directory, ["status", "--porcelain"])
  const files = status
    .split("\n")
    .filter((line) => line.trim())
    .map((line) => line.slice(3).trim().replace(/^"|"$/g, ""))

  let patch = ""
  for (const args of [["diff", "HEAD"], ["diff"], ["diff", "--cached"]]) {
    try {
      const out = await gitIn(directory, args)
      if (out.trim()) {
        patch = out
        break
      }
    } catch {
      // A missing HEAD (no commits yet) lands here; the next form is tried.
    }
  }

  // Untracked files never appear in a diff, so include their content.
  for (const file of files) {
    if (!file || file.includes(" -> ")) continue
    try {
      const tracked = await gitIn(directory, ["ls-files", "--error-unmatch", "--", file])
      if (tracked.trim()) continue
    } catch {
      // Not tracked: include it.
    }
    try {
      const body = readFileSync(join(directory, file), "utf8")
      patch += `--- ${file} (untracked, full content)\n${body}\n`
    } catch {
      // Binary or unreadable: leave it out.
    }
  }
  return { files, patch }
}

async function askModel(ctx, modelID, prompt, panelTimeoutMs) {
  const slash = modelID.indexOf("/")
  const providerID = modelID.slice(0, slash)
  const id = modelID.slice(slash + 1)
  // The free tier refuses a model call that carries no session, so each panel
  // member gets a real server-minted session, is asked once, and is removed.
  const created = await ctx.session.create({
    model: { providerID, id },
    agent: "reviewer",
    title: "review-panel",
  })
  const sessionID = created?.id ?? created?.data?.id
  if (!sessionID) throw new Error("could not create panel session")
  try {
    await ctx.session.prompt({ sessionID, text: prompt })
    // Poll rather than rely on session.wait: wait can resolve before the
    // prompt has been processed, which would read an empty transcript.
    const deadline = Date.now() + panelTimeoutMs
    while (Date.now() < deadline) {
      const messages = await ctx.session.context({ sessionID }).catch(() => null)
      const list = Array.isArray(messages) ? messages : (messages?.data ?? [])
      const texts = []
      for (const message of list) {
        for (const part of message?.content ?? []) {
          if (part?.type === "text" && part.text) texts.push(part.text)
        }
      }
      if (texts.length) return texts[texts.length - 1]
      const info = await ctx.session.get({ sessionID }).catch(() => null)
      if (info?.outcome === "failed" || info?.outcome === "interrupted") {
        throw new Error(`panel session ${info.outcome}`)
      }
      await new Promise((resolve) => setTimeout(resolve, 1000))
    }
    throw new Error(`panel session timed out after ${panelTimeoutMs}ms`)
  } finally {
    await ctx.session.remove({ sessionID }).catch(() => {})
  }
}

export default {
  id: "review-panel",
  setup: async (ctx) => {
    const config = loadConfig()
    if (!config) {
      log("idle: no config")
      return
    }
    const auto = config.auto ?? {}
    if (auto.enabled === false) {
      log("idle: disabled in config")
      return
    }

    const panel = auto.models ?? [
      "opencode/glm-5.3-flash-free",
      "opencode/deepseek-v4.1-flash-free",
    ]
    const pool = auto.pool ?? config.pool ?? panel
    const maxRounds = auto.max_rounds ?? 2
    const cooldownMs = (auto.cooldown_seconds ?? 45) * 1000
    const minChangedLines = auto.min_changed_lines ?? 3
    const maxDiffChars = auto.max_diff_chars ?? 40000
    const requireSessionChange = auto.require_session_change !== false
    const panelTimeoutMs = (auto.panel_timeout_seconds ?? 120) * 1000

    let primaryAgents = new Set()
    try {
      const response = await ctx.agent.list()
      const list = Array.isArray(response) ? response : (response?.data ?? [])
      primaryAgents = new Set(
        list
          .filter((agent) => agent.mode !== "subagent")
          .map((agent) => String(agent.name).toLowerCase()),
      )
    } catch (error) {
      log(`idle: agent list failed: ${error?.message ?? error}`)
      return
    }

    // One-time sweep: a panel session orphaned by a restart would otherwise
    // sit in the list forever. No timer, this only runs when the plugin loads.
    try {
      const listed = await ctx.session.list({ directory: ctx.location?.directory, limit: 100 })
      const sessions = Array.isArray(listed) ? listed : (listed?.data ?? [])
      for (const session of sessions) {
        if ((session?.title ?? "") !== "review-panel") continue
        await ctx.session.remove({ sessionID: session.id }).catch(() => {})
        log(`swept orphaned panel session ${session.id}`)
      }
    } catch {
      // A failed sweep is not worth breaking the plugin over.
    }

    const state = new Map()
    const stateLimit = 200

    function remember(sessionID, value) {
      state.delete(sessionID)
      state.set(sessionID, value)
      while (state.size > stateLimit) {
        const oldest = state.keys().next().value
        state.delete(oldest)
      }
    }

    // Cheap detection only. Returns the diff to review, or a reason to skip.
    async function detect(event, current) {
      const agent = String(event.agent || "").toLowerCase()
      if (EXCLUDED_AGENTS.has(agent)) return { reason: `excluded agent ${agent}` }
      if (primaryAgents.size && !primaryAgents.has(agent)) {
        return { reason: `not a primary agent (${agent})` }
      }

      // ctx.vcs reads this plugin instance's location, so only act on sessions
      // that live in the same directory.
      let sessionDir
      try {
        const session = await ctx.session.get({ sessionID: event.sessionID })
        sessionDir = session?.location?.directory
      } catch {
        return { reason: "session lookup failed" }
      }
      if (!sessionDir) return { reason: "session directory unknown" }

      if (current.rounds >= maxRounds) return { reason: "max rounds reached" }
      if (Date.now() - current.lastAt < cooldownMs) return { reason: "cooldown" }

      let tree
      try {
        tree = await readWorkingTree(sessionDir)
      } catch (error) {
        return { reason: `git failed: ${error?.message ?? error}` }
      }
      const status = tree.files
      if (!status.length) return { reason: "no changed files" }
      const changedLines = tree.patch
        .split("\n")
        .filter((line) => line.startsWith("+") || line.startsWith("-"))
        .length
      const diffText = tree.patch
      if (!diffText.trim()) return { reason: "empty diff" }

      const hash = hashString(diffText)

      // Establish the baseline before any other check. The baseline is the diff
      // as it stood when this session opened, so the panel only ever reviews
      // what the session itself changed. Capturing it later would let the
      // agent's own edit become the baseline and escape review.
      if (requireSessionChange) {
        if (!current.baseline) {
          current.baseline = hash
          return { reason: `baseline captured (${changedLines} lines, ${status.length} files)` }
        }
        if (hash === current.baseline) {
          return { reason: `no change made in this session yet (${changedLines} lines, ${status.length} files)` }
        }
      }

      if (hash === current.hash) return { reason: "diff unchanged since last review" }
      if (changedLines < minChangedLines) {
        return { reason: `only ${changedLines} changed lines` }
      }
      return { diff: diffText, hash, changedLines, files: status.length }
    }

    // The panel runs concurrently with the agent's turn. It cannot be awaited
    // inside the context hook: a mutation of event.system made after an await
    // never reaches the model, because the system prompt is snapshotted when
    // the hook is entered. The findings are delivered as a synthetic message
    // instead, which is the only asynchronous channel the model actually reads.
    async function runPanel(sessionID, diffText, panelTimeoutMs) {
      const prompt = `${REVIEWER_PROMPT}\n\nDIFF:\n${
        diffText.length > maxDiffChars
          ? diffText.slice(0, maxDiffChars) + "\n... diff truncated ...\n"
          : diffText
      }`
      const used = new Set()
      const slots = Math.min(panel.length, pool.length)
      const settled = await Promise.allSettled(
        Array.from({ length: slots }, async (_, index) => {
          const order = [panel[index], ...pool.filter((m) => m !== panel[index])]
          const errors = []
          for (const modelID of order) {
            if (used.has(modelID)) continue
            // Claim before awaiting, so two slots cannot land on the same model.
            used.add(modelID)
            try {
              const text = await askModel(ctx, modelID, prompt, panelTimeoutMs)
              return { model: modelID, text }
            } catch (error) {
              used.delete(modelID)
              errors.push(`${modelID}: ${error?.message ?? error}`)
            }
          }
          throw new Error(errors.join(" | "))
        }),
      )
      const results = settled
        .filter((entry) => entry.status === "fulfilled")
        .map((entry) => entry.value)
      if (!results.length) {
        const why = settled.map((entry) => entry.reason?.message ?? "?").join(" | ")
        throw new Error(`every panel model failed: ${why}`)
      }
      return {
        report: buildReport(results),
        models: results.map((r) => r.model),
        detail: results
          .map((r) => `${r.model}: ${String(r.text).replace(/\s+/g, " ").slice(0, 160)}`)
          .join("\n      "),
      }
    }

    await ctx.session.hook("context", async (event) => {
      const current = state.get(event.sessionID) ?? {
        hash: "",
        baseline: "",
        rounds: 0,
        lastAt: 0,
        running: false,
      }
      try {
        const found = await detect(event, current)
        if (!found.diff) {
          if (found.reason?.startsWith("baseline captured")) remember(event.sessionID, current)
          log(`skip ${found.reason} session=${event.sessionID} agent=${event.agent}`)
          return
        }
        if (current.running) {
          log(`skip panel already running session=${event.sessionID}`)
          return
        }

        current.running = true
        current.hash = found.hash
        current.lastAt = Date.now()
        remember(event.sessionID, current)
        log(
          `panel starting session=${event.sessionID} files=${found.files} ` +
            `changed=${found.changedLines}`,
        )

        const sessionID = event.sessionID
        runPanel(sessionID, found.diff, panelTimeoutMs)
          .then(async ({ report, models, detail }) => {
            if (!report) {
              log(
                `panel ${sessionID} found nothing (models=${models.join(",")} files=${found.files} changed=${found.changedLines})\n      ${detail}`,
              )
              return
            }
            current.rounds += 1
            current.running = false
            remember(sessionID, current)
            await ctx.session
              .synthetic({ sessionID, text: report, delivery: "steer" })
              .catch((error) => {
                log(`delivery failed: ${error?.message ?? error}`)
              })
            log(
              `panel session=${sessionID} models=${models.join(",")} files=${found.files} ` +
                `changed=${found.changedLines} findings=delivered round=${current.rounds}/${maxRounds}\n${report}`,
            )
          })
          .catch((error) => {
            current.running = false
            remember(sessionID, current)
            log(`panel failed: ${error?.message ?? error}`)
          })
      } catch (error) {
        // A failed panel must never break the session.
        log(`error: ${error?.message ?? error}`)
      }
    })
  },
}
