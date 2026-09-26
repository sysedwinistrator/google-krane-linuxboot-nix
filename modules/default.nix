{pkgs, config, lib, ...}: let
  inherit (lib) mkOption types;
in {
  imports = [
    ./kernel.nix
    ./linuxboot.nix
  ];

  options = {
    kernel = mkOption {
      type = types.package;
    };
    kernelParams = mkOption {
      default = [];
      type = types.listOf types.str;
    };
    dtbPath = mkOption {
      type = types.str;
    };
    initrd = mkOption {
      type = types.package;
    };
    uimg = mkOption {
      type = types.package;
    };
  };

  config.uimg = pkgs.nixosBootPkgs.uimage.override {
    kernelPath = "${config.kernel}/Image";
    dtbPath = "${config.kernel}/dtbs/mediatek/mt8183-kukui-krane-sku176.dtb";
    initrdPath = config.linuxBoot.initrd;
  };
}
