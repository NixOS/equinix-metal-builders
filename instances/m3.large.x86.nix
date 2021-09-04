{
  nixpkgs.system = "x86_64-linux";
  boot.kernelParams = [ "console=ttyS1,115200n8" "initrd=initrd" ];
  boot.initrd.availableKernelModules = [ "mpt3sas" "xhci_pci" "nvme" "ahci" "sd_mod" ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-amd" ];
  boot.extraModulePackages = [ ];
}
