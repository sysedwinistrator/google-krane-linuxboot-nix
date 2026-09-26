{
  lib,
  uimg,
  kernelCmdline ? "",
  kernelKeyblock ? "${vboot_reference}/share/vboot/devkeys/kernel.keyblock",
  signPrivate ? "${vboot_reference}/share/vboot/devkeys/kernel_data_key.vbprivk",
  stdenv,
  ubootTools,
  dtc,
  vboot_reference,
}:
stdenv.mkDerivation {
  name = "depthcharge-image-live";
  unpackPhase = "true";
  nativeBuildInputs = [
    ubootTools
    dtc
    vboot_reference
  ];
  buildPhase = ''
    dd if=/dev/zero of=bootloader.bin bs=512 count=1
    echo ${lib.escapeShellArg kernelCmdline} > config
    mkdir -p $out/image
    futility vbutil_kernel --pack $out/image/image --keyblock ${kernelKeyblock} --signprivate ${signPrivate} --bootloader bootloader.bin --vmlinuz ${uimg} --config config --arch aarch64 --version 1
  '';
  installPhase = "true";
  dontFixup = true;
  dontStrip = true;
}
