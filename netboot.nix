# Fetched from https://github.com/NixOS/nixpkgs/blob/e4837acf21f891f7f28196adcb94345dd8fec677/nixos/modules/installer/netboot/netboot.nix
# on 2019-07-23, and originally checked in to this repository in commit
# 1e51806 with no applied changes. git diff against that revision to
# see what we've done.
#------------
# This module creates netboot media containing the given NixOS
# configuration.

{ config, lib, pkgs, ... }:

with lib;

{
  options = {

    netboot.storeContents = mkOption {
      example = literalExample "[ pkgs.stdenv ]";
      description = ''
        This option lists additional derivations to be included in the
        Nix store in the generated netboot image.
      '';
    };

  };

  config = rec {
    # Don't build the GRUB menu builder script, since we don't need it
    # here and it causes a cyclic dependency.
    boot.loader.grub.enable = false;

    # !!! Hack - attributes expected by other modules.
    environment.systemPackages = [ pkgs.grub2_efi ]
      ++ (if pkgs.stdenv.hostPlatform.system == "aarch64-linux"
          then []
          else [ pkgs.grub2 pkgs.syslinux ]);

    fileSystems."/" = {
      fsType = "zfs";
      device = "rpool/root";
    };

    fileSystems."/squash-nix-store" =
      { fsType = "squashfs";
        device = "../nix-store.squashfs";
        options = [ "loop" ];
        neededForBoot = true;
      };

    boot.initrd.postMountCommands = ''
      mkdir -p $targetRoot/nix
      cp -r $targetRoot/squash-nix-store $targetRoot/nix/store
    '';

    boot.initrd.availableKernelModules = [ "squashfs" ];

    boot.initrd.kernelModules = [ "loop" ];

    # Closures to be copied to the Nix store, namely the init
    # script and the top-level system configuration directory.
    netboot.storeContents =
      [ config.system.build.toplevel ];

    # Create the squashfs image that contains the Nix store.
    system.build.squashfsStore = pkgs.callPackage "${pkgs.path}/nixos/lib/make-squashfs.nix" {
      storeContents = config.netboot.storeContents;
    };


    # Create the initrd
    system.build.netbootRamdisk = pkgs.makeInitrd {
      inherit (config.boot.initrd) compressor;
      prepend = [ "${config.system.build.initialRamdisk}/initrd" ];

      contents =
        [ { object = config.system.build.squashfsStore;
            symlink = "/nix-store.squashfs";
          }
        ];
    };

    system.build.netbootIpxeScript = pkgs.writeTextDir "netboot.ipxe" ''
      #!ipxe
      kernel ${pkgs.stdenv.hostPlatform.platform.kernelTarget} init=${config.system.build.toplevel}/init initrd=initrd ${toString config.boot.kernelParams}
      initrd initrd
      boot
    '';

    boot.loader.timeout = 10;

    boot.postBootCommands =
      ''
        # After booting, register the contents of the Nix store
        # in the Nix database in the tmpfs.
        ${config.nix.package}/bin/nix-store --load-db < /nix/store/nix-path-registration

        # nixos-rebuild also requires a "system" profile and an
        # /etc/NIXOS tag.
        touch /etc/NIXOS
        ${config.nix.package}/bin/nix-env -p /nix/var/nix/profiles/system --set /run/current-system
      '';

  };

}
