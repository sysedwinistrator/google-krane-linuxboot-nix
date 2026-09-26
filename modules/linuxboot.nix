{
  pkgs,
  config,
  lib,
  ...
}: let
  inherit (lib) mkOption types;

  cfg = config.linuxBoot;
in {
  options.linuxBoot = {
    enable = mkOption {
      default = true;
      type = types.bool;
    };

    postInitScript = mkOption {
      default = let
        modprobeCommands = builtins.concatStringsSep "\n" (map (module: "modprobe ${module}") config.genericKernel.modules);
      in ''
        ${modprobeCommands}

        exec boot -reuse none -remove none
      '';
      type = types.str;
      internal = true;
    };

    postInitScriptPkg = mkOption {
      default = pkgs.writeTextFile {
        name = "linuxboot-post-init-script";
        text = config.linuxBoot.postInitScript;
      };
      type = types.package;
      internal = true;
    };

    initrd = mkOption {
      type = types.package;
      readOnly = true;
    };

    uimg = mkOption {
      type = types.package;
      readOnly = true;
    };
  };

  config = lib.mkIf cfg.enable {
    initrd = pkgs.nixosBootPkgs.initrd-uroot.override {
      extraPaths = [
        {
          src = "${config.genericKernel.modulesClosure}/";
          dest = "/";
        }
        {
          src = cfg.postInitScript;
          dest = "/post-init";
        }
      ];
    };
  };
}
