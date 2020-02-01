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

    boot.initrd.postMountCommands = ''
      echo "Extracting initial store"
      mkdir -p $targetRoot/nix
      xz -d -T0 < ../nix-store.tar.xz | time tar -C $targetRoot -x
    '';

    boot.initrd.extraUtilsCommands = ''
      copy_bin_and_libs ${pkgs.xz}/bin/xz
    '';

    system.build.tarStore = pkgs.callPackage ./tar-store.nix {
      # Closures to be copied to the Nix store, namely the init
      # script and the top-level system configuration directory.
      storeContents = [ config.system.build.toplevel ];
    };


    # Create the initrd
    system.build.netbootRamdisk = pkgs.makeInitrd {
      inherit (config.boot.initrd) compressor;
      prepend = [ "${config.system.build.initialRamdisk}/initrd" ];

      contents =
        [ { object = config.system.build.tarStore;
            symlink = "/nix-store.tar.xz";
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
