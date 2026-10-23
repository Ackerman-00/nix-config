---
name: grounded-citations
description: "Ground answers, documents, and reports in cited, verifiable sources: maintain a source ledger with a stdlib Python script, cite inline with stable [n] markers, attach verbatim evidence quotes, and verify every citation before delivering. Sources come from web search, HTTP fetches, and the NeuraKeep vault."
---

# Grounded citations

Every claim taken from an outside source gets an inline numbered citation and
a `Sources:` list. A ledger script owns the `url -> [n]` mapping so the
numbers and URLs come from retrieval, never from memory; the model only ever
emits small integers it was handed.

For high-stakes work the ledger doubles as a fact-checking chain: verbatim
quotes are attached to each source and rejected unless they literally appear
in the fetched page text, claims from model knowledge are flagged
`[unverified]`, and the evidence gate fails any draft whose cited sources
carry no evidence.

## When to use

- Research, comparisons, "what is the current state of X".
- Any deliverable written to disk that reports outside facts: reports, briefs,
  docs, decks, wiki pages.
- Fact-finding where the user will want to check your work.
- Multi-source synthesis where conflicting sources must be attributed.

Skip inline citations when retrieval is incidental (a quick syntax lookup
mid-coding, casual conversation, creative writing). Mention a URL only if
the user would plausibly want the link.

## Where sources come from in OpenCode

| Source type | How to fetch it |
|---|---|
| Web search | the `websearch` tool, or `ctx.websearch.query({ query, providerID })` from a plugin |
| Web page | the `webfetch` tool, or `curl` / `fetch` |
| This machine's prior sessions | NeuraKeep vault via the `neurakeep-global` MCP server |

For vault-backed claims, `memory_explain_sources` returns the file path,
line, hash, and timestamp for each citation. Use that output as the
provenance record instead of a URL:

```json
{ "source_ids": ["<id-from-memory_search>"] }
```

Cite the vault source id in the ledger, and let `memory_explain_sources`
supply the path:line evidence. Say plainly when a claim comes from a local
transcript rather than a published page.

## Prerequisites

None beyond the standard toolset. `scripts/sources.py` is stdlib-only
Python 3.

Ledger location: `~/.cache/opencode/citations/ledger.json` by default.
Override per task with `--ledger <path>` or `OPENCODE_CITATION_LEDGER`.

## How to run

```bash
S=~/.agents/skills/grounded-citations/scripts/sources.py

python3 "$S" reset                                  # start a clean ledger
python3 "$S" add https://example.com/a --title "A"  # prints: [1]
python3 "$S" add https://example.com/b --title "B"  # prints: [2]
python3 "$S" list                                   # ledger table
python3 "$S" render                                 # Sources: block
python3 "$S" verify draft.md                        # catch bad citations
```

`add` is idempotent and URL-normalized: the same page always returns the same
id within a ledger, so ids stay stable across many search/fetch rounds.

## Quick reference

| Action | Command |
|---|---|
| Fresh ledger | `sources.py reset` |
| Register a source | `sources.py add <url> [--title T]` |
| Register several | `sources.py add <url1> <url2> ...` |
| Register from JSON tool output | `sources.py ingest results.json` |
| Attach verbatim evidence | `sources.py quote <id> --text "exact wording" --from page.txt` |
| Show ledger | `sources.py list [--json]` |
| Render the Sources block | `sources.py render [--style markdown\|plain\|footnotes\|bibtex\|evidence] [--only 1,3]` |
| Render only what a draft cites | `sources.py render --cited-in draft.md` |
| Rewrite a draft's Sources block | `sources.py render --replace-in draft.md` |
| Check a draft | `sources.py verify draft.md [--strict] [--min-coverage 0.6] [--evidence]` |

## Procedure

1. **Reset the ledger** at the start of a task that produces a grounded answer
   or document. Skip the reset when continuing work whose ids are already in
   a draft; reusing the ledger keeps numbering stable.

