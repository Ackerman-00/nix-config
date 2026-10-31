{
  config,
  lib,
  ...
}:
{
  options.my.cloudflareWarp = {
    enable =
      lib.mkEnableOption ''
        Cloudflare WARP. After the first switch run `warp-cli registration
        new`, then `warp-cli connect`. Verify with
        `curl https://www.cloudflare.com/cdn-cgi/trace`: it must print
        `warp=on`.
      ''
      // {
        default = true;
      };
  };

  config = {
    networking = {
      hostName = "quietcraft";
      networkmanager.enable = true;
    };

    services.cloudflare-warp = {
      enable = config.my.cloudflareWarp.enable;
      openFirewall = false;
    };

    assertions = [
      {
        assertion =
          config.networking.firewall.allowedTCPPorts == [ ]
          && config.networking.firewall.allowedUDPPorts == [ ]
          && config.networking.firewall.allowedTCPPortRanges == [ ]
          && config.networking.firewall.allowedUDPPortRanges == [ ];
        message = "network: an enabled service opened an inbound port; set its openFirewall option to false, or change this assertion on purpose";
      }
    ];
  };
}
