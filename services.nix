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

  networking.firewall.allowedTCPPorts = [ 9100 ];
  services.prometheus.exporters.node = {
    enable = true;
    enabledCollectors = [ "systemd" ];
  };
}
