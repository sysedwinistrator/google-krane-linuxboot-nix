{
  pkgs,
  kernelPath,
  kernelCompression ? "none",
  dtbPath,
  dtbCompression ? "none",
  initrdPath,
  initrdCompression ? "none",
}: let
  configIts = pkgs.writeTextFile {
    name = "config.its";
    text = ''
      /*
       * Simple U-Boot uImage source file containing a single kernel and FDT blob
       */

      /dts-v1/;

      / {
        description = "Simple image with single Linux kernel and FDT blob";
        #address-cells = <1>;

        images {
          kernel {
            description = "Vanilla Linux kernel";
            data = /incbin/("${kernelPath}");
            type = "kernel_noload";
            arch = "arm64";
            os = "linux";
            compression = "${kernelCompression}";
            hash-1 {
              algo = "sha1";
            };
          };
          fdt-1 {
            description = "Flattened Device Tree blob";
            data = /incbin/("${dtbPath}");
            type = "flat_dt";
            arch = "arm64";
            compression = "${dtbCompression}";
            hash-1 {
              algo = "sha1";
            };
          };
          ramdisk-1 {
            description = "Compressed Initramfs";
            data = /incbin/("${initrdPath}");
            type = "ramdisk";
            arch = "arm64";
            os = "linux";
            compression = "${initrdCompression}";
            hash-1 {
              algo = "sha1";
            };
          };
        };

        configurations {
          default = "conf-1";
          conf-1 {
            description = "Boot Linux kernel with FDT blob";
            kernel = "kernel";
            fdt = "fdt-1";
            ramdisk = "ramdisk-1";
            loadables = "kernel";
            compatible = "google,krane-sku176 google,krane mediatek,mt8183";
          };
        };
      };
    '';
  };
in
  pkgs.stdenv.mkDerivation {
    name = "uImage";
    unpackPhase = "true";
    nativeBuildInputs = [
      pkgs.ubootTools
      pkgs.dtc
    ];
    buildPhase = ''
      mkimage -f ${configIts} $out
    '';
    dontFixup = true;
    dontStrip = true;
  }
