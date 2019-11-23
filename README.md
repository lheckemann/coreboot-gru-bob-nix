# Nix expressions for (cross) building coreboot for gru-bob chromebook

These expressions allow building a coreboot ROM with a linux payload
for the Rockchip RK3399-based "gru-bob" Chromebook (sold as ASUS
C101PA). Lots of things are still hardcoded, but maybe this can serve
as inspiration for others :)

## Building

`nix-build -A all` produces a directory containing a bunch of handy
files. The most important one is `coreboot.rom`.

## Flashing

I've been flashing this using a SuzyQable. Initial setup for this was nontrivial, see [write-protection.md](write-protection.md).

For my user to do this, I need permissions to access a couple of things:

- Relevant USB device nodes in `/dev/bus/usb/001/038` or similar (see lsusb)
- USB tty device nodes (`/dev/ttyUSB[567]` in my case)

Then I can flash (the Chromebook needs to be on at the beginning and will be forcibly turned off!):
```
./result/flashrom -p raiden_debug_spi:target=AP -r backups/ap-$(date -Iminutes)
./result/flashrom -p raiden_debug_spi:target=AP -w ./result/flashrom.rom
```
This takes quite a long time (usually ~10 minutes to write and verify for me).
