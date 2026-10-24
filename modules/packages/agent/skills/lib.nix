{
  lib,
}:

{
  mapJson = map: builtins.toJSON map;

  overridden = map: lib.filterAttrs (_: entry: entry.owner == "agent-skills" && entry.override) map;
}
