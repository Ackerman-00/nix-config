# Agent skills artifacts
{
  pkgs,
  lib,
}:
let
  sl = import ./lib.nix { inherit lib; };
  map = import ./sources.nix;
  localCopies = lib.mapAttrsToList (_: entry: "${entry.tree}/${entry.name}") (sl.overridden map);
in
pkgs.runCommand "agent-skills" { } ''
  mkdir -p $out
  cp -r ${./overrides} $out/overrides
  cp ${./sources.nix} $out/sources.nix
  cp ${./state-seed.json} $out/state-seed.json
  cp ${./skill-lock.json} $out/skill-lock.json
  cp ${pkgs.writeText "agent-skills-upstream-map.json" (sl.mapJson map)} $out/upstream-map.json
  # Missing copies
  for copy in ${lib.escapeShellArgs localCopies}; do
    if [ ! -d "$out/overrides/''${copy%%/*}/''${copy##*/}" ]; then
      echo "agent-skills: the local copy $copy is missing" >&2
      exit 1
    fi
  done
''
