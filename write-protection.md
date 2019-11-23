# Disabling write protection on gru-bob

PLEASE DO NOT DO THIS IF YOU DO NOT HAVE A SUZYQABLE OR THE KIT TO FLASH THE FIRMWARE DIRECTLY.

Sources:
- https://wiki.mrchromebox.tech/Firmware_Write_Protect#Disabling_WP_on_CR50_Devices_via_CCD
- https://chromium.googlesource.com/chromiumos/platform/ec/+/master/docs/case_closed_debugging_cr50.md#bob

1. Open up the device and remove the write-protection screw.

2. Enable developer mode:  power on with esc and refresh buttons held, then press ctrl-D and go through the motions

3. In a root shell, `gsctool -a -o` and press the power button whenever prompted to (this takes about 3 minutes apparently, but feels like an hour)

4. Set a password for your GSC chip (don't lose it, because it can't be reset) using gsctool ???

5. Back up your firmware using flashrom's `-r` operation.

6. On the first serial console (Cr50), run the commands:
   ```
   ccd set OpenFromUSB Always
   ccd set OpenNoDevMode Always
   wp false
   wp false atboot
   ```
   The first two will allow you to open the Cr50 with the password
   even if you break your firmware.

   The second two will remove the write protection asserted by the Cr50.

Once these steps are completed, you will be able to flash your own firmware, using the flashrom included with ChromeOS on the device or your own flashrom—nix expression included in this repo :)
