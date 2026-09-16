#!/bin/bash
# Collect everything relevant to "why isn't CAN up" on a DIY SystemCore (Pi 5).
# Run with sudo and paste the whole output back.
sec() { echo; echo "################ $* ################"; }

sec "VERSION"
cat /etc/release.txt 2>/dev/null; uname -a; uptime
echo "Pi model: $(tr -d '\0' </proc/device-tree/model 2>/dev/null)"
echo "Booted from partition: $(od -An -tu1 /proc/device-tree/chosen/bootloader/partition 2>/dev/null | awk '{print $NF}')"

sec "BLOCK DEVICES / config.txt CAN lines in each boot slot"
lsblk -o NAME,SIZE,FSTYPE,LABEL,MOUNTPOINTS 2>/dev/null || lsblk
for n in 2 3; do
  part=/dev/mmcblk0p$n; [ -b $part ] || continue
  mnt=/mnt/sc-diag-p$n; mkdir -p $mnt
  if mount -t vfat -o ro $part $mnt 2>/dev/null; then
    echo "--- $part config.txt (spi/i2c/can/overlay lines) ---"
    grep -nE "^(dtparam=spi|dtoverlay=(mcp|sc-|spi|i2c))" $mnt/config.txt
    ls $mnt/overlays/mcp2515-can0.dtbo $mnt/overlays/mcp2515-can1.dtbo $mnt/overlays/mcp251xfd.dtbo $mnt/overlays/spi1-3cs.dtbo 2>&1 | sed "s/^/    /"
    umount $mnt
  fi
done

sec "DEVICE TREE: overlays the firmware actually applied"
ls /proc/device-tree/chosen/overlays/ 2>/dev/null || echo "(no /proc/device-tree/chosen/overlays)"
echo "--- mcp2515 / mcp2518fd nodes in the live DT ---"
for d in $(find /proc/device-tree -maxdepth 6 -type d \( -name "mcp2515*" -o -name "mcp2518*" -o -name "mcp251xfd*" \) 2>/dev/null); do
  echo "  $d: reg=$(od -An -tu1 $d/reg | awk '{print $NF}') interrupt-gpio=$(od -An -tu1 $d/interrupts 2>/dev/null | awk '{print $4}') status=$(tr -d '\0' <$d/status 2>/dev/null || echo okay)"
done

sec "SPI BUS / driver binding"
ls -l /sys/bus/spi/devices/ 2>/dev/null
for drv in mcp251x mcp251xfd; do echo "--- $drv driver bound to: ---"; ls /sys/bus/spi/drivers/$drv/ 2>/dev/null; done
echo "--- pinctrl state of SPI0 / INT / I2C1 pins ---"
pinctrl get 2,3,7,8,9,10,11,16,17,18,19,20,21,22,23,24,25 2>/dev/null || raspi-gpio get 2,3,7,8,9,10,11,16,17,18,19,20,21,22,23,24,25 2>/dev/null

sec "KERNEL LOG (spi / mcp251x / can / i2c / pinctrl)"
dmesg | grep -iE "mcp251|spi0|spi-dw|dw_spi|designware|i2c1|pinctrl|already requested|can:|vcan|heartbeat|can_sender" | tail -60

sec "NETWORK INTERFACES"
ip -d -s link show 2>/dev/null | grep -A5 -E "^[0-9]+: (can|vcan)" | head -120
echo "--- netdev -> sysfs device mapping ---"
for d in /sys/class/net/*/device; do [ -e "$d" ] && echo "  $(basename $(dirname $d)) -> $(basename $(readlink -f $d))"; done
echo "--- operstate / counters ---"
for c in /sys/class/net/can*; do
  [ -e "$c" ] || continue
  echo "  $(basename $c): $(cat $c/operstate) (rx=$(cat $c/statistics/rx_packets) tx=$(cat $c/statistics/tx_packets) rxerr=$(cat $c/statistics/rx_errors) txerr=$(cat $c/statistics/tx_errors))"
done

sec "INTERRUPT COUNTS (INT pin wiring check: must climb while a powered device is on the bus)"
grep -iE "mcp251|spi|gpio" /proc/interrupts | head -20

sec "SERVICES"
systemctl --no-pager -l status limelight_canbusprocess limelight_canbuswatchdog robot can-bringup mrccomm limelight_motioncoredaemon 2>&1 | grep -vE "^\s*$" | head -80
echo "--- journal (this boot) ---"
journalctl -b --no-pager -o short-monotonic -u limelight_canbusprocess -u can-bringup -u robot -u limelight_canbuswatchdog 2>/dev/null | tail -60
echo "--- ExecStart lines in effect (drop-ins) ---"
systemctl cat limelight_canbusprocess robot 2>/dev/null | grep -E "^(# /|ExecStart)"

sec "MODULES / HEARTBEAT"
lsmod | grep -E "can|mcp|heartbeat|sender|vcan|spi"; ls -la /dev/mrccan/ 2>&1

sec "LIVE TRAFFIC (3 s on can_s0 and can_s1; needs a powered device on the bus)"
for c in can_s0 can_s1; do
  ip link show $c >/dev/null 2>&1 || continue
  echo "--- $c ---"; timeout 3 candump -n 10 $c 2>&1 | head -12
done
echo; echo "done."
