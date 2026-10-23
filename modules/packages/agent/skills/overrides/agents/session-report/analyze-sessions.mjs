#!/usr/bin/env node
/* eslint-disable */
/**
 * analyze-sessions.mjs
 *
 * Reads the OpenCode session database and reports token usage, message
 * counts, runtime, cache breaks, subagent activity, and skill usage.
 *
 * Usage:
 *   node analyze-sessions.mjs [--db <path>] [--json] [--since <ISO|7d|24h>] [--top N]
 *                            [--cache-break <tokens>]
 *
 * Storage layout (verified against opencode.db):
 *   session_v2      id, project_id, parent_id, title, agent, model, cost,
 *                   tokens_input, tokens_output, tokens_reasoning,
 *                   tokens_cache_read, tokens_cache_write, directory,
 *                   time_created, time_updated
 *   session_message id, session_id, type, seq, time_created, data (JSON)
 *   project         id, worktree, name
 *
 * Message data shapes:
 *   assistant -> { time, agent, model, content[], cost, tokens:{ input, output,
 *                  reasoning, cache:{ read, write } } }
 *   user      -> { time, text, files?, agents?, skills? }
 *   content[] -> { type: "text" | "reasoning" | "tool", name?, state?:{ status,
 *                  input, output } }
 *
 * Attribution rules:
 *   - A model call is an assistant message that carries a `tokens` object.
 *   - A prompt is a user message; the model calls that follow it, up to the
 *     next user message, are attributed to that prompt.
 *   - A subagent call is a session whose `parent_id` is set. Its tokens are
 *     counted separately and never folded into the parent's prompt totals.
 *   - A skill usage is a tool part named "skill"; the tokens of the prompt
 *     turn it was loaded in are attributed to that skill, split evenly when
 *     one turn loads several.
 */

import fs from "fs"
import os from "os"
import path from "path"

const argv = process.argv.slice(2)
function flag(name, dflt) {
  const i = argv.indexOf(name)
  if (i === -1) return dflt
  const v = argv[i + 1]
  return v === undefined || v.startsWith("--") ? true : v
}

const DB = flag("--db", path.join(os.homedir(), ".local", "share", "opencode", "opencode.db"))
const AS_JSON = argv.includes("--json")
const TOP_N = parseInt(flag("--top", "15"), 10)
const CACHE_BREAK_THRESHOLD = parseInt(flag("--cache-break", "100000"), 10)
const SINCE = parseSince(flag("--since", null))
const IDLE_GAP_MS = 5 * 60 * 1000

function parseSince(s) {
  if (!s) return null
  const m = /^(\d+)([dh])$/.exec(s)
  if (m) {
    const ms = m[2] === "d" ? 86400000 : 3600000
    return new Date(Date.now() - parseInt(m[1], 10) * ms)
  }
  const d = new Date(s)
  return isNaN(d) ? null : d
}

// ---------------------------------------------------------------------------
// Database access
// ---------------------------------------------------------------------------
let DatabaseSync
try {
  ;({ DatabaseSync } = await import("node:sqlite"))
} catch {
  console.error("node:sqlite is unavailable. Node 22.5 or newer is required.")
  process.exit(1)
}

if (!fs.existsSync(DB)) {
  console.error(`No session database at ${DB}`)
  process.exit(1)
}

const db = new DatabaseSync(DB, { readOnly: true })

const projectRows = db.prepare("select id, worktree, name from project").all()
const projectById = new Map()
for (const row of projectRows) projectById.set(row.id, row)

const sessionRows = db.prepare(
  `select id, project_id, parent_id, title, agent, model, cost,
          tokens_input, tokens_output, tokens_reasoning,
          tokens_cache_read, tokens_cache_write, directory,
          time_created, time_updated
     from session_v2
    order by time_created asc`,
).all()

const sessionById = new Map()
for (const row of sessionRows) sessionById.set(row.id, row)

