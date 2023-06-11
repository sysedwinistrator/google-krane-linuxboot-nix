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
    recursiveUpdate (
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
      in {
        packages = {
          kernel = pkgs.linux.override {
            structuredExtraConfig = let
              inherit (pkgs.lib.kernel) freeform module no option unset whenHelpers yes;
            in {
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

              VIRTUALIZATION = no;
              XEN = no;

              SUSPEND = no;
              HIBERNATION = no;

              FUSE_FS = no;

              WLAN = no;
              BT = no;
              NFC = no;

              SOUND = no;
              SOUNDWIRE = no;
              MEDIA_SUPPORT = no;
              DRM_NOUVEAU = no;
              DRM_ETNAVIV = no;
            };
          };
        };
      })
    );
}
