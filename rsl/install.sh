#!/bin/bash
# Install the DIY SystemCore Robot Signal Light driver on a Raspberry Pi 5 running the
# official SystemCore image. Independent of the CAN HAT overlays. Idempotent. Run as root.
#
#   sudo ./install.sh                 # RSL on GPIO26 (header pin 37, GND on pin 39)
#   sudo ./install.sh --gpio 17       # use another free GPIO
#   sudo ./install.sh --active-low    # your MOSFET/relay module lights the RSL when the signal is LOW
#   sudo ./install.sh --no-config     # don't touch config.txt (you added the gpio-led line yourself)
#
# config.txt: only the "# >>> diy-rsl ... # <<< diy-rsl" block is written (both boot slots).
set -e

if [ "$(id -u)" != "0" ]; then
  echo "Please run as root:  sudo ./install.sh" >&2
  exit 1
fi

DIR="$(cd "$(dirname "$0")" && pwd)"
GPIO=26; ACTIVE_LOW=0; WRITE_CONFIG=1
while [ $# -gt 0 ]; do
  case "$1" in
    --gpio) GPIO="$2"; shift ;;
    --active-low) ACTIVE_LOW=1 ;;
    --no-config) WRITE_CONFIG=0 ;;
    *) echo "unknown option $1" >&2; exit 1 ;;
  esac
  shift
done
case "$GPIO" in ''|*[!0-9]*) echo "--gpio needs a BCM GPIO number" >&2; exit 1 ;; esac

OVERLAY="dtoverlay=gpio-led,gpio=${GPIO},label=rsl,trigger=none"
[ "$ACTIVE_LOW" = 1 ] && OVERLAY="${OVERLAY},active_low=1"
BLOCK_BEGIN='# >>> diy-rsl'
BLOCK_END='# <<< diy-rsl'

apply_config() { # $1 = config.txt on a boot slot
  local cfg="$1" tmp
  tmp="$(mktemp)"
  tr -d '\r' < "$cfg" > "$tmp"
  # drop a loose gpio-led rsl line from an older version of this installer, then replace
  # (or append) our block; other tools' blocks are untouched, trailing blank lines trimmed
  sed -i -E '/^dtoverlay=gpio-led,.*label=rsl/d' "$tmp"
  awk -v b="$BLOCK_BEGIN" -v e="$BLOCK_END" '
    index($0,b)==1 {skip=1; blank=0}
    skip           {if (index($0,e)==1) skip=0; next}
    NF             {for(i=0;i<blank;i++) print ""; blank=0; print; next}
                   {blank++}' "$tmp" > "$cfg"
  printf '\n%s: managed by rsl/install.sh - re-run it rather than editing here >>>\n' "$BLOCK_BEGIN" >> "$cfg"
  printf '# Robot Signal Light on GPIO%s (header pin 37 = GPIO26, GND on pin 39), exposed as /sys/class/leds/rsl\n' "$GPIO" >> "$cfg"
  printf '%s\n%s <<<\n' "$OVERLAY" "$BLOCK_END" >> "$cfg"
  rm -f "$tmp"
}

echo "==> SystemCore image: $(cat /etc/release.txt 2>/dev/null || echo unknown), kernel $(uname -r)"

# ---------------------------------------------------------------- config.txt
# The image has two A/B boot slots (/dev/mmcblk0p2 and p3, selected by autoboot.txt on
# p1; the web OTA updater can switch them), so the overlay line goes into both.
if [ "$WRITE_CONFIG" = 1 ]; then
  rootsrc="$(findmnt -no SOURCE / 2>/dev/null || true)"          # e.g. /dev/mmcblk0p5
  disk="${rootsrc%p[0-9]*}"; [ -b "$disk" ] || disk=/dev/mmcblk0
  active="$(od -An -tu1 /proc/device-tree/chosen/bootloader/partition 2>/dev/null | awk '{print $NF}')"
  echo "==> Boot disk $disk, firmware booted from partition ${active:-?}"
  for n in 2 3; do
    part="${disk}p${n}"
    [ -b "$part" ] || { echo "    $part not present, skipping"; continue; }
    mnt="/mnt/sc-boot-p${n}"
    mkdir -p "$mnt"
    if mountpoint -q "$mnt" || mount -t vfat "$part" "$mnt" 2>/dev/null; then
      cfg="$mnt/config.txt"
      if [ -f "$cfg" ]; then
        [ -f "$cfg.pre-rsl" ] || cp "$cfg" "$cfg.pre-rsl"
        apply_config "$cfg"
        echo "    $part:/config.txt: diy-rsl block = $OVERLAY (first-run backup: config.txt.pre-rsl)"
      else
        echo "    $part has no config.txt (not a boot slot?), skipping"
      fi
      umount "$mnt"
    else
      echo "    could not mount $part, skipping"
    fi
  done
fi

# ---------------------------------------------------------------- driver + service
echo "==> Installing /usr/local/sbin/diy-rsl.py and /etc/systemd/system/diy-rsl.service"
mkdir -p /usr/local/sbin
sed 's/\r$//' "$DIR/diy-rsl.py"      > /usr/local/sbin/diy-rsl.py        # tolerate CRLF checkouts
sed 's/\r$//' "$DIR/diy-rsl.service" > /etc/systemd/system/diy-rsl.service
chmod 0755 /usr/local/sbin/diy-rsl.py
chmod 0644 /etc/systemd/system/diy-rsl.service
systemctl daemon-reload
systemctl enable diy-rsl.service >/dev/null 2>&1

echo
if [ -d /sys/class/leds/rsl ]; then
  systemctl restart diy-rsl.service
  echo "Done. /sys/class/leds/rsl already exists (overlay applied on a previous boot), service restarted."
  echo "If you changed --gpio/--active-low, reboot for the new overlay line to take effect."
else
  echo "Done. Reboot now:   sudo reboot"
fi
echo "Verify with:   systemctl status diy-rsl ; cat /sys/class/leds/rsl/trigger ; cat /dev/mrccan/enabledro"
