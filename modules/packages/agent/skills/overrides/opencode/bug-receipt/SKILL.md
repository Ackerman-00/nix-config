---
name: bug-receipt
description: 'Close defects and incidents with a BUG RECEIPT and VERIFIED, PARTIAL, or BLOCKED status after diagnosis, repair, or recovery.'
metadata:
  version: "1.4.1"
---

# Bug Receipt

## Closeout output

Use the receipt block below when the user asks for a receipt, when you are closing a production incident, or when the fix is not fully provable and the evidence boundary is the point. Otherwise report the same six fields inline and in prose: what was broken, what you ran, the root cause, what you changed, what proves it, and what is still unproven.

Never drop a field because the reply is short. Concision shortens the values, it never removes a row, and it never lets a hypothesis be written as a proven cause.

```text
BUG RECEIPT · VERIFIED | PARTIAL | BLOCKED

Problem    <observed defect and intended behavior>
Baseline   <failing interaction or command and decisive result; or not run>
Root cause <proven mechanism; or unproven hypothesis>
Change     <responsible change; or none>
Proof      <supplied or executed check: result; include every decisive layer>
Gaps       <none; or exact missing proof and single next experiment/package>
Source     executed now | supplied | mixed
```

Use `not run`, `unproven`, or `none` explicitly. Never omit a row to make the receipt look complete.

## Establish the evidence boundary

Before editing, record the observed problem, intended behavior, strongest direct check, and evidence source: `executed now`, `supplied`, or `mixed`. Never imply that supplied evidence was executed in the current run.

Keep evidence privacy-minimal. Redact credentials, tokens, cookies, personal data, private URLs, and sensitive payloads; preserve only the identifiers and excerpts needed to reproduce or correlate the failure.

Reproduce the failure with the narrowest safe check when possible. If reproduction is unavailable, preserve the evidence obtained and cap the result at `PARTIAL` or `BLOCKED`.

## Trace and repair

1. Follow the live owner path from input to symptom.
2. Separate observed facts, bounded inferences, and gaps.
3. Require a concrete location or runtime transition before naming root cause.
4. Make the smallest responsible change; avoid unrelated cleanup, retries, silent fallbacks, and fixture-specific exceptions.

Do not convert a plausible patch, stale log, source read, or passing build into proof of the user-visible behavior.

## Close the proof loop

Run only checks required by the affected contract:

- original reproduction or direct acceptance check;
- nearest negative or regression check;
- affected build or integration gate;
- real UI, API, persistence, concurrency, or runtime path when the claim crosses that boundary.

Use these decisive boundaries:

| Surface | Required direct proof |
| --- | --- |
| Logic or failing test | Original failing input or focused test now passes |
| UI behavior | Real interaction plus relevant console and network observation |
| API or integration | Request, response, and responsible service behavior |
| Persistence | Write/read or reload round trip through the real owner path |
| Race or lifecycle | Repeated concurrent trigger; zero-or-one success; affected-row and transaction evidence; final invariant |
| Cross-system blocker | One sanitized failing request/response with timestamp or request ID, edge and application logs, and identity-provider logs when the trace reaches that owner |

## Assign status

- `VERIFIED`: observed baseline, concrete cause, responsible change, all declared checks passed, no material gap.
- `PARTIAL`: useful evidence exists, but a required proof layer is missing or inconclusive.
- `BLOCKED`: a specific external condition prevents reproduction, repair, or proof.

For `PARTIAL` or `BLOCKED`, name the single minimal experiment or correlated evidence package that closes the decisive gap. Never invent a command, observation, count, location, or result.

For a machine-readable receipt or CI integration, read [references/receipt-contract.md](references/receipt-contract.md) and conform to its JSON fields, evidence-source marker, compatibility rule, and status invariants.

When a JSON artifact is requested, start from [assets/receipt.template.json](assets/receipt.template.json), write it to a task-owned path, and validate it with `python3 scripts/validate_receipt.py <receipt.json>` from this skill directory. The upstream `scripts/validate-receipt.mjs` is the same contract for hosts that have a Node runtime. Do not commit the generated receipt unless the user requests it.

## Source and license

Originally published at https://github.com/lMysticl/bug-receipt under the MIT License.
