{ config, pkgs, lib, ... }:
{
  options = {
    favorability = lib.mkOption {
      type = lib.types.nullOr lib.types.int;
      default = null;
    };
    packet-nix-builder.hostKeys = lib.mkOption {
      type = lib.types.listOf (lib.types.submodule {
        options = {
          port = lib.mkOption {
            description = "SSH Listening port";
            type = lib.types.port;
          };

          system = lib.mkOption {
            description = "Listening system type";
            type = lib.types.str;
          };

          keyFile = lib.mkOption {
            description = "Location of host key file";
            type = lib.types.str;
          };
        };
      });
    };
  };

  config = {
    hardware.enableAllFirmware = true;

    systemd.services.metadata-setup-ipv6 = {
      enable = ! config.nix.makeAbout;
      wantedBy = [ "multi-user.target" ];
      path = with pkgs; [ iproute curl jq ];
      serviceConfig = {
        Type = "simple";
        Restart = "on-failure";
        RestartSec = "5s";
      };
      script = ''
        set -eux
        set -o pipefail

        defaultDevice=$(ip route get 4.2.2.2 | head -n1 | cut -d' ' -f5)
        eval "$(curl https://metadata.packet.net/metadata \
          | jq -r '
            .network.addresses[]
              | select(.address_family == 6)
              | "ip -6 addr add " + .address + "/" + (.cidr | tostring) + " dev " + $device + "; ip -6 route replace " + .address + " dev " + $device + " proto static; ip -6 route replace default via " + .gateway + " dev " + $device + " proto static"' --arg device "$defaultDevice")"
      '';
    };

    packet-nix-builder.hostKeys = [{
      system = pkgs.stdenv.hostPlatform.system;
      port = builtins.head config.services.openssh.ports;
      keyFile = "/etc/ssh/ssh_host_ed25519_key.pub";
    }];

    system.extraSystemBuilderCmds =
      if config.favorability != null then ''
        echo ${toString config.favorability} > $out/favorability
      '' else "";

    systemd.services.specialise = {
      enable = ! config.nix.makeAbout;
      wantedBy = [ "multi-user.target" ];
      path = with pkgs; [ python3 utillinux curl jq ];
      serviceConfig = {
        Type = "simple";
        Restart = "on-failure";
        RestartSec = "5s";
      };
      unitConfig = {
        X-ReloadIfChanged = false;
        X-RestartIfChanged = false;
        X-StopIfChanged = false;
        X-StopOnReconfiguration = false;
        X-StopOnRemoval = false;
      };
      script =
        let
          specialise = pkgs.runCommand "specialise.py"
            {
              buildInputs = with pkgs; [ python3 python3Packages.mypy python3Packages.black ];
            } ''
            cp ${./specialise.py} ./specialise.py
            patchShebangs ./specialise.py
            mypy ./specialise.py
            black --check --diff ./specialise.py
            mv ./specialise.py $out
          '';
        in
        ''
          set -eux
          set -o pipefail

          plan=$(curl https://metadata.packet.net/metadata | jq -r .plan)
          name=$(curl https://metadata.packet.net/metadata | jq -r .hostname)

          exec python3 ${specialise} "$plan" "$name" "/run/current-system/specialisation"
        '';
    };

    systemd.services.upload-ssh-keys = {
      wantedBy = [ "multi-user.target" ];
      path = with pkgs; [ utillinux curl jq ];
      serviceConfig = {
        Type = "simple";
        Restart = "on-failure";
        RestartSec = "5s";
      };
      unitConfig = {
        X-ReloadIfChanged = false;
        X-RestartIfChanged = false;
        X-StopIfChanged = false;
        X-StopOnReconfiguration = false;
        X-StopOnRemoval = false;
      };
      script =
        let
          cfg = config.packet-nix-builder.hostKeys;
        in
        ''
          set -eux
          set -o pipefail

          root_url=$(curl https://metadata.packet.net/metadata | jq -r .phone_home_url | rev | cut -d '/' -f2- | rev)
          url="$root_url/events"

          tell() {
            data=$(
              jq -n '$ARGS.named | .code |= tonumber' \
               --arg state "$1" \
               --arg code "$2" \
               --arg message "$3"
            )

            curl -v -X POST -d "$data" "$url"
          }

          read_host_key() {
            if [ ! -e "$3" ]; then
              echo "Missing key file: '$3'" >&2
              exit 1
            fi

            jq -n '$ARGS.named | .port |= tonumber | .key |= rtrimstr("\n")' \
              --arg system "$1" \
              --arg port "$2" \
              --rawfile key "$3"
          }

          test -f /run/current-system/about.json
          ${lib.concatMapStringsSep "\n" ({ system, port, keyFile, ... }: ''
            test -f ${lib.escapeShellArgs [ keyFile ]}
            test "x$(cat ${lib.escapeShellArgs [ keyFile ]})" != "x"
          '') cfg}


          message=$(
            (
              set -e
              ${lib.concatMapStringsSep "\n" ({ system, port, keyFile, ... }: ''
                read_host_key ${lib.escapeShellArgs [ system (toString port) keyFile ]}
              '') cfg}
            ) | jq --slurp
          )

          tell succeeded 1001 "$message"
          tell succeeded 1002 "$(cat /run/current-system/about.json)"
        '';
    };
  };
}
