# Firefox: browser + policies (policies.json only materializes with enable).
{
  config,
  lib,
  ...
}:
{
  options.my.firefox.enable = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = "Firefox browser.";
  };

  config = lib.mkIf config.my.firefox.enable {
    programs.firefox = {
      enable = true; # also installs the wrapped build (policies baked in)

      # VA-API decode on AMD (wiki: Accelerated Video Playback, FF >= 137).
      preferences = {
        "media.hardware-video-decoding.force-enabled" = true;
      };

      policies = {
        DisableTelemetry = true;
        DisableFirefoxStudies = true;
        OfferToSaveLogins = false; # Proton Pass handles logins

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
