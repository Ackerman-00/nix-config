#!/usr/bin/env python3
"""Run trigger evaluation for a skill description.

Tests whether a skill's description causes OpenCode to load the skill for a
set of queries. Outputs results as JSON.

Mechanism:
  - The skill under test is staged as a real skill directory under
    <project>/.opencode/skills/<unique-id>/SKILL.md, with a unique marker
    line in its body.
  - `opencode run --format json "<query>"` is executed in that project.
  - A run counts as triggered when the marker appears in the output, which
    means the skill body was loaded into the conversation.
"""

import argparse
import json
import os
import subprocess
import sys
import time
import uuid
from concurrent.futures import ProcessPoolExecutor, as_completed
from pathlib import Path

from scripts.utils import parse_skill_md


def find_project_root() -> Path:
    """Find the project root by walking up from cwd looking for .opencode/.

    Mimics how OpenCode discovers a project, so the staged skill ends up
    where `opencode run` will look for it.
    """
    current = Path.cwd()
    for parent in [current, *current.parents]:
        if (parent / ".opencode").is_dir():
            return parent
    return current


def stage_skill(project_root: str, skill_name: str, description: str) -> tuple[Path, str]:
    """Write the skill under test into the project's .opencode/skills tree."""
    unique_id = f"{skill_name}-eval-{uuid.uuid4().hex[:8]}"
    marker = f"SKILL_LOADED_MARKER_{unique_id.upper()}"
    skill_dir = Path(project_root) / ".opencode" / "skills" / unique_id
    skill_dir.mkdir(parents=True, exist_ok=True)

    indented = "\n  ".join(description.split("\n"))
    content = (
        "---\n"
        f"name: {skill_name}\n"
        "description: |\n"
        f"  {indented}\n"
        "---\n"
        "\n"
        f"{marker}\n"
        "\n"
        "This skill was staged for a trigger evaluation.\n"
    )
    (skill_dir / "SKILL.md").write_text(content)
    return skill_dir, marker


def run_single_query(
    query: str,
    skill_name: str,
    skill_description: str,
    timeout: int,
    project_root: str,
    model: str | None = None,
) -> bool:
    """Run a single query and return whether the skill was loaded."""
    skill_dir, marker = stage_skill(project_root, skill_name, skill_description)

    cmd = ["opencode", "run", "--format", "json", query]
    if model:
        cmd.extend(["--model", model])

    try:
        process = subprocess.Popen(
            cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
            cwd=project_root,
        )
        try:
            stdout, _ = process.communicate(timeout=timeout)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait()
            return False

        output = stdout.decode("utf-8", errors="replace")
        return marker in output
    except FileNotFoundError:
        print("Error: opencode CLI not found on PATH", file=sys.stderr)
        return False
    finally:
        try:
            (skill_dir / "SKILL.md").unlink()
            skill_dir.rmdir()
        except OSError:
            pass


def run_eval(
    eval_set: list[dict],
    skill_name: str,
    description: str,
    num_workers: int,
    timeout: int,
    project_root: Path,
    runs_per_query: int = 1,
    trigger_threshold: float = 0.5,
    model: str | None = None,
) -> dict:
    """Run the full eval set and return results."""
    results = []

    with ProcessPoolExecutor(max_workers=num_workers) as executor:
        future_to_info = {}
        for item in eval_set:
            for run_idx in range(runs_per_query):
                future = executor.submit(
                    run_single_query,
                    item["query"],
                    skill_name,
                    description,
                    timeout,
                    str(project_root),
                    model,
                )
                future_to_info[future] = (item, run_idx)

        query_triggers: dict[str, list[bool]] = {}
        query_items: dict[str, dict] = {}
        for future in as_completed(future_to_info):
            item, _ = future_to_info[future]
            query = item["query"]
            query_items[query] = item
            if query not in query_triggers:
                query_triggers[query] = []
            try:
                query_triggers[query].append(future.result())
            except Exception as e:
                print(f"Warning: query failed: {e}", file=sys.stderr)
                query_triggers[query].append(False)

    for query, triggers in query_triggers.items():
        item = query_items[query]
        trigger_rate = sum(triggers) / len(triggers)
        should_trigger = item["should_trigger"]
        if should_trigger:
            did_pass = trigger_rate >= trigger_threshold
        else:
            did_pass = trigger_rate < trigger_threshold
        results.append({
            "query": query,
            "should_trigger": should_trigger,
            "trigger_rate": trigger_rate,
            "triggers": sum(triggers),
            "runs": len(triggers),
            "pass": did_pass,
        })

    passed = sum(1 for r in results if r["pass"])
    total = len(results)

    return {
        "skill_name": skill_name,
        "description": description,
        "results": results,
        "summary": {
            "total": total,
            "passed": passed,
            "failed": total - passed,
        },
    }


def main():
    parser = argparse.ArgumentParser(description="Run trigger evaluation for a skill description")
    parser.add_argument("--eval-set", required=True, help="Path to eval set JSON file")
    parser.add_argument("--skill-path", required=True, help="Path to skill directory")
    parser.add_argument("--description", default=None, help="Override description to test")
    parser.add_argument("--num-workers", type=int, default=10, help="Number of parallel workers")
    parser.add_argument("--timeout", type=int, default=60, help="Timeout per query in seconds")
    parser.add_argument("--runs-per-query", type=int, default=3, help="Number of runs per query")
    parser.add_argument("--trigger-threshold", type=float, default=0.5, help="Trigger rate threshold")
    parser.add_argument("--model", default=None, help="Model for opencode run, e.g. provider/model#variant")
    parser.add_argument("--verbose", action="store_true", help="Print progress to stderr")
    args = parser.parse_args()

    eval_set = json.loads(Path(args.eval_set).read_text())
    skill_path = Path(args.skill_path)

    if not (skill_path / "SKILL.md").exists():
        print(f"Error: No SKILL.md found at {skill_path}", file=sys.stderr)
        sys.exit(1)

    name, original_description, content = parse_skill_md(skill_path)
    description = args.description or original_description
    project_root = find_project_root()

    if args.verbose:
        print(f"Evaluating: {description}", file=sys.stderr)

    output = run_eval(
        eval_set=eval_set,
        skill_name=name,
        description=description,
        num_workers=args.num_workers,
        timeout=args.timeout,
        project_root=project_root,
        runs_per_query=args.runs_per_query,
        trigger_threshold=args.trigger_threshold,
        model=args.model,
    )

    if args.verbose:
        summary = output["summary"]
        print(f"Results: {summary['passed']}/{summary['total']} passed", file=sys.stderr)

    print(json.dumps(output, indent=2))


if __name__ == "__main__":
    main()
