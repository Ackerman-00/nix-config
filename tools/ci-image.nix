let
  flake = builtins.getFlake "/etc/nixos";
  system = flake.nixosConfigurations.quietcraft.extendModules {
    modules = [ "${flake.inputs.nixpkgs}/nixos/modules/virtualisation/docker-image.nix" ];
  };
in
system.config.system.build.tarball
