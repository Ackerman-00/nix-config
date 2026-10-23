import { DatabaseSync } from "node:sqlite"
import { existsSync, mkdirSync, readFileSync, readdirSync, renameSync, rmSync, writeFileSync } from "node:fs"
import { homedir } from "node:os"
import { join } from "node:path"
import { buildTranscript, runNeurakeep } from "./lib.mjs"

const HOME = homedir()
const NEURAKEEP_HOME = join(HOME, ".local", "share", "neurakeep")
const DB_PATH = join(HOME, ".local", "share", "opencode", "opencode.db")
const VAULT = join(NEURAKEEP_HOME, "vault")
const VAULT_DB = join(VAULT, "memory.sqlite")
const CLI = join(NEURAKEEP_HOME, "node_modules", "neurakeep", "dist", "cli", "index.js")
const STAGE_DIR = join(NEURAKEEP_HOME, "backfill")
const MANIFEST_PATH = join(NEURAKEEP_HOME, "captured.v2.json")
const QUEUE_PATH = join(NEURAKEEP_HOME, "queue.v2.json")
const KANKAN_VAULT = join(HOME, "Documents", "Kankan", ".memory")

const args = process.argv.slice(2)
const flag = (name, fallback) => {
  const index = args.indexOf(`--${name}`)
  if (index < 0) return fallback
  const value = args[index + 1]
  return value && !value.startsWith("--") ? value : true
}

const INCLUDE_TMP = flag("include-tmp", false) === true
const SKIP_KANKAN = flag("skip-kankan", false) === true
const SPACE = String(flag("space", "personal"))

function log(line) {
  process.stdout.write(`${new Date().toISOString()} ${line}\n`)
}

function readJson(path, fallback) {
  try {
    if (!existsSync(path)) return fallback
    return JSON.parse(readFileSync(path, "utf8"))
  } catch {
    return fallback
  }
}

function writeJson(path, value) {
  const temp = `${path}.tmp`
  writeFileSync(temp, JSON.stringify(value))
  renameSync(temp, path)
}

function readMessages(db, sessionID) {
  const rows = db
    .prepare("SELECT type, seq, data FROM session_message WHERE session_id = ? ORDER BY seq ASC")
    .all(sessionID)
  const messages = []
  for (const row of rows) {
    let data
    try {
      data = JSON.parse(row.data)
    } catch {
      continue
    }
    messages.push({ type: row.type, data })
  }
  return messages
}

function messageText(message) {
  if (typeof message?.text === "string" && message.text.trim()) return message.text
  const parts = Array.isArray(message?.content) ? message.content : []
  return parts
    .filter((part) => part?.type === "text" && typeof part.text === "string")
    .map((part) => part.text)
    .join("\n")
}

function sectionsFor(vaultDb, sourceId) {
  const rows = vaultDb
    .prepare("SELECT id, heading, body FROM sections WHERE source_id = ? ORDER BY ordinal ASC")
    .all(sourceId)
  return rows.map((row) => ({ id: row.id, heading: row.heading, body: row.body }))
}

