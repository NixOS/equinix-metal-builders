{
  nixpkgs.system = "x86_64-linux";
  boot = {
    kernelModules = [ "kvm-intel" ];
    kernelParams = [ "console=ttyS1,115200n8" "initrd=initrd" ];
    initrd = {
      availableKernelModules = [
        "xhci_pci" "ehci_pci" "ahci" "megaraid_sas" "sd_mod"
      ];
    };
  };
}
