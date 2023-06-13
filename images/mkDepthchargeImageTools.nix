{
  kernel,
  dtb,
  initrd,
  keyDir ? "${vboot_reference}/share/vboot/devkeys",
  stdenv,
  ubootTools,
  dtc,
  vboot_reference,
  depthcharge-tools,
}:
stdenv.mkDerivation {
  name = "depthcharge-image";
  unpackPhase = "true";
  configurePhase = "true";
  nativeBuildInputs = [
    ubootTools
    dtc
    vboot_reference
    depthcharge-tools
  ];
  buildPhase = ''
    mkdir -p $out/image
    mkdepthcharge -v -o $out/image/image --tmpdir $TMPDIR -A arm64 -C none --keydir ${keyDir} -d ${kernel} -i ${initrd} -b ${dtb}
  '';
}
