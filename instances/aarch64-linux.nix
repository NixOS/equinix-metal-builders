(import ../make-netboot.nix)
{
  buildSystem = "aarch64-linux";
  hardware = { lib, pkgs, ... }: {
    nixpkgs.system = "aarch64-linux";
    imports = [
      ./c3.large.arm.nix
    ];

    nix = {
      gbFree = 100;
      features = [ "kvm" "nixos-test" ];
      systemTypes = [ "aarch64-linux" ];
    };

    specialisation = {
      "c3.large.arm".configuration = {
        nix = {
          maxJobs = 40;
          buildCores = 2;
        };
      };

      "c3.large.arm--big-parallel".configuration = {
        nix = {
          maxJobs = 4;
          # cores is used for make's -j and -l, meaning we leave a lot of performance on the table by dividing 80 cores by 4
          buildCores = 80;
          features = [ "big-parallel" ];
        };
      };
    };
  };
}
