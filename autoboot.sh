#!/usr/bin/env ash
set -ex
resolve() {
  local root="$1"
  local link="$2"
  local dest
  dest="$(basename "$link")"
  while
    if [[ "${dest:0:1}" = / ]] ; then
      link="$root$dest"
    else
      link="$(dirname "$link")/$dest"
    fi
    [[ -L "$link" ]]
  do
    dest="$(readlink "$link")"
  done
  echo "$link"
}

(
cd /sys/bus/platform/drivers
for mmctries in $(seq 20); do
    test -e fe330000.sdhci/mmc_host/mmc*/mmc*/block && found=1 && break
    echo fe330000.sdhci > sdhci-arasan/unbind || true
    echo fe330000.sdhci > sdhci-arasan/bind
    sleep 1
done
test -n "$found" && echo "mmc appeared after $mmctries attempts" | tee /dev/log
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
sys=$(resolve /mnt-new "$sys")
kernel=$(resolve /mnt-new "$sys/kernel")
kparams=$(resolve /mnt-new "$sys/kparams")
initrd=$(resolve /mnt-new "$sys/initrd")
init=$(resolve /mnt-new "$sys/init")
kexec -l "$kernel" --initrd "$initrd" --command-line "$(cat "$kparams") $(cat /proc/cmdline) init=$init"
#chroot /mnt-new $sys/sw/bin/kexec -l $sys/kernel --initrd $sys/initrd --command-line "$(cat $sys/kernel-params) $(cat /proc/cmdline) init=$sys/init $extra boot.shell_on_fail "
