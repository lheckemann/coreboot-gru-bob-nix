#!/usr/bin/env ash
set -ex
touch /do-boot

(
cd /sys/bus/platform/drivers/sdhci-arasan
mmctries=1000
[[ -e /dev/sda1 ]] && mmctries=20
for try in $(seq $mmctries); do
    test -e fe330000.sdhci/mmc_host/mmc*/mmc*/block && found=1 && break
    echo fe330000.sdhci > unbind || true
    echo fe330000.sdhci > bind
    sleep 1
done
test -n "$found" && echo "mmc appeared after $try attempts" | tee /dev/log
) || true
name=$(echo /sys/bus/platform/drivers/sdhci-arasan/*/mmc_host/mmc*/mmc*/block/*)
name="${name##*/}p1"

[[ -e "/dev/$name" ]] || name=sda1

mkdir -p /mnt-new
mount /dev/$name /mnt-new
for fs in proc sys dev ; do
    mount --bind /$fs /mnt-new/$fs
done


[[ -z "$sys" ]] && sys=/nix/var/nix/profiles/system
kernel=/mnt-new/$(resolvelink /mnt-new "$sys/kernel")
kparams=$(cat "/mnt-new/$(resolvelink /mnt-new "$sys/kernel-params")")
initrd=/mnt-new/$(resolvelink /mnt-new "$sys/initrd")
init=$(resolvelink /mnt-new "$sys/init")
kexec -l "$kernel" --initrd "$initrd" --command-line "$kparams $(cat /proc/cmdline) init=$init"
[[ -e /do-boot ]] && kexec -e
#chroot /mnt-new $sys/sw/bin/kexec -l $sys/kernel --initrd $sys/initrd --command-line "$(cat $sys/kernel-params) $(cat /proc/cmdline) init=$sys/init $extra boot.shell_on_fail "
