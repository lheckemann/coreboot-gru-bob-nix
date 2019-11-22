{ stdenvNoCC, writeText, ubootTools, lzma, dtc, linux, image-lzma, initramfs }:
stdenvNoCC.mkDerivation  {
  name = "indigo-uImage-${linux.version}";
  nativeBuildInputs = [ ubootTools lzma dtc ];
  its = writeText "indigo-uImage-${linux.version}.its" ''
    /dts-v1/;

    / {
      description = "Simple image with single Linux kernel and FDT blob";
      #address-cells = <1>;
      images {
        kernel {
          description = "Vanilla Linux kernel";
          data = /incbin/("${image-lzma}");
          type = "kernel";
          arch = "arm64";
          os = "linux";
          compression = "lzma";
          load = <0x80000>;
          entry = <0x80000>;
          hash-1 {
            algo = "crc32";
          };
          hash-2 {
            algo = "sha1";
          };
          hash-3 {
            algo = "sha256";
          };
        };
        fdt-1 {
          description = "Flattened Device Tree blob";
          data = /incbin/("${linux}/dtbs/rockchip/rk3399-gru-bob.dtb");
          type = "flat_dt";
          arch = "arm64";
          compression = "none";
          hash-1 {
            algo = "crc32";
          };
          hash-2 {
            algo = "sha1";
          };
          hash-3 {
            algo = "sha256";
          };
        };
        ramdisk-1 {
          description = "Compressed Initramfs";
          data = /incbin/("${initramfs}/initrd");
          type = "ramdisk";
          arch = "arm64";
          os = "linux";
          compression = "none";
          load = <00000000>;
          entry = <00000000>;
          hash-1 {
            algo = "sha1";
          };
          hash-2 {
            algo = "sha256";
          };
        };
      };
      configurations {
        default = "conf-1";
        conf-1 {
          description = "Boot Linux kernel with FDT blob";
          kernel = "kernel";
          fdt = "fdt-1";
          ramdisk = "ramdisk-1";
        };
      };
    };
  '';
  buildCommand = ''
    mkimage -f $its $out
  '';
}
