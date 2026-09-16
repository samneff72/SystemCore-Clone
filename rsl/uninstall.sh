#!/bin/bash
# Remove the DIY SystemCore RSL driver and its "# >>> diy-rsl" block from config.txt on
# both boot slots. Other add-ons' blocks (e.g. diy-can) are left alone.
set -e
if [ "$(id -u)" != "0" ]; then
  echo "Please run as root:  sudo ./uninstall.sh" >&2
  exit 1
fi

systemctl disable --now diy-rsl.service 2>/dev/null || true
rm -f /etc/systemd/system/diy-rsl.service /usr/local/sbin/diy-rsl.py
systemctl daemon-reload
[ -d /sys/class/leds/rsl ] && { echo none > /sys/class/leds/rsl/trigger; echo 0 > /sys/class/leds/rsl/brightness; } 2>/dev/null || true

rootsrc="$(findmnt -no SOURCE / 2>/dev/null || true)"
disk="${rootsrc%p[0-9]*}"; [ -b "$disk" ] || disk=/dev/mmcblk0
for n in 2 3; do
  part="${disk}p${n}"; [ -b "$part" ] || continue
  mnt="/mnt/sc-boot-p${n}"; mkdir -p "$mnt"
  if mountpoint -q "$mnt" || mount -t vfat "$part" "$mnt" 2>/dev/null; then
    if [ -f "$mnt/config.txt" ]; then
      tmp="$(mktemp)"
      # drop our block (and the blank lines right before it) and any loose gpio-led rsl line
      awk 'index($0,"# >>> diy-rsl")==1{skip=1; blank=0}
                    skip{if (index($0,"# <<< diy-rsl")==1) skip=0; next}
                    NF{for(i=0;i<blank;i++) print ""; blank=0; print; next}
                    {blank++}' "$mnt/config.txt" \
        | sed -E '/^dtoverlay=gpio-led,.*label=rsl/d' > "$tmp"
      cp "$tmp" "$mnt/config.txt"; rm -f "$tmp"
      echo "removed the diy-rsl block from $part:/config.txt"
    fi
    umount "$mnt"
  fi
done
echo "Done. The LED device disappears on the next reboot."
