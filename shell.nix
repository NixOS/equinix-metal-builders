let
  pkgs = import (builtins.fetchTarball "channel:nixos-unstable-small") { };
in
pkgs.mkShell {
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
}
