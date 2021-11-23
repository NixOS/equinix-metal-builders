{
  nixpkgs.system = "aarch64-linux";
  boot = {
    kernelParams = [
      "console=ttyAMA0"
      "initrd=initrd"
    ];
    initrd = {
      availableKernelModules = [
        "xhci_pci"
        "nvme"
      ];
    };
  };
}
