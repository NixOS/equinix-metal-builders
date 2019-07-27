# Transient Nix Builders on Packet.com

I use Packet.com's spot market to run transient, powerful Nix
builders. The files here are custom to _my_ builders and _my_ use
case. However, they could easily serve as a nice template for you to
use.

I would accept PRs parameterizing the code.

# Principles of Operation

This repository creates a bootable iPXE image. We assume each boot
starts with an empty set of disks. In case this is not true, it erases
all of the disks and creates one large ZFS stripe across all disks. If
you have any disks attached, it WILL erase it on every boot.

Each machine is stateless. As soon as it boots it is ready to build.
When the machine shuts down, all data is lost.

# To customize

1. Edit `./user.nix` to have your user and your user's key. If you
   have a key which is only used by Nix's remote builder protocol,
   then they might belong in in the sshKeys list at the top.

2. Edit `./instances/m2.xlarge.x86.nix` to match the hardware you'll
   be deploying to. These machines are all Packet.com's m2.xlarge.x86
   type, so if you're also using those, it is ready to go.

# Building

## m2.xlarge.x86

You can simply `nix-build ./instances/m2.xlarge.x86.nix` in this
directory and create a bootable image. On the other hand, I use
`./build-x86-64-linux.sh`, which instantiates locally and builds on my
netboot server. The remote server builds much faster and saves my
battery life.

## c2.large.arm

In principle this one is just as easy. If you're on a machine which
can build aarch64 binaries, then you can just run
`nix-build ./instances/c2.large.arm.nix`. However, I am not and this
is a bit annoying.

Therefore, I've written `./build-aarch64-linux.sh` which requires a
configuration file of this format:

```
buildHost       root@my.aarch64.builder
pxeHost         netboot@my.netboot.server
pxeDir          /var/lib/nginx/netboot/
opensslServer   my.netboot.server
opensslPort     61616
```

This will copy the derivations to `buildHost` for building, and then
set up an openssl-wrapped netcat tunnel from `buildHost` to
`opensslServer:opensslPort` for transfering the build products.

My laptop will SSH to the `pxeHost` and launch openssl and netcat,
then SSH to the `buildHost` and initiate a connection to
`opensslServer:opensslPort`. If this doesn't work, make sure that
port is open.

# Deploying

After building, copy the resulting directory's files to a web
accessible directory and instruct the server to boot from the
netboot.ipxe file in the result.

On Packet, edit `./create-spot-request.sh` to include the Packet API
information, and the URL of the netboot.ipxe. **This might be
expensive! Make sure you understand what it will cost.**

I always use their spot market, but you could deploy this to a
regular or reserved server just the same.

If you use their spot market, this repository leaves it up as an
exercise to the reader to implement server discovery. Although, if
you're using Hydra, an importer exists at
https://github.com/NixOS/nixos-org-configurations/tree/master/hydra-packet-importer
already.

# Implementation Notes

 - A naive implementation of a remote Nix builder might stick with the
   default unionfs. However, this approach uses a lot of extra CPU and
   causes unstable and broken builds for more complex builds. Because
   of this, we switched to making a full, proper filesystem across all
   the disks present. See: https://github.com/NixOS/nixpkgs/issues/64126

----

_btw: I don't work for Packet. Just a fan._
