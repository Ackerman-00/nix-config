# MCP registry
{
  config,
  lib,
  ...
}:
{
  options.my.mcp = {
    blender.enable = lib.mkEnableOption "Auto-connect the Blender MCP server at OpenCode startup." // {
      default = false;
    };

    neurakeep.enable =
      lib.mkEnableOption "Auto-connect the NeuraKeep MCP server at OpenCode startup."
      // {
        default = false;
      };

    playwright.enable =
      lib.mkEnableOption "Auto-connect the Playwright MCP server at OpenCode startup."
      // {
        default = false;
      };

    youtube-transcript.enable =
      lib.mkEnableOption "Auto-connect the YouTube-transcript MCP server at OpenCode startup."
      // {
        default = false;
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

            timeout = lib.mkOption {
              type = lib.types.ints.unsigned;
              default = 20000;
              description = ''
                Milliseconds an MCP request may take. The OpenCode default is
                5000, which aborts any tool that generates or downloads.
              '';
            };
          };
        }
      );
      default = { };
      description = "MCP servers registered for OpenCode/LLM clients.";
    };
  };
}
