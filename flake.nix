{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    flake-parts.url = "github:hercules-ci/flake-parts";
    pkgs-by-name-for-flake-parts.url = "github:drupol/pkgs-by-name-for-flake-parts";
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

      imports = [
        inputs.pkgs-by-name-for-flake-parts.flakeModule
      ];

      perSystem = {
        config,
        pkgs,
        ...
      }: {
        pkgsDirectory = ./pkgs;

        packages = {
          kernel = pkgs.linux;

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

      overlays.default = final: prev: {
        nixosBootPkgs = config.packages."${final.stdenv.hostPlatform.system}";
      };
    });
}
