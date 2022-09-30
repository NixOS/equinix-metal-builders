#!/bin/sh

set -eux

vault write -field=signed_key ssh-keys/sign/nixos-foundation-build-farm-root public_key=@./deploy.key.pub > deploy.key-cert.pub
