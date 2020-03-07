{ pkgs, config, baseModules, modules, lib, ... }:
let
  inherit (lib) mapAttrs mkOption types optionals concatStringsSep
    mapAttrsToList mkOverride;

  children = mapAttrs (childName: childConfig:
    (import "${pkgs.path}/nixos/lib/eval-config.nix" {
        inherit baseModules;
        modules =
           (optionals childConfig.inheritParentConfig modules)
           ++ [ { specialisation = mkOverride 0 {}; } ]
        ++ [ childConfig.configuration ];
      }).config.system.build.toplevel
    ) config.specialisation;

in {
  options = {
    specialisation = mkOption {
      default = {};
      example = lib.literalExample "{ fewJobsManyCores.configuration = { nix.buildCores = 0; nix.maxJobs = 1; }; }";
      description = ''
        Additional configurations to build. If
        <literal>inheritParentConfig</literal> is true, the system
        will be based on the overall system configuration.

        To switch to a specialised configuration
        (e.g. <literal>fewJobsManyCores</literal>) at runtime, run:

        <programlisting>
        # sudo /run/current-system/specialisation/fewJobsManyCores/bin/switch-to-configuration test
        </programlisting>
      '';
      type = types.attrsOf (types.submodule (
        { ... }: {
          options.inheritParentConfig = mkOption {
            type = types.bool;
            default = true;
            description = "Include the entire system's configuration. Set to false to make a completely differently configured system.";
          };

          options.configuration = mkOption {
            default = {};
            description = "Arbitrary NixOS configuration options.";
          };
        })
      );
    };
  };

  config = {
    system.extraSystemBuilderCmds = ''
      mkdir $out/specialisation
      ${concatStringsSep "\n"
      (mapAttrsToList (name: path: "ln -s ${path} $out/specialisation/${name}") children)}
    '';
  };

}
