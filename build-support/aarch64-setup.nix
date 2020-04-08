{ pkgs ? import <nixpkgs> {} }:
let
  importer = pkgs.callPackage ./hydra-packet-importer.nix {};
in pkgs.writeShellScript "aarch64-setup" ''
  PATH=${pkgs.jq}/bin:${pkgs.coreutils}/bin

  scratch=$(mktemp -d -t tmp.XXXXXXXXXX)
  function finish {
    rm -rf "$scratch"
  }
  trap finish EXIT

  (
    cd "$scratch"
    echo 'Using the PACKET_ACCESS_KEY environment variable for Packet creds'
    touch config.creds.json
    chmod 0600 config.creds.json
    cat ${./config.json} | jq '. | .token = env.PACKET_ACCESS_KEY' > ./config.creds.json

    ${importer}/bin/hydra-packet-importer ./config.creds.json > machines
  )
  cp $scratch/machines ./machines
''
