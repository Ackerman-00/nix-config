import { execFile } from "node:child_process"
import { promisify } from "node:util"

const execFileAsync = promisify(execFile)

export function indentBody(text) {
  return text
    .replace(/\r\n/g, "\n")
    .split("\n")
    .map((line, index) => (index === 0 ? line : " " + line))
    .join("\n")
}

export function buildTranscript(blocks, meta) {
  const header = [
    `Session-Id: ${meta.sessionID}`,
    `Project: ${meta.project}`,
    `Title: ${meta.title}`,
    `Agent-Name: ${meta.agent}`,
  ].join("\n")
  const body = blocks
    .map((block, index) => `${block.role}: [M${index}] ${indentBody(block.text)}`)
    .join("\n\n")
  return `${header}\n\n${body}\n`
}

export function parseJsonLoose(text) {
  if (!text) return null
  let cleaned = text.trim()
  const fence = cleaned.match(/```(?:json)?\s*([\s\S]*?)```/i)
  if (fence) cleaned = fence[1].trim()
  try {
    return JSON.parse(cleaned)
  } catch {
  }
  const start = cleaned.indexOf("{")
  if (start < 0) return null
  let depth = 0
  let inString = false
  let escaped = false
  for (let index = start; index < cleaned.length; index++) {
    const char = cleaned[index]
    if (inString) {
      if (escaped) escaped = false
      else if (char === "\\") escaped = true
      else if (char === '"') inString = false
      continue
    }
    if (char === '"') inString = true
    else if (char === "{") depth++
    else if (char === "}") {
      depth--
      if (depth === 0) {
        try {
          return JSON.parse(cleaned.slice(start, index + 1))
        } catch {
          return null
        }
      }
    }
  }
  return null
}

export function toSectionIndex(value) {
  if (typeof value === "number" && Number.isInteger(value)) return value
  const match = String(value ?? "").match(/-?\d+/)
  if (!match) return null
  const parsed = Number.parseInt(match[0], 10)
  return Number.isInteger(parsed) ? parsed : null
}

export function stringsOnly(value, max = 12) {
  if (!Array.isArray(value)) return []
  return value.filter((item) => typeof item === "string" && item.trim()).slice(0, max)
}

function buildDiff(parsed, cite) {
  const diff = { events: [], facts: [], failures: [] }
  for (const event of Array.isArray(parsed?.events) ? parsed.events : []) {
    const cited = cite(event?.section)
    if (!cited.length) continue
    if (typeof event?.summary !== "string" || !event.summary.trim()) continue
    diff.events.push({
      type: event.type === "decision" ? "decision" : "event",
      summary: event.summary.trim(),
      sectionIds: cited,
      project: typeof event.project === "string" ? event.project : null,
      graphSubjects: stringsOnly(event.graphSubjects),
      confidence: typeof event.confidence === "number" ? event.confidence : 0.7,
    })
  }
  for (const fact of Array.isArray(parsed?.facts) ? parsed.facts : []) {
    const cited = cite(fact?.section)
    if (!cited.length) continue
    if (typeof fact?.subject !== "string" || !fact.subject.trim()) continue
    if (typeof fact?.predicate !== "string" || !fact.predicate.trim()) continue
    if (typeof fact?.object !== "string" || !fact.object.trim()) continue
    diff.facts.push({
      subject: fact.subject.trim(),
      predicate: fact.predicate.trim(),
      object: fact.object.trim(),
      sectionIds: cited,
      graphSubjects: stringsOnly(fact.graphSubjects),
      confidence: typeof fact.confidence === "number" ? fact.confidence : 0.7,
    })
  }
  for (const failure of Array.isArray(parsed?.failures) ? parsed.failures : []) {
    const cited = cite(failure?.section)
    if (!cited.length) continue
    if (typeof failure?.attempted !== "string" || !failure.attempted.trim()) continue
    if (typeof failure?.failedBecause !== "string" || !failure.failedBecause.trim()) continue
    if (typeof failure?.doNotRepeat !== "string" || !failure.doNotRepeat.trim()) continue
    diff.failures.push({
      attempted: failure.attempted.trim(),
      failedBecause: failure.failedBecause.trim(),
      doNotRepeat: failure.doNotRepeat.trim(),
      revisitCondition: typeof failure.revisitCondition === "string" ? failure.revisitCondition : null,
      sectionIds: cited,
      graphSubjects: stringsOnly(failure.graphSubjects),
      confidence: typeof failure.confidence === "number" ? failure.confidence : 0.85,
    })
  }
  return diff
}

export function toDiff(parsed, sectionIds) {
  const messageCount = sectionIds.length - 1
  return buildDiff(parsed, (value) => {
    const index = toSectionIndex(value)
    if (index === null || index < 0 || index >= messageCount) return []
    return [sectionIds[index + 1]]
  })
}

