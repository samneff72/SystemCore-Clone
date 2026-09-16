#!/bin/bash
# Remove the "# >>> diy-fan" block from config.txt on both boot slots and the module hint.
# The fan then depends on the bootloader's auto-detection again. Other add-ons' blocks
# (diy-can, diy-rsl) are left alone.
set -e
if [ "$(id -u)" != "0" ]; then
  echo "Please run as root:  sudo ./uninstall.sh" >&2
  exit 1
fi

rm -f /etc/modules-load.d/diy-fan.conf

rootsrc="$(findmnt -no SOURCE / 2>/dev/null || true)"
disk="${rootsrc%p[0-9]*}"; [ -b "$disk" ] || disk=/dev/mmcblk0
for n in 2 3; do
  part="${disk}p${n}"; [ -b "$part" ] || continue
  mnt="/mnt/sc-boot-p${n}"; mkdir -p "$mnt"
  if mountpoint -q "$mnt" || mount -t vfat "$part" "$mnt" 2>/dev/null; then
    if [ -f "$mnt/config.txt" ]; then
      tmp="$(mktemp)"
      # drop our block (and the blank lines right before it)
      awk 'index($0,"# >>> diy-fan")==1{skip=1; blank=0}
                    skip{if (index($0,"# <<< diy-fan")==1) skip=0; next}
                    NF{for(i=0;i<blank;i++) print ""; blank=0; print; next}
                    {blank++}' "$mnt/config.txt" > "$tmp"
      cp "$tmp" "$mnt/config.txt"; rm -f "$tmp"
      echo "removed the diy-fan block from $part:/config.txt"
    fi
    umount "$mnt"
  fi
done
echo "Done. Takes effect on the next reboot."