2. **Register every source at retrieval time.** After each search, fetch, or
   vault read, pass the URLs to `sources.py add` before writing prose.
   Registering later, from memory, is the failure mode this skill prevents.

3. **Write cite-while-drafting.** Place the bracketed id(s) right after each
   sentence the source supports:

   ```
   Ice floats because it is less dense than liquid water.[1][2]
   ```

   - No space before the bracket; each id in its own brackets.
   - Max 3 ids per sentence. Cite per sentence, not one dump at the end.
   - Only ids the ledger returned. Never invent an id or a URL.
   - Claims from your own knowledge get no citation.
   - Conflicting sources: present both readings, each with its own id.
   - Quote exact figures, dates, and names as the source states them; flag
     gaps explicitly ("no source found for X") instead of smoothing them.

4. **Append the Sources block** with `sources.py render --cited-in <draft>` so
   the id -> URL mapping is generated mechanically. For other targets see
   `references/citation-formats.md`.

5. **Verify before delivering.** `sources.py verify <draft>` exits non-zero on
   unknown ids, on a Sources block that disagrees with the ledger, or (with
   `--min-coverage`) on prose that is too thinly cited. Fix and re-run.

6. **Chat answers** follow the same steps with the draft in your reply:
   register sources, cite inline, end with the rendered `Sources:` list.

## Fact-checking mode

For work where the reader must check the chain (medical, legal, financial,
safety, disputed claims), upgrade from citations to evidence:

1. **Attach a verbatim quote per source.** Save the fetched page text to a
   file, then:

   ```bash
   python3 "$S" quote 1 --text "Ice is about 9% less dense than liquid water." --from page1.txt
   ```

   The quote is rejected unless it appears verbatim in the evidence text
   (insensitive to whitespace, case, and markdown markup). Copy from the
   fetched text; never retype.

2. **Flag model-knowledge claims with `[unverified]`.**

   ```
   The refactor likely predates the 2.0 release.[unverified]
   ```

   `verify --min-coverage` counts `[unverified]` sentences as covered: the
   goal is declared provenance for every claim, not a citation on every
   sentence.

3. **Cross-check disputed facts against a second independent source.** Cite
   both readings with their own ids and quotes, and say which you weight.

4. **Verify with the evidence gate and render the evidence block:**

   ```bash
   python3 "$S" verify report.md --evidence --min-coverage 0.5
   python3 "$S" render --style evidence --replace-in report.md
   ```

   `--evidence` fails the draft if any cited source has no attached quote.

**What `--min-coverage` counts.** Coverage is `sentences with declared
provenance / prose sentences`. A prose sentence is a non-empty line fragment
of 4+ words after the Sources block; headings, table rows, and fenced code
are dropped. Provenance is declared by either a `[n]` citation or an
`[unverified]` marker.

## Pitfalls

- **Registering after writing.** The ledger must come from tool output.
- **Renumbering mid-task.** Never hand-edit ids in a draft.
- **Retyping URLs into the Sources block.** Always `render`.
- **Citing a search snippet as if you read the page.** A snippet supports
  only what it literally says.
- **Over-citing.** Three ids on a sentence is the ceiling.
- **Citing the ledger in code or config artifacts.** Source comments belong
  in prose deliverables.
- **Parallel subagents.** Each subagent has its own working directory; point
  them all at one ledger with `--ledger` (or `OPENCODE_CITATION_LEDGER`).
- **Using `[unverified]` as an escape hatch.** If most sentences carry it, the
  task needed more retrieval, not more markers.
- **Quoting from a snippet instead of the page.** Fetch the page first.

## Verification

```bash
python3 "$S" verify report.md --strict --min-coverage 0.5
```

Green means: every `[n]` exists in the ledger, the Sources block lists
exactly the cited ids with the ledger's URLs, and the cited share of
source-bearing sentences meets the threshold. Read the warnings even when
the exit code is 0.