export function toDiffBatch(parsed, items) {
  const byIndex = new Map(items.map((item) => [item.sessionIndex, item]))
  const out = new Map()
  for (const entry of Array.isArray(parsed?.sessions) ? parsed.sessions : []) {
    const item = byIndex.get(Number(entry?.session))
    if (!item) continue
    const offset = item.headerOffset ?? 1
    const messageCount = item.sectionIds.length - offset
    const diff = buildDiff(entry, (value) => {
      const ref = String(value ?? "").trim()
      const match = ref.match(/^S(\d+):M(\d+)$/i)
      let messageIndex = null
      if (match) {
        if (Number(match[1]) !== item.sessionIndex) return []
        messageIndex = Number(match[2])
      } else {
        messageIndex = toSectionIndex(ref)
      }
      if (messageIndex === null || messageIndex < 0 || messageIndex >= messageCount) return []
      return [item.sectionIds[messageIndex + offset]]
    })
    out.set(item.sessionIndex, diff)
  }
  return out
}

export function buildBatchExtractionPrompt(items, maxCharsPerItem = 6000) {
  const sections = items.map((item) => {
    const lines = [`[S${item.sessionIndex}] session=${item.sessionID} project=${item.project} title=${item.title}`]
    item.blocks.forEach((block, index) => {
      const text = String(block.text ?? "").slice(0, maxCharsPerItem)
      lines.push(`[S${item.sessionIndex}:M${index}] ${block.role}: ${text}`)
    })
    return lines.join("\n")
  })
  return [
    "You extract durable memory from transcripts of past coding sessions.",
    "",
    "Return ONLY a JSON object. No prose, no markdown fence. Shape:",
    '{"sessions":[{"session":0,"events":[{"type":"event","summary":"...","section":"S0:M3"}],',
    '"facts":[{"subject":"...","predicate":"...","object":"...","section":"S0:M1","confidence":0.9}],',
    '"failures":[{"attempted":"...","failedBecause":"...","doNotRepeat":"...","section":"S0:M2"}]}]}',
    "",
    "The \"session\" field is the S number of the transcript the item came from.",
    "The \"section\" field is the S and M marker of the exact message the item came from.",
    "",
    "Keep only what helps a future session: decisions and their reasons, user preferences,",
    "environment and tooling facts, constraints, and anything that broke and how it was fixed.",
    "A failure needs a doNotRepeat rule written as a short imperative.",
    "Skip transient chatter, tool output, file listings, and anything already obvious from the code.",
    "Never record secrets, tokens, credentials, or private keys.",
    "Per transcript: at most 8 events, 12 facts and 5 failures. Every item must cite a marker that exists.",
    "",
    "TRANSCRIPTS:",
    sections.join("\n\n"),
  ].join("\n")
}

export function buildExtractionPrompt(blocks, meta) {
  const transcript = blocks
    .map((block, index) => `[M${index}] ${block.role}: ${block.text}`)
    .join("\n\n")
  return [
    "You extract durable memory from a coding session transcript.",
    "",
    'Return ONLY a JSON object with the keys "events", "facts" and "failures". No prose, no markdown fence.',
    'Each item must carry a "section" field holding the integer index of the [Mn] marker it came from.',
    "",
    'events: [{"type": "event" | "decision", "summary": "...", "section": 0, "project": "optional", "confidence": 0.0}]',
    'facts: [{"subject": "...", "predicate": "...", "object": "...", "section": 0, "confidence": 0.0}]',
    'failures: [{"attempted": "...", "failedBecause": "...", "doNotRepeat": "...", "revisitCondition": "...", "section": 0}]',
    "",
    "Keep only what helps a future session: decisions and their reasons, user preferences,",
    "environment and tooling facts, constraints, and anything that broke and how it was fixed.",
    "A failure needs a doNotRepeat rule written as a short imperative.",
    "Skip transient chatter, tool output, file listings, and anything already obvious from the code.",
    "Never record secrets, tokens, credentials, or private keys.",
    "At most 8 events, 12 facts and 5 failures. Every item must cite a section index that exists.",
    "",
    `Project: ${meta.project}`,
    `Agent: ${meta.agent}`,
    "",
    "TRANSCRIPT:",
    transcript,
  ].join("\n")
}

export function parseModelRef(value) {
  const [providerID, ...rest] = String(value).split("/")
  if (!providerID || rest.length === 0) return null
  return { providerID, id: rest.join("/") }
}

export async function runNeurakeep(options) {
  const { cli, root, args, timeout = 60000, env } = options
  const { stdout } = await execFileAsync("node", [cli, ...args, "--root", root, "--json"], {
    timeout,
    maxBuffer: 32 * 1024 * 1024,
    env: { ...process.env, ...(env ?? {}) },
  })
  const text = stdout.trim()
  if (!text) return null
  try {
    return JSON.parse(text)
  } catch {
    return { raw: text }
  }
}
