#!/usr/bin/env python3
"""Generate the agent-skills upstream map, the override trees and the refresh state.

Reads the real on-disk state (the `skills` CLI lockfile, the OpenChamber
install manifest and the two skill trees OpenCode reads) and writes:

  sources.nix        upstream map: skill -> { repo, path, tree, owner, override,
                     rev }
  overrides/<tree>/<skill>/   the authoritative copy of every local-only and
                     locally adapted skill
  state-seed.json    upstream HEAD commits + installed hashes, so the first
                     activation after a rebuild knows what is already current
  skill-lock.json    a copy of the CLI lockfile, so the upstream map is
                     reviewable in git instead of living only in $HOME

Upstream content is compared with git tree hashes: every repo is cloned
without blobs and the tree hash of the skill folder is compared with the tree
hash of the local copy. That is exact, needs no registry and no API quota.

The upstream of a skill is picked from three kinds of evidence, strongest
first: a copy that is byte identical to the installed one, an install record
that names the repo and the path, and a repo that holds a skill with that
name. Ties are broken by PRIORITY_REPOS, then by the install records, then
alphabetically.

The run is idempotent: same inputs -> same outputs. The HEAD of a repo in
state-seed.json comes from the committed seed, not from the clone, so an
upstream that moved does not change the file.
"""

import argparse
import concurrent.futures
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile

SKIP_DIRS = {".git", "node_modules", "__pycache__"}
SKIP_FILES = {"metadata.json"}

# Priority upstreams
PRIORITY_REPOS = (
    "obra/superpowers",
    "mattpocock/skills",
    "anthropics/skills",
    "anthropics/claude-code",
)

# Upstream aliases
UPSTREAM_ALIASES = {
    "writing-hookify-rules": (
        "anthropics/claude-code",
        "plugins/hookify/skills/writing-rules",
    ),
}

# Known lagging upstream
LAGGING_UPSTREAM = ("reverse-engineer-anything",)

# Candidate upstreams
CANDIDATE_REPOS = (
    "cursor/plugins",
    "mattpocock/skills",
    "anthropics/skills",
    "anthropics/claude-code",
    "anthropics/claude-plugins-official",
    "openai/skills",
    "github/awesome-copilot",
    "morluto/rea",
    "emilkowalski/skills",
    "addyosmani/agent-skills",
    "wshobson/agents",
    "affaan-m/ecc",
    "nousresearch/hermes-agent",
    "midasmatterhorn/artcraft-skills",
)

# Flake-pinned upstreams
FLAKE_PINS = {"obra/superpowers": "superpowers-src"}


# Git Tree Hash


def blob_sha(data):
    return hashlib.sha1(b"blob %d\0" % len(data) + data).hexdigest()


def tree_sha(entries):
    entries = sorted(
        entries, key=lambda entry: entry[1] + ("/" if entry[0] == "40000" else "")
    )
    body = b"".join(
        f"{mode} {name}\0".encode() + bytes.fromhex(sha) for mode, name, sha in entries
    )
    return hashlib.sha1(b"tree %d\0" % len(body) + body).hexdigest()


def local_tree_sha(path):
    def walk(base):
        entries = []
        for name in sorted(os.listdir(base)):
            full = os.path.join(base, name)
            if os.path.islink(full):
                entries.append(("120000", name, blob_sha(os.readlink(full).encode())))
            elif os.path.isdir(full):
                if name in SKIP_DIRS:
                    continue
                entries.append(("40000", name, walk(full)))
            elif os.path.isfile(full):
                if name in SKIP_FILES:
                    continue
                with open(full, "rb") as handle:
                    data = handle.read()
                mode = "100755" if os.access(full, os.X_OK) else "100644"
                entries.append((mode, name, blob_sha(data)))
        return tree_sha(entries)

    return walk(path)


# Upstream Repos


