{ stdenv, fetchgit, bc, ncurses, m4, bison, flex, zlib
, lib
, iasl
, buildEnv
, pkgconfig
, pkgsCross
, python3
, rsync
, u-boot }:
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
    ignoreCollisions = true;
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
    rev = "v2.5";
    sha256 = "0w3blkqgmyb5bahlp04hmh8abrflbzy0qg83kmj1x9nv4mw66f3b";
  };
  vbootSource = fetchgit {
    url = "https://review.coreboot.org/vboot.git";
    rev = "4e982f1c39da417100e4021fb1c2c370da5f8dd6"; # master 2021-06-15
    sha256 = "1fr35gh4c81gb75q6zpf4v9hnvk74ppzdww54fhrr28ahzd73qi6";
  };
in stdenv.mkDerivation {
  name = "coreboot-4.11-${u-boot.pname}";
  src = fetchgit {
    url = "https://review.coreboot.org/coreboot.git";
    rev = "4.14";
    sha256 = "06y46bjzkmps84dk5l2ywjcxmsxmqak5cr7sf18s5zv1pm566pqa";
    fetchSubmodules = false;
  };
  nativeBuildInputs = [ m4 bison flex bc iasl rsync python3 pkgconfig ];
  buildInputs = [ zlib ];
  makeFlags = makeVars "arm" arm32 ++ makeVars "arm64" arm64 ++ [
    "CROSS_COMPILE_arm64=${arm64.stdenv.cc.targetPrefix}"
    "CROSS_COMPILE_arm=${arm32.stdenv.cc.targetPrefix}"
  ];
  postPatch = ''
    patchShebangs util/xcompile
    patchShebangs util/rockchip/make_idb.py
    patchShebangs util/genbuild_h/genbuild_h.sh
  '';
  configurePhase = ''
    runHook preConfigure

    export PATH="${crossEnv}/bin:$PATH"
    export ARCH=aarch64
    export CPUS=$NIX_BUILD_CORES
    grep -v -e 'CONFIG_PAYLOAD_FILE' ${./coreboot.config} > .config
    cat >>.config <<EOF
    CONFIG_PAYLOAD_FILE=${u-boot}/u-boot-dtb.bin
    EOF
    rm -r 3rdparty/arm-trusted-firmware
    cp -r ${atfSource}/ 3rdparty/arm-trusted-firmware
    chmod -R u+w 3rdparty/arm-trusted-firmware

    rm -r 3rdparty/vboot
    cp -r ${vbootSource} 3rdparty/vboot
    chmod -R u+w 3rdparty/vboot
    sed -i 's/-Wno-unknown-warning//' 3rdparty/vboot/Makefile

    export NIX_CFLAGS_COMPILE_aarch64_unknown_linux_gnu=-Wno-error=address-of-packed-member\ -Wno-error=format-truncation\ -Wno-error=int-conversion
    export NIX_CFLAGS_COMPILE=-Wno-error=format-truncation

    runHook postConfigure
  '';
  enableParallelBuilding = true;
  installPhase = ''
    ./build/cbfstool build/coreboot.rom remove -n fallback/payload
    ./build/cbfstool build/coreboot.rom add-flat-binary -f ${u-boot}/u-boot-dtb.bin -n fallback/payload -l 0x00a00000 -e 0x00a00000
    mkdir $out
    cp build/coreboot.rom $out
  '';
}
