{
  config,
  lib,
  pkgs,
  ...
}:
{
  options.my.ollama.enable = lib.mkEnableOption "Ollama with the Vulkan backend." // {
    default = true;
  };

  config = lib.mkIf config.my.ollama.enable {
    environment.systemPackages = [ pkgs.ollama-vulkan ];
  };
}
