#!/usr/bin/env nix-shell
#!nix-shell -i bash ./shell.nix

set -eu
set -o pipefail

selfloc=$(dirname "$(realpath "$0")")

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

get_devices() {
    curl \
        --header 'Accept: application/json' \
        --header 'Content-Type: application/json' \
        --header "X-Auth-Token: $PACKET_AUTH_TOKEN" \
        --fail \
        "https://api.equinix.com/metal/v1/spot-market-requests/${1}?include=devices" \
        | jq -c '.devices[] | { id, short_id }'

}

reservation_id=$1

get_devices "$reservation_id" | while read -r device; do
    id=$(echo "$device" | jq -r .id)
    host=$(echo "$device" | jq -r '.short_id + ".packethost.net"')
    echo "Draining $id / $host"
    "$selfloc/drain.sh" "$id" "$host"
done
