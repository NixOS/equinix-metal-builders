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

if [ "${PACKET_TOKEN:-x}" == "x" ]; then
    PACKET_TOKEN=$(cfgOpt "packetKey")
fi
if [ "${PACKET_PROJECT_ID:-x}" == "x" ]; then
    PACKET_PROJECT_ID=$(cfgOpt "packetProjectId")
fi

drain() {
    data=$((
        curl \
            --header 'Accept: application/json' \
            --header 'Content-Type: application/json' \
            --header "X-Auth-Token: $PACKET_TOKEN" \
            --fail \
            "https://api.packet.net/devices/${1}" \
            | jq -r '.tags | .[]'
        echo "skip-hydra"
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
        --header "X-Auth-Token: $PACKET_TOKEN" \
        --fail \
        "https://api.packet.net/devices/${1}" 2> /dev/null > /dev/null
}

restore() {
    data=$((
        curl \
            --header 'Accept: application/json' \
            --header 'Content-Type: application/json' \
            --header "X-Auth-Token: $PACKET_TOKEN" \
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
        --header "X-Auth-Token: $PACKET_TOKEN" \
        --fail \
        "https://api.packet.net/devices/${1}" > /dev/null 2> /dev/null
}

current_jobs() {
    curl -q \
        --header 'Accept: application/json' \
        --fail \
        "https://status.nixos.org/prometheus/api/v1/query?query=hydra_machine_current_jobs\{host=%22root@${1}%22\}" 2> /dev/null \
        | jq -r '.data.result[0].value[1]'
}

reboot() {
    curl \
        --data '{"type": "reboot"}' \
        --header 'Accept: application/json' \
        --header 'Content-Type: application/json' \
        --header "X-Auth-Token: $PACKET_TOKEN" \
        --fail \
        "https://api.packet.net/devices/${1}/actions"
}


id=$1
host=$2
sos=$3


echo "--- Draining  ${id}..."
drain "${id}"
echo "Draining builds ..."
while [ $(current_jobs "$host") -gt 0 ]; do
    echo -n "."
    sleep 1
done
echo ""

echo "--- Rebooting  ${id}..."

reboot "${id}"

echo "--- waiting for ${id} to go down"
while [ $(ssh-keyscan "$host" 2> /dev/null | wc -l) -gt 0 ] ; do
    echo -n "."
done
echo ""
echo "        ... down!"

echo "--- waiting for ${id} to come back up"

up=0
last_keyscan=$(date +%s)
keyscans_remaining=60
coproc SSH (ssh -o StrictHostKeyChecking=no \
                -o UserKnownHostsFile=/dev/null \
                "${sos}" 2>&1 | while read -r line; do printf "         %s  %s\n" "$(date)" "$line"; done)
while [ $up -eq 0 ]; do
    if read -t5 -r output <&"${SSH[0]}"; then
        echo "$output"
    fi

    now=$(date +%s)
    if [ $((now - last_keyscan)) -gt 30 ]; then
        last_keyscan=$now
        if [ $(ssh-keyscan "$host" 2> /dev/null  | wc -l) -eq 0 ] ; then
            echo -n "."
            keyscans_remaining=$((keyscans_remaining - 1))
            if [ $keyscans_remaining -eq 0 ]; then
                reboot "${id}"
                keyscans_remaining=60
            fi
        else
            up=1
        fi
    fi
done
kill "${SSH_PID}"

echo ""
echo "   ... up!"

echo "--- testing remote Nix builds"
(
    if ! ssh \
         -o StrictHostKeyChecking=no \
         -o UserKnownHostsFile=/dev/null \
         "root@$host" \
         "export NIX_PATH=pkgs=https://nixos.org/channels/nixos-unstable/nixexprs.tar.xz; nix-build '<pkgs>' -A hello && nix-build '<pkgs>' --check -A hello"; then
        echo "^^^   ... failed!"
        exit 1
    fi
) 2>&1 | sed -e 's/^/ │ /'

echo "--- adding back to hydra"
restore "${id}"

echo "--- ok!"
