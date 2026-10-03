{
  config,
  lib,
  pkgs,
  ...
}:
{
  options.my.kankan.enable = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = "Build and packaging tools for the Kankan manga translator (Rust GUI).";
  };

  config = lib.mkIf config.my.kankan.enable {
    environment.systemPackages = with pkgs; [
      appimage-run
      cmake
      gnumake
      patchelf
      squashfs-tools
      llvmPackages.libclang.lib
    ];
  };
}
