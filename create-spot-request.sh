#!/usr/bin/env nix-shell
#!nix-shell -p curl -p jq -i bash

set -eu
set -o pipefail

# Set these ...
#PACKET_PROJECT_ID=
#PACKET_TOKEN=
#URL=

facilities='["ams1"]'

PLAN=m2.xlarge.x86


json=$(cat <<EOF | jq -r .
      {
        "plan": "$PLAN",
        "hostname": "hydra-x86",
        "billing_cycle": "hourly",
        "userdata": "",
        "project_ssh_keys": [
        ],
        "user_ssh_keys": [
        ]
      }
EOF
    )

json=$(jq -s '$extra * $json' --argjson json "$json" --argjson extra '
        {
        "ipxe_script_url": "'"$URL"'",
        "always_pxe": true,
        "tags": [ "hydra" ],
        "operating_system": "7516833e-1b77-4611-93e9-d48225ca8b3c"
        }
        ' < /dev/null)

json=$(jq -s '$extra | .instance_parameters = $json | .facilities = $facilities' --argjson json "$json" --argjson facilities "$facilities" --argjson extra '
        {
            "devices_max": 10,
            "devices_min": 1,
            "max_bid_price": 0.50
        }
        ' < /dev/null)


echo "Creating server with: ${json}" >&2

curl --data "$json" \
         --header 'Accept: application/json' \
         --header 'Content-Type: application/json' \
         --header "X-Auth-Token: $PACKET_TOKEN" \
         --fail \
         "https://api.packet.net/projects/$PACKET_PROJECT_ID/spot-market-requests" \
         | tee /dev/stderr \
         | jq '.'
