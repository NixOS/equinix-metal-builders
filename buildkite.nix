let
  mkBuildStep = arch: type: {
    label = "build: ${type}";
    command = ''
      set -eux
      cp /etc/aarch64-build-cfg ./build.cfg
      ./build-${arch}.sh ${type}

      echo '${builtins.toJSON (mkRebootSteps type)}' > buildkite-generated.yaml
      buildkite-agent pipeline upload ./buildkite-generated.yaml
    '';
    env = {
      NIX_PATH = "nixpkgs=https://nixos.org/channels/nixos-19.03-small";
      NIX_SSHOPTS = "-i /etc/aarch64-ssh-private";
    };

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
        env = {
          NIX_PATH = "nixpkgs=https://nixos.org/channels/nixos-19.03-small";
          NIX_SSHOPTS = "-i /etc/aarch64-ssh-private";
        };
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

/*
steps:
  - label: m2.xlarge.x86
    command: cp /etc/aarch64-build-cfg ./build.cfg && ./build-x86-64-linux.sh m2.xlarge.x86 && ./rolling-reboot.sh m2.xlarge.arm
    env:
      NIX_PATH: "nixpkgs=https://nixos.org/channels/nixos-19.03-small"
      NIX_SSHOPTS: "-i /etc/aarch64-ssh-private"
    agents:
      r13y: true
    concurrency: 1
    concurrency_group: 'build-x86_64-linux'

  - label: c2.large.arm
    command: cp /etc/aarch64-build-cfg ./build.cfg && ./build-aarch64-linux.sh c2.large.arm && ./rolling-reboot.sh c2.large.arm
    env:
      NIX_PATH: "nixpkgs=https://nixos.org/channels/nixos-19.03-small"
      NIX_SSHOPTS: "-i /etc/aarch64-ssh-private"
    agents:
      r13y: true
    concurrency: 1
    concurrency_group: 'build-aarch64-linux'

  - label: c1.large.arm
    command: cp /etc/aarch64-build-cfg ./build.cfg && ./build-aarch64-linux.sh c1.large.arm && ./rolling-reboot.sh c1.large.arm
    env:
      NIX_PATH: "nixpkgs=https://nixos.org/channels/nixos-19.03-small"
      NIX_SSHOPTS: "-i /etc/aarch64-ssh-private"
    agents:
      r13y: true
    concurrency: 1
    concurrency_group: 'build-aarch64-linux'

*/
