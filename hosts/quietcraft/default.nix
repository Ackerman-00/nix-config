{ inputs, ... }:
{
  imports = [
    "${inputs.local-hardware}"
    ../../modules
  ];

  system.stateVersion = "26.11";
}
