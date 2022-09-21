{ config, lib, pkgs, ... }:
let
  inherit (lib) mapAttrs mkOption types optionals concatStringsSep
    mapAttrsToList mkEnableOption mkIf mkMerge;

  about = pkgs.writeText "about.json" (builtins.toJSON {
    features = config.nix.features;
    system_types = config.nix.systemTypes;
    max_jobs = config.nix.maxJobs;
  });
in
{
  options = {
    nix = {
      gbFree = mkOption {
        description = "Number of GB to keep free.";
        type = types.int;
      };

      systemTypes = mkOption {
        description = "List of systems this machine can build";
        type = types.listOf types.str;
      };

      features = mkOption {
        description = "List of features this machine supports";
        type = types.listOf types.str;
      };
    };
  };

  config = {
    systemd.services.nix-daemon.serviceConfig.LimitNOFILE = lib.mkForce 1048576;
    nix.gc.options = ''--max-freed "$((${toString config.nix.gbFree} * 1024**3 - 1024 * $(df -P -k /nix/store | tail -n 1 | ${pkgs.gawk}/bin/awk '{ print $4 }')))"'';
    system.extraSystemBuilderCmds = ''
      cp ${about} $out/about.json
    '';
  };
}
