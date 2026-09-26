{
  pkgs,
  config,
  lib,
  ...
}: let
  inherit (lib) mkOption types;

  cfg = config.genericKernel;
in {
  options = {
    genericKernel = {
      enable = mkOption {
        default = true;
        type = types.bool;
      };
      kernelPackages = mkOption {
        default = pkgs.linuxPackages;
        type = types.raw;
      };
      modules = mkOption {
        default = [];
        type = types.listOf types.str;
      };
      modulesClosure = mkOption {
        readOnly = true;
        type = types.package;
      };
    };
  };

  config.genericKernel.moduleClosure = pkgs.makeModulesClosure {
    rootModules = cfg.modules;
    inherit (cfg.kernelPackages) kernel;
    firmware = [pkgs.linux-firmware];
    allowMissing = false;
    extraFirmwarePaths = [];
  };
}
