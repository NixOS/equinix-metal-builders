{ config, pkgs, lib, ... }:
let
  post-device-cmds = pkgs.writeScript "post-device-commands"
    ''
      #!/bin/sh

      set -eux
      set -o pipefail

      ${pkgs.utillinux}/bin/lsblk -d -e 1,7,11 -o NAME -n \
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
  nix.gc.automatic = true;
}
