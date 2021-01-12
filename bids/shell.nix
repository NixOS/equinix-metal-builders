let
  pkgs = import (builtins.fetchTarball "channel:nixos-unstable-small") {};
in pkgs.mkShell {
  buildInputs = [
    pkgs.jq
    (pkgs.terraform_0_12.withPlugins (p: [
      (pkgs.buildGoPackage rec {
        pname = "terraform-provider-metal";
        version = "1.0.0";
        goPackagePath = "github.com/equinix/terraform-provider-metal";
        subPackages = [ "." ];
        src = pkgs.fetchFromGitHub {
          owner = "equinix";
          repo = "terraform-provider-metal";
          rev = "v1.0.0";
          sha256 = "sha256-wA3L0SEDWyU5OwrK+5W59Be9hNaC/gahu1fBaU5xmt4=";
        };
        # Terraform allow checking the provider versions, but this breaks
        # if the versions are not provided via file paths.
        postBuild = "mv go/bin/terraform-provider-metal{,_v1.0.0}";
      })
    ]))
  ];
}
