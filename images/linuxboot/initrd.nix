{
  kernelPackage,
  stdenv,
  go,
  uroot,
}:
stdenv.mkDerivation {
  name = "initrd.cpio.zstd";
  inherit (uroot) src;
  buildInputs = [go];
  env = {
    GOARCH = "arm64";
    GOCACHE = "/tmp/gocache";
    GOROOT = "${go}/share/go";
  };
  buildPhase = ''
    ${uroot}/bin/u-root -build binary -o $out -uroot-source $src -tmpdir $TMP -uinitcmd=boot -files ${kernelPackage}/lib:/lib core ./cmds/boot/boot
  '';
}
