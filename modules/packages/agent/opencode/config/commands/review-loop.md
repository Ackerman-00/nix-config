---
description: Run a free-model review loop. One writer implements, a panel of independent reviewers critiques, the writer fixes, and any provider error fails over to another free model.
---

Run the free-model review loop on the task below.

TASK:
$ARGUMENTS

Run it with the `shell` tool, from the project directory:

```sh
~/.local/bin/oc-review-loop --task "$ARGUMENTS"
```

If the task text contains a double quote, a dollar sign or a newline, the shell will mangle
the quoted argument above. Pass the task on stdin with a quoted heredoc instead. The
terminator must start at the first column, with no indentation:

```sh
~/.local/bin/oc-review-loop --stdin <<'REVIEW_TASK'
$ARGUMENTS
REVIEW_TASK
```

Wait for the command to finish. It runs one writer model plus a panel of independent
reviewer models, and it fails over to another free model whenever a provider errors or
rate-limits.

Then report, in this order:

1. Which models actually ran, and which failed over to which.
2. The consolidated reviewer findings, by severity, with the consensus count.
3. What the writer changed in response to the findings.
4. Where the transcripts and artifacts were written.

Do not implement the task yourself. Do not re-run the loop.
