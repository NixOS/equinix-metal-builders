{ config, lib, pkgs, ... }:

let
  cfg = config.packet-nix-builder.armv7;

  inherit (lib) mkIf mkEnableOption;
in

{
  options = {
    packet-nix-builder.armv7 = {
      enable = mkEnableOption "Enable armv7l build vm";
    };
  };

  config = mkIf cfg.enable {
    users.users.armv7-builder = {
      isSystemUser = true;
    };

    # Relocate host service's ports
    services.prometheus.exporters.node.port = 9101;
    services.openssh.ports = [ 2200 ] ;
    # Open these ports for our VM's services
    networking.firewall.allowedTCPPorts = [ 22 9100 ];

    services.managedVMs.armv7 = {
      machine = "virt,highmem=off,gic-version=3";
      cpu = "host,aarch64=off";
      smp = 16;
      mem = "32g";
      rootFilesystemSize = "128g";
      forwardPorts = [
        { hostPort = 22; vmPort = 22; protocol = "tcp"; }
        { hostPort = 9100; vmPort = 9100; protocol = "tcp"; }
      ];
      user = "armv7-builder";
      config = { pkgs, ... }: {
        imports = [
          ./user.nix
          ./services.nix
        ];

        nixpkgs.system = "aarch64-linux";
        nixpkgs.crossSystem = { system = "armv7l-linux"; };

        swapDevices = [
          { device = "/var/swapfile"; size = 8192; }
        ];

        boot.kernelPackages = pkgs.linuxPackages_latest;

        boot.kernelPatches = [
          {
            name = "enable-lpae";
            patch = null;
            extraConfig = ''
              ARM_LPAE y
            '';
          }
        ];
        systemd.tmpfiles.rules = [
          "d '/run/state/ssh' - root - - -"
        ];

        systemd.services.export-host-key = {
          wantedBy = [ "multi-user.target" ];
          path = with pkgs; [ utillinux ];
          serviceConfig = {
            Type = "simple";
            Restart = "on-failure";
            RestartSec = "5s";
          };
          script = ''
            set -eux
            set -o pipefail

            if [ ! -f /etc/ssh/ssh_host_ed25519_key.pub ]; then
              exit 1
            fi

            cp /etc/ssh/ssh_host_ed25519_key.pub /run/state/ssh
          '';
        };
      };
    };

    packet-nix-builder.hostKeys = [{
      system = "armv7l-linux";
      port = 22;
      keyFile = "/var/lib/vm-armv7/ssh/ssh_host_ed25519_key.pub";
    }];

  };
}
