{ stdenv, fetchgit, bc, ncurses, m4, bison, flex, zlib
, lib
, iasl
, buildEnv
, pkgsCross
, python2
, rsync
, uImage }:
let
  crossTools = set: [
    set.stdenv.cc
    set.buildPackages.nasm
    set.buildPackages.binutils
    set.buildPackages.gcc-unwrapped
  ];
  arm32 = pkgsCross.armv7l-hf-multiplatform;
  arm64 = pkgsCross.aarch64-multiplatform;
  crossEnv = buildEnv {
    name = "coreboot-crossenv";
    paths = crossTools arm64 ++ crossTools arm32 ++ [ pkgsCross.arm-embedded.stdenv.cc ];
    pathsToLink = ["/bin"];
  };
  tool_gcc = tool: set: "${set.stdenv.cc}/bin/${set.stdenv.cc.targetPrefix}${tool}";
  tool_binutils = tool: set: "${set.buildPackages.binutils-unwrapped}/bin/${set.stdenv.cc.targetPrefix}${tool}";

  makeVars = arch: set: [
    "CC_${arch}=${tool_gcc "cc" set}"
    "LD_${arch}=${tool_gcc "ld" set}"
    "OBJCOPY_${arch}=${tool_binutils "objcopy" set}"
    "OBJDUMP_${arch}=${tool_binutils "objdump" set}"
    "NM_${arch}=${tool_binutils "nm" set}"
    "AR_${arch}=${tool_binutils "ar" set}"
  ];

  atfSource = fetchgit {
    url = "https://review.coreboot.org/arm-trusted-firmware.git";
    rev = "ace23683beb81354d6edbc61c087ab8c384d0631";
    sha256 = "01q12p7jfwiv6mxfq36qwrckfb2l3v8c0nqpv8wpca47lbmvnfjx";
  };
  vbootSource = fetchgit {
    url = "https://review.coreboot.org/vboot.git";
    rev = "b2c8984d37e378b2faad170d4ec9b378c0c2b145";
    sha256 = "1nlnrmhvqjhwdmlihcjf7dwjsk5qmij8svsgw64ayl9j61jq07ay";
  };
in stdenv.mkDerivation {
  name = "coreboot-${uImage.name}";
  src = fetchgit {
    url = "https://review.coreboot.org/coreboot.git";
    rev = "0e6e45770293781a19bd92d440bc6da6da642f7f";
    sha256 = "1fypgwp8hgn1jl6li40f4rf27h8ia2xdaqpn9hhfhyyca16nvkj7";
    fetchSubmodules = false;
  };
  nativeBuildInputs = [ m4 bison flex bc iasl rsync python2 ];
  buildInputs = [ zlib ];
  makeFlags = makeVars "arm" arm32 ++ makeVars "arm64" arm64 ++ [
    "VBOOT_SOURCE=${vbootSource}"
    "CROSS_COMPILE_arm64=${arm64.stdenv.cc.targetPrefix}"
    "CROSS_COMPILE_arm=${arm32.stdenv.cc.targetPrefix}"
  ];
  postPatch = ''
    patchShebangs util/xcompile
    patchShebangs util/rockchip/make_idb.py
  '';
  configurePhase = ''
    runHook preConfigure

    export PATH="${crossEnv}/bin:$PATH"
    export ARCH=aarch64
    export CPUS=$NIX_BUILD_CORES
    grep -v -e 'CONFIG_PAYLOAD_FILE'  ${./coreboot.config} > .config
    cat >>.config <<EOF
    CONFIG_PAYLOAD_FILE=${uImage}
    EOF
    rm -r 3rdparty/arm-trusted-firmware
    cp -r ${atfSource}/ 3rdparty/arm-trusted-firmware
    chmod -R u+w 3rdparty/arm-trusted-firmware

    runHook postConfigure
  '';
  enableParallelBuilding = true;
  installPhase = ''
    mkdir $out
    cp build/coreboot.rom $out
  '';
}