async function main() {
  if (!existsSync(DB_PATH)) throw new Error(`no opencode database at ${DB_PATH}`)
  const db = new DatabaseSync(DB_PATH, { readOnly: true })
  const vaultDb = new DatabaseSync(VAULT_DB, { readOnly: true })
  mkdirSync(STAGE_DIR, { recursive: true })

  const sessions = db
    .prepare("SELECT id, directory, title, parent_id, time_created FROM session_v2 ORDER BY time_created ASC")
    .all()

  const manifest = readJson(MANIFEST_PATH, { sessions: {} }).sessions ?? {}
  const queue = readJson(QUEUE_PATH, [])
  if (!Array.isArray(queue)) queue.length = 0
  const queuedSources = new Set(queue.map((item) => item.sourceId))

  let ingested = 0
  let skipped = 0
  let queued = 0
  let failed = 0

  log(`backfill: ${sessions.length} sessions, includeTmp=${INCLUDE_TMP}, skipKankan=${SKIP_KANKAN}`)

  for (const session of sessions) {
    const directory = session.directory ?? ""
    if (!INCLUDE_TMP && directory.startsWith("/tmp")) {
      skipped++
      continue
    }
    const messages = readMessages(db, session.id)
    if (!messages.length) continue

    const blocks = []
    for (const message of messages) {
      if (message.type !== "user" && message.type !== "assistant") continue
      const text = messageText(message.data).slice(0, 4000)
      if (!text.trim()) continue
      blocks.push({ role: message.type, text })
    }
    const totalChars = blocks.reduce((sum, block) => sum + block.text.length, 0)
    if (!blocks.length || totalChars < 60) {
      skipped++
      continue
    }

    const agent =
      [...messages].reverse().find((message) => message.type === "assistant")?.data?.agent ?? ""
    const meta = {
      sessionID: session.id,
      project: directory ? directory.split("/").filter(Boolean).pop() : "unknown",
      title: session.title ?? "",
      agent,
    }
    const transcript = buildTranscript(blocks, meta)
    const file = join(STAGE_DIR, `${session.id}.jsonl`)
    writeFileSync(file, transcript)

    try {
      const ingest = await runNeurakeep({
        cli: CLI,
        root: VAULT,
        args: [
          "ingest",
          file,
          "--kind",
          "session",
          "--space",
          SPACE,
          "--trust-level",
          "observed",
          "--origin",
          "session",
          "--visibility",
          "private",
          "--sensitivity",
          "internal",
        ],
        timeout: 60000,
      })
      if (!ingest?.sourceId) {
        failed++
        log(`ingest failed ${session.id}: ${JSON.stringify(ingest).slice(0, 200)}`)
        continue
      }
      if (ingest.skipped) {
        skipped++
        manifest[session.id] = { index: messages.length, at: new Date().toISOString() }
        continue
      }
      ingested++

      const sections = sectionsFor(vaultDb, ingest.sourceId)
      if (sections.length === blocks.length + 1 && !queuedSources.has(ingest.sourceId)) {
        queuedSources.add(ingest.sourceId)
        queue.push({
          sourceId: ingest.sourceId,
          sessionID: session.id,
          project: meta.project,
          title: meta.title,
          agent: meta.agent,
          sectionIds: sections.map((section) => section.id),
          headerOffset: 1,
          blocks: sections.slice(1).map((section) => ({ role: "document", text: section.body })),
        })
        queued++
      } else {
        log(`section mismatch for ${session.id}: ${sections.length} vs ${blocks.length + 1}`)
      }
      manifest[session.id] = { index: messages.length, at: new Date().toISOString() }
    } catch (error) {
      failed++
      log(`session failed ${session.id}: ${error?.message ?? error}`)
    } finally {
      rmSync(file, { force: true })
    }
  }

  if (!SKIP_KANKAN && existsSync(KANKAN_VAULT)) {
    const files = [
      ...readdirSync(join(KANKAN_VAULT, "raw", "episodes")).map((name) =>
        join(KANKAN_VAULT, "raw", "episodes", name),
      ),
      ...readdirSync(join(KANKAN_VAULT, "wiki")).map((name) => join(KANKAN_VAULT, "wiki", name)),
    ]
    for (const path of files) {
      if (!path.endsWith(".md")) continue
      const name = path.split("/").pop()
      try {
        const ingest = await runNeurakeep({
          cli: CLI,
          root: VAULT,
          args: [
            "ingest",
            path,
            "--kind",
            "markdown",
            "--space",
            "project",
            "--trust-level",
            "trusted",
            "--origin",
            "import",
            "--visibility",
            "private",
            "--sensitivity",
            "internal",
          ],
          timeout: 60000,
        })
        if (!ingest?.sourceId) continue
        if (ingest.skipped) continue
        ingested++
        const sections = sectionsFor(vaultDb, ingest.sourceId)
        if (!sections.length) continue
        queue.push({
          sourceId: ingest.sourceId,
          sessionID: `kankan-${name}`,
          project: "Kankan",
          title: name,
          agent: "",
          sectionIds: sections.map((section) => section.id),
          headerOffset: 0,
          blocks: sections.map((section) => ({ role: "document", text: section.body })),
        })
        queued++
      } catch (error) {
        failed++
        log(`kankan file failed ${path}: ${error?.message ?? error}`)
      }
    }
  }

  writeJson(QUEUE_PATH, queue)
  writeJson(MANIFEST_PATH, {
    version: 1,
    updatedAt: new Date().toISOString(),
    sessions: manifest,
  })
  db.close()
  vaultDb.close()
  log(`backfill done: ingested=${ingested} queued=${queued} skipped=${skipped} failed=${failed}`)
}

main().catch((error) => {
  log(`backfill failed: ${error?.stack ?? error}`)
  process.exit(1)
})
