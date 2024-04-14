{ config, lib, pkgs, ... }:

with lib;
let
  sshKeys = rec {
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

  users.users = {
    root.openssh.authorizedKeys.keys = [
      (authorizedNixStoreKey sshKeys.hydra-queue-runner-rhea)
      ''cert-authority,principals="netboot" ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDPfNvbD6olP68N7muphzh0hsdNnPfG4LaJvc0oe7D5V8ui54zGvJ4MC6YSwJN6p0pqTOjMBW/fFpsXRuTNon+o1nBaOMU1r9LQM0Y/YKArqVRtDflnOUaz5DUR3Fbg6u8hqpJ92ZSNh0e/QwtE2PD0IzybUlz9SLwBxfkXRG0Hxhtpy7XlS/VqmljFVilI5xRHB91kZRb9mOU7mOx2wwEq5o/8hy3WFcvY9gQkoS0AGJSp4Iyz5VZMRxxsZlchu/RK4efNecfYLmiAYJmSTVngGYBjnzLdW0YISzngQTA8k/z4WDqlCeuxgtAPfnkQECk//X5iDlFjiy1778PngjSuGw4ryOIkmmt0dOqqu58Ua+3N5tNRN5+yTcUeHO955iNLZTFi73Y9khtqQx7+7ckF36cHz7aKD/030KYjYptoUA1+fKs3+kvEZAvybqILNTYmWhPvLwUHXNrsqdSzos4ZRjUgBR2laR6L8x+S+xM+Yu1XT8Uhyti3PV6t4zykUc4Ngi9EWMmGkHMVnwutFJdJymHV0dvdvoA+D2elH2sbEQt7+mIUT06f0dVSHe85vTj56hXGRUqAxur7TM3Ps8Rehk9P89ukP4eicBIte+w4qpoxO+XouCyr3P+v7todrOLno/BQdkAVDl832FPTZA2k/kYCWzd6/jjWu+elswZRyQ==''

      #### infra-core

      # delroth
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAII3tjB4KYDok3KlWxdBp/yEmqhhmybd+w0VO4xUwLKKV"

      # hexa
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAWQRR7dspgQ6kCwyFnoVlgmmPR4iWL1+nvq6a5ad2Ug hexa@gaia"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFSpdtIxIBFtd7TLrmIPmIu5uemAFJx4sNslRsJXfFxr hexa@helix"

      # vcunat
      "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC4IJkFIVyImkfD4fM89ya+hy2ig8kUg09PCdjB5rS82akFoucYZSYMG41ZrlMT5LAikIgWusBzpO5bBkqxqcYqaYK/VF06zVBk3kF1pAIoitst9z0PLXY8/N+bFJg6oT7p6EWGRvFggUviSTTvJFMNUdDgEpsLqLp8+IYXjfM3Cz6+TQmyWQSockobRqgdILTjc1p2uxmNSzy2fElpZ0sKRPLNYG4SVPBPnOavs1KPOtyC1pIHOuz5A605gPLFXoWpX2lIK6atmGheiHxURDAX3pANVm+iMmnjteP0jEGU26/SPqgVP3OxdcryHxL3WnSJGtTnycoa30qP/Edmy9vB"
    ];
  };
}
