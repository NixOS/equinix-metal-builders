{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable-small";
    nix-netboot-serve = {
      url = "github:DeterminateSystems/nix-netboot-serve/grahamc-patch-1";
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
            ./modules/user.nix
            ./modules/services.nix
            ./modules/nix.nix
            ./modules/system.nix

            {
              system.stateVersion = "22.11";
              nix = {
                gbFree = 100;
                features = [ "kvm" "nixos-test" ];
              };
            }
          ];
        }).config.system.build.toplevel;
    in
    rec {
      devShell.x86_64-linux = let pkgs = nixpkgs.legacyPackages.x86_64-linux; in pkgs.mkShell {
        buildInputs = [
          pkgs.awscli
          pkgs.bashInteractive
          pkgs.curl
          pkgs.gawk
          pkgs.gnused
          pkgs.jq
          pkgs.openssh
          pkgs.vault
          (pkgs.terraform_1.withPlugins (p: [ p.metal ]))
        ];
      };

      nixosConfigurations.c3-medium-x86 = mkNixOS "x86_64-linux" {
        imports = [ ./instances/c3.medium.x86.nix ];

        nix = {
          systemTypes = [ "x86_64-linux" "i686-linux" ];
          settings.max-jobs = 24;
          settings.cores = 2;
        };
      };

      nixosConfigurations.c3-medium-x86--big-parallel = mkNixOS "x86_64-linux" {
        imports = [ ./instances/c3.medium.x86.nix ];

        nix = {
          features = [ "big-parallel" ];
          systemTypes = [ "x86_64-linux" "i686-linux" ];
          settings.max-jobs = 2;
          settings.cores = 24;
        };
      };

      nixosConfigurations.m3-large-x86 = mkNixOS "x86_64-linux" {
        imports = [ ./instances/m3.large.x86.nix ];

        nix = {
          systemTypes = [ "x86_64-linux" "i686-linux" ];
          settings.max-jobs = 2;
          settings.cores = 24;
        };
      };

      nixosConfigurations.m3-large-x86--big-parallel = mkNixOS "x86_64-linux" {
        imports = [ ./instances/m3.large.x86.nix ];

        nix = {
          features = [ "big-parallel" ];
          systemTypes = [ "x86_64-linux" "i686-linux" ];
          settings.max-jobs = 2;
          settings.cores = 24;
        };
      };

      nixosConfigurations.c3-large-arm = mkNixOS "aarch64-linux" {
        imports = [ ./instances/c3.large.arm.nix ];

        nix = {
          systemTypes = [ "aarch64-linux" ];
          settings.max-jobs = 40;
          settings.cores = 2;
        };
      };

      nixosConfigurations.c3-large-arm--big-parallel = mkNixOS "aarch64-linux" {
        imports = [ ./instances/c3.large.arm.nix ];

        nix = {
          features = [ "big-parallel" ];
          systemTypes = [ "aarch64-linux" ];
          settings.max-jobs = 4;
          settings.cores = 80;
        };
      };

      hydraJobs = nixosConfigurations;
    };
}
