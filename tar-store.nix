{ stdenv, closureInfo, storeContents, xz }:

# like make-squashfs.nix but for tars

stdenv.mkDerivation {
  name = "store.tar";

  nativeBuildInputs = [ xz ];

  buildCommand =
    ''
      closureInfo=${closureInfo { rootPaths = storeContents; }}

      # Also include a manifest of the closures in a format suitable
      # for nix-store --load-db.
      mkdir -p nix/store
      cp $closureInfo/registration nix/store/nix-path-registration

      # Generate the tarball.
      tar -c \
        nix/store/nix-path-registration \
        -C / \
        $(cat $closureInfo/store-paths) \
        | xz -8 -T0 > $out
    '';
}
