{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable-small";
    nix-netboot-serve = {
      url = "github:DeterminateSystems/nix-netboot-serve";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, nix-netboot-serve, flake-utils }:
    let
      mkNixOS = system: module:
        (nixpkgs.lib.nixosSystem {
          inherit system;

          modules = [
            nix-netboot-serve.nixosModules.no-filesystem
            nix-netboot-serve.nixosModules.register-nix-store
            nix-netboot-serve.nixosModules.swap-to-disk
            nix-netboot-serve.nixosModules.tmpfs-root


            module
            ./user.nix
            ./services.nix
            ./nix.nix
            ./system.nix

            {
              system.stateVersion = "22.11";
            }
          ];
        }).config.system.build.toplevel;
    in
    {
      nixosConfigurations.c3-medium-x86 = mkNixOS "x86_64-linux" {
        imports = [ ./instances/c3.medium.x86.nix ];

        nix = {
          gbFree = 100;
          features = [ "kvm" "nixos-test" ];
          systemTypes = [ "x86_64-linux" "i686-linux" ];
          maxJobs = 24;
          buildCores = 2;
        };
      };

      nixosConfigurations.c3-medium-x86--big-parallel = mkNixOS "x86_64-linux" {
        imports = [ ./instances/c3.medium.x86.nix ];

        nix = {
          gbFree = 100;
          features = [ "kvm" "nixos-test" "big-parallel" ];
          systemTypes = [ "x86_64-linux" "i686-linux" ];
          maxJobs = 2;
          buildCores = 24;
        };
      };
    };
}
