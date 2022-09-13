{ config, lib, pkgs, ... }:

with lib;
let
  sshKeys = rec {
    hydra-queue-runner-ceres = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCyM48VC5fpjJssLI8uolFscP4/iEoMHfkPoT9R3iE3OEjadmwa1XCAiXUoa7HSshw79SgPKF2KbGBPEVCascdAcErZKGHeHUzxj7v3IsNjObouUOBbJfpN4DR7RQT28PZRsh3TvTWjWnA9vIrSY/BvAK1uezFRuObvatqAPMrw4c0DK+JuGuCNkKDGHLXNSxYBc5Pmr1oSU7/BDiHVjjyLIsAMIc20+q8SjWswKqL1mY193mN7FpUMBtZrd0Za9fMFRII9AofEIDTOayvOZM6+/1dwRWZXM6jhE6kaPPF++yromHvDPBnd6FfwODKLvSF9BkA3pO5CqrD8zs7ETmrV hydra-queue-runner@chef";
    hydra-queue-runner-rhea = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOdxl6gDS7h3oeBBja2RSBxeS51Kp44av8OAJPPJwuU/ hydra-queue-runner@rhea";
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
      (authorizedNixStoreKey sshKeys.hydra-queue-runner-ceres)
      (authorizedNixStoreKey sshKeys.hydra-queue-runner-rhea)
      ''cert-authority,principals="netboot" ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDPfNvbD6olP68N7muphzh0hsdNnPfG4LaJvc0oe7D5V8ui54zGvJ4MC6YSwJN6p0pqTOjMBW/fFpsXRuTNon+o1nBaOMU1r9LQM0Y/YKArqVRtDflnOUaz5DUR3Fbg6u8hqpJ92ZSNh0e/QwtE2PD0IzybUlz9SLwBxfkXRG0Hxhtpy7XlS/VqmljFVilI5xRHB91kZRb9mOU7mOx2wwEq5o/8hy3WFcvY9gQkoS0AGJSp4Iyz5VZMRxxsZlchu/RK4efNecfYLmiAYJmSTVngGYBjnzLdW0YISzngQTA8k/z4WDqlCeuxgtAPfnkQECk//X5iDlFjiy1778PngjSuGw4ryOIkmmt0dOqqu58Ua+3N5tNRN5+yTcUeHO955iNLZTFi73Y9khtqQx7+7ckF36cHz7aKD/030KYjYptoUA1+fKs3+kvEZAvybqILNTYmWhPvLwUHXNrsqdSzos4ZRjUgBR2laR6L8x+S+xM+Yu1XT8Uhyti3PV6t4zykUc4Ngi9EWMmGkHMVnwutFJdJymHV0dvdvoA+D2elH2sbEQt7+mIUT06f0dVSHe85vTj56hXGRUqAxur7TM3Ps8Rehk9P89ukP4eicBIte+w4qpoxO+XouCyr3P+v7todrOLno/BQdkAVDl832FPTZA2k/kYCWzd6/jjWu+elswZRyQ==''

      # eelco
      "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDfNUQXdhu4tIC+oDtq12aKRw3mfHa1nP/sMRkE379bnByQWqgpr8cCsXaNsZIrM49Iv/cP2JxZT1S3K4kfp6ouvNN+rYubOrpHLt+NWhiI+1s5IpgZv21Ln1kANjo4jzKLTRfoGv1gWILTG1KSD8oTev1kE1p3GJph5pTVilzAW1uXNhkSpYVMIw6HwqPR4QN1UliD5FvAdz6FJ16E7/xhaVWdeEOcsYw2uRXBaY/rXkKtikscZ99wnOiCf6Gph2ahLkmZ/I3QmNq+xH+Xq6vpx6Kky0MKNm2zlh5tRDOd7Wd5N3sQpGAtHL4qGObq0N3VCtuJIL5eVRpZ5l5yNLsp"
    ];
  };
}
