{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = {
    self,
    nixpkgs,
    flake-utils,
  }: let
    inherit (builtins) concatStringsSep;
    inherit (nixpkgs.lib.attrsets) recursiveUpdate;
    eachSystem = expr:
      flake-utils.lib.eachSystem [
        flake-utils.lib.system.aarch64-linux
        flake-utils.lib.system.x86_64-linux
      ]
      expr;
  in (recursiveUpdate (
      # tooling, compiled for host system
      eachSystem (
        system: let
          pkgs = import nixpkgs {inherit system;};
          inherit (pkgs) callPackage;
        in {
          packages = {
            depthcharge-tools = callPackage ./pkgs/depthcharge-tools.nix {};

            linuxboot-initrd = let
              inherit (self.packages."${system}") kernel;

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

              modprobeCommands = concatStringsSep "\n" (map (module: "modprobe ${module}") kernelModules);

              # Script to be sourced by gosh after init
              postInitScript = pkgs.writeTextFile {
                name = "linuxboot-post-init-script";
                text = ''
                  ${modprobeCommands}

                  exec boot -reuse none -remove none
                '';
              };
            in
              callPackage ./images/linuxboot/u-root-initrd.nix {
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
              inherit (self.packages."${system}") kernel linuxboot-initrd;
            in
              callPackage ./images/mkuImage.nix {
                kernelPath = "${kernel}/Image";
                dtbPath = "${kernel}/dtbs/mediatek/mt8183-kukui-krane-sku176.dtb";
                initrdPath = linuxboot-initrd;
              };

            linuxboot-depthcharge-img = callPackage ./images/mkDepthchargeImage.nix {
              uimg = self.packages."${system}".linuxboot-uimg;
              kernelCmdline = "console=ttyS0,115200n8 console=tty0 uroot.uinitargs=\"-c 'source /post-init'\"";
            };

            linuxboot-depthcharge-img-tools = let
              inherit (self.packages."${system}") depthcharge-tools kernel linuxboot-initrd;
            in
              callPackage ./images/mkDepthchargeImageTools.nix {
                kernel = "${kernel}/Image";
                dtb = "${kernel}/dtbs/mediatek/mt8183-kukui-krane-sku176.dtb";
                initrd = linuxboot-initrd;
                inherit depthcharge-tools;
                cmdline = "console=ttyS0,115200 console=ttyS1,115200 console=tty0 console=tty1 init=/bin/init";
              };

            linuxboot-image = let
              inherit (self.packages."${system}") linuxboot-depthcharge-img;
            in
              callPackage ./images/mkChromebookImage.nix {
                bootImg = "${linuxboot-depthcharge-img}/image/image";
              };

            linuxboot-image-tools = let
              inherit (self.packages."${system}") linuxboot-depthcharge-img-tools;
            in
              callPackage ./images/mkChromebookImage.nix {
                bootImg = "${linuxboot-depthcharge-img-tools}/image/image";
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
          kernel = nixpkgs.legacyPackages."aarch64-linux".linux;
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
    ));
}
