# Concat MCP bridge: stdio server wrapping the JSON-RPC socket
# (127.0.0.1:7420), vendored in-tree under python/. Upstream is building
# a native one on the Rust `rmcp` SDK (Concat issue #95); this goes away
# when that ships. (Concat 0.2.5 release notes, checked 2026-10-02, mention
# no native MCP server yet, so the bridge stays.)
#
# Token resolution: CONCAT_API_TOKEN, then the token pinned in the
# window's Settings > Remote page, then ~/.config/concat-mcp/token.
# A window-minted token rotates every launch, so pinning one is the
# durable path. No secret in the declarative config.
#
# The binary is installed but never auto-connected: the server registers
# with `disabled: true` unless my.mcp.concat.enable is set.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  concat-mcp = pkgs.python3Packages.buildPythonApplication {
    pname = "concat-mcp";
    version = "0.2.4";
    pyproject = true;
    src = ./python;
    build-system = with pkgs.python3Packages; [ setuptools ];
    dependencies = with pkgs.python3Packages; [ mcp ];
    # Upstream has no nix-wired test suite; the stdio entrypoint is
    # verified via `concat-mcp --help` plus a live Concat socket check.
    doCheck = false;
    meta = {
      description = "MCP bridge for the Concat video editor JSON-RPC API";
      homepage = "https://github.com/jub0t/Concat";
      license = lib.licenses.agpl3Plus;
      mainProgram = "concat-mcp";
    };
  };
in
{
  options.my.concat-mcp.enable = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = "Concat MCP bridge (stdio server wrapping Concat's JSON-RPC socket) for OpenCode/LLM clients.";
  };

  config = lib.mkIf config.my.concat-mcp.enable {
    environment.systemPackages = [ concat-mcp ];

    my.mcp.servers.concat = {
      command = [ "/run/current-system/sw/bin/concat-mcp" ];
      enabled = config.my.mcp.concat.enable;
    };
  };
}
