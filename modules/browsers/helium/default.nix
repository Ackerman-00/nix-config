# Helium browser, policies, mime, default-browser wiring.
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
  options.my.helium.enable = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = "Helium browser.";
  };

  config = lib.mkIf config.my.helium.enable {
    programs.chromium = {
      enable = true;
      extensions = [
        "ghmbeldphafepmbegfdlkpapadhbakde" # Proton Pass
      ];
    };

    environment = {
      systemPackages = [ helium ];

      sessionVariables = {
        DEFAULT_BROWSER = lib.getExe helium;
        BROWSER = lib.getExe helium;
      };
    };

    # Widevine CDM comes from nixpkgs, not the tarball.
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
