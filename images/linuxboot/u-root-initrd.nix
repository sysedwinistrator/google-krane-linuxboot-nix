{
  stdenv,
  u-root,
  go,
  extraPaths,
}:
stdenv.mkDerivation {
  name = "initrd.cpio";

  inherit (u-root) src;

  buildInputs = [
    u-root
    go
  ];

  preConfigure = ''
    export GOCACHE=$TMPDIR/go-cache
    export GOPATH="$TMPDIR/go"
    export GOPROXY=off
    export GOSUMDB=off
  '';

  buildPhase = let
    extraFileArgs = builtins.concatStringsSep " " (map (path: "-files ${path.src}:${path.dest}") extraPaths);
  in ''
    u-root -v -o $out -build gbb -uinitcmd=/bbin/gosh -defaultsh=/bbin/gosh ${extraFileArgs} core boot
  '';
}
