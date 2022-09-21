(import ../make-netboot.nix)
{
  buildSystem = "x86_64-linux";
  hardware = { pkgs, ... }: { };
}
