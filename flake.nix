{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-23.05";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = {
    self,
    nixpkgs,
    flake-utils,
  }: let
    inherit (nixpkgs.lib.attrsets) recursiveUpdate;
  in
    (recursiveUpdate (
        # tooling, compiled for host system
        flake-utils.lib.eachDefaultSystem (
          system: let
            pkgs = import nixpkgs {inherit system;};
          in {
            packages = {
              uroot = pkgs.buildGoModule rec {
                name = "uroot";
                version = src.rev;

                CGO_ENABLED = 0;

                src = pkgs.fetchFromGitHub {
                  owner = "u-root";
                  repo = "u-root";
                  rev = "b4273b092637ad78ca07f36da43bda09d7276b6b";
                  sha256 = "K6j1xn+Pz4YTMR6eIhFr3xhEKML8rJV5GtV9J3sGx4g=";
                };

                vendorHash = null;

                doCheck = false; # currently broken as it expects /bin/bash and /bin/ls
              };

              depthcharge-tools = let
                inherit (pkgs.python3Packages) buildPythonPackage fetchPypi setuptools;
              in
                buildPythonPackage rec {
                  pname = "depthcharge-tools";
                  version = "0.6.1";

                  propagatedBuildInputs = [setuptools];

                  src = fetchPypi {
                    inherit pname version;
                    sha256 = "sha256-JICP7+Zfn4EBg793mvXv4U4zccbM8KYJoiW1NNKFCTI=";
                  };
                };

              initrd = let
                inherit (self.packages."${system}") uroot kernel;
              in
                pkgs.stdenv.mkDerivation {
                  name = "initrd.cpio.zstd";
                  inherit (uroot) src;
                  buildInputs = [pkgs.go];
                  env = {
                    GOARCH = "arm64";
                    GOCACHE = "/tmp/gocache";
                    GOROOT = "${pkgs.go}/share/go";
                  };
                  buildPhase = ''
                    ${uroot}/bin/u-root -build binary -o initrd.cpio -uroot-source $src -tmpdir $TMP -uinitcmd=boot -files ${kernel}/lib:/lib core ./cmds/boot/boot
                  '';
                  installPhase = ''
                    cat initrd.cpio | ${pkgs.zstd}/bin/zstd -T0 -19 | dd conv=sync bs=512 of=$out
                  '';
                };

              uImage = let
                inherit (self.packages."${system}") kernel initrd;
              in
                pkgs.callPackage ./mkuImage.nix {
                  kernelPath = "${kernel}/Image";
                  dtbPath = "${kernel}/dtbs/mediatek/mt8183-kukui-krane-sku176.dtb";
                  initrdPath = initrd;
                };

              uImageLive = let
                inherit (self.nixosConfigurations.live.config.system.build) kernel initialRamdisk;
              in
                pkgs.callPackage ./mkuImage.nix {
                  kernelPath = "${kernel}/Image";
                  dtbPath = "${kernel}/dtbs/mediatek/mt8183-kukui-krane-sku176.dtb";
                  initrdPath = "${initialRamdisk}/initrd.zst";
                };
depthcharge-image-live = let
                inherit (self.packages."${system}") uImageLive;
                keyDir = "${pkgs.vboot_reference}/share/vboot/devkeys";
              in
                pkgs.stdenv.mkDerivation {
                  name = "depthcharge-image-live";
                  unpackPhase = "true";
                  nativeBuildInputs = [
                    pkgs.ubootTools
                    pkgs.dtc
                    pkgs.vboot_reference
                  ];
                  buildPhase = ''
                    dd if=/dev/zero of=bootloader.bin bs=512 count=1
                    echo "init=${self.nixosConfigurations.live.config.system.build.toplevel}/init console=tty0 console=tty1" > config
                    mkdir -p $out/image
                    futility vbutil_kernel --pack $out/image/image --keyblock ${keyDir}/kernel.keyblock --signprivate ${keyDir}/kernel_data_key.vbprivk --bootloader bootloader.bin --vmlinuz ${uImageLive} --config config --arch aarch64 --version 1
                  '';
                  installPhase = "true";
                  dontFixup = true;
                  dontStrip = true;
                };

              depthcharge-image-live-tools = let
                inherit (self.nixosConfigurations.live.config.system.build) kernel initialRamdisk;
                keyDir = "${pkgs.vboot_reference}/share/vboot/devkeys";
              in
                pkgs.stdenv.mkDerivation {
                  name = "depthcharge-image";
                  # inherit (pkgs.ubootTools) src;
                  unpackPhase = "true";
                  configurePhase = "true";
                  nativeBuildInputs = [
                    pkgs.ubootTools
                    pkgs.dtc
                    pkgs.vboot_reference
                    self.packages."${system}".depthcharge-tools
                  ];
                  buildPhase = ''
                    mkdir -p $out/image
                    mkdepthcharge -v -o $out/image/image --tmpdir $TMPDIR -A arm64 -C none --keydir ${keyDir} -d ${kernel}/Image -i ${initialRamdisk}/initrd.zst -b ${kernel}/dtbs/mediatek/mt8183-kukui-krane-sku176.dtb
                  '';
                };

              depthcharge-image = let
                inherit (self.packages."${system}") kernel uImage;
                keyDir = "doc/chromium/files/devkeys";
              in
                pkgs.stdenv.mkDerivation {
                  name = "depthcharge-image";
                  inherit (pkgs.ubootTools) src;
                  configurePhase = "true";
                  nativeBuildInputs = [
                    pkgs.ubootTools
                    pkgs.dtc
                    pkgs.vboot_reference
                  ];
                  buildPhase = ''
                    dd if=/dev/zero of=bootloader.bin bs=512 count=1
                    echo "console=tty0" > config
                    mkdir -p $out/image
                    futility vbutil_kernel --pack $out/image/image --keyblock ${keyDir}/kernel.keyblock --signprivate ${keyDir}/kernel_data_key.vbprivk --bootloader bootloader.bin --vmlinuz ${uImage} --config config --arch arm64 --version 1
                  '';
                  installPhase = "true";
                };

              depthcharge-image-tools = let
                inherit (self.packages."${system}") kernel initrd;
                keyDir = "doc/chromium/files/devkeys";
              in
                pkgs.stdenv.mkDerivation {
                  name = "depthcharge-image";
                  inherit (pkgs.ubootTools) src;
                  configurePhase = "true";
                  nativeBuildInputs = [
                    pkgs.ubootTools
                    pkgs.dtc
                    pkgs.vboot_reference
                    self.packages."${system}".depthcharge-tools
                  ];
                  buildPhase = ''
                    mkdir $out/image
                    mkdepthcharge -o $out/image/image --tmpdir $TMPDIR -A arm64 -C lzma --keyblock ${keyDir}/kernel.keyblock --signprivate ${keyDir}/kernel_data_key.vbprivk ${kernel}/Image ${initrd} ${kernel}/dtbs/mediatek/mt8183-kukui-krane-sku176.dtb
                  '';
                };

              liveRootFs = pkgs.callPackage "${nixpkgs.outPath}/nixos/lib/make-ext4-fs.nix" {
                storePaths = [self.nixosConfigurations.live.config.system.build.toplevel];
                compressImage = false;
                volumeLabel = "NIXOS_LIVE";
              };

              liveImage = let
                boot = self.packages."${system}".depthcharge-image-live;
                rootfs = self.packages."${system}".liveRootFs;
              in
                pkgs.stdenv.mkDerivation {
                  name = "live-image";
                  unpackPhase = "true";
                  buildInputs = [
                    pkgs.parted
                    pkgs.vboot_reference
                    pkgs.util-linux
                  ];
                  buildPhase = ''
                    gap=2048
                    bootSizeBlocks=$(du -B 512 --apparent-size ${boot}/image/image | awk '{ print $1 }')
                    rootSizeBlocks=$(du -B 512 --apparent-size ${rootfs} | awk '{ print $1 }')
                    imageSize=$((bootSizeBlocks * 512 + rootSizeBlocks * 512 + gap * 512))


                    img=$out
                    truncate -s $imageSize $img
                    echo PASS 0

                    # parted $img mklabel gpt
                    # gapBytes=$((gap * 1024 * 1024))
                    # bootPartitionEnd=$((gapBytes + bootSizeBlocks * 512))

                    # parted --script $img -- \
                    #   mklabel gpt \
                    #   unit MiB \
                    #   mkpart Kernel $gap $(((bootSizeBlocks * 512)/(1024 * 1024))) \
                    #   align-check optimal 1 \
                    #   mkpart Root $(((bootSizeBlocks * 512)/(1024 * 1024) + 30 )) 100% \
                    #   align-check optimal 2 \
                    #   print

                    sfdisk $img <<EOF
                        label: gpt

                        start=$gap, size=$bootSizeBlocks
                        start=$((gap + bootSizeBlocks))
                    EOF

                    echo PASS 1

                    cgpt add -i 1 -t kernel -S 1 -T 5 -P 15 $img
                    echo PASS 2


                    eval $(partx $img -o START,SECTORS --nr 1 --pairs)
                    dd conv=notrunc if=${boot}/image/image of=$img seek=$START count=$SECTORS

                    eval $(partx $img -o START,SECTORS --nr 2 --pairs)
                    dd conv=notrunc if=${rootfs} of=$img seek=$START count=$SECTORS

                    echo PASS 3
                  '';
                  fixupPhase = "true";
                };
            };
          }
        )
      ) (
        # packages, compiled for arm64
        flake-utils.lib.eachDefaultSystem (system: let
          pkgs =
            if system == "aarch64-linux"
            then import nixpkgs {inherit system;}
            else
              import nixpkgs {
                inherit system;
                crossSystem = {config = "aarch64-unknown-linux-gnu";};
              };
          inherit (pkgs) lib;
        in {
          packages = {
            kernel = pkgs.linux.override {
              structuredExtraConfig = let
                inherit (lib.kernel) freeform module no option unset whenHelpers yes;
              in {
                KEYBOARD_MT6779 = yes;
                KEYBOARD_MTK_PMIC = yes;

                DRM_MEDIATEK_DP = module;

                NET_VENDOR_MEDIATEK = yes;
                NET_MEDIATEK_SOC = module;

                ARCH_ACTIONS = no;
                ARCH_SUNXI = no;
                ARCH_ALPINE = no;
                ARCH_APPLE = no;
                ARCH_BCM = no;
                ARCH_BERLIN = no;
                ARCH_BITMAIN = no;
                ARCH_EXYNOS = no;
                ARCH_SPARX5 = no;
                ARCH_K3 = no;
                ARCH_LG1K = no;
                ARCH_HISI = no;
                ARCH_KEEMBAY = no;
                ARCH_MESON = no;
                ARCH_MVEBU = no;
                ARCH_NXP = no;
                ARCH_NPCM = no;
                ARCH_QCOM = no;
                ARCH_REALTEK = no;
                ARCH_RENESAS = no;
                ARCH_ROCKCHIP = no;
                ARCH_SEATTLE = no;
                ARCH_INTEL_SOCFPGA = no;
                ARCH_SYNQUACER = no;
                ARCH_TEGRA = no;
                ARCH_SPRD = no;
                ARCH_THUNDER = no;
                ARCH_THUNDER2 = no;
                ARCH_UNIPHIER = no;
                ARCH_VEXPRESS = no;
                ARCH_VISCONTI = no;
                ARCH_XGENE = no;
                ARCH_ZYNQMP = no;
                ARM64_SVE = no;
                SURFACE_PLATFORMS = no;

                VIRTUALIZATION = no;
                XEN = lib.mkForce no;
                VIRTIO_MENU = no;
                VIRTIO_BLK = no;
                VIRTIO_CONSOLE = no;
                VIRTIO_NET = no;

                SUSPEND = no;
                HIBERNATION = no;

                FUSE_FS = no;

                WLAN = no;
                BT = no;
                NFC = no;
                CAN = no;
                GNSS = no;

                NET_VENDOR_3COM = no;
                NET_VENDOR_8390 = no;
                NET_VENDOR_ACTIONS = no;
                NET_VENDOR_ADAPTEC = no;
                NET_VENDOR_ADI = no;
                NET_VENDOR_AEROFLEX = no;
                NET_VENDOR_AGERE = no;
                NET_VENDOR_ALACRITECH = no;
                NET_VENDOR_ALLWINNER = no;
                NET_VENDOR_ALTEON = no;
                NET_VENDOR_ALTERA = no;
                NET_VENDOR_AMAZON = no;
                NET_VENDOR_AMD = no;
                NET_VENDOR_APM = no;
                NET_VENDOR_APPLE = no;
                NET_VENDOR_AQUANTIA = no;
                NET_VENDOR_ARC = no;
                NET_VENDOR_ASIX = no;
                NET_VENDOR_ATHEROS = no;
                NET_VENDOR_BROADCOM = no;
                NET_VENDOR_BROCADE = no;
                NET_VENDOR_CADENCE = no;
                NET_VENDOR_CALXEDA = no;
                NET_VENDOR_CAVIUM = no;
                NET_VENDOR_CHELSIO = no;
                NET_VENDOR_CIRRUS = no;
                NET_VENDOR_CISCO = no;
                NET_VENDOR_CORTINA = no;
                NET_VENDOR_DAVICOM = no;
                NET_VENDOR_DEC = no;
                NET_VENDOR_DLINK = no;
                NET_VENDOR_EMULEX = no;
                NET_VENDOR_ENGLEDER = no;
                NET_VENDOR_EZCHIP = no;
                NET_VENDOR_FARADAY = no;
                NET_VENDOR_FREESCALE = no;
                NET_VENDOR_FUJITSU = no;
                NET_VENDOR_FUNGIBLE = no;
                NET_VENDOR_GOOGLE = no;
                NET_VENDOR_HISILICON = no;
                NET_VENDOR_HUAWEI = no;
                NET_VENDOR_I825XX = no;
                NET_VENDOR_IBM = no;
                NET_VENDOR_INTEL = no;
                NET_VENDOR_LITEX = no;
                NET_VENDOR_MARVELL = no;
                NET_VENDOR_MELLANOX = no;
                NET_VENDOR_MICREL = no;
                NET_VENDOR_MICROCHIP = no;
                NET_VENDOR_MICROSOFT = no;
                NET_VENDOR_MOXA = no;
                NET_VENDOR_MSCC = no;
                NET_VENDOR_MYRICOM = no;
                NET_VENDOR_NATSEMI = no;
                NET_VENDOR_NETERION = no;
                NET_VENDOR_NETRONOME = no;
                NET_VENDOR_NI = no;
                NET_VENDOR_NVIDIA = no;
                NET_VENDOR_NXP = no;
                NET_VENDOR_OKI = no;
                NET_VENDOR_PACKETENGINES = no;
                NET_VENDOR_PASEMI = no;
                NET_VENDOR_PENSANDO = no;
                NET_VENDOR_QLOGIC = no;
                NET_VENDOR_RDC = no;
                NET_VENDOR_RENESAS = no;
                NET_VENDOR_ROCKER = no;
                NET_VENDOR_SAMSUNG = no;
                NET_VENDOR_SEEQ = no;
                NET_VENDOR_SFC = no;
                NET_VENDOR_SGI = no;
                NET_VENDOR_SILAN = no;
                NET_VENDOR_SIS = no;
                NET_VENDOR_SMSC = no;
                NET_VENDOR_SOCIONEXT = no;
                NET_VENDOR_STMICRO = no;
                NET_VENDOR_SUN = no;
                NET_VENDOR_SUNPLUS = no;
                NET_VENDOR_SYNOPSYS = no;
                NET_VENDOR_TEHUTI = no;
                NET_VENDOR_TI = no;
                NET_VENDOR_TOSHIBA = no;
                NET_VENDOR_TUNDRA = no;
                NET_VENDOR_VERTEXCOM = no;
                NET_VENDOR_VIA = no;
                NET_VENDOR_WANGXUN = no;
                NET_VENDOR_WIZNET = no;
                NET_VENDOR_XILINX = no;
                NET_VENDOR_XIRCOM = no;
                NET_VENDOR_XSCALE = no;

                SOUND = no;
                SOUNDWIRE = no;

                MEDIA_SUPPORT = no;
                DRM_NOUVEAU = no;
                DRM_AMDGPU = no;
                DRM_RADEON = no;
                DRM_VMWGFX = no;
                DRM_LIMA = no;
                DRM_ETNAVIV = no;
                DRM_HISI_HIBMC = no;
                DRM_HISI_KIRIN = no;

                INFINIBAND = lib.mkForce no;
              };
            };
          };
        })
      ))
    // {
      nixosConfigurations.live = nixpkgs.lib.nixosSystem rec {
        system = "aarch64-linux";
        pkgs = nixpkgs.legacyPackages."${system}";
        modules = [
          "${nixpkgs.outPath}/nixos/modules/profiles/base.nix"
          "${nixpkgs.outPath}/nixos/modules/profiles/all-hardware.nix"
          "${nixpkgs.outPath}/nixos/modules/profiles/installation-device.nix"
          ({...}: {
            fileSystems."/" = {
              device = "/dev/disk/by-label/NIXOS_LIVE";
              fsType = "ext4";
            };
            boot.loader.grub.enable = false;
            boot.loader.generic-extlinux-compatible.enable = true;
            boot.consoleLogLevel = pkgs.lib.mkDefault 7;

            boot.kernelPatches = [
              {
                name = "display";
                patch = ./01-RESEND-v2-1-2-drm-panel-Add-inx-Himax8279d-MIPI-DSI-LCD-panel-driver.patch;
                structuredExtraConfig = let
                  inherit (pkgs.lib.kernel) freeform module no option unset whenHelpers yes;
                in {
                  DRM_PANEL_INNOLUX_HIMAX8279D = yes;
                };
              }
            ];
          })
        ];
      };
    };
}
