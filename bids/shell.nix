let
  pkgs = import (builtins.fetchTarball "channel:nixos-unstable-small") {};
in pkgs.mkShell {
  buildInputs = [
    pkgs.jq
    (pkgs.terraform_1.withPlugins (p: [
      (pkgs.buildGoPackage rec {
        pname = "terraform-provider-metal";
        version = "3.1.0";
        goPackagePath = "github.com/equinix/terraform-provider-metal";
        subPackages = [ "." ];
        src = pkgs.fetchFromGitHub {
          owner = "equinix";
          repo = "terraform-provider-metal";
          rev = "v3.1.0";
          sha256 = "sha256-9K3DnEWQAFXMKdWAsi83qUfQ7ZWxblS4gRjhvphSblc=";
        };
        # Terraform allow checking the provider versions, but this breaks
        # if the versions are not provided via file paths.
        postBuild = "mv go/bin/terraform-provider-metal{,_v3.1.0}";
      })
    ]))
  ];
}
