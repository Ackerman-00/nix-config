{ pkgs, ... }:
{
  hardware = {
    enableAllFirmware = true;
    bluetooth.enable = true;
    cpu.amd.updateMicrocode = true;
    graphics = {
      enable = true;
      enable32Bit = true;
      extraPackages = with pkgs; [
        mesa.opencl
      ];
    };
  };
}
