#!/bin/bash
# Undo systemcore-can-*-setup/install.sh: remove the services/rules/scripts and put
# config.txt on both boot slots back to stock (drop the diy-can block, restore the
# "#diy-can: " commented lines). Other add-ons' blocks (e.g. diy-rsl) are left alone.
set -e
if [ "$(id -u)" != "0" ]; then
  echo "Please run as root:  sudo ./uninstall.sh" >&2
  exit 1
fi

rm -f /etc/systemd/system/limelight_canbusprocess.service.d/10-diy-can.conf \
      /etc/systemd/system/robot.service.d/10-diy-can.conf \
      /etc/udev/rules.d/71-diy-can-interface-names.rules \
      /usr/local/sbin/diy-can-setup.sh /usr/local/sbin/diy-can-wait.sh
rmdir /etc/systemd/system/limelight_canbusprocess.service.d /etc/systemd/system/robot.service.d 2>/dev/null || true
systemctl daemon-reload
udevadm control --reload-rules 2>/dev/null || true

rootsrc="$(findmnt -no SOURCE / 2>/dev/null || true)"
disk="${rootsrc%p[0-9]*}"; [ -b "$disk" ] || disk=/dev/mmcblk0
for n in 2 3; do
  part="${disk}p${n}"; [ -b "$part" ] || continue
  mnt="/mnt/sc-boot-p${n}"; mkdir -p "$mnt"
  if mountpoint -q "$mnt" || mount -t vfat "$part" "$mnt" 2>/dev/null; then
    if [ -f "$mnt/config.txt" ]; then
      tmp="$(mktemp)"
      # drop our block (and the blank lines right before it), restore the prefixed stock lines
      awk 'index($0,"# >>> diy-can")==1{skip=1; blank=0}
                    skip{if (index($0,"# <<< diy-can")==1) skip=0; next}
                    NF{for(i=0;i<blank;i++) print ""; blank=0; print; next}
                    {blank++}' "$mnt/config.txt" \
        | sed -e 's/^#diy-can: //' > "$tmp"
      cp "$tmp" "$mnt/config.txt"; rm -f "$tmp"
      echo "restored stock CAN lines in $part:/config.txt"
    fi
    umount "$mnt"
  fi
done
echo "Done. Reboot to go back to the stock CAN setup:   sudo reboot"
