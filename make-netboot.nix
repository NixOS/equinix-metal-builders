{ buildSystem, hardware }:
let
  pkgs = import <nixpkgs> { system = buildSystem; };
  makeNetboot = config:
    let
      config_evaled = import "${pkgs.path}/nixos/lib/eval-config.nix" {
        modules = [
          config
        ];
      };
      build = config_evaled.config.system.build;
      kernelTarget = config_evaled.pkgs.stdenv.hostPlatform.linux-kernel.target;
    in
    pkgs.runCommand "netboot" { } ''
      mkdir $out
      ln -s ${build.netbootRamdisk}/initrd $out/
      ln -s ${build.kernel}/${kernelTarget} $out/
      ln -s ${build.netbootIpxeScript}/netboot.ipxe $out/
    '';
in
makeNetboot ({
  imports = [
    hardware
    ./user.nix
    ./services.nix
    ./nix.nix
    ./system.nix
    ./netboot.nix
    ./managed-vm.nix
    ./armv7.nix
  ];
})
