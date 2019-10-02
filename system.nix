{ config, pkgs, lib, ... }:
let
  post-device-cmds = pkgs.writeScript "post-device-commands"
    ''
      #!/bin/sh

      set -eux
      set -o pipefail

      ${pkgs.utillinux}/bin/lsblk -d -e 1,7,11,230 -o NAME -n \
        | ${pkgs.busybox}/bin/sed -e "s#^#/dev/#" \
        | ${pkgs.busybox}/bin/xargs ${pkgs.zfs}/bin/zpool \
            create -f \
                -O mountpoint=none \
                -O atime=off \
                -O compression=lz4 \
                -O xattr=sa \
                -O acltype=posixacl \
                -O relatime=on \
                -o ashift=12 \
                rpool

      ${pkgs.zfs}/bin/zfs create -o mountpoint=legacy rpool/root

    '';
in {
  boot.supportedFilesystems = [ "zfs" ];
  boot.initrd.postDeviceCommands = "${post-device-cmds}";

  nixpkgs.config.allowUnfree = true;
  hardware.enableAllFirmware = true;
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

  systemd.services.metadata-setup-ipv6 = {
    wantedBy = [ "multi-user.target" ];
    path = with pkgs; [ iproute curl jq ];
    serviceConfig = {
      Type = "simple";
      Restart = "on-failure";
      RestartSec = "5s";
    };
    script = ''
      set -eux
      set -o pipefail

      defaultDevice=$(ip route get 4.2.2.2 | head -n1 | cut -d' ' -f5)
      eval "$(curl https://metadata.packet.net/metadata \
        | jq -r '
          .network.addresses[]
            | select(.address_family == 6)
            | "ip -6 addr add " + .address + "/" + (.cidr | tostring) + " dev " + $device + "; ip -6 route replace " + .address + " dev " + $device + " proto static; ip -6 route replace default via " + .gateway + " dev " + $device + " proto static"' --arg device "$defaultDevice")"
    '';
  };
}
