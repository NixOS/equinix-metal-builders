(import ../make-netboot.nix)
{
  buildSystem = "aarch64-linux";
  hardware = {
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
      in "--max-freed $((${toString gbFree} * 1024**3 - 1024 * $(df -P -k /nix/store | tail -n 1 | awk '{ print $4 }')))";

      # If we drop below 40G, free 100G
      extraOptions = ''
        min-free = ${toString (40*1024*1024*1024)}
        max-free = ${toString (100*1024*1024*1024)}
      '';
    };
  };
}