class Repos:
    """Blobless clones of the upstream repos."""

    def __init__(self, workdir, pins=None):
        self.workdir = workdir
        self.paths = {}
        self.pins = pins or {}

    def clone(self, repo):
        target = os.path.join(self.workdir, repo.replace("/", "__"))
        if os.path.isdir(target):
            shutil.rmtree(target)
        result = subprocess.run(
            [
                "git",
                "clone",
                "--depth",
                "1",
                "--filter=blob:none",
                "--no-checkout",
                "--quiet",
                f"https://github.com/{repo}.git",
                target,
            ],
            capture_output=True,
            text=True,
            timeout=600,
            check=False,
        )
        if result.returncode != 0:
            return None
        return target

    def prepare(self, repos):
        with concurrent.futures.ThreadPoolExecutor(max_workers=8) as pool:
            for repo, path in zip(repos, pool.map(self.clone, repos)):
                if path:
                    self.paths[repo] = path
        for repo, rev in self.pins.items():
            self.fetch_rev(repo, rev)

    def fetch_rev(self, repo, rev):
        """Make a pinned commit available in a shallow clone."""
        if not self.paths.get(repo):
            return
        if self.git(repo, "cat-file", "-e", f"{rev}^{{commit}}"):
            return
        subprocess.run(
            ["git", "-C", self.paths[repo], "fetch", "--depth", "1", "origin", rev],
            capture_output=True,
            text=True,
            timeout=600,
            check=False,
        )

    def git(self, repo, *args):
        path = self.paths.get(repo)
        if not path:
            return None
        result = subprocess.run(
            ["git", "-C", path, *args],
            capture_output=True,
            text=True,
            timeout=300,
            check=False,
        )
        if result.returncode != 0:
            return None
        return result.stdout

    def ref(self, repo):
        """The commit the lookup runs against: the pin, or the branch head."""
        return self.pins.get(repo, "HEAD")

    def head(self, repo):
        if repo in self.pins:
            return self.pins[repo]
        return (self.git(repo, "rev-parse", "HEAD") or "").strip() or None

    def tree_sha(self, repo, path, ref=None):
        """Tree hash of an upstream folder, without the registry metadata file."""
        ref = ref or self.ref(repo)
        if path:
            raw = self.git(repo, "rev-parse", f"{ref}:{path}")
        else:
            raw = self.git(repo, "rev-parse", f"{ref}^{{tree}}")
        if not raw:
            return None
        sha = raw.strip()
        listing = self.git(repo, "ls-tree", sha)
        if listing is None:
            return sha
        lines = [
            line
            for line in listing.splitlines()
            if line.split("\t")[-1] not in SKIP_FILES
        ]
        if len(lines) == len(listing.splitlines()):
            return sha
        result = subprocess.run(
            ["git", "-C", self.paths[repo], "mktree", "--missing"],
            input="\n".join(lines) + "\n",
            capture_output=True,
            text=True,
            timeout=300,
            check=False,
        )
        if result.returncode != 0:
            return sha
        return result.stdout.strip()

    def skill_index(self, repo):
        """Every path of every skill in a repo, keyed by the skill name."""
        listing = self.git(repo, "ls-tree", "-r", "--name-only", self.ref(repo))
        if not listing:
            return {}
        found = {}
        for line in listing.splitlines():
            if not line.endswith("/SKILL.md"):
                continue
            directory = line[: -len("/SKILL.md")]
            found.setdefault(directory.rsplit("/", 1)[-1], []).append(directory)
        return found


# Attribution


def repo_rank(repo, records):
    """Where a repo sits in the order that breaks a tie."""
    lowered = repo.lower()
    for index, name in enumerate(PRIORITY_REPOS):
        if lowered == name.lower():
            return (0, index)
    for record, _ in records:
        if record.lower() == lowered:
            return (1, 0)
    return (2, 0)


def path_rank(path, records):
    """The recorded path wins over another path of the same repo."""
    return 0 if any(path == recorded for _, recorded in records) else 1


def choose_source(
    name,
    records,
    index,
    repos,
    local,
    allow_name,
    key=None,
    seed=None,
    local_hash=None,
    previous=None,
):
    """The upstream of one skill, or None when it has none.

    records: the (repo, path) pairs the install records name.
    index: every path of every skill in the candidate repos, keyed by name.
    local: the tree hash of the installed copy.
    allow_name: a repo that only holds a skill with this name may name it.
    seed: the committed state, holding the upstream tree hash of every skill.
    local_hash: the hash of the installed copy, as the seed records it.
    previous: the map of the last run.
    """
    candidates = []
    seen = set()

    def add(repo, path):
        key_ = (repo.lower(), path)
        if key_ in seen:
            return
        seen.add(key_)
        candidates.append((repo, path))

    for repo, path in records:
        add(repo, path)
    for repo in sorted(index):
        for path in index[repo].get(name, []):
            add(repo, path)

    scored = []
    for repo, path in candidates:
        upstream = repos.tree_sha(repo, path)
        recorded = None
        recorded_hash = None
        if key and seed:
            recorded = seed.get(repo, {}).get("trees", {}).get(key)
            recorded_hash = seed.get(repo, {}).get("skills", {}).get(key)
        was = (previous or {}).get(key, {})
        was_upstream = (
            was.get("repo", "").lower() == repo.lower() and was.get("override") is False
        )
        unchanged = bool(was_upstream) and (
            recorded_hash is None
            or (local_hash is not None and recorded_hash == local_hash)
        )
        if upstream is None and recorded is None and not unchanged:
            # Unreachable
            continue
        if unchanged:
            evidence = 0
            at = "recorded"
        elif upstream == local:
            evidence = 0
            at = "upstream"
        elif recorded == local:
            evidence = 0
            at = "recorded"
        elif any(
            repo.lower() == record.lower() and path == recorded_path
            for record, recorded_path in records
        ):
            evidence = 1
            at = None
        else:
            evidence = 2
            at = None
        scored.append(
            (
                evidence,
                repo_rank(repo, records),
                path_rank(path, records),
                repo,
                path,
                upstream,
                at,
            )
        )
    if not scored:
        return None
    scored.sort()
    best = scored[0]
    if best[0] == 2 and not allow_name:
        return None
    return {
        "repo": best[3],
        "path": best[4],
        "matched": best[0] == 0,
        "at": best[6],
        "tree": best[5],
    }


