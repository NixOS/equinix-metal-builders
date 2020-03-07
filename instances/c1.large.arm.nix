{
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
}
