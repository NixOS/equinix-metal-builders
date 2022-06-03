(import ../make-netboot.nix)
{
  buildSystem = "x86_64-linux";
  hardware = { pkgs, ... }: {
    nixpkgs.system = "x86_64-linux";
    imports = [
      ./c3.medium.x86.nix
      ./m3.large.x86.nix
    ];

    nix = {
      gbFree = 100;
      features = [ "kvm" "nixos-test" ];
      systemTypes = [ "x86_64-linux" "i686-linux" ];
    };

    specialisation = {
      "c3.medium.x86".configuration = {
        favorability = 80;
        nix = {
          maxJobs = 24;
          buildCores = 2;
          makeAbout = true;
        };
      };

      "c3.medium.x86--big-parallel".configuration = {
        favorability = 20;
        nix = {
          maxJobs = 2;
          buildCores = 24;
          makeAbout = true;
          features = [ "big-parallel" ];
        };
      };

      "m3.large.x86".configuration = {
        favorability = 80;
        nix = {
          maxJobs = 32;
          buildCores = 2;
          makeAbout = true;
        };
      };

      "m3.large.x86--big-parallel".configuration = {
        favorability = 20;
        nix = {
          maxJobs = 2;
          buildCores = 32;
          makeAbout = true;
          features = [ "big-parallel" ];
        };
      };
    };
  };
}
