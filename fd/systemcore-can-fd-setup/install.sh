#!/bin/bash
# Install the DIY SystemCore CAN bring-up (Pi 5 + Waveshare 2-CH CAN FD HAT) onto an
# official SystemCore image (written for beta13 / beta14). Idempotent. Run as root.
#
#   sudo ./install.sh                      # writes ../config_with_fd.txt to both boot slots + installs overlay
#   sudo ./install.sh --no-config          # leave config.txt alone (you edited it yourself)
#   sudo ./install.sh --int0 25 --int1 24  # override the INT GPIOs if your HAT differs
set -e

CONFIG_NAME=config_with_fd.txt   # looked for next to this script, then one directory up

if [ "$(id -u)" != "0" ]; then
  echo "Please run as root:  sudo ./install.sh" >&2
  exit 1
fi

DIR="$(cd "$(dirname "$0")" && pwd)"
WRITE_CONFIG=1; INT0=""; INT1=""
while [ $# -gt 0 ]; do
  case "$1" in
    --no-config) WRITE_CONFIG=0 ;;
    --int0) INT0="$2"; shift ;;
    --int1) INT1="$2"; shift ;;
    *) echo "unknown option $1" >&2; exit 1 ;;
  esac
  shift
done

echo "==> SystemCore image: $(cat /etc/release.txt 2>/dev/null || echo unknown), kernel $(uname -r)"

# ---------------------------------------------------------------- config.txt
if [ "$WRITE_CONFIG" = 1 ]; then
  cfgsrc=""
  for c in "$DIR/$CONFIG_NAME" "$DIR/../$CONFIG_NAME"; do [ -f "$c" ] && { cfgsrc="$c"; break; }; done
  if [ -z "$cfgsrc" ]; then
    echo "ERROR: $CONFIG_NAME not found in $DIR or $DIR/.. (copy it from the repo, or use --no-config)" >&2
    exit 1
  fi
  rootsrc="$(findmnt -no SOURCE / 2>/dev/null || true)"          # e.g. /dev/mmcblk0p5
  disk="${rootsrc%p[0-9]*}"; [ -b "$disk" ] || disk=/dev/mmcblk0
  active="$(od -An -tu1 /proc/device-tree/chosen/bootloader/partition 2>/dev/null | awk '{print $NF}')"
  echo "==> Boot disk $disk, firmware booted from partition ${active:-?} (autoboot.txt: 2 = slot A, 3 = slot B/tryboot)"
  # optional INT pin overrides: first CAN line = HAT CAN_0, second = HAT CAN_1
  sedargs=()
  [ -n "$INT0" ] && sedargs+=(-e "/^dtoverlay=(mcp2515-can0|mcp251xfd,spi0-0)/s/interrupt=[0-9]+/interrupt=${INT0}/")
  [ -n "$INT1" ] && sedargs+=(-e "/^dtoverlay=(mcp2515-can1|mcp251xfd,spi1-0)/s/interrupt=[0-9]+/interrupt=${INT1}/")
  tmpcfg="$(mktemp)"
  if [ ${#sedargs[@]} -gt 0 ]; then sed -E "${sedargs[@]}" "$cfgsrc" > "$tmpcfg"; else tr -d '\r' < "$cfgsrc" > "$tmpcfg"; fi
  for n in 2 3; do
    part="${disk}p${n}"
    [ -b "$part" ] || { echo "    $part not present, skipping"; continue; }
    mnt="/mnt/sc-boot-p${n}"
    mkdir -p "$mnt"
    if mountpoint -q "$mnt" || mount -t vfat "$part" "$mnt" 2>/dev/null; then
      if [ -f "$mnt/config.txt" ]; then
        [ -f "$mnt/config.txt.stock" ] || cp "$mnt/config.txt" "$mnt/config.txt.stock"
        cp "$tmpcfg" "$mnt/config.txt"
        echo "    wrote $part:/config.txt from $(basename "$cfgsrc") (original kept as config.txt.stock)"
      else
        echo "    $part has no config.txt (not a boot slot?), skipping"
      fi
      umount "$mnt"
    else
      echo "    could not mount $part, skipping"
    fi
  done
  rm -f "$tmpcfg"
fi

# ---------------------------------------------------------------- scripts / rules
echo "==> Installing /usr/local/sbin/diy-can-setup.sh and diy-can-wait.sh"
mkdir -p /usr/local/sbin
install -m 0755 "$DIR/diy-can-setup.sh" /usr/local/sbin/diy-can-setup.sh
install -m 0755 "$DIR/diy-can-wait.sh"  /usr/local/sbin/diy-can-wait.sh

echo "==> Installing /etc/udev/rules.d/71-diy-can-interface-names.rules"
install -m 0644 "$DIR/71-diy-can-interface-names.rules" /etc/udev/rules.d/71-diy-can-interface-names.rules

echo "==> Installing systemd drop-ins"
mkdir -p /etc/systemd/system/limelight_canbusprocess.service.d /etc/systemd/system/robot.service.d
install -m 0644 "$DIR/dropins/limelight_canbusprocess.override.conf" /etc/systemd/system/limelight_canbusprocess.service.d/10-diy-can.conf
install -m 0644 "$DIR/dropins/robot.override.conf"                   /etc/systemd/system/robot.service.d/10-diy-can.conf

# The previous version of this overlay used a separate can-bringup.service; it
# would now fight with the drop-in above, so retire it.
if [ -e /etc/systemd/system/can-bringup.service ]; then
  echo "==> Disabling previously installed can-bringup.service (superseded by the drop-in)"
  systemctl disable --now can-bringup.service 2>/dev/null || true
  rm -f /etc/systemd/system/can-bringup.service
fi
# Stock images before ~12 auto-loaded robot_heartbeat too early; harmless if absent.
rm -f /etc/modules-load.d/robot_heartbeat.conf

udevadm control --reload-rules 2>/dev/null || true
systemctl daemon-reload
systemctl enable limelight_canbusprocess.service >/dev/null 2>&1 || true

echo
echo "Done. Reboot now:   sudo reboot"
echo "Then verify with:   sudo ./diagnose.sh      (or:  ip -br link | grep can_s ; ls /dev/mrccan)"
