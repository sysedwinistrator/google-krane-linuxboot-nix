{...}: {
  genericKernel.modules = [
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
  dtbPath = "dtbs/mediatek/mt8183-kukui-krane-sku176.dtb";
}
