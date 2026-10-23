---
name: skill-creator
description: Create new skills, modify and improve existing skills, and measure skill performance. Use when users want to create a skill from scratch, edit, or optimize an existing skill, run evals to test a skill, benchmark skill performance with variance analysis, or optimize a skill's description for better triggering accuracy.
---

# Skill Creator

A skill for creating new skills and iteratively improving them.

At a high level, the process of creating a skill goes like this:

- Decide what you want the skill to do and roughly how it should do it
- Write a draft of the skill
- Create a few test prompts and run OpenCode with access to the skill on them
- Help the user evaluate the results both qualitatively and quantitatively
  - While the runs happen in the background, draft some quantitative evals if there aren't any. Then explain them to the user
  - Use the `eval-viewer/generate_review.py` script to show the user the results, and also let them look at the quantitative metrics
- Rewrite the skill based on feedback from the user's evaluation of the results
- Repeat until you're satisfied
- Expand the test set and try again at larger scale

Your job when using this skill is to figure out where the user is in this process and then jump in and help them progress through these stages.

Be flexible about order. If the user just wants a draft and says "I don't need to run a bunch of evaluations, just vibe with me", do that.

## Communicating with the user

This skill gets used by people with very different levels of comfort with coding jargon. Pay attention to context cues:

- "evaluation" and "benchmark" are borderline, but fine
- for "JSON" and "assertion" use serious cues that the user knows those things before using them without explaining
- a short definition is fine when you are unsure

---

## OpenCode skill basics

### Where skills live

| Scope | Path |
|-------|------|
| Global | `~/.config/opencode/skills/<id>/SKILL.md` |
| Global (shared) | `~/.agents/skills/<id>/SKILL.md` |
| Project | `.opencode/skills/<id>/SKILL.md` |
| Project (shared) | `.agents/skills/<id>/SKILL.md` |

OpenCode also discovers skills from a legacy Claude-compatible directory at the user and project level. The paths above are the ones to install into.

More directories can be added with the `skills` key in `opencode.json`:

```jsonc
{
  "$schema": "https://opencode.ai/config.json",
  "skills": ["./team-skills", "~/shared/opencode-skills"],
}
```

### The ID is the directory name

OpenCode loads a skill by its **path-derived ID**, not by the frontmatter `name`.

| File | ID |
|------|-----|
| `skills/git-release.md` | `git-release` |
| `skills/git-release/SKILL.md` | `git-release` |
| `skills/teams/release/SKILL.md` | `release` |

IDs are case-sensitive. Keep them lowercase kebab-case and aligned with the directory name.

### Frontmatter

```markdown
---
name: Git Release
description: Prepare release notes, version bumps, and GitHub releases
metadata:
  opencode/autoinvoke: false
---
```

| Field | Effect |
|-------|--------|
| `name` | Display label. Defaults to the ID. |
| `description` | What the model sees when deciding whether to load the skill. |
| `metadata.opencode/autoinvoke: false` | Hide the skill from the model's advertised list. It stays loadable by ID. |
| `disable-model-invocation: true` | Same effect. `opencode/autoinvoke` wins when both are set. |
| `license`, `compatibility` | Accepted and ignored. |

### Progressive disclosure

1. **Metadata** (ID, name, description) is advertised to the model at every step. Keep it short.
2. **The SKILL.md body** is added to the conversation only when the model loads the skill with the `skill` tool, or when the user mentions `@skill-id`.
3. **Bundled files** are not loaded at all until the skill points at them. Supporting files live next to `SKILL.md`.

```text
.opencode/skills/git-release/
├── SKILL.md
├── references/release-policy.md
└── scripts/changelog.ts
```

Paths written inside a skill are relative to the directory holding `SKILL.md`.

### Gating a skill

Use the `skill` permission action with the skill ID as the resource:

```jsonc
{
  "permissions": [
    { "action": "skill", "resource": "*", "effect": "allow" },
    { "action": "skill", "resource": "deploy-*", "effect": "ask" },
    { "action": "skill", "resource": "internal-*", "effect": "deny" },
  ],
}
```

