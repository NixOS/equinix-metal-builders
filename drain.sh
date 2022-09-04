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

drain() {
    data=$((
        curl \
            --header 'Accept: application/json' \
            --header 'Content-Type: application/json' \
            --header "X-Auth-Token: $PACKET_AUTH_TOKEN" \
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
        --header "X-Auth-Token: $PACKET_AUTH_TOKEN" \
        --fail \
        "https://api.packet.net/devices/${1}" 2> /dev/null > /dev/null
}

current_jobs() {
    curl -q \
        --header 'Accept: application/json' \
        --fail \
        "https://status.nixos.org/prometheus/api/v1/query?query=hydra_machine_current_jobs\{host=%22root@${1}%22\}" 2> /dev/null \
        | jq -r '.data.result[0].value[1]'
}

id=$1
host=$2
sos=$3


drain "${id}"
echo "Draining builds ..."

starttime=$(date +%s)
while
    current=$(current_jobs "$host")
    printf "%s\t%s\n" "$(date)" "$current"
    
    now=$(date +%s)
    duration=$((now - starttime))
    [ "$current" -gt 0 ] || [ "$duration" -gt 43200 ] # 12 hours
do
    sleep 1
done
