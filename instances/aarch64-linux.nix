(import ../make-netboot.nix)
{
  buildSystem = "aarch64-linux";
  hardware = { lib, pkgs, ... }: {
    nixpkgs.system = "aarch64-linux";
    imports = [
      ./c1.large.arm.nix
      ./c2.large.arm.nix
    ];

    nix = {
      gbFree = 100;
      features = [ "kvm" "nixos-test" ];
      systemTypes = [ "aarch64-linux" ];
    };

    specialisation = {
      "c1.large.arm".configuration = {
        favorability = 100;
        nix = {
          maxJobs = 32;
          buildCores = 3;
          makeAbout = true;
        };
      };

      "c2.large.arm".configuration = {
        favorability = 50;
        nix = {
          maxJobs = 16;
          buildCores = 2;
          makeAbout = true;
        };
      };

      "c2.large.arm--armv7l".configuration = {
        favorability = 20;
        services.openssh.ports = [ 2200 ];
        packet-nix-builder.armv7.enable = true;
        nix = {
          maxJobs = 5;
          buildCores = 2;
          makeAbout = true;
          systemTypes = lib.mkForce [ "armv7l-linux" ];
        };
      };

      "c2.large.arm--big-parallel".configuration = {
        favorability = 30;
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
