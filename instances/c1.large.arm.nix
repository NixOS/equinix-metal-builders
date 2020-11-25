{ pkgs, ... }: {
  nixpkgs.system = "aarch64-linux";
  boot = {
    kernelPackages = pkgs.linuxPackages_4_19;
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
