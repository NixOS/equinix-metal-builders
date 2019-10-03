#!/usr/bin/env nix-shell
#!nix-shell -p curl -p jq -i bash

set -eu
set -o pipefail

PLAN=$1

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

sos() {
    curl \
        --header 'Accept: application/json' \
        --header 'Content-Type: application/json' \
        --header "X-Auth-Token: $PACKET_TOKEN" \
        --fail \
        "https://api.packet.net/devices/${1}" \
        | jq -r '
.id + "@sos." + .facility.code + ".packet.net"
'
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

for id in $(ids_to_reboot); do
    echo " ═> Rebooting ${id}..."
    reboot "${id}"
    host=$(echo "$id" | cut -d- -f1 | sed -e 's/$/.packethost.net/')
    echo -n " ├─ waiting for ${id} to go down"
    while [ $(ssh-keyscan "$host" 2> /dev/null | wc -l) -gt 0 ] ; do
        echo -n "."
    done
    echo ""
    echo " │    ... down!"

    echo " ├─ waiting for ${id} to come back up"

    up=0
    last_keyscan=$(date +%s)
    keyscans_remaining=60
    coproc SSH (ssh -o StrictHostKeyChecking=no \
                    -o UserKnownHostsFile=/dev/null \
                    "$(sos "${id}")" 2>&1 | while read -r line; do printf " │         %s  %s\n" "$(date)" "$line"; done)
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
                    reboot "${id}"IRC li
                    keyscans_remaining=60
                fi
            else
                up=1
            fi
        fi
    done
    kill "${SSH_PID}"

    echo ""
    echo " │    ... up!"
    echo " ├─ testing remote Nix builds"
    (
        if ! ssh \
            -o StrictHostKeyChecking=no \
            -o UserKnownHostsFile=/dev/null \
            "root@$host" \
            "export NIX_PATH=pkgs=https://nixos.org/channels/nixos-unstable/nixexprs.tar.xz; nix-build '<pkgs>' -A hello && nix-build '<pkgs>' --check -A hello"; then
            echo "   ... failed!"
            exit 1
        fi
    ) 2>&1 | sed -e 's/^/ │ /'
    echo " └─ ok!"
done
