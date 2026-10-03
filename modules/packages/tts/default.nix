# TTS (text-to-speech) Python packages for AI video editing workflows.
# Libs go to the single interpreter via `my.python.packages`
# (python-env.nix builds it); the CLI wrappers below reuse that
# interpreter and only add their bins (no bin/python collision).
{
  config,
  lib,
  pkgs,
  ...
}:

{
  options.my.tts.enable = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = "TTS Python packages for AI video editing.";
  };

  config = lib.mkIf config.my.tts.enable {
    environment.systemPackages = with pkgs; [
      python3Packages.gtts
      python3Packages.edge-tts
    ];

    my.python.packages = [
      "gtts"
      "edge-tts"
    ];
  };
}