const messageRows = db.prepare(
  "select session_id, type, seq, time_created, data from session_message order by session_id asc, seq asc",
).all()

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------
function projectKey(session) {
  const project = projectById.get(session.project_id)
  const root = project?.worktree || session.directory || "unknown"
  return root
}

function shortPath(p) {
  const home = os.homedir()
  let s = String(p || "")
  if (home && s.startsWith(home)) s = "~" + s.slice(home.length)
  const parts = s.split("/").filter(Boolean)
  return parts.length > 2 ? parts.slice(-2).join("/") : s
}

function newStats() {
  return {
    sessions: new Set(),
    apiCalls: 0,
    inputUncached: 0,
    inputCacheRead: 0,
    inputCacheWrite: 0,
    outputTokens: 0,
    reasoningTokens: 0,
    cost: 0,
    humanMessages: 0,
    wallClockMs: 0,
    activeMs: 0,
    cacheBreaks: [],
    subagentCalls: 0,
    subagentTokens: 0,
    skillInvocations: {},
    firstTs: null,
    lastTs: null,
  }
}

function emptyComponent() {
  return {
    sessions: new Set(),
    apiCalls: 0,
    humanMessages: 0,
    inputUncached: 0,
    inputCacheRead: 0,
    inputCacheWrite: 0,
    outputTokens: 0,
    hours: { active: 0, wall_clock: 0 },
    cacheBreaks: 0,
    subagent: { calls: 0, tokens: 0 },
  }
}

function addToComponent(component, usage) {
  component.apiCalls += 1
  component.inputUncached += usage.uncached
  component.inputCacheRead += usage.cacheRead
  component.inputCacheWrite += usage.cacheWrite
  component.outputTokens += usage.output
}

function finishComponent(component) {
  const total = component.inputUncached + component.inputCacheRead + component.inputCacheWrite
  return {
    sessions: component.sessions.size,
    api_calls: component.apiCalls,
    human_messages: component.humanMessages,
    input_tokens: {
      total,
      uncached: component.inputUncached,
      cache_create: component.inputCacheWrite,
      cache_read: component.inputCacheRead,
      pct_cached: total > 0 ? Math.round((component.inputCacheRead / total) * 100) : 0,
    },
    output_tokens: component.outputTokens,
    hours: {
      active: Math.round((component.hours.active / 3600000) * 10) / 10,
      wall_clock: Math.round((component.hours.wall_clock / 3600000) * 10) / 10,
    },
    cache_breaks_over_100k: component.cacheBreaks,
    subagent: {
      calls: component.subagent.calls,
      avg_tokens_per_call:
        component.subagent.calls > 0
          ? Math.round(component.subagent.tokens / component.subagent.calls)
          : 0,
    },
  }
}

// ---------------------------------------------------------------------------
// Walk sessions
// ---------------------------------------------------------------------------
const overall = newStats()
const byProject = new Map()
const bySubagent = new Map()
const bySkill = new Map()
const prompts = []
const cacheBreaks = []
const days = new Map()

function componentFor(map, key) {
  if (!map.has(key)) map.set(key, emptyComponent())
  return map.get(key)
}

function dayKey(ts) {
  const d = new Date(ts)
  const y = d.getFullYear()
  const m = String(d.getMonth() + 1).padStart(2, "0")
  const day = String(d.getDate()).padStart(2, "0")
  return `${y}-${m}-${day}`
}

function dowOf(key) {
  const names = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
  const [y, m, d] = key.split("-").map(Number)
  return names[new Date(y, m - 1, d).getDay()]
}

const messagesBySession = new Map()
for (const row of messageRows) {
  if (!messagesBySession.has(row.session_id)) messagesBySession.set(row.session_id, [])
  messagesBySession.get(row.session_id).push(row)
}

