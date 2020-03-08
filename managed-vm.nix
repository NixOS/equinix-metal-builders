{ config, lib, pkgs, ... }:

let
  managedVMConfig = { config, lib, pkgs, modulesPath, ... }: {
    imports = [
      (modulesPath + "/profiles/qemu-guest.nix")
    ];

    config = {
      boot.loader.grub.enable = false;

      boot.kernelParams = [ "console=ttyAMA0,115200" ];

      system.build.tarStore = pkgs.callPackage ./tar-store.nix {
        storeContents = [ config.system.build.toplevel ];
      };

      fileSystems = {
        "/" = {
          device = "/dev/disk/by-id/virtio-scratch";
          fsType = "ext4";
        };

        "/run/state" = {
          device = "state";
          fsType = "9p";
          options = [ "trans=virtio" "version=9p2000.L" "cache=loose" ];
        };
      };

      boot.initrd.extraUtilsCommands = ''
        copy_bin_and_libs ${pkgs.xz}/bin/xz
        copy_bin_and_libs ${pkgs.e2fsprogs}/bin/mke2fs
      '';

      boot.initrd.postDeviceCommands = ''
        mke2fs -t ext4 -L scratch /dev/disk/by-id/virtio-scratch
      '';

      boot.initrd.postMountCommands = ''
        mkdir -p $targetRoot/etc
        echo -n > $targetRoot/etc/NIXOS

        echo "Extracting initial store"
        mkdir -p $targetRoot/nix
        xz -d -T0 < /dev/disk/by-id/virtio-store | time tar -C $targetRoot -x
      '';

      boot.postBootCommands = ''
        # After booting, register the contents of the Nix store
        # in the Nix database in the scratch drive.
        ${config.nix.package}/bin/nix-store --load-db < /nix/store/nix-path-registration
      '';

      # Pretty heavy dependency for a vm
      services.udisks2.enable = false;
    };
  };

  minimalConfig = {
    programs.command-not-found.enable = false;
    security.polkit.enable = false;
    services.udisks2.enable = false;
    documentation.enable = false;
    environment.noXlibs = true;
  };

  mkManagedVM = configuration: (import (pkgs.path + "/nixos")) {
    inherit configuration;
  };
in

let
  inherit (lib)
    mkMerge flip mapAttrsToList mkOption concatStringsSep types makeBinPath
    optionalString optionals;

  managedVMConfigType = types.submodule {
    options = {
      cpu = mkOption {
        type = types.str;
        description = "QEMU -cpu option";
        default = "host";
        example = "host,aarch64=off";
      };

      machine = mkOption {
        type = types.str;
        description = "QEMU -machine option";
        default = "virt";
        example = "virt,highmem=off,gic-version=3";
      };

      smp = mkOption {
        type = types.either types.int types.str;
        description = "QEMU -smp option";
        default = 1;
        example = 16;
      };

      mem = mkOption {
        type = types.str;
        description = "QEMU -mem option";
        default = "1g";
        example = "8g";
      };

      minimal = mkOption {
        type = types.bool;
        description = "Minimize build packages and dependencies";
        default = true;
        example = false;
      };

      # TODO: what is the type of nixos config?
      config = mkOption {
        description = "NixOS configuration for the VM";
        default = {};
      };

      consolePort = mkOption {
        type = types.nullOr types.port;
        default = null;
      };

      rootFilesystemSize = mkOption {
        description = "Size of root filesystem, allocated with qemu-img";
        type = types.str;
        example = "128g";
        default = "4g";
      };

      forwardPorts = mkOption {
        type = types.listOf (types.submodule {
          options = {
            hostPort = mkOption {
              type = types.port;
            };

            vmPort = mkOption {
              type = types.port;
            };

            protocol = mkOption {
              type = types.enum [ "tcp" "udp" ];
            };
          };
        });
        default = [];
      };
    };
  };
in

{
  options = {
    services.managedVMs = mkOption {
      default = {};
      type = types.attrsOf managedVMConfigType;
    };
  };

  config = {
    systemd.services = mkMerge (flip mapAttrsToList config.services.managedVMs (name: cfg:
      let
        vmNixos = mkManagedVM {
          imports = [ managedVMConfig cfg.config ] ++ optionals cfg.minimal [ minimalConfig ];
        };
        vmConfig = vmNixos.config;
        kernelTarget = vmNixos.pkgs.stdenv.hostPlatform.platform.kernelTarget;

        netdev = concatStringsSep "," (
          [ "user" "id=user.0" ] ++
          (flip map cfg.forwardPorts ({ protocol, vmPort, hostPort, ... }:
            "hostfwd=${protocol}:0.0.0.0:${toString hostPort}-:${toString vmPort}"
          )));
      in {
        "vm@${name}" = {
          wantedBy = [ "multi-user.target" ];
          script = ''
            set -euo pipefail

            export PATH=${makeBinPath [ pkgs.qemu_kvm ]}:$PATH

            : ''${STATEDIR:=/var/lib/vm-${name}}
            : ''${TMPDIR:=/tmp}

            qemu-img create -f qcow2 $TMPDIR/scratch.qcow2 ${cfg.rootFilesystemSize}

            serial=""
            ${optionalString (cfg.consolePort != null) ''
              if ! [ -t 1 ]; then
                serial="telnet:localhost:${toString cfg.consolePort},server,nowait"
              fi
            ''}

            if [ -z "$serial" ]; then
              serial="chardev:char0"
            fi

            exec qemu-system-${pkgs.stdenv.hostPlatform.qemuArch} \
              -kernel ${vmConfig.system.build.kernel}/${kernelTarget} \
              -initrd ${vmConfig.system.build.initialRamdisk}/initrd \
              -append "init=${vmConfig.system.build.toplevel}/init ${toString vmConfig.boot.kernelParams}" \
              -machine ${cfg.machine} -cpu ${cfg.cpu} -smp ${toString cfg.smp} \
              -m ${cfg.mem} -enable-kvm \
              -nographic \
              -device virtio-rng-pci \
              -drive if=none,id=hd0,file=${vmConfig.system.build.tarStore},format=raw,readonly, \
              -device virtio-blk-pci,drive=hd0,serial=store \
              -drive if=none,id=hd1,file=$TMPDIR/scratch.qcow2,format=qcow2,werror=report,cache.direct=on,cache=unsafe,aio=native \
              -device virtio-blk-pci,drive=hd1,serial=scratch \
              -fsdev local,id=state,path=$STATEDIR,security_model=none \
              -device virtio-9p-pci,fsdev=state,mount_tag=state \
              -net nic,netdev=user.0,model=virtio \
              -netdev ${netdev} \
              -chardev stdio,mux=on,id=char0 \
              -mon chardev=char0,mode=readline \
              -serial "$serial" \
              "''${extra_args[@]}"
          '';

          serviceConfig = {
            StateDirectory = "vm-%i";
            Type = "simple";
            PrivateTmp = true;
          };
        };
      }
    ));
  };
}