A `deny` hides the skill from the model and rejects loading it. Put a skill behind `opencode/autoinvoke: false` when the user should trigger it explicitly rather than have the model pick it up.

---

## Creating a skill

### Capture Intent

Start by understanding the user's intent. The conversation may already contain a workflow the user wants to capture. If so, extract answers from the conversation first — the tools used, the sequence of steps, corrections the user made, input/output formats observed. The user should confirm before you proceed.

1. What should this skill enable the agent to do?
2. When should it trigger? (which user phrases and contexts)
3. What is the expected output format?
4. Should we set up test cases? Skills with objectively verifiable outputs (file transforms, data extraction, fixed workflow steps) benefit from test cases. Skills with subjective output often do not. Suggest a default, let the user decide.

### Interview and Research

Ask about edge cases, input/output formats, example files, success criteria, and dependencies. Wait until this is settled before writing test prompts.

Research in parallel when useful — docs, similar existing skills, best practices — so the user has less to answer.

### Write the SKILL.md

Fill in these components:

- **name**: display label
- **description**: when to trigger and what it does. This is the primary triggering mechanism. Put both what the skill does and the specific contexts for when to use it. All "when to use" information goes here, not in the body.
- **the rest of the skill**

Write the description to be recognisable among the other advertised skills. It competes for attention with every other description in the list.

### Anatomy of a skill

```text
skill-id/
├── SKILL.md (required)
│   ├── YAML frontmatter (name, description)
│   └── Markdown instructions
└── Bundled resources (optional)
    ├── scripts/    - executable code for deterministic, repetitive work
    ├── references/ - docs loaded into context as needed
    └── assets/     - files used in output (templates, icons, fonts)
```

### Writing patterns

**Progressive disclosure, in practice**

- Keep SKILL.md under roughly 500 lines. When it grows past that, split detail into `references/` and point at it.
- Reference bundled files clearly from SKILL.md, with guidance on when to read them.
- For a skill that covers several variants, organise by variant:

```text
cloud-deploy/
├── SKILL.md          (workflow + selection)
└── references/
    ├── aws.md
    ├── gcp.md
    └── azure.md
```

The agent then reads only the relevant reference file.

**Principle of Lack of Surprise**

A skill must not contain malware, exploit code, or anything that could compromise system security. Its contents should not surprise the user relative to its description. Do not build misleading skills or skills that facilitate unauthorized access or data exfiltration. A "roleplay as an XYZ" skill is fine.

**Defining output formats**

```markdown
## Report structure
ALWAYS use this exact template:
# [Title]
## Executive summary
## Key findings
## Recommendations
```

**Examples pattern**

```markdown
## Commit message format
**Example 1:**
Input: Added user authentication with JWT tokens
Output: feat(auth): implement JWT-based authentication
```

**Writing style**

Prefer the imperative form. Explain why something matters instead of stacking hard rules. Write a draft, then reread it with fresh eyes and improve it.

### Test Cases

After writing the draft, come up with 2-3 realistic test prompts — the kind of thing a real user would actually say. Share them: "Here are a few test cases I'd like to try. Do these look right?" Then run them.

Save test cases to `evals/evals.json`. Prompts only at this stage; assertions come next.

```json
{
  "skill_name": "example-skill",
  "evals": [
    {
      "id": 1,
      "prompt": "User's task prompt",
      "expected_output": "Description of expected result",
      "files": []
    }
  ]
}
```

See `references/schemas.md` for the full schema including the `assertions` field.

---

## Running and evaluating test cases

This section is one continuous sequence — don't stop partway through.

Put results in `<skill-name>-workspace/` as a sibling of the skill directory. Within the workspace, organise by iteration (`iteration-1/`, `iteration-2/`) and within that, one directory per test case (`eval-0/`, `eval-1/`). Create directories as you go, not upfront.

### Step 1: Spawn all runs in the same turn

For each test case, spawn two runs in the same turn — one with the skill, one without. Launch everything at once so it all finishes around the same time. Do not come back for baselines later.

