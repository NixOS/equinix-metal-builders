#!/usr/bin/env nix-shell
#!nix-shell -i bash ./shell.nix
# shellcheck shell=bash
set -eux

scriptroot=$(dirname "$(realpath "$0")")
cd "$scriptroot/bids"

terraform init
terraform apply ./terraform.plan
