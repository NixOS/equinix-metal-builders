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
        favorability = 50;
        nix = {
          maxJobs = 40;
          buildCores = 2;
          makeAbout = true;
        };
      };

      "c3.large.arm--big-parallel".configuration = {
        favorability = 50;
        nix = {
          maxJobs = 4;
          # cores is used for make's -j and -l, meaning we leave a lot of performance on the table by dividing 80 cores by 4
          buildCores = 80;
          makeAbout = true;
          features = [ "big-parallel" ];
        };
      };
    };
  };
}