**With-skill run:**

```
Execute this task:
- Skill path: <path-to-skill>
- Task: <eval prompt>
- Input files: <eval files if any, or "none">
- Save outputs to: <workspace>/iteration-<N>/eval-<ID>/with_skill/outputs/
- Outputs to save: <what the user cares about>
```

**Baseline run** (same prompt, baseline depends on context):

- **Creating a new skill**: no skill at all. Save to `without_skill/outputs/`.
- **Improving an existing skill**: the old version. Before editing, snapshot the skill (`cp -r <skill-path> <workspace>/skill-snapshot/`) and point the baseline at the snapshot. Save to `old_skill/outputs/`.

Write an `eval_metadata.json` for each test case (assertions can be empty for now). Name each eval descriptively — use the name for the directory too. If the iteration uses new or modified prompts, create these files for each new eval directory; don't assume they carry over.

```json
{
  "eval_id": 0,
  "eval_name": "descriptive-name-here",
  "prompt": "The user's task prompt",
  "assertions": []
}
```

### Step 2: While runs are in progress, draft assertions

Don't wait idle. Draft quantitative assertions for each test case and explain them to the user. If assertions already exist in `evals/evals.json`, review and explain them.

Assertions should be objectively verifiable with descriptive names — someone glancing at the benchmark should understand what each one checks. Subjective skills (writing style, design quality) are better evaluated qualitatively; don't force assertions onto judgment calls.

Update the `eval_metadata.json` files and `evals/evals.json` with the assertions once drafted. Explain what the user will see in the viewer: both the qualitative outputs and the quantitative benchmark.

### Step 3: Capture timing data

When a run completes, save its token and duration totals to `timing.json` in the run directory:

```json
{
  "total_tokens": 84852,
  "duration_ms": 23332,
  "total_duration_seconds": 23.3
}
```

Capture this as each run finishes, not at the end.

### Step 4: Grade, aggregate, and launch the viewer

Once all runs are done:

1. **Grade each run** — read `agents/grader.md` and evaluate each assertion against the outputs. Save results to `grading.json` in each run directory. The expectations array must use the fields `text`, `passed`, and `evidence`; the viewer depends on those exact names. For assertions that can be checked programmatically, write and run a script rather than eyeballing it.

2. **Aggregate into a benchmark**:
   ```bash
   python -m scripts.aggregate_benchmark <workspace>/iteration-N --skill-name <name>
   ```
   This produces `benchmark.json` and `benchmark.md` with pass rate, time, and tokens per configuration, with mean ± stddev and the delta. See `references/schemas.md` for the exact schema the viewer expects. Put each with_skill version before its baseline counterpart.

3. **Analyst pass** — read the benchmark data and surface patterns the aggregate stats hide. See `agents/analyzer.md` for what to look for: assertions that always pass regardless of the skill (non-discriminating), high-variance evals (possibly flaky), time/token tradeoffs.

4. **Launch the viewer** with both qualitative outputs and quantitative data:
   ```bash
   nohup python <skill-creator-path>/eval-viewer/generate_review.py \
     <workspace>/iteration-N \
     --skill-name "my-skill" \
     --benchmark <workspace>/iteration-N/benchmark.json \
     > /dev/null 2>&1 &
   VIEWER_PID=$!
   ```
   For iteration 2+, also pass `--previous-workspace <workspace>/iteration-<N-1>`.

   **Headless environments:** if there is no browser or display, use `--static <output_path>` to write a standalone HTML file instead of starting a server. Feedback downloads as `feedback.json`; copy it into the workspace directory for the next iteration.

   Use `generate_review.py` to create the viewer; don't write custom HTML.

5. **Tell the user**: "I've opened the results in your browser. There are two tabs — 'Outputs' lets you click through each test case and leave feedback, 'Benchmark' shows the quantitative comparison. When you're done, come back here and let me know."

### What the user sees in the viewer

The "Outputs" tab shows one test case at a time: the prompt, the output files rendered inline where possible, previous output (iteration 2+), formal grades (collapsed), a feedback box that auto-saves, and previous feedback.

