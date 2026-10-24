{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  helium = pkgs.callPackage ./package.nix { heliumPin = inputs.helium-pin; };
in
{
  options.my.helium.enable = lib.mkEnableOption "Helium browser." // {
    default = true;
  };

  config = lib.mkIf config.my.helium.enable {
    programs.chromium = {
      enable = true;
      extensions = [
        "ghmbeldphafepmbegfdlkpapadhbakde"
      ];
    };

    environment = {
      systemPackages = [ helium ];

      sessionVariables = {
        DEFAULT_BROWSER = lib.getExe helium;
        BROWSER = lib.getExe helium;
      };
    };

    home-manager.users.ackerman.xdg.configFile."net.imput.helium/WidevineCdm/latest-component-updated-widevine-cdm".text =
      builtins.toJSON {
        Path = "${pkgs.widevine-cdm}/share/google/chrome/WidevineCdm";
      };

    xdg.mime.defaultApplications = {
      "text/html" = "helium.desktop";
      "x-scheme-handler/http" = "helium.desktop";
      "x-scheme-handler/https" = "helium.desktop";
      "x-scheme-handler/discord" = "vesktop.desktop";
    };
  };
}
