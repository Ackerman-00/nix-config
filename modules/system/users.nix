{ pkgs, ... }:
{
  users.users.ackerman = {
    isNormalUser = true;
    description = "Quietcraft";
    extraGroups = [
      "networkmanager"
      "wheel"
      "video"
      "input"
      "gamemode"
    ];
    shell = pkgs.zsh;
  };
}
