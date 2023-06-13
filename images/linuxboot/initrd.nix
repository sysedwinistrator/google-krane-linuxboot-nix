{
  kernelPackage,
  stdenv,
  go,
  uroot,
  zstd,
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
    ${uroot}/bin/u-root -build binary -o initrd.cpio -uroot-source $src -tmpdir $TMP -uinitcmd=boot -files ${kernelPackage}/lib:/lib core ./cmds/boot/boot
  '';
  installPhase = ''
    cat initrd.cpio | ${zstd}/bin/zstd -T0 -19 | dd conv=sync bs=512 of=$out
  '';
}
