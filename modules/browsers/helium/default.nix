# Helium, vendored in-tree: tarball build (_package.nix) + policies, mime,
# default-browser wiring. Tarball reads /etc/chromium/policies natively.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  helium = pkgs.callPackage ./_package.nix { };
in
{
  options.my.helium.enable = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = "Helium browser.";
  };

  config = lib.mkIf config.my.helium.enable {
    # Policy files only, no browser install. Verify live via helium://policy.
    programs.chromium = {
      enable = true;
      extensions = [
        "ghmbeldphafepmbegfdlkpapadhbakde" # Proton Pass
        # Force-install more declaratively, e.g.:
        # "nngceckbapebfimnlniiiahkandclblb" # Bitwarden
        # "cjpalhdlnbpafiamejdnhcphjbkeiagm" # uBlock Origin
      ];
      # IDs = 32-char tail of the Chrome Web Store URL.
    };

    environment = {
      systemPackages = [ helium ];

      sessionVariables = {
        DEFAULT_BROWSER = lib.getExe helium;
        BROWSER = lib.getExe helium;
      };
    };

    # DRM: point Helium at nixpkgs Widevine CDM (Ly-sec's component trick).
    home-manager.users.ackerman.xdg.configFile."net.imput.helium/WidevineCdm/latest-component-updated-widevine-cdm".text =
      builtins.toJSON {
        Path = "${pkgs.widevine-cdm}/share/google/chrome/WidevineCdm";
      };

    xdg.mime.defaultApplications = {
      "text/html" = "helium.desktop";
      "x-scheme-handler/http" = "helium.desktop";
      "x-scheme-handler/https" = "helium.desktop";
      "x-scheme-handler/about" = "helium.desktop";
      "x-scheme-handler/unknown" = "helium.desktop";
      "x-scheme-handler/discord" = "vesktop.desktop";
    };
  };
}