for (const session of sessionRows) {
  if (SINCE && session.time_created < SINCE.getTime()) continue

  const isSubagent = !!session.parent_id
  const project = projectKey(session)
  const agentId = session.agent || (isSubagent ? "subagent" : "unknown")
  const messages = messagesBySession.get(session.id) || []

  // Skip sessions with no activity in the window when a window is set.
  const sessionStart = session.time_created
  const sessionEnd = session.time_updated || session.time_created
  if (SINCE && sessionEnd < SINCE.getTime()) continue

  const projectComponent = componentFor(byProject, project)
  projectComponent.sessions.add(session.id)

  const sessionStats = newStats()
  let currentPrompt = null
  const promptStack = []
  let lastActivityTs = null

  for (const row of messages) {
    if (SINCE && row.time_created < SINCE.getTime()) continue
    let data
    try {
      data = JSON.parse(row.data)
    } catch {
      continue
    }

    if (row.type === "user") {
      const text = typeof data.text === "string" ? data.text : ""
      const prompt = {
        ts: row.time_created,
        project,
        session: session.id,
        text: text.slice(0, 400),
        api_calls: 0,
        subagent_calls: 0,
        skills: [],
        input: { uncached: 0, cache_create: 0, cache_read: 0 },
        output: 0,
        total_tokens: 0,
        context: [],
      }
      promptStack.push(prompt)
      currentPrompt = prompt
      sessionStats.humanMessages += 1
      projectComponent.humanMessages += 1
      overall.humanMessages += 1
      if (isSubagent) {
        const sub = componentFor(bySubagent, agentId)
        sub.humanMessages += 1
      }
      continue
    }

    if (row.type !== "assistant") continue

    const content = Array.isArray(data.content) ? data.content : []
    const skillsInTurn = []
    for (const part of content) {
      if (part.type !== "tool" || part.name !== "skill") continue
      const id = part.state?.input?.id || part.state?.input?.skill
      if (id) skillsInTurn.push(String(id))
    }
    if (skillsInTurn.length && currentPrompt) {
      for (const id of skillsInTurn) {
        if (!currentPrompt.skills.includes(id)) currentPrompt.skills.push(id)
        overall.skillInvocations[id] = (overall.skillInvocations[id] || 0) + 1
      }
    }

    const tokens = data.tokens
    if (!tokens) continue

    const usage = {
      uncached: tokens.input || 0,
      cacheRead: tokens.cache?.read || 0,
      cacheWrite: tokens.cache?.write || 0,
      output: tokens.output || 0,
      reasoning: tokens.reasoning || 0,
    }
    const totalInput = usage.uncached + usage.cacheRead + usage.cacheWrite

    sessionStats.apiCalls += 1
    sessionStats.inputUncached += usage.uncached
    sessionStats.inputCacheRead += usage.cacheRead
    sessionStats.inputCacheWrite += usage.cacheWrite
    sessionStats.outputTokens += usage.output
    sessionStats.reasoningTokens += usage.reasoning
    overall.apiCalls += 1
    overall.inputUncached += usage.uncached
    overall.inputCacheRead += usage.cacheRead
    overall.inputCacheWrite += usage.cacheWrite
    overall.outputTokens += usage.output
    overall.reasoningTokens += usage.reasoning
    overall.cost += data.cost || 0
    addToComponent(projectComponent, usage)

    if (currentPrompt) {
      currentPrompt.api_calls += 1
      currentPrompt.input.uncached += usage.uncached
      currentPrompt.input.cache_create += usage.cacheWrite
      currentPrompt.input.cache_read += usage.cacheRead
      currentPrompt.output += usage.output
      currentPrompt.total_tokens += totalInput + usage.output
    }

    // Skill attribution: split the turn across the skills it loaded.
    if (skillsInTurn.length && currentPrompt) {
      const share = (totalInput + usage.output) / skillsInTurn.length
      for (const id of skillsInTurn) {
        if (!bySkill.has(id)) bySkill.set(id, emptyComponent())
        const skill = bySkill.get(id)
        skill.apiCalls += 1
        skill.sessions.add(session.id)
        skill.inputUncached += usage.uncached / skillsInTurn.length
        skill.inputCacheRead += usage.cacheRead / skillsInTurn.length
        skill.outputTokens += usage.output / skillsInTurn.length
      }
    }

    // Cache break: a call whose uncached input exceeds the threshold.
    if (usage.uncached > CACHE_BREAK_THRESHOLD) {
      const entry = {
        ts: row.time_created,
        project,
        session: session.id,
        uncached: usage.uncached,
        total: totalInput,
        kind: isSubagent ? "subagent" : "main",
        agentType: isSubagent ? agentId : undefined,
        context: [],
      }
      cacheBreaks.push(entry)
      sessionStats.cacheBreaks.push(entry)
      projectComponent.cacheBreaks += 1
    }

    // Runtime accounting
    if (lastActivityTs !== null) {
      const gap = row.time_created - lastActivityTs
      sessionStats.wallClockMs += gap
      if (gap <= IDLE_GAP_MS) sessionStats.activeMs += gap
    }
    lastActivityTs = row.time_created
    if (sessionStats.firstTs === null) sessionStats.firstTs = row.time_created
    sessionStats.lastTs = row.time_created
  }

  // Finish the prompt list for this session.
  for (const prompt of promptStack) {
    prompt.context = buildContext(promptStack, prompt)
    prompts.push(prompt)
  }

  // Subagent accounting
  if (isSubagent) {
    overall.subagentCalls += 1
    overall.subagentTokens += sessionStats.inputUncached + sessionStats.inputCacheRead + sessionStats.outputTokens
    const sub = componentFor(bySubagent, agentId)
    sub.subagent.calls += 1
    sub.subagent.tokens += sessionStats.inputUncached + sessionStats.inputCacheRead + sessionStats.outputTokens
    sub.apiCalls += sessionStats.apiCalls
    sub.outputTokens += sessionStats.outputTokens
    sub.inputUncached += sessionStats.inputUncached
    sub.inputCacheRead += sessionStats.inputCacheRead
  }

  // Day buckets
  const key = dayKey(sessionStart)
  if (!days.has(key)) days.set(key, { date: key, dow: dowOf(key), tokens: 0, sessions: [] })
  const day = days.get(key)
  day.tokens += sessionStats.inputUncached + sessionStats.inputCacheRead + sessionStats.outputTokens
  day.sessions.push({
    project,
    id: session.id,
    start_min: minutesOfDay(sessionStart),
    end_min: minutesOfDay(sessionEnd),
    tokens: sessionStats.inputUncached + sessionStats.inputCacheRead + sessionStats.outputTokens,
  })

  // Fold session stats into overall and the project component.
  overall.sessions.add(session.id)
  overall.wallClockMs += sessionStats.wallClockMs
  overall.activeMs += sessionStats.activeMs
  projectComponent.hours.wall_clock += sessionStats.wallClockMs
  projectComponent.hours.active += sessionStats.activeMs
  if (sessionStats.firstTs !== null) {
    if (overall.firstTs === null) overall.firstTs = sessionStats.firstTs
    overall.lastTs = sessionStats.lastTs
  }
}

