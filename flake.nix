{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    flake-parts.url = "github:hercules-ci/flake-parts";
  };

  outputs = inputs @ {flake-parts, ...}:
    flake-parts.lib.mkFlake {inherit inputs;} (top @ {
      config,
      withSystem,
      moduleWithSystem,
      ...
    }: {
      systems = [
        "aarch64-linux"
        "x86_64-linux"
      ];

      perSystem = {
        config,
        pkgs,
        ...
      }: {
        packages = {
          kernel = pkgs.linux;

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

          linuxboot-initrd = let
            inherit (config.packages) kernel;

            kernelModules = [
              # Input
              "cros-ec-keyb"
              "hid-google-hammer"
              "hid-multitouch"

              # Output
              "mediatek-drm"
              "panel-boe-tv101wum-nl6"
              "phy-mtk-mipi-dsi-drv"
              "pwm-bl"
              "pwm-mtk-disp"

              # Misc
              "mmc-block"
              "sbs-battery"
            ];

            modulesClosure = pkgs.makeModulesClosure {
              rootModules = kernelModules;
              inherit kernel;
              firmware = [pkgs.linux-firmware];
              allowMissing = false;
              extraFirmwarePaths = [];
            };

            modprobeCommands = builtins.concatStringsSep "\n" (map (module: "modprobe ${module}") kernelModules);

            # Script to be sourced by gosh after init
            postInitScript = pkgs.writeTextFile {
              name = "linuxboot-post-init-script";
              text = ''
                ${modprobeCommands}

                exec boot -reuse none -remove none
              '';
            };
          in
            pkgs.callPackage ./images/linuxboot/u-root-initrd.nix {
              extraPaths = [
                {
                  src = "${modulesClosure}/";
                  dest = "/";
                }
                {
                  src = postInitScript;
                  dest = "/post-init";
                }
              ];
            };

          linuxboot-uimg = let
            inherit (config.packages) kernel linuxboot-initrd;
          in
            pkgs.callPackage ./images/mkuImage.nix {
              kernelPath = "${kernel}/Image";
              dtbPath = "${kernel}/dtbs/mediatek/mt8183-kukui-krane-sku176.dtb";
              initrdPath = linuxboot-initrd;
            };

          linuxboot-depthcharge-img = pkgs.callPackage ./images/mkDepthchargeImage.nix {
            uimg = config.packages.linuxboot-uimg;
            kernelCmdline = "console=ttyS0,115200n8 console=tty0 uroot.uinitargs=\"-c 'source /post-init'\"";
          };

          linuxboot-image = let
            inherit (config.packages) linuxboot-depthcharge-img;
          in
            pkgs.callPackage ./images/mkChromebookImage.nix {
              bootImg = "${linuxboot-depthcharge-img}/image/image";
            };
        };
      };
    });
}
