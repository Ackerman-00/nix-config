#!/usr/bin/env bash
# check-workflows.sh - validate .github/workflows/*.yml before pushing them.
#
# A workflow file that GitHub rejects kills every run of it: the push creates
# a failed run with no jobs and the schedule dies silently. That happened on
# 2026-09-09 (commit ad69ca3 added the invalid scope `workflows: write`) and
# again on 2026-10-20 (the scopes `code-quality` and `vulnerability-alerts` are
# NOT valid in a permissions block, even though the docs table lists them).
# actionlint is the authority on the accepted scope list, not the docs prose.
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 2
FAIL=0

echo "== YAML parse =="
python3 - <<'PY' || FAIL=1
import glob, sys, yaml
for f in sorted(glob.glob(".github/workflows/*.yml")):
    try:
        yaml.safe_load(open(f))
        print(f"OK   {f}")
    except Exception as e:
        print(f"FAIL {f}: {e}")
        sys.exit(1)
PY

echo "== actionlint =="
# -shellcheck= disables shellcheck integration: its style infos are not
# workflow validity and would otherwise fail a valid file.
if command -v actionlint >/dev/null 2>&1; then
  actionlint -shellcheck= -no-color .github/workflows/*.yml && echo "OK   actionlint clean" || FAIL=1
else
  if [ -x /tmp/opencode/actionlint ]; then
    /tmp/opencode/actionlint -shellcheck= -no-color .github/workflows/*.yml && echo "OK   actionlint clean" || FAIL=1
  else
    echo "SKIP actionlint not installed - install it with:"
    echo "  bash <(curl -sL https://raw.githubusercontent.com/rhysd/actionlint/main/scripts/download-actionlint.bash)"
  fi
fi

echo "== permission scopes =="
if python3 tools/workflow-valid.py .github/workflows/*.yml; then
  :
else
  FAIL=1
fi

if [ "$FAIL" -ne 0 ]; then
  echo "WORKFLOW VALIDATION FAILED - do not push"
  exit 1
fi
echo "WORKFLOW VALIDATION PASSED"
