let
  devices = let
    raw_data = builtins.fromJSON (builtins.readFile ./devices.json);
    is_interesting = device: (
      (builtins.elem "hydra" device.tags)
      && (device.operating_system.slug == "custom_ipxe")
    );
  in builtins.filter is_interesting raw_data.devices;

  env = {
    NIX_PATH = "nixpkgs=https://nixos.org/channels/nixos-19.09/nixexprs.tar.xz";
  };

  buildId = { platform } @ args: "build-${builtins.replaceStrings [ "." ] ["-"] (sourceSlug args) }";
  sourceSlug = { platform }:
    "${platform}";
  toBuildUrl = { platform }:
    "http://netboot.gsc.io/hydra-${sourceSlug { inherit platform; }}/netboot.ipxe";

  mkBuildStep = { platform }: {
    id = buildId { inherit platform; };
    label = "build: ${sourceSlug { inherit platform; }}";
    command = ''
      set -eux

      export NIX_PATH="nixpkgs=https://nixos.org/channels/nixos-19.09/nixexprs.tar.xz"

      cp /etc/aarch64-build-cfg ./build.cfg
      ./build-${platform}.sh ${sourceSlug { inherit platform; }}
    '';

    inherit env;

    agents.nixos-foundation-netboot = true;
    concurrency = 1;
    concurrency_group = "build-${platform}-pxe";
  };

  mkRebootStep = device: { platform, ... } @ info: {
    id = "reboot-${device.id}";
    depends_on = buildId { inherit platform; };
    label = "reboot: ${sourceSlug { inherit platform; }} -- ${device.plan.slug} -- ${device.facility.code} -- ${device.id}";
    command = let
      dns_target = device.short_id + ".packethost.net";
    in ''
      set -eux

      export NIX_PATH="nixpkgs=https://nixos.org/channels/nixos-19.09/nixexprs.tar.xz"

      cp /etc/aarch64-build-cfg ./build.cfg
      ./reboot.sh ${device.id} ${dns_target} ${device.id}@sos.${device.facility.code}.packet.net
    '';

    inherit env;

    agents.nixos-foundation-netboot = true;
    concurrency = 2;
    concurrency_group = "reboot-${sourceSlug { inherit platform; } }";
  };

  to_build = [
    { platform = "x86_64-linux"; }
    { platform = "aarch64-linux"; }
  ];

in {
  dag = true;
  steps = let
    build_steps = map mkBuildStep to_build;

    reboot_steps = let
      plan_urls = map (todo: { inherit (todo) platform; url = toBuildUrl todo; })
        to_build;

      arch_by_url = builtins.listToAttrs (
        map (todo: { name = todo.url; value = { inherit (todo) platform; }; })
        plan_urls
      );

      interesting_urls = builtins.attrNames arch_by_url;

      devices_to_reboot = builtins.filter
        (device: builtins.elem device.ipxe_script_url interesting_urls)
        devices;
    in
    (map (device: mkRebootStep device arch_by_url."${device.ipxe_script_url}") devices_to_reboot);

  in build_steps ++ reboot_steps;
}
