# agent

Agent tooling: the skills every agent on this machine shares.

```
skills/                  the skills subsystem
  default.nix            options and wiring
  activation.nix         the refresh activation
  refresh.mjs            the refresh driver
  package.nix            the buildable artifacts
  sources.nix            the upstream map (generated)
  state-seed.json        upstream HEADs and installed hashes (generated)
  skill-lock.json        a copy of the skills CLI lockfile (generated)
  generate.py            the generator
  overrides/agents/      the local copies for ~/.agents/skills
  overrides/opencode/    the local copies for ~/.config/opencode/skills
```

## What a rebuild does

`my.skills.excluded` is the only list of skills the refresh must not touch.
Everything else with an upstream is refreshed from that upstream, and every
locally authored or locally adapted skill is restored verbatim afterwards.

The refresh runs in the Home Manager activation, in this order:

1. restore the local copies from the store into `~/.agents/skills` and
   `~/.config/opencode/skills`
2. refresh the upstream skills from the git archive of the probed commit
3. restore the local copies again, so the refresh cannot clobber them

The local copies are restored by the activation rather than linked with
`home.file`: Home Manager moves a real directory aside before it links it,
and a leftover `skill.hm-backup` inside `~/.agents/skills` would be read as a
second skill.

Only the two directories OpenCode reads are touched.

## Where every skill comes from

The upstream map names one repo and one path per skill. The generator picks
them from three kinds of evidence, strongest first:

1. a copy in a candidate repo that is byte identical to the installed one
2. an install record: the `skills` CLI lockfile for the canonical tree, the
   OpenChamber manifest and the lockfile for the curated tree
3. a repo that holds a skill with that name, used only for the curated tree,
   which has no lockfile of its own

Ties are broken by a fixed order, never by the order the repos happen to be
read in: `obra/superpowers`, `mattpocock/skills`, `anthropics/skills` and
`anthropics/claude-code` win over every other repo, then the install
records, then the remaining repos alphabetically. A skill that no repo holds
and that no install record names is local only: it stays a pinned copy in
`overrides/` and never updates.

The map has 253 entries:

| Group | Count | Upstream |
|---|---|---|
| canonical tree, tracked | 155 | the repo the `skills` CLI lockfile names, one per skill |
| canonical tree, pinned | 29 | the repo the lockfile or the alias names, but the local copy differs from it |
| curated tree, tracked | 29 | the repo the content or the install records name |
| curated tree, pinned | 17 | the repo the content or the install records name, but the local copy differs |
| curated tree, local only | 2 | none: `first-mobile-app`, `first-mobile-app-workspace` |
| owned by `media/hyperframes` | 21 | `heygen-com/hyperframes`, pinned by that module |

Five of the 155 tracked entries of the canonical tree have no directory on
this machine: `best-practices`, `heygen-avatar`, `heygen-translate`,
`heygen-video` and `web-quality-audit`. They stay in the map so the
exclusion list has something to act on, and the refresh cannot bring them
back.

Three skills of the canonical tree are OpenCode rewrites of the Claude Code
plugin skills in `anthropics/claude-code`
(`plugins/plugin-dev/skills/plugin-settings`,
`plugins/plugin-dev/skills/plugin-structure` and
`plugins/hookify/skills/writing-rules`). They are not byte identical to it,
so the map names the upstream and keeps the local copy pinned.

`first-mobile-app` is a hand written guide. `first-mobile-app-workspace` is
the evaluation workspace of the skill creator run, not a skill: it has no
`SKILL.md`, so OpenCode never loads it.

The 48 skills in `overrides/` are the locally adapted copies: the upstream
still has them under a different content, and the local copy is kept
verbatim.

## Where the upstream content comes from

Every repo is fetched from git, never through a registry:

1. `git ls-remote` gives the HEAD of the repo, or the pinned commit when the
   map names one
2. the archive of that commit is downloaded and unpacked
3. the skill directory inside the archive is hashed
4. the same directory is copied out of the same archive into the tree

The hash that is compared and the bytes that are installed are therefore the
same ones. That proves the archive was unpacked intact, not that the archive
is the content you reviewed: the refresh follows the upstream HEAD and keeps
no independent per-skill content hash. A compromised upstream would be
installed on the next rebuild. Only the copies in `overrides/` are immune.
The path in the map is the in-repo path of the skill directory, so a skill
whose upstream path is not its own name lands under its name anyway:
`mcollina/skills` at `skills/fastify`, `tencent/browserskill` at
`crates/bsk-cli/skill`, `leonxlnx/taste-skill` at `skills/taste-skill`.

