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
  autoboot = pkgs.writeScript "autoboot" ''
    #!${pkgsTarget.busybox}/bin/ash
    export PATH=${resolvelink}/bin:$PATH
    ${pkgsTarget.busybox}/bin/ash ${./autoboot.sh}
  '';
  resolvelink = resolvelink-cxx;
  resolvelink-cxx = pkgsTarget.pkgsStatic.stdenv.mkDerivation {
    name = "resolvelink";
    buildInputs = [ pkgsTarget.pkgsStatic.boost ];
    dontUnpack = true;
    dontInstall = true;
    buildPhase = ''
      mkdir -p $out/bin
      cp ${./resolvelink.cpp} resolvelink.cpp
      $CXX resolvelink.cpp -o $out/bin/resolvelink -lboost_filesystem -lboost_system -Os -g0
    '';
    postFixup = ''
      rm $out/nix-support/propagated-build-inputs
    '';
  };
  resolvelink-rs = pkgsTarget.callPackage ({rustPlatform}: rustPlatform.buildRustPackage {
    pname = "resolvelink";
    version = "0.1.0";
    src = ./resolvelink;
    cargoVendorDir = "";
  }) {};
  resolvelink-rs = pkgsTarget.callPackage ({runCommandCC, rustc}: runCommandCC "resolvelink" {
    nativeBuildInputs = [ rustc ];
  } ''
    mkdir -p $out/bin
    rustc ${./resolvelink.rs} -o $out/bin/resolvelink
  '') {};
  init = pkgs.writeScript "init" ''
    #!${pkgsTarget.busybox}/bin/ash
    export PATH=${pkgsTarget.busybox}/bin:${pkgsTarget.kexectools}/bin
    mkdir -p /dev /sys /proc
    mount -t devtmpfs devtmpfs /dev
    mount -t sysfs sysfs /sys
    mount -t proc proc /proc
    ${autoboot} &
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
  flashrom = pkgs.flashrom.overrideAttrs ({makeFlags ? [], buildInputs ? [], ...}: {
    name = "flashrom-cros";
    buildInputs = buildInputs ++ [ pkgs.libusb1 ];
    src = pkgs.fetchgit {
      url = "https://chromium.googlesource.com/chromiumos/third_party/flashrom";
      rev = "fadf15bb7cb80c852589ca0916a9063c92b1e178";
      sha256 = "1xgyslv8q100simm7pzzqrizfdry02ypq9hxa5vdp2d27yxw827n";
    };
    makeFlags = makeFlags ++ ["CONFIG_RAIDEN_DEBUG_SPI=yes"];
    patches = [ ./flashrom-overflow.patch ./flashrom-nopower.patch ./flashrom-nofirmwarelock.patch ];
  });
  all = pkgs.runCommandNoCC "indigo" {} ''
    mkdir -p $out
    cp ${init} $out/init
    cp -r ${linux} $out/linux
    cp -r ${image-lzma} $out/Image.lzma
    cp -r ${initramfs}/initrd $out/initramfs.cpio.xz
    cp -r ${uImage} $out/uImage
    cp ${coreboot}/coreboot.rom $out/
    cp ${linux}/dtbs/rockchip/rk3399-gru-bob.dtb $out
    cp ${flashrom}/bin/flashrom $out/
  '';
};
in self