function minutesOfDay(ts) {
  const d = new Date(ts)
  return d.getHours() * 60 + d.getMinutes()
}

function buildContext(stack, target) {
  const index = stack.indexOf(target)
  const slice = stack.slice(Math.max(0, index - 2), index + 1)
  return slice.map((p) => ({
    text: p.text.slice(0, 240),
    ts: p.ts,
    here: p === target,
    calls: p.api_calls,
  }))
}

// Cache break contexts: attach neighbouring prompts from the same session.
const promptsBySession = new Map()
for (const prompt of prompts) {
  if (!promptsBySession.has(prompt.session)) promptsBySession.set(prompt.session, [])
  promptsBySession.get(prompt.session).push(prompt)
}
for (const entry of cacheBreaks) {
  const list = promptsBySession.get(entry.session) || []
  const before = list.filter((p) => p.ts <= entry.ts).slice(-2)
  entry.context = before.map((p) => ({
    text: p.text.slice(0, 240),
    ts: p.ts,
    here: p.ts === entry.ts,
    calls: p.api_calls,
  }))
}

// ---------------------------------------------------------------------------
// Day peaks
// ---------------------------------------------------------------------------
const byDay = [...days.values()].sort((a, b) => (a.date < b.date ? -1 : 1))
for (const day of byDay) {
  const points = day.sessions.map((s) => [s.start_min, 1]).concat(day.sessions.map((s) => [s.end_min, -1]))
  points.sort((a, b) => a[0] - b[0])
  let current = 0
  let peak = 0
  let peakAt = day.sessions.length ? day.sessions[0].start_min : 0
  for (const [time, delta] of points) {
    current += delta
    if (current > peak) {
      peak = current
      peakAt = time
    }
  }
  day.peak = peak
  day.peak_at_min = peakAt
}

