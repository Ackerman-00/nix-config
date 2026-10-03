# OpenCode config, rendered from the my.mcp.servers registry.
# Servers with enabled = false render as `disabled: true`: still listed in
# /mcp (toggleable live per session) but never spawned automatically.
{
  osConfig,
  lib,
  ...
}:
let
  toServer =
    s:
    {
      type = "local";
      inherit (s) command;
    }
    // (if s.environment != { } then { inherit (s) environment; } else { })
    // (if s.enabled then { } else { disabled = true; });
in
{
  xdg.configFile."opencode/opencode.jsonc".text = builtins.toJSON {
    "$schema" = "https://opencode.ai/config.json";
    mcp.servers = builtins.mapAttrs (_: toServer) osConfig.my.mcp.servers;
  };
}
