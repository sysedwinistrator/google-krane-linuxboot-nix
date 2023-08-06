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
    inherit (builtins) mapAttrs;
    inherit (nixpkgs.lib.attrsets) recursiveUpdate;
    eachSystem = expr:
      flake-utils.lib.eachSystem [
        flake-utils.lib.system.aarch64-linux
        flake-utils.lib.system.x86_64-linux
      ]
      expr;
  in
    (recursiveUpdate (
        # tooling, compiled for host system
        eachSystem (
          system: let
            pkgs = import nixpkgs {inherit system;};
            inherit (pkgs) callPackage;
          in {
            packages = {
              uroot = callPackage ./pkgs/u-root.nix {};

              depthcharge-tools = callPackage ./pkgs/depthcharge-tools.nix {};

              linuxboot-initrd = callPackage ./images/linuxboot/initrd.nix {
                kernelPackage = self.packages."${system}".kernel;
                uroot = self.packages."${system}".uroot;
              };

              linuxboot-initrd-pm = callPackage ./images/linuxboot/initrd.nix {
                kernelPackage = self.packages."${system}".pmKernel;
                uroot = self.packages."${system}".uroot;
              };

              pmKernel = pkgs.stdenv.mkDerivation {
                name = "pmkernelapk";
                src = pkgs.fetchurl {
                  url = "https://mirror.postmarketos.org/postmarketos/master/aarch64/linux-postmarketos-mediatek-mt8183-6.1.28-r1.apk";
                  sha256 = "sha256-1LUxPVOAA86lB6Xmqzyatlwtqp1f1KU8Tctp3DJgVwk=";
                };
                unpackPhase = "true";
                buildPhase = "true";
                installPhase = ''
                  mkdir $out
                  tar -C $out -xf $src
                  cat $out/boot/vmlinuz | gzip -d > $out/boot/Image
                '';
                fixupPhase = "true";
              };

              linuxboot-uimg = let
                inherit (self.packages."${system}") kernel linuxboot-initrd;
              in
                callPackage ./images/mkuImage.nix {
                  kernelPath = "${kernel}/Image";
                  dtbPath = "${kernel}/dtbs/mediatek/mt8183-kukui-krane-sku176.dtb";
                  initrdPath = linuxboot-initrd;
                };

              linuxboot-uimg-pm = let
                inherit (self.packages."${system}") pmKernel linuxboot-initrd-pm;
              in
                callPackage ./images/mkuImage.nix {
                  kernelPath = "${pmKernel}/boot/Image";
                  dtbPath = "${pmKernel}/boot/dtbs/mediatek/mt8183-kukui-krane-sku176.dtb";
                  initrdPath = linuxboot-initrd-pm;
                };

              nixos-uimg = let
                inherit (self.nixosConfigurations.live.config.system.build) kernel initialRamdisk;
              in
                callPackage ./images/mkuImage.nix {
                  kernelPath = "${kernel}/Image";
                  dtbPath = "${kernel}/dtbs/mediatek/mt8183-kukui-krane-sku176.dtb";
                  initrdPath = "${initialRamdisk}/initrd";
                };

              nixos-depthcharge-img = callPackage ./images/mkDepthchargeImage.nix {
                uimg = self.packages."${system}".nixos-uimg;
                kernelCmdline = "init=${self.nixosConfigurations.live.config.system.build.toplevel}/init console=ttyS0 console=tty0 console=tty1";
              };

              nixos-depthcharge-img-tools = let
                inherit (self.nixosConfigurations.live.config.system.build) kernel initialRamdisk;
              in
                callPackage ./images/mkDepthchargeImageTools.nix {
                  kernel = "${kernel}/Image";
                  dtb = "${kernel}/dtbs/mediatek/mt8183-kukui-krane-sku176.dtb";
                  initrd = "${initialRamdisk}/initrd.zst";
                  inherit (self.packages."${system}") depthcharge-tools;
                };

              linuxboot-depthcharge-img = callPackage ./images/mkDepthchargeImage.nix {
                uimg = self.packages."${system}".linuxboot-uimg;
                kernelCmdline = "console=ttyS0 console=tty0 init=/init";
              };

              linuxboot-depthcharge-img-pm = callPackage ./images/mkDepthchargeImage.nix {
                uimg = self.packages."${system}".linuxboot-uimg-pm;
                kernelCmdline = "console=ttyS0 console=tty0 init=/init";
              };

              linuxboot-depthcharge-img-tools = let
                inherit (self.packages."${system}") depthcharge-tools kernel linuxboot-initrd;
              in
                callPackage ./images/mkDepthchargeImageTools.nix {
                  kernel = "${kernel}/Image";
                  dtb = "${kernel}/dtbs/mediatek/mt8183-kukui-krane-sku176.dtb";
                  initrd = linuxboot-initrd;
                  inherit depthcharge-tools;
                };

              linuxboot-image = let
                inherit (self.packages."${system}") linuxboot-depthcharge-img;
              in
                callPackage ./images/mkChromebookImage.nix {
                  bootImg = "${linuxboot-depthcharge-img}/image/image";
                };

              linuxboot-image-pm = let
                inherit (self.packages."${system}") linuxboot-depthcharge-img-pm;
              in
                callPackage ./images/mkChromebookImage.nix {
                  bootImg = "${linuxboot-depthcharge-img-pm}/image/image";
                };

              nixos-rootfs = callPackage "${nixpkgs.outPath}/nixos/lib/make-ext4-fs.nix" {
                storePaths = [self.nixosConfigurations.live.config.system.build.toplevel];
                compressImage = false;
                volumeLabel = "NIXOS_LIVE";
              };

              nixos-image = let
                bootDrv = self.packages."${system}".nixos-depthcharge-img;
              in
                callPackage ./images/mkChromebookImage.nix {
                  bootImg = "${bootDrv}/image/image";
                  rootImg = self.packages."${system}".nixos-rootfs;
                };
            };
          }
        )
      ) (
        # packages, compiled for arm64
        eachSystem (system: let
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
            kernel = pkgs.linux_6_4.override {
              structuredExtraConfig = let
                inherit (lib) mkForce;
                inherit (lib.kernel) freeform module no option unset whenHelpers yes;
              in {
                MODULE_COMPRESS_XZ = lib.mkForce no;
                MODULE_COMPRESS_NONE = yes;

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

                BT = no;
                NFC = no;
                CAN = no;
                GNSS = no;

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

                INFINIBAND = mkForce no;

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
              };
            };
            modscan = pkgs.buildGoModule rec {
              pname = "modscan";
              version = src.rev;
              src = pkgs.fetchFromGitHub {
                owner = "sysedwinistrator";
                repo = "modscan";
                rev = "731ce4e573a7816d8554549098636e134ae693da";
                sha256 = "sha256-U5xdQESgqpA/nyIAK6ifjTkKbvg42bN11FjxAWgA9SQ=";
              };
              vendorHash = null;
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
          ({config, ...}: {
            fileSystems."/" = {
              device = "/dev/disk/by-label/NIXOS_LIVE";
              fsType = "ext4";
            };
            boot.loader.grub.enable = false;
            boot.loader.generic-extlinux-compatible.enable = true;
            boot.consoleLogLevel = pkgs.lib.mkDefault 7;

            boot.initrd.compressor = "cat";
            boot.initrd.kernelModules = [
              "gpu-sched"
              "i2c-hid-of"
              "hid-multitouch"
              "cros-ec-keyb"
              "sbs-battery"
            ];

            boot.postBootCommands = ''
              # On the first boot do some maintenance tasks
              if [ -f /nix-path-registration ]; then
                set -euo pipefail
                set -x
                # Figure out device names for the boot device and root filesystem.
                rootPart=$(${pkgs.util-linux}/bin/findmnt -n -o SOURCE /)
                bootDevice=$(lsblk -npo PKNAME $rootPart)
                partNum=$(lsblk -npo MAJ:MIN $rootPart | ${pkgs.gawk}/bin/awk -F: '{print $2}')

                # Resize the root partition and the filesystem to fit the disk
                echo ",+," | sfdisk -N$partNum --no-reread $bootDevice
                ${pkgs.parted}/bin/partprobe
                ${pkgs.e2fsprogs}/bin/resize2fs $rootPart

                # Register the contents of the initial Nix store
                ${config.nix.package.out}/bin/nix-store --load-db < /nix-path-registration

                # nixos-rebuild also requires a "system" profile and an /etc/NIXOS tag.
                touch /etc/NIXOS
                ${config.nix.package.out}/bin/nix-env -p /nix/var/nix/profiles/system --set /run/current-system

                # Prevents this from running on later boots.
                rm -f /nix-path-registration
              fi
            '';

            users.users.root.openssh.authorizedKeys.keys = [
              "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIM+ResginDO3aOjCVc+5JIbvnxaw58LEwRhTSsv6JHJ4 edwin@dhyana"
              "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJNW41pUgA356Qnuia0EX9939R5DFlZb+6MHi95Vm+oK cepheus"
              "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOCmJ7RS1nKlNjY307l6ox3w7UttNBl3we/ReYNhEdrC edwin@heraclitus"
            ];

            environment.systemPackages = [self.packages.aarch64-linux.modscan];
          })
        ];
      };

      hydraJobs = {
        nixosConfigurations = mapAttrs (name: value: nixpkgs.lib.hydraJob value.config.system.build.toplevel) self.nixosConfigurations;
        packages.x86_64-linux = mapAttrs (name: value: nixpkgs.lib.hydraJob value) self.packages.x86_64-linux;
      };
    };
}
