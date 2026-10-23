---
name: llm-wiki
description: "Build and maintain a compounding knowledge base as interlinked markdown: a wiki directory with SCHEMA.md, index.md, log.md, raw sources, and entity/concept/comparison pages with wikilinks, frontmatter, and provenance. Use for creating a KB, ingesting sources, querying it, or linting it."
---

# LLM Wiki

Build and maintain a persistent, compounding knowledge base as interlinked
markdown files. Based on
[Andrej Karpathy's LLM Wiki pattern](https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f).

Unlike traditional RAG (which rediscovers knowledge per query), the wiki
compiles knowledge once and keeps it current. Cross-references are already
there. Contradictions have already been flagged. Synthesis reflects everything
ingested.

**Division of labor:** the human curates sources and directs analysis; the
agent summarizes, cross-references, files, and maintains consistency.

## When this skill activates

- The user asks to create, build, or start a wiki or knowledge base.
- The user asks to ingest, add, or process a source into their wiki.
- The user asks a question and a wiki exists at the configured path.
- The user asks to lint, audit, or health-check their wiki.
- The user references "the wiki", "knowledge base", or "notes" in a research
  context.

## Wiki location

Set via `WIKI_PATH` (for example in `~/.config/opencode/AGENTS.md` or the
shell environment). Unset defaults to `~/wiki`.

```bash
WIKI="${WIKI_PATH:-$HOME/wiki}"
```

The wiki is a plain directory of markdown files. No database, no special
tooling. Open it in Obsidian, VS Code, or any editor.

## Architecture

```
wiki/
├── SCHEMA.md           # Conventions, structure rules, domain config
├── index.md            # Sectioned content catalog with one-line summaries
├── log.md              # Chronological action log (append-only, rotated yearly)
├── raw/                # Layer 1: immutable source material
│   ├── articles/       # Web articles, clippings
│   ├── papers/         # PDFs, arxiv papers
│   ├── transcripts/    # Meeting notes, interviews
│   └── assets/         # Images, diagrams referenced by sources
├── entities/           # Layer 2: entity pages
├── concepts/           # Layer 2: concept pages
├── comparisons/        # Layer 2: side-by-side analyses
└── queries/            # Layer 2: filed query results worth keeping
```

**Layer 1 - Raw sources:** immutable. Read but never modify.
**Layer 2 - The wiki:** agent-owned markdown, created and cross-referenced by
the agent.
**Layer 3 - The Schema:** `SCHEMA.md` defines structure, conventions, and tag
taxonomy.

## How this fits OpenCode

The wiki is the human-facing knowledge base. It is not the agent's memory
store.

- Durable agent memory on this machine lives in the NeuraKeep vault
  (`~/.local/share/neurakeep/vault`), queried with `memory_search` and
  `memory_read`, and captured automatically from every session.
- The wiki is what the user reads, edits, and diffs. It is versioned with
  the project when it lives inside a repo.
- Rules that must hold on every turn belong in `AGENTS.md`, not in a wiki
  page. Point at the wiki page instead.

Use the wiki for knowledge that is worth re-reading; use the vault for what
happened; use `AGENTS.md` for what must always apply.

## Resuming an existing wiki

Always orient before doing anything:

1. Read `SCHEMA.md` (domain, conventions, tag taxonomy).
2. Read `index.md` (what pages exist).
3. Scan the last 20-30 entries of `log.md` (recent activity).

This prevents duplicate pages, missing cross-references, schema violations,
and repeated work.

For wikis with 100+ pages, search the tree for the topic before creating
anything new.

## Initializing a new wiki

1. Determine the path (`$WIKI_PATH`, or ask; default `~/wiki`).
2. Create the directory structure above.
3. Ask the user what domain the wiki covers. Be specific.
4. Write `SCHEMA.md` customised to the domain.
5. Write initial `index.md` with sectioned headers.
6. Write initial `log.md` with the creation entry.
7. Confirm and suggest first sources to ingest.

### SCHEMA.md template

```markdown
# Wiki Schema

## Domain
[What this wiki covers]

## Conventions
- File names: lowercase, hyphens, no spaces
- Every wiki page starts with YAML frontmatter
- Use `[[wikilinks]]` to link between pages (minimum 2 outbound links)
- When updating a page, always bump the `updated` date
- Every new page must be added to `index.md` under the correct section
- Every action must be appended to `log.md`
- **Provenance markers:** on pages that synthesize 3+ sources, append
  `^[raw/articles/source-file.md]` at the end of paragraphs whose claims
  come from a specific source

## Frontmatter
  ```yaml
  ---
  title: Page Title
  created: YYYY-MM-DD
  updated: YYYY-MM-DD
  type: entity | concept | comparison | query | summary
  tags: [from taxonomy below]
  sources: [raw/articles/source-name.md]
  confidence: high | medium | low
  contested: true
  contradictions: [other-page-slug]
  ---
  ```

## Tag Taxonomy
[10-20 top-level tags. Add new tags here BEFORE using them.]

## Page Thresholds
- **Create a page** when an entity/concept appears in 2+ sources OR is
  central to one source
- **Add to an existing page** when a source mentions something already covered
- **DON'T create a page** for passing mentions or minor details
- **Split a page** when it exceeds ~200 lines
- **Archive a page** when its content is fully superseded

## Entity Pages
Overview, key facts and dates, relationships ([[wikilinks]]), source
references.

## Concept Pages
Definition, current state of knowledge, open questions, related concepts.

## Comparison Pages
What is compared and why, dimensions (table preferred), verdict, sources.

## Update Policy
When new information conflicts with existing content:
1. Check dates; newer sources generally supersede older ones
2. If genuinely contradictory, note both positions with dates and sources
3. Mark it: `contradictions: [page-name]`
4. Flag for review in the lint report
```

### index.md template

```markdown
# Wiki Index

> Content catalog. Every wiki page listed under its type with a one-line
> summary. Read this first to find relevant pages for any query.
> Last updated: YYYY-MM-DD | Total pages: N

## Entities
## Concepts
## Comparisons
## Queries
```

Scaling rule: when a section exceeds 50 entries, split it by first letter or
sub-domain. When the index exceeds 200 entries, create
`_meta/topic-map.md` grouping pages by theme.

### log.md template

```markdown
# Wiki Log

> Chronological record of all wiki actions. Append-only.
> Format: `## [YYYY-MM-DD] action | subject`
> Actions: ingest, update, query, lint, create, archive, delete
> When this file exceeds 500 entries, rotate: rename to log-YYYY.md.

## [YYYY-MM-DD] create | Wiki initialized
```

## Core operations

### 1. Ingest

1. **Capture the raw source.** URL or PDF: fetch it (the `webfetch` tool, or
   `curl`) and save the text under `raw/`. Pasted text: save to the right
   `raw/` subdirectory. Name the file descriptively, e.g.
   `raw/articles/karpathy-llm-wiki-2026.md`.
   Add raw frontmatter (`source_url`, `ingested`, `sha256` of the body). On
   re-ingest, recompute the sha256: skip if identical, flag drift if
   different.
2. **Discuss takeaways** with the user (skip in automated runs).
3. **Check what already exists** by searching `index.md` and the tree. This
   is the difference between a growing wiki and a pile of duplicates.
4. **Write or update pages:**
   - New pages only if they meet the Page Thresholds.
   - Existing pages: add new information, update facts, bump `updated`.
   - Cross-reference: every new or updated page links to at least 2 others.
   - Tags: only from the taxonomy in `SCHEMA.md`.
   - Provenance: append `^[raw/articles/source.md]` on multi-source pages.
   - Confidence: `medium` or `low` for opinion-heavy, fast-moving, or
     single-source claims.
5. **Update navigation:** add pages to `index.md` under the correct section,
   update the page count and date, append to `log.md`, list every file
   touched.
6. **Report what changed**, file by file.

A single source can trigger updates across 5-15 pages. That is the point.

### 2. Query

1. Read `index.md` to identify relevant pages.
2. For wikis with 100+ pages, also search all `.md` files for key terms.
3. Read the relevant pages.
4. Synthesise from the compiled knowledge and cite the pages used.
5. File valuable answers back into `queries/` or `comparisons/`. Do not file
   trivial lookups.
6. Update `log.md` with the query and whether it was filed.

### 3. Lint

1. **Orphan pages:** pages with no inbound `[[wikilinks]]`.
2. **Broken wikilinks:** `[[links]]` pointing at pages that do not exist.
3. **Index completeness:** every page appears in `index.md`.
4. **Frontmatter validation:** required fields present, tags in the taxonomy.
5. **Stale content:** `updated` more than 90 days older than the most recent
   source on the same entity.
6. **Contradictions:** pages with `contested: true` or `contradictions:`.
7. **Quality signals:** pages with `confidence: low`, and single-source pages
   with no confidence field.
8. **Source drift:** recompute `sha256` for each `raw/` file and flag
   mismatches.
9. **Page size:** flag pages over 200 lines as split candidates.
10. **Tag audit:** list tags in use that are not in the taxonomy.
11. **Log rotation:** `log.md` over 500 entries.
12. **Report** findings grouped by severity: broken links > orphans > source
    drift > contested pages > stale content > style.
13. **Append to `log.md`:** `## [YYYY-MM-DD] lint | N issues found`.

## Working with the wiki

```bash
# Find pages by content
rg -l "transformer" "$WIKI" --glob '*.md'
# Find pages by filename
rg --files "$WIKI" -g '*.md'
# Recent activity
tail -30 "$WIKI/log.md"
```

### Bulk ingest

Read all sources first, find all entities and concepts in one pass, check
existing pages in one search pass, create or update pages in one pass, update
`index.md` once, and write a single log entry covering the batch.

### Archiving

Move the page to `_archive/` keeping its relative path, remove it from
`index.md`, update inbound links to plain text plus "(archived)", and log
the action.

### Obsidian integration

The wiki directory works as an Obsidian vault: `[[wikilinks]]` render as
clickable links, Graph View visualises the network, YAML frontmatter powers
Dataview queries, `raw/assets/` holds images referenced via `![[image.png]]`.

Set Obsidian's attachment folder to `raw/assets/`. If the `obsidian` skill is
used alongside this one, point `OBSIDIAN_VAULT_PATH` at the same directory.

### Obsidian headless (servers)

On a machine without a display, `obsidian-headless` syncs vaults through
Obsidian Sync without a GUI:

```bash
npm install -g obsidian-headless
ob login --email <email> --password '<password>'
ob sync-create-remote --name "LLM Wiki"
cd ~/wiki && ob sync-setup --vault "<vault-id>"
ob sync
```

Run it under systemd (`~/.config/systemd/user/obsidian-wiki-sync.service`)
with `Restart=on-failure`. Enable linger so it survives logout:

```bash
systemctl --user daemon-reload
systemctl --user enable --now obsidian-wiki-sync
sudo loginctl enable-linger $USER
```

## Pitfalls

- **Never modify files in `raw/`.** Sources are immutable.
- **Always orient first** (schema + index + recent log).
- **Always update `index.md` and `log.md`.**
- **Don't create pages for passing mentions.**
- **Don't create pages without cross-references.** Every page needs at least
  2 outbound links.
- **Frontmatter is required.**
- **Tags must come from the taxonomy.** Add new tags to `SCHEMA.md` first.
- **Keep pages scannable.** Split over 200 lines.
- **Ask before mass-updating.** If an ingest touches 10+ pages, confirm
  scope first.
- **Rotate the log** at 500 entries.
- **Handle contradictions explicitly.** Never silently overwrite.

## Related

[llm-wiki-compiler](https://github.com/atomicmemory/llm-wiki-compiler) is a
Node CLI that compiles sources into a concept wiki with the same inspiration.
It owns page generation and is tuned for small corpora. Use this skill for
agent-in-the-loop curation; use llmwiki for batch compilation of a source
directory.
