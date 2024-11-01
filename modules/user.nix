{ config, lib, pkgs, ... }:

with lib;
let
  sshKeys = {
    hydra-queue-runner-rhea = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOdxl6gDS7h3oeBBja2RSBxeS51Kp44av8OAJPPJwuU/ hydra-queue-runner@rhea";
  };

  authorizedNixStoreKey = key:
    let
      environment = concatStringsSep " " [
        "NIX_SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
      ];
    in
    "command=\"${environment} ${config.nix.package}/bin/nix-store --serve --write\" ${key}";
in
{
  security.sudo.wheelNeedsPassword = false;
  services = {
    openssh.settings = {
      KbdInteractiveAuthentication = false;
      PasswordAuthentication = false;
    };
  };

  nix.settings.trusted-users = [
    "build"
    "root"
  ];

  security.pam.loginLimits = [
    {
      domain = "@nixbld";
      type = "-"; # both soft and hard limit
      item = "nofile";
      value = "1048576";
    }
  ];

  users.users = {
    root.openssh.authorizedKeys.keys = [
      (authorizedNixStoreKey sshKeys.hydra-queue-runner-rhea)

      #### infra-core

      # hexa
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAWQRR7dspgQ6kCwyFnoVlgmmPR4iWL1+nvq6a5ad2Ug hexa@gaia"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFSpdtIxIBFtd7TLrmIPmIu5uemAFJx4sNslRsJXfFxr hexa@helix"

      # vcunat
      "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC4IJkFIVyImkfD4fM89ya+hy2ig8kUg09PCdjB5rS82akFoucYZSYMG41ZrlMT5LAikIgWusBzpO5bBkqxqcYqaYK/VF06zVBk3kF1pAIoitst9z0PLXY8/N+bFJg6oT7p6EWGRvFggUviSTTvJFMNUdDgEpsLqLp8+IYXjfM3Cz6+TQmyWQSockobRqgdILTjc1p2uxmNSzy2fElpZ0sKRPLNYG4SVPBPnOavs1KPOtyC1pIHOuz5A605gPLFXoWpX2lIK6atmGheiHxURDAX3pANVm+iMmnjteP0jEGU26/SPqgVP3OxdcryHxL3WnSJGtTnycoa30qP/Edmy9vB"
    ];
    build = {
      isNormalUser = true;
      uid = 2000;
      openssh.authorizedKeys.keys = [
        (authorizedNixStoreKey sshKeys.hydra-queue-runner-rhea)
      ];
    };
  };
}
