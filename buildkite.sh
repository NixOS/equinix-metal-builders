#!/usr/bin/env nix-shell
#!nix-shell -p curl -p jq -i bash

set -eu
set -o pipefail

cfgOpt() {
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

PACKET_TOKEN=$(cfgOpt "packetKey")
PACKET_PROJECT_ID=$(cfgOpt "packetProjectId")

curl \
    --header 'Accept: application/json' \
    --header 'Content-Type: application/json' \
    --header "X-Auth-Token: $PACKET_TOKEN" \
    --fail \
    "https://api.packet.net/projects/${PACKET_PROJECT_ID}/devices?per_page=1000" \
    | jq . > ./devices.json

nix-instantiate --eval --strict --json ./buildkite.nix | jq .
