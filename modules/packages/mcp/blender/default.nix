# Blender MCP server (ahujasid/mcp-for-blender, Oct 2026 latest: v2.1.3).
# Source pinned via the `blender-mcp-src` flake input (commit-pinned, no
# upstream tags exist); bump by updating the rev in flake.nix, then:
#   nix flake update blender-mcp-src
# Then rebuild: sudo nixos-rebuild switch --flake /etc/nixos#quietcraft
#
# The binary is installed but never auto-connected: the server registers
# with `disabled: true` unless my.mcp.blender.enable is set.
{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
let
  version = "2.1.3";
  mcp-for-blender = pkgs.python3Packages.buildPythonApplication {
    pname = "mcp-for-blender";
    inherit version;
    pyproject = true;
    src = inputs.blender-mcp-src;
    build-system = with pkgs.python3Packages; [ setuptools ];
    dependencies = with pkgs.python3Packages; [
      httpx
      mcp
    ];
    # Upstream has no nix-wired test suite; the stdio entrypoint is
    # verified via `mcp-for-blender --help` plus a live Blender socket check.
    doCheck = false;
    postInstall = ''
      # Keep the old `blender-mcp` name working: tutorials and existing
      # configs reference both names for the same server.
      ln -s $out/bin/mcp-for-blender $out/bin/blender-mcp
    '';
    meta = {
      description = "Community Blender MCP server (Model Context Protocol bridge for Blender)";
      homepage = "https://github.com/ahujasid/mcp-for-blender";
      license = lib.licenses.mit;
      mainProgram = "mcp-for-blender";
    };
  };
in
{
  options.my.blender-mcp.enable = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = "Community Blender MCP server binary (mcp-for-blender, +blender-mcp compat link) for OpenCode/LLM clients.";
  };

  config = lib.mkIf config.my.blender-mcp.enable {
    environment.systemPackages = [ mcp-for-blender ];

    my.mcp.servers.blender = {
      command = [ "/run/current-system/sw/bin/blender-mcp" ];
      environment = {
        BLENDER_HOST = "localhost";
        BLENDER_PORT = "9876";
      };
      enabled = config.my.mcp.blender.enable;
    };
  };
}
