#!/usr/bin/env nix-shell
#!nix-shell -p curl -p jq -i bash

set -eu
set -o pipefail

#export PACKET_TOKEN=
#export PACKET_PROJECT_ID=
PLAN=$1

ids_to_reboot() {
    curl \
        --header 'Accept: application/json' \
        --header 'Content-Type: application/json' \
        --header "X-Auth-Token: $PACKET_TOKEN" \
        --fail \
        "https://api.packet.net/projects/${PACKET_PROJECT_ID}/devices?per_page=1000" \
        | jq -r '
.devices
| map(select(
  # Only operate on machines tagged for hydra
  (.tags | any(. == "hydra"))
  # and matching OS
  and (.operating_system.slug == "custom_ipxe")
  and (.ipxe_script_url == "http://netboot.gsc.io/hydra-" + $plan + "/netboot.ipxe")
))
| .[] | .id
' --arg plan "$PLAN"
}

for id in $(ids_to_reboot); do
    echo "Rebooting ${id}..."
    curl \
        --data '{"type": "reboot"}' \
        --header 'Accept: application/json' \
        --header 'Content-Type: application/json' \
        --header "X-Auth-Token: $PACKET_TOKEN" \
        --fail \
        "https://api.packet.net/devices/${id}/actions"

    host=$(echo "$id" | cut -d- -f1 | sed -e 's/$/.packethost.net/')
    echo -n "    waiting for ${id} to go down"
    while [ $(ssh-keyscan "$host" | wc -l) -gt 0 ] ; do
        echo -n "."
    done
    echo " down!"

    echo -n "    waiting for ${id} to come back up"
    while [ $(ssh-keyscan "$host" | wc -l) -eq 0 ] ; do
        echo -n "."
    done
    echo "--> UP!"
done
