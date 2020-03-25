(import ../make-netboot.nix)
{
  buildSystem = "x86_64-linux";
  hardware = { pkgs, ... }: {
    nixpkgs.system = "x86_64-linux";
    imports = [
      ./c2.medium.x86.nix
      ./m1.xlarge.x86.nix
      ./m2.xlarge.x86.nix
    ];

    nix = {
      gbFree = 100;
      features = [ "kvm" "nixos-test" ];
      systemTypes = [ "x86_64-linux" "i686-linux" ];
    };

    specialisation = {
      "c2.medium.x86".configuration = {
        favorability = 100;
        nix = {
          maxJobs = 24;
          buildCores = 2;
          makeAbout = true;
        };
      };

      "m1.xlarge.x86".configuration = {
        favorability = 70;
        nix = {
          maxJobs = 24;
          buildCores = 2;
          makeAbout = true;
        };
      };
      "m1.xlarge.x86--big-parallel".configuration = {
        favorability = 30;
        nix = {
          maxJobs = 1;
          buildCores = 48;
          makeAbout = true;
          features = [ "big-parallel" ];
        };
      };

      "m2.xlarge.x86".configuration = {
        favorability = 80;
        nix = {
          maxJobs = 28;
          buildCores = 2;
          makeAbout = true;
        };
      };

      "m2.xlarge.x86--big-parallel".configuration = {
        favorability = 20;
        nix = {
          maxJobs = 1;
          buildCores = 48;
          makeAbout = true;
          features = [ "big-parallel" ];
        };
      };
    };
  };
}
