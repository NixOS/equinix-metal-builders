#!/usr/bin/env nix-shell
#!nix-shell -i bash ./bids/shell.nix
# shellcheck shell=bash
set -eux

scriptroot=$(dirname "$(realpath "$0")")
cd "$scriptroot/bids"

set +e
terraform init
terraform plan -detailed-exitcode -input=false -out ./terraform.plan
exitcode=$?
set -e

if [ "$exitcode" -eq 2 ]; then
  echo "Diff present, uploading pipline apply stage."
  buildkite-agent pipeline upload "$scriptroot/terraform-apply.yml"
elif [ "$exitcode" -eq 0 ]; then
  echo "No change, not uploading pipline apply stage."
else
  exit "$exitcode"
fi