# Helpers


def skill_dirs(root):
    if not os.path.isdir(root):
        return []
    return sorted(
        name for name in os.listdir(root) if os.path.isdir(os.path.join(root, name))
    )


def folder_hash(path):
    """Hash a skill folder the way the refresh driver hashes an installed one."""
    if not os.path.isdir(path):
        return None
    files = []
    for base, dirs, names in os.walk(path):
        dirs[:] = [d for d in dirs if d not in SKIP_DIRS]
        for name in names:
            if name in SKIP_FILES:
                continue
            rel = os.path.relpath(os.path.join(base, name), path).replace(os.sep, "/")
            files.append((rel, os.path.join(base, name)))
    digest = hashlib.sha256()
    for rel, full in sorted(files):
        digest.update(rel.encode())
        with open(full, "rb") as handle:
            digest.update(handle.read())
    return digest.hexdigest()


def read_previous(out_dir):
    """The map of the last run, so an upstream we cannot reach keeps its entry."""
    path = os.path.join(out_dir, "sources.nix")
    entries = {}
    if not os.path.isfile(path):
        return entries
    with open(path) as handle:
        text = handle.read()
    for match in re.finditer(r'"([^"]+)" = \{\n(.*?)\n  \};', text, re.DOTALL):
        fields = dict(re.findall(r'(\w+) = ("[^"]*"|true|false);', match.group(2)))
        entries[match.group(1)] = {
            key: value.strip('"') if value.startswith('"') else value == "true"
            for key, value in fields.items()
        }
    return entries


def copy_skill(src, dst):
    if os.path.exists(dst):
        shutil.rmtree(dst)
    shutil.copytree(src, dst, ignore=shutil.ignore_patterns(*SKIP_DIRS, "*.pyc"))