The "Benchmark" tab shows the stats summary: pass rates, timing, and token usage per configuration, with per-eval breakdowns and analyst observations.

Navigation is via prev/next buttons or arrow keys. When done, the user clicks "Submit All Reviews", which saves all feedback to `feedback.json`.

### Step 5: Read the feedback

When the user says they are done, read `feedback.json`:

```json
{
  "reviews": [
    {"run_id": "eval-0-with_skill", "feedback": "the chart is missing axis labels", "timestamp": "..."},
    {"run_id": "eval-1-with_skill", "feedback": "", "timestamp": "..."}
  ],
  "status": "complete"
}
```

Empty feedback means the user was happy. Focus improvements on the cases where the user left specific complaints.

Kill the viewer server when you are done with it:

```bash
kill $VIEWER_PID 2>/dev/null
```

---

## Improving the skill

This is the heart of the loop. You ran the test cases, the user reviewed the results, and now the skill needs to be better.

### How to think about improvements

1. **Generalize from the feedback.** The goal is a skill that works across a million prompts, not five. Rather than making fiddly overfit changes or piling on restrictive rules, try a different angle or a different working pattern when something keeps going wrong. It is cheap to try and sometimes it lands.

2. **Keep the prompt lean.** Remove anything that is not pulling its weight. Read the transcripts, not just the final outputs — if the skill is making the model waste time, cut the parts that cause it.

3. **Explain the why.** Explain why each step matters. Today's models are smart and do better with good reasoning than with rote instructions. If you find yourself writing ALWAYS or NEVER in all caps, that is a yellow flag — reframe so the model understands the point.

4. **Look for repeated work across test cases.** If every test case ended with the agent writing the same helper script, the skill should bundle that script in `scripts/` and tell the agent to use it. That saves every future invocation from reinventing it.

Write a draft revision, then look at it with fresh eyes and improve it again.

### The iteration loop

1. Apply your improvements to the skill
2. Rerun all test cases into `iteration-<N+1>/`, including baseline runs. For a new skill the baseline stays `without_skill`. For an improved skill, use the original or the previous iteration as the baseline, whichever makes more sense.
3. Launch the reviewer with `--previous-workspace` pointing at the previous iteration
4. Wait for the user's review
5. Read the new feedback, improve again, repeat

Keep going until the user says they are happy, the feedback is all empty, or you are no longer making progress.

---

## Advanced: Blind comparison

For a rigorous comparison of two versions of a skill, there is a blind comparison system: give two outputs to an independent agent without saying which is which and let it judge quality, then analyse why the winner won. Read `agents/comparator.md` and `agents/analyzer.md`.

This is optional, requires subagents, and most users do not need it. The human review loop is usually enough.

---

## Description Optimization

The description is the primary mechanism that decides whether the agent loads a skill. After creating or improving a skill, offer to optimize the description.

### Step 1: Generate trigger eval queries

Create 20 eval queries — a mix of should-trigger and should-not-trigger. Save as JSON:

```json
[
  {"query": "the user prompt", "should_trigger": true},
  {"query": "another prompt", "should_trigger": false}
]
```

The queries must be realistic: something an OpenCode user would actually type. Not abstract requests, but concrete ones with file paths, personal context, column names, company names, URLs. A little backstory. Some lowercase, some with typos. Mix lengths, and focus on edge cases rather than clear-cut cases.

Bad: `"Format this data"`. Good: `"ok so my boss just sent me this xlsx file (it's in my downloads, called something like 'Q4 sales final FINAL v2.xlsx') and she wants me to add a column that shows the profit margin as a percentage"`.

For should-trigger queries, think about coverage: different phrasings of the same intent, some formal and some casual, cases where the user never names the skill but clearly needs it.

For should-not-trigger queries, the valuable ones are near-misses that share keywords but need something else. "Write a fibonacci function" is a useless negative test for a PDF skill.

### Step 2: Review with the user

Present the eval set using the HTML template:

