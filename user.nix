{ config, lib, pkgs, ... }:

with lib;
let
  sshKeys = rec {
    hydra-queue-runner = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCyM48VC5fpjJssLI8uolFscP4/iEoMHfkPoT9R3iE3OEjadmwa1XCAiXUoa7HSshw79SgPKF2KbGBPEVCascdAcErZKGHeHUzxj7v3IsNjObouUOBbJfpN4DR7RQT28PZRsh3TvTWjWnA9vIrSY/BvAK1uezFRuObvatqAPMrw4c0DK+JuGuCNkKDGHLXNSxYBc5Pmr1oSU7/BDiHVjjyLIsAMIc20+q8SjWswKqL1mY193mN7FpUMBtZrd0Za9fMFRII9AofEIDTOayvOZM6+/1dwRWZXM6jhE6kaPPF++yromHvDPBnd6FfwODKLvSF9BkA3pO5CqrD8zs7ETmrV hydra-queue-runner@chef";
  };

  authorizedNixStoreKey = key:
    let
      environment = concatStringsSep " " [
        "NIX_SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
      ];
    in "command=\"${environment} ${config.nix.package}/bin/nix-store --serve --write\" ${key}";
in
{
  security.sudo.wheelNeedsPassword = false;
  services = {
    openssh = {
      challengeResponseAuthentication = false;
      passwordAuthentication = false;
    };
  };

  users.users = {
    root.openssh.authorizedKeys.keys = [
      (authorizedNixStoreKey sshKeys.hydra-queue-runner)
    ];

    grahamc = {
      isNormalUser = true;
      extraGroups = [ "wheel" ];
      createHome = true;
      home = "/home/grahamc";
      openssh.authorizedKeys.keys = [
        "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDY8wRHQtq9uBzdiAYzpSNmF+nmIHmW+AOeBTDNmdva+CFGIBbB56q7w6GCOhfXs8edrPY4qOcQGaOD0ussIvHnqkVfw8e6CbxnpXKeAuIz7+1V72AhLPzOkif4yPrI6tSYF5nvzq6U4Yk1qFnXiLQjkA1s4EcZH6V0KbHMsu7Mtv3Irspdn8KUI3j2UwZcssFu1EuLHhLNussziRQK9tOg9ixb0U1WXuUJn7Noh9odTAsAt6jLFdr5eN/IINgC9WQqvY/W94Tc2/z5TWR7z382pEkMBR/3sf+nYKA82069tagkyrtJ/YXi00CWU4vjpnMvwPEYcmtCddfCPi8ZIUrn"
      ];
    };
  };
}
