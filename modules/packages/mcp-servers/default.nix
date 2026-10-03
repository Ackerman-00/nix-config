# mcp-youtube-transcript v0.7.0 (jkawamoto) + yt-dlp CLI.
# v0.7.0 is the newest release compatible with nixpkgs mcp 1.x (locked:
# 1.29.0, checked 2026-10-02); v0.7.1+ through v0.8.0 (Oct 2026 latest)
# needs mcp>=2, unpackaged. Bump by retagging the flake input once nixpkgs
# ships mcp 2.x.
#
# The binaries are installed but never auto-connected: both servers register
# with `disabled: true` unless my.mcp.<name>.enable is set.
#
# Playwright (browser automation via Helium) is NOT nix-packaged: upstream
# ships npm-only. The pin lives here (`playwrightMcpVersion` below) and
# is registered in `my.mcp.servers` for the opencode renderer; there is
# no second copy to drift.
# Helium over Firefox: system Firefox is broken on this snapshot
# (libxul.so wants NSS_3.113, system has NSS 3.112.5), Helium is a healthy
# Chromium 154, and Playwright targets Chromium first-class.
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
    # Upstream has no nix-wired test suite; the stdio entrypoint is
    # verified via `mcp-youtube-transcript --help` plus a live fetch.
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
  options.my.mcp-servers.enable = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = "YouTube transcript MCP server + yt-dlp for OpenCode/LLM clients.";
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

    # NOT nix-packaged (upstream ships npm-only). --executable-path
    # avoids Playwright's own browser download, broken on NixOS.
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
