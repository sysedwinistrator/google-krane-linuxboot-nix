{
  stdenv,
  go,
  uroot,
  extraFiles ? [],
  uinitcmd ? "boot",
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
  buildPhase = let
    extraFileArg = builtins.concatStringsSep " " (builtins.map (file: "-files ${file}") extraFiles);
  in ''
    ${uroot}/bin/u-root -build binary -o $out -uroot-source $src -tmpdir $TMP -uinitcmd="${uinitcmd}" ${extraFileArg} core ./cmds/boot/boot
  '';
}
