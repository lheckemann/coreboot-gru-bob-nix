{ pkgs ? import <nixpkgs> {}
, pkgsTarget ? pkgs.pkgsCross.aarch64-multiplatform-musl
}: let
callPackage = pkgs.newScope (pkgs // self);
self = rec {
  linux = pkgsTarget.linuxManualConfig {
    inherit (pkgsTarget) stdenv;
    inherit (pkgs.linux_latest) src version;
    configfile = ./linux-config;
    kernelPatches = [];
    #autoModules = false;
    #kernelTarget = "Image";
  };
  image-lzma = pkgs.runCommandNoCC "${linux.name}.lzma" { nativeBuildInputs = [pkgs.lzma]; } ''
    lzma <${linux}/Image >$out
  '';
  automount-usb = pkgs.writeScript "automount-usb" ''
    #!${pkgsTarget.busybox}/bin/ash
    do_mount() {
      mount /dev/sda1 /mnt
      for fs in proc sys dev ; do
        mount --bind /$fs /mnt/$fs
      done
      exit
    }
    mkdir /mnt
    for try in $(seq 10) ; do
      if [[ -e /dev/sda1 ]] ; then
        do_mount
      fi
      sleep 1
    done
    while true; do
      if [[ -e /dev/sda1 ]] ; then
        do_mount
      fi
      sleep 10
    done
  '';
  init = pkgs.writeScript "init" ''
    #!${pkgsTarget.busybox}/bin/ash
    export PATH=${pkgsTarget.busybox}/bin:${pkgsTarget.kexectools}/bin
    mkdir -p /dev /sys /proc
    mount -t devtmpfs devtmpfs /dev
    mount -t sysfs sysfs /sys
    mount -t proc proc /proc
    ${automount-usb} &
    </dev/tty0 >/dev/tty0 2>/dev/tty0 ash &
    exec ${pkgsTarget.busybox}/bin/ash
  '';
  initramfs = pkgs.makeInitrd {
    contents = [
      { object = init; symlink = "/init"; }
    ];
    compressor = "${pkgs.xz}/bin/xz --check=crc32";
  };
  ubootTools = pkgs.ubootTools.overrideAttrs (o: {
    preBuild = ''
      mv .config .config-pre
      cat - <(grep -vEe 'FIT(=| is not)' -e 'SYS_TEXT_BASE' .config-pre) >.config <<EOF
      CONFIG_FIT=y
      CONFIG_SYS_TEXT_BASE=0x0
      EOF
      make oldconfig
    '';
  });
  uImage = callPackage ./uimage.nix {};
  coreboot = callPackage ./coreboot.nix {};
  all = pkgs.runCommandNoCC "indigo" {} ''
    mkdir -p $out
    cp ${init} $out/init
    cp -r ${linux} $out/linux
    cp -r ${image-lzma} $out/Image.lzma
    cp -r ${initramfs}/initrd $out/initramfs.cpio.xz
    cp -r ${uImage} $out/uImage
    cp ${coreboot}/coreboot.rom $out/
    cp ${linux}/dtbs/rockchip/rk3399-gru-bob.dtb $out
  '';
};
in self
