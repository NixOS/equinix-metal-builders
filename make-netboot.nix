let
  pkgs  = import <nixpkgs> { };
  makeNetboot = config:
    let
      config_evaled = import "${pkgs.path}/nixos/lib/eval-config.nix" {
        modules = [
          config
        ];
      };
      build = config_evaled.config.system.build;
      kernelTarget = config_evaled.pkgs.stdenv.platform.kernelTarget;
    in pkgs.runCommand "netboot" {} ''
      mkdir $out
      ln -s ${build.netbootRamdisk}/initrd $out/
      ln -s ${build.kernel}/${kernelTarget} $out/
      ln -s ${build.netbootIpxeScript}/netboot.ipxe $out/
    '';
in machineConfig: makeNetboot ({
  imports = [
    machineConfig
    ./user.nix
    ./system.nix
    ./netboot.nix
  ];
})
