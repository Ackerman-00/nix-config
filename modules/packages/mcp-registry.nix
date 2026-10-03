# MCP server registry: providers declare `my.mcp.servers.<name>` inside
# their own `mkIf enable` block, so disabling a module unregisters its
# server. home-manager/programs/opencode.nix renders it to JSON.
#
# Nothing auto-connects: each server also has `my.mcp.<name>.enable`
# (default false). Off renders as `"disabled": true`, so OpenCode lists it
# in /mcp (toggleable live per session) but spawns no process. An agent
# turns one on by setting the flag and rebuilding.
{
  config,
  lib,
  ...
}:
{
  options.my.mcp = {
    blender.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Auto-connect the Blender MCP server at OpenCode startup.";
    };

    concat.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Auto-connect the Concat MCP server at OpenCode startup.";
    };

    playwright.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Auto-connect the Playwright MCP server at OpenCode startup.";
    };

    youtube-transcript.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Auto-connect the YouTube-transcript MCP server at OpenCode startup.";
    };

    servers = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule {
          options = {
            command = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              description = "argv to spawn for this MCP server.";
            };
            environment = lib.mkOption {
              type = lib.types.attrsOf lib.types.str;
              default = { };
              description = "Extra env vars for this MCP server.";
            };
            enabled = lib.mkOption {
              type = lib.types.bool;
              default = false;
              description = "Connect at startup. Off renders as `disabled: true` (no process spawned).";
            };
          };
        }
      );
      default = { };
      description = "MCP servers registered for OpenCode/LLM clients.";
    };
  };
}
