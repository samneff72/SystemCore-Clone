#!/bin/bash
# Show why the Pi 5 fan is (or isn't) running, and optionally spin it up as a test.
#   sudo ./status.sh          # temperature, fan node/driver state, current level, RPM
#   sudo ./status.sh --test   # also drive the fan at full speed for 5 s (the thermal governor
#                             # takes control back afterwards)

temp() { local t; t="$(cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null)"; [ -n "$t" ] && awk -v t="$t" 'BEGIN{printf "%.1f C", t/1000}' || echo "?"; }

echo "CPU temperature:        $(temp)"

# device tree node (no "status" property means enabled)
if [ -d /proc/device-tree/cooling_fan ]; then
  st="$(tr -d '\0' < /proc/device-tree/cooling_fan/status 2>/dev/null)"
  case "$st" in
    okay|"") echo "cooling_fan DT node:    enabled" ;;
    *)       echo "cooling_fan DT node:    $st  <- not enabled; run install.sh (dtparam=cooling_fan=on) and reboot" ;;
  esac
else
  echo "cooling_fan DT node:    missing (not a Pi 5 device tree?)"
fi

# driver binding
if [ -e /sys/bus/platform/drivers/pwm-fan/cooling_fan ]; then
  echo "pwm-fan driver:         bound to cooling_fan"
else
  echo "pwm-fan driver:         NOT bound ($(lsmod | grep -q '^pwm_fan' && echo 'module loaded, no device' || echo 'module not loaded'))"
fi

# cooling device level + trip points
cdev=""
for d in /sys/class/thermal/cooling_device*; do
  [ "$(cat "$d/type" 2>/dev/null)" = "pwm-fan" ] && cdev="$d" && break
done
if [ -n "$cdev" ]; then
  echo "cooling level:          $(cat "$cdev/cur_state") / $(cat "$cdev/max_state")   (0 = off; levels = PWM 75,125,175,250 of 255 by default)"
else
  echo "cooling level:          no pwm-fan cooling device"
fi
tz=/sys/class/thermal/thermal_zone0
if [ -d "$tz" ]; then
  trips=""
  for t in "$tz"/trip_point_*_temp; do
    [ -e "$t" ] || continue
    ty="$(cat "${t%_temp}_type" 2>/dev/null)"
    [ "$ty" = "active" ] && trips="$trips $(awk -v v="$(cat "$t")" 'BEGIN{printf "%g", v/1000}')"
  done
  [ -n "$trips" ] && echo "fan trip points (C):   $trips   (fan is OFF below the first one - normal)"
fi

# tachometer
for h in /sys/class/hwmon/hwmon*; do
  if [ "$(cat "$h/name" 2>/dev/null)" = "pwmfan" ]; then
    echo "fan speed:              $(cat "$h/fan1_input" 2>/dev/null || echo '?') RPM"
  fi
done

# config.txt block on the booted slot
part="$(od -An -tu1 /proc/device-tree/chosen/bootloader/partition 2>/dev/null | awk '{print $NF}')"
if [ -n "$part" ] && [ "$(id -u)" = 0 ]; then
  mnt=/mnt/sc-fan-status; mkdir -p $mnt
  if mount -t vfat -o ro "/dev/mmcblk0p${part}" $mnt 2>/dev/null; then
    if grep -q '^# >>> diy-fan' $mnt/config.txt; then
      echo "config.txt (slot p$part): diy-fan block present:"; sed -n '/^# >>> diy-fan/,/^# <<< diy-fan/p' $mnt/config.txt | grep '^dtparam' | sed 's/^/                          /'
    else
      echo "config.txt (slot p$part): no diy-fan block (fan relies on bootloader auto-detect)"
    fi
    umount $mnt
  fi
fi

if [ "$1" = "--test" ]; then
  if [ -z "$cdev" ]; then echo "cannot test: no pwm-fan cooling device"; exit 1; fi
  [ "$(id -u)" = 0 ] || { echo "--test needs sudo"; exit 1; }
  max="$(cat "$cdev/max_state")"
  echo; echo "spinning the fan at level $max for 5 s ..."
  echo "$max" > "$cdev/cur_state"
  sleep 5
  for h in /sys/class/hwmon/hwmon*; do
    [ "$(cat "$h/name" 2>/dev/null)" = "pwmfan" ] && echo "fan speed at full:      $(cat "$h/fan1_input" 2>/dev/null) RPM"
  done
  echo 0 > "$cdev/cur_state"
  echo "released; the thermal governor is back in control."
fi
