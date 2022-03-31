#!/usr/bin/env nix-shell
#!nix-shell -i bash ./shell.nix

set -eu
set -o pipefail

cfgOpt() {
    touch build.cfg
    ret=$(awk '$1 == "'"$1"'" { print $2; }' build.cfg)
    if [ -z "$ret" ]; then
        echo "Config option '$1' isn't specified in build.cfg" >&2
        echo "Example format:"
        echo "$1        value"
        echo ""
        exit 1
    fi

    echo "$ret"
}

if [ "${PACKET_AUTH_TOKEN:-x}" == "x" ]; then
    PACKET_AUTH_TOKEN=$(cfgOpt "packetKey")
fi
if [ "${PACKET_PROJECT_ID:-x}" == "x" ]; then
    PACKET_PROJECT_ID=$(cfgOpt "packetProjectId")
fi

delete() {
    curl \
        --request "DELETE" \
        --header 'Accept: application/json' \
        --header "X-Auth-Token: $PACKET_AUTH_TOKEN" \
        --fail \
        "https://api.packet.net/devices/${1}"
}


id=$1

echo "--- Deleting ${id}"
delete "${id}"
