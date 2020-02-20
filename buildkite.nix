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
    NIX_SSHOPTS = "-i /etc/aarch64-ssh-private";
  };

  buildId = { plan, subcategory } @ args: "build-${builtins.replaceStrings [ "." ] ["-"] (sourceSlug args) }";
  sourceSlug = { plan, subcategory }:
    "${plan}${if subcategory == null then "" else "-${subcategory}"}";
  toBuildUrl = { plan, subcategory, ... }:
    "http://netboot.gsc.io/hydra-${sourceSlug { inherit plan subcategory; }}/netboot.ipxe";

  mkBuildStep = { platform, plan, subcategory }: {
    id = buildId { inherit plan subcategory; };
    label = "build: ${sourceSlug { inherit plan subcategory; }}";
    command = ''
      set -eux

      export NIX_PATH="nixpkgs=https://nixos.org/channels/nixos-19.09/nixexprs.tar.xz"

      cp /etc/aarch64-build-cfg ./build.cfg
      ./build-${platform}.sh ${sourceSlug { inherit plan subcategory; }}
    '';

    inherit env;

    agents.r13y = true;
    concurrency = 1;
    concurrency_group = "build-${platform}-pxe";
  };

  mkRebootStep = device: { plan, subcategory, ... } @ info: {
    id = "reboot-${device.id}";
    depends_on = buildId { inherit plan subcategory; };
    label = "reboot: ${sourceSlug { inherit plan subcategory; }} -- ${device.facility.code} -- ${device.id}";
    command = let
      dns_target = device.short_id + ".packethost.net";
    in ''
      set -eux

      export NIX_PATH="nixpkgs=https://nixos.org/channels/nixos-19.09/nixexprs.tar.xz"

      cp /etc/aarch64-build-cfg ./build.cfg
      ./reboot.sh ${device.id} ${dns_target} ${device.id}@sos.${device.facility.code}.packet.net
    '';

    inherit env;

    agents.r13y = true;
    concurrency = 2;
    concurrency_group = "reboot-${sourceSlug { inherit (info) plan subcategory; } }";
  };

  to_build = [
    { platform = "x86_64-linux"; plan = "m1.xlarge.x86"; subcategory = null; }
    { platform = "x86_64-linux"; plan = "m2.xlarge.x86"; subcategory = null; }
    { platform = "x86_64-linux"; plan = "m2.xlarge.x86"; subcategory = "big-parallel"; }
    { platform = "x86_64-linux"; plan = "c2.medium.x86"; subcategory = null; }
    { platform = "aarch64-linux"; plan = "c1.large.arm"; subcategory = null; }
    { platform = "aarch64-linux"; plan = "c2.large.arm"; subcategory = null; }
    { platform = "aarch64-linux"; plan = "c2.large.arm"; subcategory = "big-parallel"; }
  ];

in {
  dag = true;
  steps = let
    build_steps = map mkBuildStep to_build;

    reboot_steps = let
      plan_urls = map (todo: { inherit (todo) platform plan subcategory; url = toBuildUrl todo; })
        to_build;

      arch_by_url = builtins.listToAttrs (
        map (todo: { name = todo.url; value = { inherit (todo) platform plan subcategory; }; })
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
