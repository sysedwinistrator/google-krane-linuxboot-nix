{
  stdenv,
  u-root,
  go,
  extraPaths,
  urootPkgs ? [
    "core"
    "boot"
    "./cmds/exp/modprobe"
  ]
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
    urootPkgsArgs = builtins.concatStringsSep " " urootPkgs;
  in ''
    u-root -v -o $out -build bb -uinitcmd=/bbin/gosh -defaultsh=/bbin/gosh ${extraFileArgs} ${urootPkgsArgs}
  '';
}
