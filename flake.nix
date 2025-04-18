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
    inherit (builtins) concatStringsSep mapAttrs;
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

              linuxboot-initrd = let
                inherit (self.packages."${system}") kernel modscan;
              in
                callPackage ./images/linuxboot/initrd.nix {
                  uroot = self.packages."${system}".uroot;
                  extraFiles = [
                    "${kernel}/lib/modules/${kernel.modDirVersion}:/lib/modules/${kernel.modDirVersion}"
                    "${modscan}/bin/modscan:/bin/modscan"
                  ];
                  uinitcmd = "/bin/modscan load -k ${kernel.modDirVersion} && boot";
                };

              linuxboot-initrd-pm = let
                inherit (self.packages."${system}") pmKernel;
              in
                callPackage ./images/linuxboot/initrd.nix {
                  uroot = self.packages."${system}".uroot;
                  extraFiles = [
                    "${pmKernel}/lib/modules/${pmKernel.modDirVersion}:/lib/modules"
                  ];
                };

              pmKernel = pkgs.stdenv.mkDerivation rec {
                name = "pmkernelapk";
                version = "6.1.39";
                src = pkgs.fetchurl {
                  url = "https://mirror.postmarketos.org/postmarketos/master/aarch64/linux-postmarketos-mediatek-mt8183-${version}-r0.apk";
                  sha256 = "sha256-88uCg7z86RChIsb5Q39CoQsk+V0+GniHFab/XGAFPwE=";
                };
                unpackPhase = "true";
                buildPhase = "true";
                installPhase = ''
                  mkdir $out
                  tar -C $out -xf $src
                  cat $out/boot/vmlinuz | gzip -d > $out/boot/Image
                '';
                fixupPhase = "true";
                modDirVersion = "${version}-mt8183";
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

              linuxboot-depthcharge-img = let
                kernelModulesToLoad = [
                  "8021q"
                  "at24"
                  "ath10k_sdio"
                  "bridge"
                  "cmdlinepart"
                  "coresight_cpu_debug"
                  "cros_ec_chardev"
                  "cros_ec_debugfs"
                  "cros_ec_dev"
                  "cros_ec_keyb"
                  "cros_ec_light_prox"
                  "cros_ec_sensors"
                  "cros_ec_spi"
                  "cros_ec_sysfs"
                  "cros_ec_typec"
                  "cros_usbpd_charger"
                  "cros_usbpd_logger"
                  "dm_mod"
                  "extcon_usbc_cros_ec"
                  "governor_passive"
                  "hci_uart"
                  "hid_google_hammer"
                  "hid_multitouch"
                  "i2c_cros_ec_tunnel"
                  "i2c_hid_of"
                  "joydev"
                  "macvlan"
                  "mediatek_drm"
                  "mousedev"
                  "mt6577_auxadc"
                  "mtk_cci_devfreq"
                  "mtk_jpeg"
                  "mtk_mdp3"
                  "mtk_pmic_keys"
                  "panel_boe_tv101wum_nl6"
                  "panfrost"
                  "polyval_ce"
                  "pwm_bl"
                  "pwm_mediatek"
                  "sbs_battery"
                  "snd_soc_bt_sco"
                  "snd_soc_max98357a"
                  "snd_soc_mt6358"
                  "snd_soc_mt8183_afe"
                  "spi_mt65xx"
                  "tap"
                  "thermal_generic_adc"
                  "tpm_tis_spi"
                  "uas"
                  "uio_pdrv_genirq"
                  "xt_tcpudp"
                ];
              in
                callPackage ./images/mkDepthchargeImage.nix {
                  uimg = self.packages."${system}".linuxboot-uimg;
                  kernelCmdline = "console=ttyS0 console=tty0 init=/init modules_load=${concatStringsSep "," kernelModulesToLoad}";
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
        in {
          packages = {
            kernel = nixpkgs.legacyPackages."aarch64-linux".linux_6_4;
            modscan = pkgs.pkgsStatic.buildGoModule rec {
              pname = "modscan";
              version = src.rev;
              src = pkgs.fetchFromGitHub {
                owner = "sysedwinistrator";
                repo = "modscan";
                rev = "731ce4e573a7816d8554549098636e134ae693da";
                sha256 = "sha256-U5xdQESgqpA/nyIAK6ifjTkKbvg42bN11FjxAWgA9SQ=";
              };
              vendorHash = null;
              CGO_ENABLED = 0;
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
