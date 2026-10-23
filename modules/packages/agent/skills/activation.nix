# Refresh activation
{
  lib,
  pkgs,
  refreshScript,
  mapFile,
  seedFile,
  overrides,
  homeDirectory,
  excludedSkills,
  runRefresh,
  runRestore,
  refreshDeadline,
}:
let
  inherit (pkgs) git gnutar nodejs;
in
''
  export SKILLS_MAP="${mapFile}"
  export SKILLS_SEED="${seedFile}"
  export SKILLS_STATE="${homeDirectory}/.local/state/agent-skills/refresh-state.json"
  export SKILLS_OVERRIDES="${overrides}"
  export SKILLS_AGENTS_DIR="${homeDirectory}/.agents/skills"
  export SKILLS_OPENCODE_DIR="${homeDirectory}/.config/opencode/skills"
  export SKILLS_GIT="${git}/bin/git"
  export SKILLS_TAR="${gnutar}/bin/tar"
  export SKILLS_EXCLUDED="${lib.concatStringsSep " " excludedSkills}"
  export SKILLS_REFRESH="${if runRefresh then "1" else "0"}"
  export SKILLS_RESTORE="${if runRestore then "1" else "0"}"
  export SKILLS_DEADLINE="${toString refreshDeadline}"
  if [[ -v DRY_RUN ]]; then
    export SKILLS_DRY_RUN=1
  else
    export SKILLS_DRY_RUN=0
  fi
  ${nodejs}/bin/node ${refreshScript}
''