A repo whose HEAD did not move is not fetched at all: the recorded head and
the hashes of the installed trees are compared with the live ones, and the
fetch is skipped when they still agree. The fetch itself is one download per
repo, so a rebuild with nothing to do is a `git ls-remote` per repo.

## The ArtCraft skills

The 13 ArtCraft skills — `cadcraft`, `deckcraft`, `designcraft`, `effectcraft`,
`figcraft`, `filmcraft`, `gridcraft`, `lightcraft`, `pdfcraft`, `photocraft`,
`soundcraft`, `vectorcraft` and `wordcraft` — are tracked against
`github.com/midasmatterhorn/artcraft-skills` and refresh from it. They are
not pinned: the repo is the upstream, and a rebuild picks up its new commits.

Their frontmatter upstream is not valid YAML (an unquoted `description` with
a `: ` in it). The `skills` CLI parses the frontmatter of every skill it
finds and skips the three it cannot read:

```
⚠ Skipped .../designcraft/SKILL.md — YAML parse error: Nested mappings are not allowed in compact mappings
```

The refresh does not parse the frontmatter, so all 13 land. The upstream bug
is not fixed here: the frontmatter in
`midasmatterhorn/artcraft-skills` is still invalid, and OpenCode reads it
because its own loader is tolerant.

## The superpowers plugin

`obra/superpowers` ships 15 skills inside the OpenCode plugin, not as skill
directories. The plugin is pinned by the `superpowers-src` flake input, and
the one skill that also exists as a directory,
`~/.agents/skills/test-driven-development`, is fetched from git at the same
commit, so the two copies cannot drift apart.

`nix flake update superpowers-src` moves the pin to the upstream default
branch. The generator has to run afterwards, because the map carries the
commit.

## Ownership

`media/hyperframes` owns the 21 skills of `heygen-com/hyperframes`. They are
pinned by the `hyperframes-src` flake input and layered with that module's own
`overrides/` tree, so this module leaves them alone. The upstream map records
the owner of every skill; only the entries owned by `agent-skills` are
refreshed here.

The two activations are ordered: `media/hyperframes` writes its skills first,
the agent-skills refresh runs after it.

## Refreshing

The upstream map is generated from the `skills` CLI lockfile, the OpenChamber
install manifest and the two skill trees OpenCode reads. Re-run the generator
after adding or editing skills:

```sh
modules/packages/agent/skills/generate.sh
```

The wrapper builds `media/hyperframes` first and passes its skills to the
generator. Without that the 21 skills that module owns lose their owner and
this module would fight it for them.

The generator clones every upstream without blobs and compares git tree
hashes, so it needs no registry and no API quota. Its output is committed.
The HEAD of a repo in `state-seed.json` comes from the committed seed rather
than from the clone, so an upstream that moved does not change the file and a
second run reproduces it byte for byte.

The clones are shallow, so the generator cannot prove from history that a
pinned copy is merely one commit behind its upstream. A differing local copy
is therefore pinned in `overrides/` and restored verbatim; it is not fetched.
To update one, compare it with upstream by hand, then re-run the generator.
The one known lagging case is listed in `LAGGING_UPSTREAM` and is treated as
tracked.

To try the refresh without touching the live trees:

```sh
modules/packages/agent/skills/dryrun.sh
```

It copies both trees into `/tmp/opencode/dryrun.work` and runs the driver
there. `SKILLS_DRY_RUN=1` reports what would change and writes nothing into
the live trees; the temporary archive is still downloaded and removed. The
copy is made again when the workdir is from another day; `--fresh` forces it.

## What a rebuild does with the network

The refresh writes its state after every repo, so a run that is cut short
keeps the work it did. `home-manager-ackerman.service` gets a 45 minute
timeout for the same reason: a run that moves a hundred skills downloads the
archive of every upstream it updates, and that takes longer than the five
minutes Home Manager allows by default.

The refresh has a wall clock budget of its own: `my.skills.deadline`, 1200
seconds by default. When it is spent the refresh stops, the repos it did not
reach stay uncached, and the activation still succeeds.

A repo that cannot be reached is not a failure either: it is skipped, it
keeps its cached head, and the next rebuild tries again. Only an install that
does not land the upstream content fails the activation.
