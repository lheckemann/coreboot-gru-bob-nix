{ pkgs ? import <nixpkgs> {}
, pkgsTarget ? pkgs.pkgsCross.aarch64-multiplatform-musl
}: let
callPackage = pkgs.newScope (pkgs // self);
self = rec {
  coreboot = callPackage ./coreboot.nix {};
  u-boot = pkgsTarget.buildUBoot {
    name = "u-boot-chromebook_bob";
    defconfig = "chromebook_bob_defconfig";
    filesToInstall = ["u-boot-dtb.bin"];
    postConfigure = ''
      sed -i 's/CONFIG_SYS_TEXT_BASE=.*/CONFIG_SYS_TEXT_BASE=0x00a00000/' .config
    '';
    enableParallelBuilding = true;
  };
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
    cp ${coreboot}/coreboot.rom $out/
    cp ${flashrom}/bin/flashrom $out/
  '';
};
in self
