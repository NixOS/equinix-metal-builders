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

restore() {
    data=$((
        curl \
            --header 'Accept: application/json' \
            --header 'Content-Type: application/json' \
            --header "X-Auth-Token: $PACKET_AUTH_TOKEN" \
            --fail \
            "https://api.packet.net/devices/${1}" \
            | jq -r '.tags | .[]' | grep -v '^skip-hydra$'
        # using jq -R . to convert the lines in to JSON strings,
        # use jq -s . to convert the of JSON strings in to a JSON list
          ) | jq -R . | jq -s '{
          id: $id,
          tags: .
          }' --arg id "$1")

    curl -X PATCH \
        --data "${data}" \
        --header 'Accept: application/json' \
        --header 'Content-Type: application/json' \
        --header "X-Auth-Token: $PACKET_AUTH_TOKEN" \
        --fail \
        "https://api.packet.net/devices/${1}" > /dev/null 2> /dev/null
}


id=$1
host=$2
sos=$3

echo "--- adding back to hydra"
restore "${id}"

echo "--- ok!"
