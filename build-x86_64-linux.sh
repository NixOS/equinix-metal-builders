#!/usr/bin/env nix-shell
#!nix-shell -i bash ./shell.nix

set -eu
set -o pipefail

type=$1

drv=$(realpath $(time nix-instantiate "./instances/$type.nix" --show-trace --add-root "./result-$type.drv" --indirect))

. ./config.sh

nix-copy-closure \
    --use-substitutes \
    --to "$pxeHost" \
    "$drv"

ssh $NIX_SSHOPTS \
    "$pxeHost" \
    NIX_REMOTE=daemon \
    nix-store \
      --realize "$drv" \
      --add-root "$pxeDir/hydra-$type" \
      --indirect --keep-going
