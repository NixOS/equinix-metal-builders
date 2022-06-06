{ buildSystem, hardware }:
let
  pkgs = import <nixpkgs> { system = buildSystem; };
  makeNetboot = config:
    let
      tmpfsroot = { pkgs, ... }:
        {
          boot.kernelParams = [ "nonroot_initramfs" ];
          boot.kernelPatches = [
            {
              name = "nonroot_initramfs";

              # Linux upstream unpacks the initramfs in to the rootfs directly. This breaks
              # pivot_root which breaks Nix's process of setting up the build sandbox. This
              # Nix uses pivot_root even when the sandbox is disabled.
              #
              # This patch has been upstreamed by Ignat Korchagin <ignat@cloudflare.com> before,
              # then updated by me and upstreamed again here:
              #
              # https://lore.kernel.org/all/20210914170933.1922584-2-graham@determinate.systems/T/#m433939dc30c753176404792628b9bcd64d05ed7b
              #
              # It is available on my Linux fork on GitHub:
              # https://github.com/grahamc/linux/tree/v5.15-rc1-nonroot-initramfs
              #
              # If this patch stops applying it should be fairly easy to rebase that
              # branch on future revisions of the kernel. If it stops being easy to
              # rebase, we can stop building our own kernel and take a slower approach
              # instead, proposed on the LKML: as the very first step in our init:
              #
              # 1. create a tmpfs at /root
              # 2. copy everything in / to /root
              # 3. switch_root to /root
              #
              # This takes extra time as it will need to copy everything, and it may use
              # double the memory. Unsure. Hopefully this patch is merged or applies
              # easily forever.
              patch = pkgs.fetchpatch {
                name = "nonroot_initramfs";
                url = "https://github.com/grahamc/linux/commit/65d2e9daeb2c849ad5c73f587604fec24c5cce43.patch";
                sha256 = "sha256-ERzjkick0Kzq4Zxgp6f7a+oiT3IbL05k+c9P+MdMi+h=";
              };
            }
          ];
        };

      config_evaled = import (pkgs.path + "/nixos") {
        configuration = { pkgs, ... }: {
          imports = [ config tmpfsroot ];

          fileSystems."/" = {
            device = "/dev/bogus";
            fsType = "ext4";
          };
          boot.loader.grub.enable = false;

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

  users.users.root.password = "foobar";
})
