{ lib, config, ... }:
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
