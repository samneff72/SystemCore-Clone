#!/bin/bash
# Enable the Raspberry Pi 5 fan (Active Cooler / fan header) on the official SystemCore
# image. Independent of the CAN HAT overlays and of rsl/. Idempotent. Run as root.
#
#   sudo ./install.sh                  # fan forced on, stock curve (off <50C, then 30/50/70/100 %)
#   sudo ./install.sh --start-temp 40  # start the curve at 40C instead of 50C
#   sudo ./install.sh --always-on      # lowest level from boot onward
#   sudo ./install.sh --min-speed 120  # PWM (0-255) of the lowest level, default 75
#   sudo ./install.sh --temps 45,55,65,72   # all four trip temperatures in C
#   sudo ./install.sh --no-config      # don't touch config.txt
#
# config.txt: only the "# >>> diy-fan ... # <<< diy-fan" block is written (both boot slots).
set -e

if [ "$(id -u)" != "0" ]; then
  echo "Please run as root:  sudo ./install.sh" >&2
  exit 1
fi

DIR="$(cd "$(dirname "$0")" && pwd)"
WRITE_CONFIG=1; ALWAYS_ON=0; MIN_SPEED=""; TEMPS=""; START_TEMP=""
while [ $# -gt 0 ]; do
  case "$1" in
    --no-config) WRITE_CONFIG=0 ;;
    --always-on) ALWAYS_ON=1 ;;
    --start-temp) START_TEMP="$2"; shift ;;
    --min-speed) MIN_SPEED="$2"; shift ;;
    --temps) TEMPS="$2"; shift ;;
    *) echo "unknown option $1" >&2; exit 1 ;;
  esac
  shift
done
case "$MIN_SPEED" in ''|[0-9]|[0-9][0-9]|[0-9][0-9][0-9]) ;; *) echo "--min-speed needs 0-255" >&2; exit 1 ;; esac

# ---- build the dtparam lines for our block
PARAMS="dtparam=cooling_fan=on"
if [ -n "$TEMPS" ]; then
  IFS=, read -r t0 t1 t2 t3 <<EOF
$TEMPS
EOF
  if [ -z "$t3" ]; then echo "--temps needs four comma-separated temperatures in C" >&2; exit 1; fi
  i=0
  for t in "$t0" "$t1" "$t2" "$t3"; do
    mc="$(awk -v t="$t" 'BEGIN{printf "%d", t*1000}')"
    PARAMS="$PARAMS
dtparam=fan_temp${i}=${mc}"
    i=$((i+1))
  done
fi
if [ -n "$START_TEMP" ]; then
  # first trip only (fan comes on at this temperature, off again 5 C below it)
  PARAMS="$(printf '%s\n' "$PARAMS" | sed '/^dtparam=fan_temp0=/d')
dtparam=fan_temp0=$(awk -v t="$START_TEMP" 'BEGIN{printf "%d", t*1000}')"
fi
if [ "$ALWAYS_ON" = 1 ]; then
  # first trip at 1 C (hysteresis 5 C) => the lowest level is engaged from boot onward
  PARAMS="$(printf '%s\n' "$PARAMS" | sed '/^dtparam=fan_temp0=/d')
dtparam=fan_temp0=1000"
fi
[ -n "$MIN_SPEED" ] && PARAMS="$PARAMS
dtparam=fan_temp0_speed=${MIN_SPEED}"

BLOCK_BEGIN='# >>> diy-fan'
BLOCK_END='# <<< diy-fan'

apply_config() { # $1 = config.txt on a boot slot
  local cfg="$1" tmp
  tmp="$(mktemp)"
  tr -d '\r' < "$cfg" > "$tmp"
  # replace (or append) our block; other tools' blocks are untouched, trailing blank lines trimmed
  awk -v b="$BLOCK_BEGIN" -v e="$BLOCK_END" '
    index($0,b)==1 {skip=1; blank=0}
    skip           {if (index($0,e)==1) skip=0; next}
    NF             {for(i=0;i<blank;i++) print ""; blank=0; print; next}
                   {blank++}' "$tmp" > "$cfg"
  {
    printf '\n%s: managed by fan/install.sh - re-run it rather than editing here >>>\n' "$BLOCK_BEGIN"
    printf '# Pi 5 fan: force the pwm-fan "cooling_fan" node on (the bootloader only enables it when it\n'
    printf '# detects a fan at power-on); the kernel thermal governor drives it from the CPU temperature.\n'
    printf '%s\n' "$PARAMS"
    printf '%s <<<\n' "$BLOCK_END"
  } >> "$cfg"
  rm -f "$tmp"
}

echo "==> SystemCore image: $(cat /etc/release.txt 2>/dev/null || echo unknown), kernel $(uname -r)"

# ---------------------------------------------------------------- config.txt (both A/B boot slots)
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
        [ -f "$cfg.pre-fan" ] || cp "$cfg" "$cfg.pre-fan"
        apply_config "$cfg"
        echo "    $part:/config.txt: diy-fan block written (first-run backup: config.txt.pre-fan)"
        printf '%s\n' "$PARAMS" | sed 's/^/        /'
      else
        echo "    $part has no config.txt (not a boot slot?), skipping"
      fi
      umount "$mnt"
    else
      echo "    could not mount $part, skipping"
    fi
  done
fi

# ---------------------------------------------------------------- module hint
# pwm-fan is a module on this image and normally auto-loads when the node is enabled; this
# makes it load at boot regardless (harmless when the node is off).
echo "==> Installing /etc/modules-load.d/diy-fan.conf (pwm-fan)"
printf 'pwm-fan\n' > /etc/modules-load.d/diy-fan.conf
modprobe pwm-fan 2>/dev/null || true

echo
echo "Done. Reboot now:   sudo reboot"
echo "Then check with:    sudo ./status.sh        (add --test to spin the fan at full speed for 5 s)"
echo "Note: with the stock curve the fan is OFF below 50 C - that is normal, not a fault."
