# For a m2.xlarge.x86
{
  nixpkgs.system = "x86_64-linux";
  boot = {
    kernelModules = ["kvm-amd" ];
    kernelParams = [ "console=ttyS1,115200n8" "initrd=initrd" ];
    initrd = {
      availableKernelModules = [
        "xhci_pci" "ahci" "mpt3sas" "sd_mod"
      ];
    };
  };

  nix = {
    maxJobs = 28;
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
}
