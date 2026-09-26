{
  stdenv,
  cpio,
  rsync,
  paths ? [],
}:
stdenv.mkDerivation {
  name = "initrd.cpio";
  # No source to unpack
  unpackPhase = "true";
  buildPhase = let
    copyCmds =
      builtins.map (path: ''
        if [ -d ${path.src} ]; then
          mkdir -p $tmpdir/${path.dest}
        else
          _dirname=$(dirname ${path.dest})
          mkdir -p $tmpdir/$_dirname
          # Ensure target directory is writable
          chmod 755 $tmpdir/$_dirname
        fi
        ${rsync}/bin/rsync -rvLt ${path.src} $tmpdir/${path.dest}
      '')
      paths;

    copyCmdsString = builtins.concatStringsSep "\n" copyCmds;
  in ''
    export tmpdir=$(mktemp -d)

    ${copyCmdsString}

    cd $tmpdir
    find | ${cpio}/bin/cpio -ov --format=newc > $out
  '';
}
