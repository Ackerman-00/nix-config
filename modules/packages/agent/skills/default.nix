# Agent skills
{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
let
  cfg = config.my.skills;
  homeDirectory = config.users.users.ackerman.home;
  hm = inputs.home-manager.lib;

  # Store copies
  artifacts = pkgs.callPackage ./package.nix { inherit lib; };
  overrides = "${artifacts}/overrides";

  mapFile = "${artifacts}/upstream-map.json";
  seedFile = "${artifacts}/state-seed.json";
  lockFile = "${artifacts}/skill-lock.json";
in
{
  options.my.skills = {
    enable = lib.mkEnableOption "Refresh the agent skills from their upstreams on rebuild." // {
      default = true;
    };

    excluded = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "best-practices"
        "heygen-avatar"
        "heygen-translate"
        "heygen-video"
        "web-quality-audit"
      ];
      description = ''
        Skills that must never be fetched again. They were removed from this
        machine on purpose: the HeyGen ones because the service is paid, the
        web-quality ones because that upstream pair was dropped. The refresh
        skips them, so they cannot come back.
      '';
    };

    refresh = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Fetch the upstream skills during the Home Manager activation. Turning
        this off keeps the network out of the rebuild; the local copies are
        still restored, see `my.skills.restore`.
      '';
    };

    restore = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Put the local copies back into the two skill trees during the Home
        Manager activation. This has nothing to do with the network, so it
        works with `my.skills.refresh` turned off.
      '';
    };

    deadline = lib.mkOption {
      type = lib.types.int;
      default = 1200;
      description = ''
        Wall clock budget of the upstream refresh, in seconds. When it is
        spent the refresh stops, leaves the repos it did not reach uncached
        and the activation still succeeds.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    # Clone time
    systemd.services.home-manager-ackerman.serviceConfig.TimeoutStartSec = lib.mkForce "45min";

    home-manager.users.ackerman.home = {
      file = {
        ".local/share/agent-skills/skill-lock.json".source = "${lockFile}";
        ".local/share/agent-skills/upstream-map.json".source = "${mapFile}";
      };

      # Writes the live tree
      activation.agent-skills =
        hm.hm.dag.entryAfter
          [
            "writeBoundary"
            "linkGeneration"
            "hyperframes-skills"
          ]
          (
            import ./activation.nix {
              refreshScript = ./refresh.mjs;
              excludedSkills = cfg.excluded;
              runRefresh = cfg.refresh;
              runRestore = cfg.restore;
              refreshDeadline = cfg.deadline;
              inherit
                lib
                pkgs
                homeDirectory
                mapFile
                seedFile
                overrides
                ;
            }
          );
    };
  };
}
