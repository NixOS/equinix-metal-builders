{ buildSystem, hardware }:
let
  pkgs = import <nixpkgs> { system = buildSystem; };
  makeNetboot = config:
    let
      config_evaled = import "${pkgs.path}/nixos" {
        configuration = { pkgs, ... }: {
          imports = [ config ];

          fileSystems."/" = {
            device = "/dev/bogus";
            fsType = "ext4";
          };
          boot.loader.grub.devices = [ "/dev/bogus" ];

          boot.initrd.availableKernelModules = [ "virtio_net" "virtio_pci" "virtio_mmio" "virtio_blk" "virtio_scsi" "9p" "9pnet_virtio" ];
          boot.initrd.kernelModules = [ "virtio_balloon" "virtio_console" "virtio_rng" ];
          boot.initrd.supportedFilesystems = [ "9p" ];


          boot.postBootCommands = ''
            PATH=${pkgs.nix}/bin /nix/.nix-netboot-serve-db/register
          '';

          systemd.services.add-disks-to-swap = {
            wantedBy = [ "multi-user.target" ];
            serviceConfig = {
              Type = "simple";
              Restart = "on-failure";
              RestartSec = "5s";
            };
            unitConfig = {
              X-ReloadIfChanged = false;
              X-RestartIfChanged = false;
              X-StopIfChanged = false;
              X-StopOnReconfiguration = false;
              X-StopOnRemoval = false;
            };
            script = ''
              set -eux
              ${pkgs.kmod}/bin/modprobe raid0
              echo 2 > /sys/module/raid0/parameters/default_layout
              ${pkgs.util-linux}/bin/lsblk -d -e 1,7,11,230 -o PATH -n | ${pkgs.findutils}/bin/xargs ${pkgs.mdadm}/bin/mdadm /dev/md/spill.decrypted --create --level=0 --force --raid-devices=$(${pkgs.util-linux}/bin/lsblk -d -e 1,7,11,230 -o PATH -n | ${pkgs.busybox}/bin/wc -l)
              ${pkgs.cryptsetup}/bin/cryptsetup -c aes-xts-plain64 -d /dev/random create spill.encrypted /dev/md/spill.decrypted

              ${pkgs.util-linux}/bin/mkswap /dev/mapper/spill.encrypted
              ${pkgs.util-linux}/bin/swapon /dev/mapper/spill.encrypted

              ${pkgs.util-linux}/bin/mount -o remount,size=$(${pkgs.util-linux}/bin/lsblk --noheadings --bytes --output SIZE /dev/mapper/spill.encrypted) /
          '';
          };
        };
      };
    in
    config_evaled.system;
in
makeNetboot ({
  imports = [
    hardware
    ./user.nix
    ./services.nix
    ./nix.nix
    ./system.nix
    #./netboot.nix
    ./managed-vm.nix
    ./armv7.nix
  ];
})
