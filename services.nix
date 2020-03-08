{ lib, config, ... }:
{
  config = lib.mkMerge [
    {
      nixpkgs.config.allowUnfree = true;
      services.openssh.enable = true;

      networking.hostId = "00000000";
      nix = {
        nrBuildUsers = 100;
        gc = {
          automatic = true;
          dates = "*:0/30";
        };
      };

      networking.firewall.allowedTCPPorts = [ config.services.prometheus.exporters.node.port ];
      services.prometheus.exporters.node = {
        enable = true;
        enabledCollectors = [ "systemd" ];
      };
    }
    # start out with these weird ports, and when specializing, go
    # go the normal ports. Note: VM specializations override these
    # host settings. This is so that when switching to the VM hosts,
    # they can start without the existing SSH / prom settings
    # interfering. (Normal ports + 5 :P)
    (lib.mkIf (config.nix.makeAbout == false) {
      services.prometheus.exporters.node.port = lib.mkDefault 9105;
      services.openssh.ports = lib.mkDefault [ 27 ];
    })
    (lib.mkIf config.nix.makeAbout {
      services.prometheus.exporters.node.port = lib.mkDefault 9100;
      services.openssh.ports = lib.mkDefault [ 22 ];
    })
  ];
}
