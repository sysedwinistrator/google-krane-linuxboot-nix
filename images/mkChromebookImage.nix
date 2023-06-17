{
  bootImg,
  rootImg,
  stdenv,
  parted,
  vboot_reference,
  util-linux,
}:
stdenv.mkDerivation {
  name = "chromebookImage";
  unpackPhase = "true";
  buildInputs = [
    parted
    vboot_reference
    util-linux
  ];
  buildPhase = ''
    gap=8192 # blocks

    # calculate size of partitions and images in blocks
    bootSizeBlocks=$(du -B 512 --apparent-size ${bootImg} | awk '{ print $1 }')
    rootSizeBlocks=$(du -B 512 --apparent-size ${rootImg} | awk '{ print $1 }')
    imageSize=$((bootSizeBlocks * 512 + rootSizeBlocks * 512 + gap * 512 + gap * 512))

    # create empty image
    img=$out
    truncate -s $imageSize $img

    # partition
    parted --script $img mklabel gpt
    cgpt add -i 1 -t kernel -l Kernel -b $gap -s $bootSizeBlocks -S 1 -T 5 -P 10 $img
    cgpt add -i 2 -t data -l NIXOS -b $((bootSizeBlocks + gap)) -s $rootSizeBlocks $img

    # flash boot img
    eval $(partx $img -o START,SECTORS --nr 1 --pairs)
    dd conv=notrunc if=${bootImg} of=$img seek=$START count=$SECTORS

    # flash root fs
    eval $(partx $img -o START,SECTORS --nr 2 --pairs)
    dd conv=notrunc if=${rootImg} of=$img seek=$START count=$SECTORS
  '';
  fixupPhase = "true";
}
