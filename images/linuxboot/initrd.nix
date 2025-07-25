{
  stdenv,
  cpio,
  rsync,
  zstd,
  paths ? [],
}:
stdenv.mkDerivation {
  name = "initrd.cpio.zstd";
  # No source to unpack
  unpackPhase = "true";
  buildPhase = let
    copyCmds =
      builtins.map (path: ''
        mkdir -p $tmpdir/${path.dest}
        ${rsync}/bin/rsync -rvLt ${path.src} $tmpdir/${path.dest}
      '')
      paths;

    copyCmdsString = builtins.concatStringsSep "\n" copyCmds;
  in ''
    export tmpdir=$(mktemp -d)

    ${copyCmdsString}

    cd $tmpdir
    find | ${cpio}/bin/cpio -ov | ${zstd}/bin/zstd -19 -T0 > $out
  '';
}
