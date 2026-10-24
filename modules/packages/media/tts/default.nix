{
  config,
  lib,
  pkgs,
  ...
}:

{
  options.my.tts.enable = lib.mkEnableOption "TTS Python packages for AI video editing." // {
    default = true;
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
