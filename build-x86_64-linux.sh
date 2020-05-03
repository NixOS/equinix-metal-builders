#!/usr/bin/env nix-shell
#!nix-shell -p gawk gnused -i bash

set -eu
set -o pipefail

type=$1

drv=$(realpath $(time nix-instantiate "./instances/$type.nix" --show-trace --add-root "./result-$type.drv" --indirect))

nix-copy-closure \
    --use-substitutes \
    --to "netboot@2011dfe7.packethost.net" \
    "$drv"

ssh $NIX_SSHOPTS \
    "netboot@2011dfe7.packethost.net" \
    NIX_REMOTE=daemon \
    nix-store \
      --realize "$drv" \
      --add-root "/var/lib/nginx/netboot/webroot/hydra-$type" \
      --indirect --keep-going
