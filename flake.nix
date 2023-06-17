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
                inherit (self.packages."${system}") pmKernel linuxboot-initrd;
              in
                callPackage ./images/mkuImage.nix {
                  kernelPath = "${pmKernel}/boot/Image";
                  dtbPath = "${pmKernel}/boot/dtbs/mediatek/mt8183-kukui-krane-sku176.dtb";
                  initrdPath = linuxboot-initrd;
                };

              nixos-uimg = let
                inherit (self.nixosConfigurations.live.config.system.build) kernel initialRamdisk;
              in
                callPackage ./images/mkuImage.nix {
                  kernelPath = "${kernel}/Image";
                  dtbPath = "${kernel}/dtbs/mediatek/mt8183-kukui-krane-sku176.dtb";
                  initrdPath = "${initialRamdisk}/initrd.zst";
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
                kernelCmdline = "console=ttyS0,115200";
              };

              linuxboot-depthcharge-img-pm = callPackage ./images/mkDepthchargeImage.nix {
                uimg = self.packages."${system}".linuxboot-uimg-pm;
                kernelCmdline = "kern_guid=%U console=null";
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
          packages.kernel = pkgs.callPackage ./images/minimalKernel.nix {};
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

            boot.initrd.kernelModules = [
              "gpu-sched"
              "i2c-hid-of"
              "hid-multitouch"
              "cros-ec-keyb"
              "sbs-battery"
            ];

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

      hydraJobs = {
        nixosConfigurations = mapAttrs (name: value: nixpkgs.lib.hydraJob value.config.system.build.toplevel) self.nixosConfigurations;
        packages.x86_64-linux = mapAttrs (name: value: nixpkgs.lib.hydraJob value) self.packages.x86_64-linux;
      };
    };
}