def flake_pins(lock_path):
    """The revision every pinned repo is bound to."""
    if not os.path.isfile(lock_path):
        return {}
    with open(lock_path) as handle:
        lock = json.load(handle)
    nodes = lock.get("nodes", {})
    pins = {}
    for repo, name in FLAKE_PINS.items():
        rev = nodes.get(name, {}).get("locked", {}).get("rev")
        if rev:
            pins[repo] = rev
    return pins


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--agents-dir", default=os.path.expanduser("~/.agents/skills"))
    parser.add_argument(
        "--opencode-dir", default=os.path.expanduser("~/.config/opencode/skills")
    )
    parser.add_argument(
        "--lock", default=os.path.expanduser("~/.agents/.skill-lock.json")
    )
    parser.add_argument(
        "--manifest",
        default=os.path.expanduser(
            "~/.config/openchamber/skills-installed-sources.json"
        ),
    )
    parser.add_argument(
        "--hyperframes-dir", default=None, help="built hyperframes-skills dir"
    )
    parser.add_argument(
        "--flake-lock",
        default=os.path.join(
            os.path.dirname(os.path.abspath(__file__)),
            "..",
            "..",
            "..",
            "..",
            "flake.lock",
        ),
        help="the flake lock that pins the repos of FLAKE_PINS",
    )
    parser.add_argument("--out", default=os.path.dirname(os.path.abspath(__file__)))
    args = parser.parse_args()

    with open(args.lock) as handle:
        lock = json.load(handle)
    entries = lock["skills"]
    hyperframes_owned = (
        set(skill_dirs(args.hyperframes_dir)) if args.hyperframes_dir else set()
    )

    seed_path = os.path.join(args.out, "state-seed.json")
    committed_seed = {}
    if os.path.isfile(seed_path):
        with open(seed_path) as handle:
            committed_seed = json.load(handle).get("repos", {})
    seed = committed_seed
    previous = read_previous(args.out)

    manifest = {}
    if os.path.isfile(args.manifest):
        with open(args.manifest) as handle:
            manifest_entries = json.load(handle).get("entries", [])
        for entry in manifest_entries:
            manifest[entry["skillName"]] = (entry["sourceRef"], entry["skillDir"])

    trees = (("agents", args.agents_dir), ("opencode", args.opencode_dir))
    tree_root = dict(trees)
    curated = skill_dirs(args.opencode_dir)

    pins = flake_pins(args.flake_lock)
    repo_pool = sorted(
        set(CANDIDATE_REPOS)
        | set(PRIORITY_REPOS)
        | set(pins)
        | {ref for ref, _ in manifest.values()}
        | {
            entries[name]["source"]
            for name in curated
            if name in entries and entries[name].get("sourceType") == "github"
        }
        | {
            entries[name]["source"]
            for name in skill_dirs(args.agents_dir)
            if name in entries
        }
    )

    repos = Repos(tempfile.mkdtemp(prefix="agent-skills-repos-"), pins)
    try:
        repos.prepare(repo_pool)
        index = {repo: repos.skill_index(repo) for repo in repos.paths}

        map_entries = {}
        overrides = {}
        upstream_at = {}

        def record(tree, name, source, owner):
            key = f"{tree}/{name}"
            if source is None:
                old = previous.get(key)
                if old and old.get("repo"):
                    source = {
                        "repo": old["repo"],
                        "path": old.get("path", ""),
                        "matched": not old.get("override", False),
                        "at": "recorded",
                        "tree": None,
                    }
            if source is None:
                if owner == "agent-skills":
                    overrides.setdefault(tree, []).append(name)
                map_entries[key] = {
                    "name": name,
                    "repo": "",
                    "path": "",
                    "tree": tree,
                    "owner": owner,
                    "override": True,
                }
                return
            repo = source["repo"]
            entry = {
                "name": name,
                "repo": repo,
                "path": source["path"],
                "tree": tree,
                "owner": owner,
                "override": not source["matched"],
            }
            if repo in pins:
                entry["rev"] = pins[repo]
            map_entries[key] = entry
            upstream_at[key] = source.get("at")
            if entry["override"] and owner == "agent-skills":
                overrides.setdefault(tree, []).append(name)

        # Canonical tree
        for name in skill_dirs(args.agents_dir):
            owner = "hyperframes" if name in hyperframes_owned else "agent-skills"
            key = f"agents/{name}"
            entry = entries.get(name)
            skill_dir = os.path.join(args.agents_dir, name)
            local = local_tree_sha(skill_dir)
            local_hash = folder_hash(skill_dir)
            if not entry or entry.get("sourceType") != "github":
                # No lockfile entry
                source = choose_source(
                    name,
                    [],
                    index,
                    repos,
                    local,
                    allow_name=True,
                    key=key,
                    seed=seed,
                    local_hash=local_hash,
                    previous=previous,
                )
                if source is None and name in UPSTREAM_ALIASES:
                    repo, path = UPSTREAM_ALIASES[name]
                    upstream = repos.tree_sha(repo, path)
                    source = (
                        {
                            "repo": repo,
                            "path": path,
                            "matched": upstream == local,
                            "at": "upstream" if upstream == local else None,
                            "tree": upstream,
                        }
                        if upstream is not None
                        else None
                    )
                record("agents", name, source, owner)
                continue
            repo = entry["source"]
            path = entry["skillPath"][:-9]
            upstream = repos.tree_sha(repo, path)
            recorded = seed.get(repo, {}).get("trees", {}).get(key)
            recorded_hash = seed.get(repo, {}).get("skills", {}).get(key)
            was = previous.get(key, {})
            was_upstream = (
                was.get("repo", "").lower() == repo.lower()
                and was.get("override") is False
            )
            unchanged = bool(was_upstream) and (
                recorded_hash is None
                or (local_hash is not None and recorded_hash == local_hash)
            )
            if owner == "hyperframes":
                if upstream is None and recorded is None and not unchanged:
                    source = None
                else:
                    source = {
                        "repo": repo,
                        "path": path,
                        "matched": unchanged
                        or (upstream is not None and upstream == local)
                        or recorded == local,
                        "at": "upstream"
                        if upstream == local
                        else ("recorded" if (recorded == local or unchanged) else None),
                        "tree": upstream,
                    }
            else:
                source = choose_source(
                    name,
                    [(repo, path)],
                    index,
                    repos,
                    local,
                    allow_name=False,
                    key=key,
                    seed=seed,
                    local_hash=local_hash,
                    previous=previous,
                )
            record("agents", name, source, owner)

        # Curated tree
        for name in curated:
            key = f"opencode/{name}"
            records = []
            if name in manifest:
                records.append(manifest[name])
            entry = entries.get(name)
            if entry and entry.get("sourceType") == "github":
                records.append((entry["source"], entry["skillPath"][:-9]))
            skill_dir = os.path.join(args.opencode_dir, name)
            local = local_tree_sha(skill_dir)
            local_hash = folder_hash(skill_dir)
            source = choose_source(
                name,
                records,
                index,
                repos,
                local,
                allow_name=True,
                key=key,
                seed=seed,
                local_hash=local_hash,
                previous=previous,
            )
            if source is not None and name in LAGGING_UPSTREAM:
                source["matched"] = True
            record("opencode", name, source, "agent-skills")

        # Removed skills
        for name, entry in entries.items():
            if entry.get("sourceType") != "github":
                continue
            if os.path.isdir(os.path.join(args.agents_dir, name)):
                continue
            if name in hyperframes_owned:
                continue
            map_entries[f"agents/{name}"] = {
                "name": name,
                "repo": entry["source"],
                "path": entry["skillPath"][:-9],
                "tree": "agents",
                "owner": "agent-skills",
                "override": False,
            }

        # Override trees
        for tree in ("agents", "opencode"):
            root = os.path.join(args.out, "overrides", tree)
            if os.path.exists(root):
                shutil.rmtree(root)
            os.makedirs(root, exist_ok=True)
            for name in overrides.get(tree, []):
                copy_skill(
                    os.path.join(tree_root[tree], name), os.path.join(root, name)
                )

        # Upstream map
        lines = [
            "# Upstream map for every skill this machine tracks.",
            "# Generated by generate.py from the skills CLI lockfile, the OpenChamber",
            "# install manifest and the two skill trees OpenCode reads.",
            "# Do not edit by hand.",
            "{",
        ]
        for key in sorted(map_entries):
            entry = map_entries[key]
            lines.append(f"  {json.dumps(key)} = {{")
            lines.append(f"    name = {json.dumps(entry['name'])};")
            lines.append(f"    repo = {json.dumps(entry['repo'])};")
            lines.append(f"    path = {json.dumps(entry['path'] or '')};")
            lines.append(f"    tree = {json.dumps(entry['tree'])};")
            lines.append(f"    owner = {json.dumps(entry['owner'])};")
            lines.append(f"    override = {'true' if entry['override'] else 'false'};")
            if entry.get("rev"):
                lines.append(f"    rev = {json.dumps(entry['rev'])};")
            lines.append("  };")
        lines.append("}")
        with open(os.path.join(args.out, "sources.nix"), "w") as handle:
            handle.write("\n".join(lines) + "\n")

        # State seed
        by_repo = {}
        for key, entry in map_entries.items():
            if not entry["repo"]:
                continue
            by_repo.setdefault(entry["repo"], []).append(key)
        new_seed = {"version": 1, "repos": {}}
        for repo in sorted(by_repo):
            hashes = {
                key: folder_hash(
                    os.path.join(
                        tree_root[map_entries[key]["tree"]], map_entries[key]["name"]
                    )
                )
                for key in sorted(by_repo[repo])
            }
            trees = {}
            for key in sorted(by_repo[repo]):
                recorded = committed_seed.get(repo, {}).get("trees", {}).get(key)
                entry = map_entries[key]
                skill_dir = os.path.join(tree_root[entry["tree"]], entry["name"])
                if entry["override"]:
                    if recorded:
                        trees[key] = recorded
                elif os.path.isdir(skill_dir):
                    trees[key] = local_tree_sha(skill_dir)
            head = repos.head(repo)
            previous_repo = committed_seed.get(repo, {})
            current = all(upstream_at.get(key) == "upstream" for key in by_repo[repo])
            if repo not in pins and previous_repo.get("head") and not current:
                head = previous_repo["head"]
            new_seed["repos"][repo] = {"head": head, "skills": hashes, "trees": trees}
        with open(seed_path, "w") as handle:
            json.dump(new_seed, handle, indent=2, sort_keys=True)
            handle.write("\n")

        shutil.copyfile(args.lock, os.path.join(args.out, "skill-lock.json"))

        counts = {
            "mapped": len(map_entries),
            "overridden": sum(len(v) for v in overrides.values()),
            "hyperframes": len(hyperframes_owned),
        }
        print(json.dumps(counts, sort_keys=True))
    finally:
        shutil.rmtree(repos.workdir, ignore_errors=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
