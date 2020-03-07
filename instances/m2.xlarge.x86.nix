{
  nixpkgs.system = "x86_64-linux";
  boot = {
    kernelModules = [ "kvm-intel" ];
    kernelParams = [ "console=ttyS1,115200n8" "initrd=initrd" ];
    initrd = {
      availableKernelModules = [
        "ahci" "xhci_pci" "mpt3sas" "nvme" "sd_mod"
      ];
    };
  };
}