1. Read `assets/eval_review.html`
2. Replace `__EVAL_DATA_PLACEHOLDER__` with the JSON array (no quotes — it is a JS variable assignment), `__SKILL_NAME_PLACEHOLDER__` with the skill name, `__SKILL_DESCRIPTION_PLACEHOLDER__` with the current description
3. Write it to a temp file, e.g. `/tmp/eval_review_<skill-name>.html`, and open it
4. The user can edit queries, toggle should-trigger, then click "Export Eval Set"

Bad eval queries lead to a bad description. This step matters.

### Step 3: Run the optimization loop

Tell the user: "This will take some time — I'll run the optimization loop in the background and check on it periodically."

Save the eval set to the workspace, then run in the background:

```bash
python -m scripts.run_loop \
  --eval-set <path-to-trigger-eval.json> \
  --skill-path <path-to-skill> \
  --model <model-id-powering-this-session> \
  --max-iterations 5 \
  --verbose
```

Use the model ID from your system prompt so the triggering test matches what the user actually experiences.

While it runs, tail the output to give the user updates on which iteration it is on and what the scores look like.

The loop splits the eval set into 60% train and 40% held-out test, evaluates the current description (running each query several times for a reliable trigger rate), then asks a model to propose improvements based on what failed. It re-evaluates each new description on both train and test, iterating up to 5 times, then returns JSON with `best_description` — selected by test score rather than train score to avoid overfitting.

### How skill triggering works

At each model step OpenCode lists permitted skills that have a description and are not hidden with `opencode/autoinvoke: false`. The list carries only the ID, name, and description, not the Markdown body. The model decides whether to load a skill based on that description.

Two consequences for your eval queries:

- The agent only consults a skill for tasks it cannot easily handle alone. Simple one-step queries may not trigger a skill even when the description matches perfectly.
- Your eval queries should therefore be substantive enough that the agent would really benefit from the skill. "Read file X" is a poor test case.

### Step 4: Apply the result

Take `best_description` from the JSON output and update the SKILL.md frontmatter. Show the user before and after and report the scores.

---

## Distributing a skill

OpenCode has no `.skill` bundle format. Distribution is a directory.

- **Copy it into a skills directory**: `~/.config/opencode/skills/<id>/` for all projects, `.opencode/skills/<id>/` for one project, or `~/.agents/skills/<id>/` for the shared location.
- **Publish to the registry** and install with the `skills` CLI:
  ```bash
  npx skills add <owner>/<repo> -s <skill-id> -g -a opencode -y --copy
  ```
  `-g` installs globally, `-a opencode` targets OpenCode, `--copy` copies instead of linking. The registry is skills.sh.
- **Bundle for handoff**: `python -m scripts.package_skill <path/to/skill-folder>` writes a zip of the skill directory that the user can unzip into any skills directory.

When updating an existing skill:

- **Preserve the directory name and the frontmatter `name`.** The ID is path-derived, so renaming the directory changes the ID.
- **Copy to a writable location before editing** if the installed path is read-only.
- **Keep the description accurate.** It is what the model sees.

---

## Reference files

The `agents/` directory contains instructions for the specialised subagents you spawn. Read them when you need the corresponding subagent:

- `agents/grader.md` — evaluating assertions against outputs
- `agents/comparator.md` — blind A/B comparison between two outputs
- `agents/analyzer.md` — analysing why one version beat another

The `references/` directory has additional documentation:

- `references/schemas.md` — JSON structures for evals.json, grading.json, and the benchmark

---

Repeating the core loop for emphasis:

- Figure out what the skill is about
- Draft or edit the skill
- Run the agent with access to the skill on test prompts
- With the user, evaluate the outputs:
  - Create benchmark.json and run `eval-viewer/generate_review.py` so the human can review test cases
  - Run quantitative evals
- Repeat until you and the user are satisfied
- Package the final skill and return it to the user

Add these to your todo list if you have one, so nothing gets forgotten. The eval viewer step in particular: generate it before you evaluate the outputs yourself. Get them in front of the human as fast as possible.

Good luck!
