{ pkgsPath ? builtins.fetchTarball (builtins.fromJSON (builtins.readFile ./nixpkgs.json))
, pkgs ? import pkgsPath {}
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
    name = "flashrom-ccd";
    src = pkgs.fetchgit {
      url = "https://review.coreboot.org/flashrom.git";
      rev = "c7e9a6e15153684672bbadd1fc6baed8247ba0f6";
      sha256 = "09njximl6rdjnpx6d3asvb587q6x3jqbf8107cfygy1b7c051ryd";
    };
    buildInputs = buildInputs ++ [ pkgs.libusb1 ];
  });
  all = pkgs.runCommandNoCC "indigo" {} ''
    mkdir -p $out
    cp ${coreboot}/coreboot.rom $out/
    cp ${flashrom}/bin/flashrom $out/
  '';
};
in self
