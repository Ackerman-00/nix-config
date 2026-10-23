# Network
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
      openFirewall = true;
    };
  };
}
