{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
let
  version = "0.7.0";
  playwrightMcpVersion = "0.0.83";
  mcp-youtube-transcript = pkgs.python3Packages.buildPythonApplication {
    pname = "mcp-youtube-transcript";
    inherit version;
    pyproject = true;
    src = "${inputs.mcp-youtube-transcript-src}";
    build-system = with pkgs.python3Packages; [ hatchling ];
    dependencies = with pkgs.python3Packages; [
      beautifulsoup4
      humanize
      mcp
      pydantic
      requests
      rich-click
      youtube-transcript-api
      yt-dlp
    ];
    doCheck = false;
    meta = {
      description = "MCP server retrieving transcripts of YouTube videos (yt-dlp based, no API key)";
      homepage = "https://github.com/jkawamoto/mcp-youtube-transcript";
      license = lib.licenses.mit;
      mainProgram = "mcp-youtube-transcript";
    };
  };
in
{
  options.my.mcp-servers.enable =
    lib.mkEnableOption "YouTube transcript MCP server + yt-dlp for OpenCode/LLM clients."
    // {
      default = true;
    };

  config = lib.mkIf config.my.mcp-servers.enable {
    environment.systemPackages = [
      mcp-youtube-transcript
      pkgs.yt-dlp
    ];

    my.mcp.servers.youtube-transcript = {
      command = [ "/run/current-system/sw/bin/mcp-youtube-transcript" ];
      enabled = config.my.mcp.youtube-transcript.enable;
    };

    my.mcp.servers.playwright = {
      command = [
        "/run/current-system/sw/bin/npx"
        "-y"
        "@playwright/mcp@${playwrightMcpVersion}"
        "--headless"
        "--isolated"
        "--executable-path"
        "/run/current-system/sw/bin/helium"
      ];
      enabled = config.my.mcp.playwright.enable;
    };
  };
}
