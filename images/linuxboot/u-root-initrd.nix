{
  stdenv,
  u-root,
  go,
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

  buildPhase = ''
    u-root -v -o $out -build gbb -uinitcmd=/bin/gosh -defaultsh=/bin/gosh core boot
  '';
}
