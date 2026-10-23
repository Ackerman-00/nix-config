#!/usr/bin/env python3
"""Validate a bug receipt against the receipt contract.

Python port of the upstream validate-receipt.mjs, for hosts without a Node runtime.
Standard library only.

    python3 validate_receipt.py <receipt.json> [--json]
    python3 validate_receipt.py - [--json]      # read from stdin
"""

import json
import sys

STATUSES = {"verified", "partial", "blocked"}
EVIDENCE_SOURCES = {"executed-now", "supplied", "mixed"}
BASELINE_RESULTS = {"failed", "observed", "not-run"}
VERIFICATION_RESULTS = {"passed", "failed", "not-run"}

TOP_FIELDS = {
    "version",
    "status",
    "evidenceSource",
    "problem",
    "baseline",
    "rootCause",
    "changes",
    "verification",
    "gaps",
}


def is_object(value):
    return isinstance(value, dict)


def non_empty(value):
    return isinstance(value, str) and bool(value.strip())


def validate_receipt(receipt):
    issues = []

    def add(path, message):
        issues.append({"path": path, "message": message})

    def reject_unknown(value, allowed, path):
        if not is_object(value):
            return
        for key in value:
            if key not in allowed:
                add(f"{path}.{key}" if path else key, "Unknown field.")

    if not is_object(receipt):
        return {
            "valid": False,
            "issues": [{"path": "$", "message": "Receipt must be a JSON object."}],
        }

    reject_unknown(receipt, TOP_FIELDS, "")

    if receipt.get("version") not in (1, 2):
        add("version", "Must equal 1 or 2.")
    if receipt.get("status") not in STATUSES:
        add("status", "Must be verified, partial, or blocked.")
    if receipt.get("evidenceSource") is not None and receipt.get("evidenceSource") not in EVIDENCE_SOURCES:
        add("evidenceSource", "Must be executed-now, supplied, or mixed.")
    if receipt.get("version") == 2 and receipt.get("evidenceSource") not in EVIDENCE_SOURCES:
        add("evidenceSource", "Version 2 requires an evidence source.")
    if not non_empty(receipt.get("problem")):
        add("problem", "Must be a non-empty string.")

    baseline = receipt.get("baseline")
    if not is_object(baseline):
        add("baseline", "Must be an object.")
    else:
        reject_unknown(baseline, {"command", "result", "evidence"}, "baseline")
        if not non_empty(baseline.get("command")):
            add("baseline.command", "Must be a non-empty string.")
        if baseline.get("result") not in BASELINE_RESULTS:
            add("baseline.result", "Must be failed, observed, or not-run.")
        if not non_empty(baseline.get("evidence")):
            add("baseline.evidence", "Must be a non-empty string.")

    root_cause = receipt.get("rootCause")
    if not is_object(root_cause):
        add("rootCause", "Must be an object.")
    else:
        reject_unknown(root_cause, {"summary", "evidence"}, "rootCause")
        if not non_empty(root_cause.get("summary")):
            add("rootCause.summary", "Must be a non-empty string.")
        evidence = root_cause.get("evidence")
        if not isinstance(evidence, list):
            add("rootCause.evidence", "Must be an array.")
        else:
            for index, entry in enumerate(evidence):
                if not is_object(entry):
                    add(f"rootCause.evidence[{index}]", "Must be an object.")
                    continue
                reject_unknown(entry, {"location", "observation"}, f"rootCause.evidence[{index}]")
                if not non_empty(entry.get("location")):
                    add(f"rootCause.evidence[{index}].location", "Must be a non-empty string.")
                if not non_empty(entry.get("observation")):
                    add(f"rootCause.evidence[{index}].observation", "Must be a non-empty string.")

    changes = receipt.get("changes")
    if not isinstance(changes, list):
        add("changes", "Must be an array.")
    else:
        for index, entry in enumerate(changes):
            if not is_object(entry):
                add(f"changes[{index}]", "Must be an object.")
                continue
            reject_unknown(entry, {"file", "summary"}, f"changes[{index}]")
            if not non_empty(entry.get("file")):
                add(f"changes[{index}].file", "Must be a non-empty string.")
            if not non_empty(entry.get("summary")):
                add(f"changes[{index}].summary", "Must be a non-empty string.")

    verification = receipt.get("verification")
    if not isinstance(verification, list):
        add("verification", "Must be an array.")
    else:
        for index, entry in enumerate(verification):
            if not is_object(entry):
                add(f"verification[{index}]", "Must be an object.")
                continue
            reject_unknown(entry, {"command", "result", "evidence"}, f"verification[{index}]")
            if not non_empty(entry.get("command")):
                add(f"verification[{index}].command", "Must be a non-empty string.")
            if entry.get("result") not in VERIFICATION_RESULTS:
                add(f"verification[{index}].result", "Must be passed, failed, or not-run.")
            if not non_empty(entry.get("evidence")):
                add(f"verification[{index}].evidence", "Must be a non-empty string.")

    gaps = receipt.get("gaps")
    if not isinstance(gaps, list) or any(not non_empty(gap) for gap in gaps):
        add("gaps", "Must be an array of non-empty strings.")

    if receipt.get("status") == "verified":
        if is_object(baseline) and baseline.get("result") == "not-run":
            add("baseline.result", "Verified requires an observed baseline.")
        root_evidence = root_cause.get("evidence") if is_object(root_cause) else None
        if not isinstance(root_evidence, list) or not root_evidence:
            add("rootCause.evidence", "Verified requires concrete root-cause evidence.")
        if not isinstance(changes, list) or not changes:
            add("changes", "Verified requires at least one changed file or artifact.")
        if not isinstance(verification, list) or not verification:
            add("verification", "Verified requires at least one verification check.")
        elif any(not is_object(entry) or entry.get("result") != "passed" for entry in verification):
            add("verification", "Every verification check must pass for verified status.")
        if isinstance(gaps, list) and gaps:
            add("gaps", "Verified status cannot contain proof gaps.")

    if receipt.get("status") == "partial" and isinstance(gaps, list) and not gaps:
        add("gaps", "Partial status must name at least one missing proof layer.")
    if receipt.get("status") == "blocked" and isinstance(gaps, list) and not gaps:
        add("gaps", "Blocked status must name the external blocking condition.")

    return {"valid": not issues, "issues": issues}


def main(argv):
    args = [a for a in argv if a != "--json"]
    as_json = "--json" in argv
    if not args:
        sys.stderr.write("Usage: python3 validate_receipt.py <receipt.json> [--json]\n")
        return 2

    path = args[0]
    try:
        if path == "-":
            raw = sys.stdin.read()
        else:
            with open(path, encoding="utf-8") as handle:
                raw = handle.read()
        receipt = json.loads(raw)
    except (OSError, json.JSONDecodeError) as error:
        sys.stderr.write(f"bug-receipt: {error}\n")
        return 2

    result = validate_receipt(receipt)

    if as_json:
        sys.stdout.write(json.dumps(result) + "\n")
    elif result["valid"]:
        sys.stdout.write(f"OK {path} is a valid {str(receipt.get('status', '')).upper()} bug receipt.\n")
    else:
        sys.stderr.write(f"FAIL {path} is not a valid bug receipt:\n")
        for issue in result["issues"]:
            sys.stderr.write(f"  {issue['path']}: {issue['message']}\n")
    return 0 if result["valid"] else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
