#!/usr/bin/env nix-shell
#!nix-shell -p gawk gnused -i bash

set -eu
set -o pipefail

drv=$(realpath $(time nix-instantiate ./instances/m2.xlarge.x86.nix --show-trace --add-root ./result-m2.xlarge.x86.drv --indirect))

nix-copy-closure --use-substitutes --to "netboot@flexo.gsc.io" "$drv"
ssh $NIX_SSHOPTS "netboot@flexo.gsc.io" NIX_REMOTE=daemon nix-store --realize "$drv" --add-root /var/lib/nginx/netboot/netboot.gsc.io/hydra-m2.xlarge.x86 --indirect --keep-going
