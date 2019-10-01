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
      "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDFSwa8cFdYhwMQpc3JvgU9GyYY+pOhYDngXXiKkocUcbBmS0CPDY8HuypnJLigSMrsXMVv/RD3K2AqO5DyUY5H2hMXzD8toeiiDUWru5ig9waPz8YVf1w+XNIu5d7wK9Hw5sGRF5BmKcOylNR7Jsc8ISavZjVqhqP9Mdhq0xVbICUYCHCKfmk5Tnnj440bi3Csqa1FwXNKpBqNMTn6eZLIxA7bvpib4sYhLULD1WJk2zyEMBduG2IBQ20MSqVPldLqpZp9VHTrISomPDgKnFoUoL7jwaCWuiWo4FNPVnhmxzFeyb9E3UPMVlEk0Smis8MrVfdof70QUA5LbN48wbGR" # builder
    ];
  };
}
