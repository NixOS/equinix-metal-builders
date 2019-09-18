(import ../make-netboot.nix)
{
  buildSystem = "aarch64-linux";
  hardware = { pkgs, ... }: {
    nixpkgs.system = "aarch64-linux";
    boot = {
      kernelParams = [
        "cma=0M" "biosdevname=0" "net.ifnames=0" "console=ttyAMA0"
        "initrd=initrd"
      ];
      initrd = {
        availableKernelModules = [
          "ahci" "pci_thunder_ecam"
        ];
      };
    };

    nix = {
      maxJobs = 16;
      buildCores = 2;
      gc.options = let
        gbFree = 100;
      in ''--max-freed "$((${toString gbFree} * 1024**3 - 1024 * $(df -P -k /nix/store | tail -n 1 | ${pkgs.gawk}/bin/awk '{ print $4 }')))"'';

      /*
      # Buggy as of 2019-08-01 https://nix-cache.s3.amazonaws.com/log/5gkp2g9l56hy9jzdl6qmrxgmjp7sz36z-rustc-1.36.0.drv
      # If we drop below 40G, free 100G
      extraOptions = ''
        min-free = ${toString (40*1024*1024*1024)}
        max-free = ${toString (100*1024*1024*1024)}
      '';
      */
    };
  };
}
