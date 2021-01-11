#!/usr/bin/env nix-shell
#!nix-shell -p curl -p jq -i bash

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

reboot() {
    curl \
        --data '{"type": "reboot"}' \
        --header 'Accept: application/json' \
        --header 'Content-Type: application/json' \
        --header "X-Auth-Token: $PACKET_AUTH_TOKEN" \
        --fail \
        "https://api.packet.net/devices/${1}/actions"
}


id=$1
host=$2
sos=$3

reboot "${id}"

echo "--- waiting for ${id} to go down"
while [ $(ssh-keyscan "$host" 2> /dev/null | wc -l) -gt 0 ] ; do
    echo -n "."
done
echo ""
echo "        ... down!"

echo "--- waiting for ${id} to come back up"

keyscans_remaining=1800

while [ $(ssh-keyscan "$host" 2> /dev/null  | wc -l) -eq 0 ]; do
    echo -n "."
    keyscans_remaining=$((keyscans_remaining - 1))
    if [ $keyscans_remaining -eq 0 ]; then
        echo "Doesn't seem to be up after some time..."
        exit 10
    fi
done

echo ""
echo "   ... up!"
