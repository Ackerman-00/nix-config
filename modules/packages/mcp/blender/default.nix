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
      mcp_1
    ];
    doCheck = false;
    postInstall = ''
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
  options.my.blender-mcp.enable =
    lib.mkEnableOption "Community Blender MCP server binary (mcp-for-blender, +blender-mcp compat link) for OpenCode/LLM clients."
    // {
      default = true;
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
