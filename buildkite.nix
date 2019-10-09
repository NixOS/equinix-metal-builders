let
  env = {
    NIX_PATH = "nixpkgs=https://nixos.org/channels/nixos-19.09-small";
    NIX_SSHOPTS = "-i /etc/aarch64-ssh-private";
  };

  mkBuildStep = arch: type: {
    label = "build: ${type}";
    command = ''
      set -eux
      cp /etc/aarch64-build-cfg ./build.cfg
      ./build-${arch}.sh ${type}

      echo '${builtins.toJSON (mkRebootSteps type)}' > buildkite-generated.yaml
      buildkite-agent pipeline upload ./buildkite-generated.yaml
    '';

    inherit env;

    agents.r13y = true;
    concurrency = 1;
    concurrency_group = "build-${arch}-pxe";
  };

  mkRebootSteps = type: {
    steps = [
      {
        label = "reboot: ${type}";
        command = ''
          set -eux
          cp /etc/aarch64-build-cfg ./build.cfg
          ./rolling-reboot.sh ${type}
        '';

        inherit env;
        agents.r13y = true;
      }
    ];
  };
in {
  steps = (map (mkBuildStep "x86_64-linux") [
    "m1.xlarge.x86"
    "m2.xlarge.x86"
    "c2.medium.x86"
  ]) ++ (map (mkBuildStep "aarch64-linux") [
    "c1.large.arm"
    "c2.large.arm"
  ]);
}
