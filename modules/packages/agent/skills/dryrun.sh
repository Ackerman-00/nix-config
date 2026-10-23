#!/usr/bin/env bash
# Refresh dry run
# --fresh: recopy the live trees
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)
export PATH="/nix/var/nix/profiles/default/bin:$PATH"

fresh=0
for arg in "$@"; do
  case "$arg" in
    --fresh) fresh=1 ;;
    *)
      echo "usage: dryrun.sh [--fresh]" >&2
      exit 2
      ;;
  esac
done

nix_cmd=(nix --extra-experimental-features 'nix-command flakes' --accept-flake-config)

store=$("${nix_cmd[@]}" build --no-link --print-out-paths "$root#agent-skills" | tail -1)

# Exclusions from the flake
excluded=$("${nix_cmd[@]}" eval --raw \
  --apply 'xs: builtins.concatStringsSep " " xs' \
  "$root#nixosConfigurations.quietcraft.config.my.skills.excluded")

work=${DRYRUN_WORK:-/tmp/opencode/dryrun.work}
today=$(date -u +%Y-%m-%d)
stamp="$work/.dryrun-day"
mkdir -p "$work/state"
if [ "$fresh" = 1 ] || [ ! -f "$stamp" ] || [ "$(cat "$stamp")" != "$today" ]; then
  rm -rf "$work/home"
  mkdir -p "$work/home"
  cp -a "$HOME/.agents/skills" "$work/home/agents-skills"
  cp -a "$HOME/.config/opencode/skills" "$work/home/opencode-skills"
  printf '%s\n' "$today" > "$stamp"
fi

export SKILLS_MAP="$store/upstream-map.json"
export SKILLS_SEED="$store/state-seed.json"
export SKILLS_OVERRIDES="$store/overrides"
export SKILLS_AGENTS_DIR="$work/home/agents-skills"
export SKILLS_OPENCODE_DIR="$work/home/opencode-skills"
export SKILLS_STATE="$work/state/refresh-state.json"
export SKILLS_GIT="$(command -v git)"
export SKILLS_TAR="$(command -v tar)"
export SKILLS_EXCLUDED="$excluded"
export SKILLS_REFRESH=1
export SKILLS_RESTORE=1
export SKILLS_DRY_RUN="${SKILLS_DRY_RUN:-0}"
export SKILLS_DEADLINE="${SKILLS_DEADLINE:-1200}"

node "$root/modules/packages/agent/skills/refresh.mjs"
