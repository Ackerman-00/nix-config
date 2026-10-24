{
  config,
  lib,
  ...
}:
{
  options.my.firefox.enable = lib.mkEnableOption "Firefox browser." // {
    default = false;
  };

  config = lib.mkIf config.my.firefox.enable {
    programs.firefox = {
      enable = true;

      preferences = {
        "media.hardware-video-decoding.force-enabled" = true;
      };

      policies = {
        DisableTelemetry = true;
        DisableFirefoxStudies = true;
        OfferToSaveLogins = false;

        ExtensionSettings = {
          "78272b6fa58f4a1abaac99321d503a20@proton.me" = {
            installation_mode = "force_installed";
            install_url = "https://addons.mozilla.org/firefox/downloads/latest/proton-pass/latest.xpi";
          };
          "uBlock0@raymondhill.net" = {
            installation_mode = "force_installed";
            install_url = "https://addons.mozilla.org/firefox/downloads/latest/ublock-origin/latest.xpi";
          };
        };
      };
    };
  };
}
