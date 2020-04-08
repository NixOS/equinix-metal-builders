{ pkgs ? import <nixpkgs> {} }:
let
  # Flakes would be nice here.
  nixos-org-configurations = builtins.fetchGit {
    url = "https://github.com/NixOS/nixos-org-configurations.git";
    ref = "master";
  };
in pkgs.callPackage "${nixos-org-configurations}/hydra-packet-importer" {}
