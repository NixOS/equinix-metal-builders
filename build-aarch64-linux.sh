#!/usr/bin/env nix-shell
#!nix-shell -p gawk gnused -i bash

set -eu
set -o pipefail

type=$1

. ./config.sh

set -x

nix-build ./build-support/aarch64-setup.nix --out-link ./importer
./importer
buildHost=$(cat machines | grep aarch64 | cut -d' ' -f1 | head -n1)
printf "%s %s\n" \
       "$(echo "$buildHost" | cut -d@ -f2)" \
       "$(grep "$buildHost" machines | head -n1 | cut -d' ' -f8 | base64 -d)" > KnownHosts



tmpDir=$(mktemp -t -d aarch64-builder.XXXXXX)
SSHOPTS="${NIX_SSHOPTS:-}"
# SSHOPTS="${SSHOPTS:-} -o ControlMaster=auto -o ControlPath=$tmpDir/ssh-%n -o ControlPersist=60"
SSHOPTS="${SSHOPTS:-} -o UserKnownHostsFile=$(pwd)/KnownHosts"

recvpid=0
cleanup() {
    for ctrl in "$tmpDir"/ssh-*; do
        ssh -o ControlPath="$ctrl" -O exit dummyhost 2>/dev/null || true
    done
    rm -rf "$tmpDir"

    if [ "$recvpid" -gt 0 ]; then
        kill -9 "$recvpid"
    fi
}
trap cleanup EXIT

set -eux

drv=$(realpath $(nix-instantiate "./instances/$type.nix" --show-trace --add-root "./result-$type.drv" --indirect))
NIX_SSHOPTS=$SSHOPTS nix-copy-closure --use-substitutes --to "$buildHost" "$drv"
out=$(ssh $SSHOPTS "$buildHost" NIX_REMOTE=daemon nix-store --keep-going -r "$drv" -j 5 --cores 45)

ssh $SSHOPTS "$buildHost" ls $out

psk=$(head -c 9000 /dev/urandom | md5sum | awk '{print $1}')

ssh $SSHOPTS "$pxeHost" rm -rf "${pxeDir}/hydra-${type}.next"
ssh $SSHOPTS "$pxeHost" mkdir -p "${pxeDir}/hydra-${type}.next"

ssh $SSHOPTS "$buildHost" -- tar -C "$out" -hvvvczf - '{Image,initrd,netboot.ipxe}' \
    | ssh $SSHOPTS "$pxeHost" -- tar -C "${pxeDir}/hydra-${type}.next" -vvvzxf -

ssh $SSHOPTS "$pxeHost" mkdir -p "${pxeDir}/hydra-${type}"
ssh $SSHOPTS "$pxeHost" rm -rf "${pxeDir}/hydra-${type}.old"
ssh $SSHOPTS "$pxeHost" mv "${pxeDir}/hydra-${type}" "${pxeDir}/hydra-${type}.old"
ssh $SSHOPTS "$pxeHost" mv "${pxeDir}/hydra-${type}.next" "${pxeDir}/hydra-${type}"
