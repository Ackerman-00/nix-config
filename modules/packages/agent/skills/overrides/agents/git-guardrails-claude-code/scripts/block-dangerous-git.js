import fs from "node:fs"
import path from "node:path"
import { fileURLToPath } from "node:url"

// OpenCode plugin that blocks destructive git commands.
//
// The blocked patterns live in blocked-git-patterns.txt next to this file,
// one extended regular expression per line. Blank lines and lines starting
// with "#" are ignored.
//
// The plugin evaluates shell permission requests dynamically, so it also
// catches a dangerous command hidden inside a compound command such as
// "cd repo && git push --force".

const PATTERN_FILE = path.join(path.dirname(fileURLToPath(import.meta.url)), "blocked-git-patterns.txt")

function loadPatterns(file) {
  try {
    return fs
      .readFileSync(file, "utf8")
      .split("\n")
      .map((line) => line.trim())
      .filter((line) => line.length > 0 && !line.startsWith("#"))
  } catch (error) {
    console.error(`[git-guardrails] cannot read ${file}: ${error.message}`)
    return []
  }
}

function findBlocked(patterns, resources) {
  for (const resource of resources) {
    if (typeof resource !== "string") continue
    for (const pattern of patterns) {
      try {
        if (new RegExp(pattern).test(resource)) return { resource, pattern }
      } catch {
        // An invalid pattern must not block anything.
      }
    }
  }
  return null
}

export default {
  id: "git-guardrails",
  async setup(ctx) {
    const patterns = loadPatterns(PATTERN_FILE)
    if (patterns.length === 0) return

    const registration = await ctx.permission.hook("evaluate", async (event) => {
      if (event.action !== "shell") return
      const blocked = findBlocked(patterns, event.resources ?? [])
      if (!blocked) return
      event.effect = "deny"
      event.message = `Blocked by git guardrails: '${blocked.resource}' matches '${blocked.pattern}'.`
    })

    return () => registration.dispose()
  },
}
