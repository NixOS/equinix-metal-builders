{
  nixpkgs.system = "x86_64-linux";
  boot = {
    kernelModules = [ "kvm-amd" ];
    kernelParams = [ "console=ttyS1,115200n8" "initrd=initrd" ];
    initrd = {
      availableKernelModules = [
        "xhci_pci" "ahci" "mpt3sas" "sd_mod"
      ];
    };
  };
}