// ---------------------------------------------------------------------------
// Output
// ---------------------------------------------------------------------------
const totalInput = overall.inputUncached + overall.inputCacheRead + overall.inputCacheWrite
const overallComponent = finishComponent({
  sessions: overall.sessions,
  apiCalls: overall.apiCalls,
  humanMessages: overall.humanMessages,
  inputUncached: overall.inputUncached,
  inputCacheRead: overall.inputCacheRead,
  inputCacheWrite: overall.inputCacheWrite,
  outputTokens: overall.outputTokens,
  hours: { active: overall.activeMs, wall_clock: overall.wallClockMs },
  cacheBreaks: cacheBreaks.length,
  subagent: { calls: overall.subagentCalls, tokens: overall.subagentTokens },
})

const report = {
  generated_at: new Date().toISOString(),
  since: SINCE ? SINCE.toISOString() : null,
  root: DB,
  overall: {
    ...overallComponent,
    cost: Math.round(overall.cost * 10000) / 10000,
    reasoning_tokens: overall.reasoningTokens,
  },
  by_project: Object.fromEntries([...byProject.entries()].map(([k, v]) => [k, finishComponent(v)])),
  by_subagent_type: Object.fromEntries([...bySubagent.entries()].map(([k, v]) => [k, finishComponent(v)])),
  by_skill: Object.fromEntries([...bySkill.entries()].map(([k, v]) => [k, finishComponent(v)])),
  by_day: byDay,
  cache_breaks: cacheBreaks
    .sort((a, b) => b.uncached - a.uncached)
    .slice(0, 200),
  top_prompts: prompts
    .filter((p) => p.total_tokens > 0)
    .sort((a, b) => b.total_tokens - a.total_tokens)
    .slice(0, 100),
}

if (AS_JSON) {
  console.log(JSON.stringify(report))
} else {
  const o = report.overall
  console.log(`sessions      ${o.sessions}`)
  console.log(`api calls     ${o.api_calls}`)
  console.log(`prompts       ${o.human_messages}`)
  console.log(`input         ${totalInput} (${o.input_tokens.pct_cached}% cached)`)
  console.log(`output        ${o.output_tokens}`)
  console.log(`subagents     ${o.subagent.calls} (avg ${o.subagent.avg_tokens_per_call} tokens)`)
  console.log(`cache breaks  ${o.cache_breaks_over_100k}`)
  console.log(`active hours  ${o.hours.active} (${o.hours.wall_clock} wall-clock)`)
  console.log(`\nby project:`)
  for (const [k, v] of Object.entries(report.by_project).sort((a, b) => b[1].sessions - a[1].sessions)) {
    console.log(`  ${shortPath(k).padEnd(40)} ${v.sessions} sessions  ${v.api_calls} calls`)
  }
  console.log(`\nby skill:`)
  for (const [k, v] of Object.entries(report.by_skill).sort((a, b) => b[1].api_calls - a[1].api_calls)) {
    console.log(`  ${k.padEnd(40)} ${v.api_calls} calls`)
  }
}
