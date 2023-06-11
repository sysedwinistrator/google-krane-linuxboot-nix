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
        inherit (pkgs) lib;
      in {
        packages = {
          kernel = pkgs.linux.override {
            structuredExtraConfig = let
              inherit (lib.kernel) freeform module no option unset whenHelpers yes;
            in {
              KEYBOARD_MT6779 = yes;
              KEYBOARD_MTK_PMIC = yes;

              DRM_MEDIATEK_DP = module;

              NET_VENDOR_MEDIATEK = yes;
              NET_MEDIATEK_SOC = module;

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

              VIRTUALIZATION = no;
              XEN = lib.mkForce no;
              VIRTIO_MENU = no;
              VIRTIO_BLK = no;
              VIRTIO_CONSOLE = no;
              VIRTIO_NET = no;

              SUSPEND = no;
              HIBERNATION = no;

              FUSE_FS = no;

              WLAN = no;
              BT = no;
              NFC = no;
              CAN = no;
              GNSS = no;

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

              INFINIBAND = lib.mkForce no;
            };
          };
        };
      })
    );
}
