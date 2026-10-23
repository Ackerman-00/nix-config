# Helpers
{
  lib,
}:

{
  mapJson = map: builtins.toJSON map;

  # Ours only
  overridden = map: lib.filterAttrs (_: entry: entry.owner == "agent-skills" && entry.override) map;
}
