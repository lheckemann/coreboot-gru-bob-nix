{ pkgs ? import <nixpkgs> {}
, pkgsTarget ? pkgs.pkgsCross.aarch64-multiplatform-musl
}: let
callPackage = pkgs.newScope (pkgs // self);
self = {
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
  init = pkgs.writeScript "init" ''
    #!${pkgsTarget.busybox}/bin/ash
    ${pkgsTarget.busybox}/bin/ash
  '';
  initramfs = pkgs.makeInitrd {
    contents = [
      { object = init; symlink = "/init"; }
    ];
    compressor = "${pkgs.xz}/bin/xz";
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
  uImage = callPackage ./uimage.nix {};;
  #coreboot = callPackage
};
in self
