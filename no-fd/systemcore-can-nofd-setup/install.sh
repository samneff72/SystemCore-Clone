#!/bin/bash
# Install the DIY SystemCore CAN bring-up onto a SystemCore-base image.
# Idempotent: safe to re-run. Run as root (sudo).
set -e

if [ "$(id -u)" != "0" ]; then
  echo "Please run as root:  sudo ./install.sh" >&2
  exit 1
fi

DIR="$(cd "$(dirname "$0")" && pwd)"

echo "==> Installing /usr/local/sbin/diy-can-setup.sh"
mkdir -p /usr/local/sbin
install -m 0755 "$DIR/diy-can-setup.sh" /usr/local/sbin/diy-can-setup.sh

echo "==> Installing /etc/systemd/system/can-bringup.service"
install -m 0644 "$DIR/can-bringup.service" /etc/systemd/system/can-bringup.service

# robot_heartbeat must NOT auto-load from modules-load.d: it runs before any CAN
# interface exists and fails ("No such device"). Our service loads it at the right time.
if [ -e /etc/modules-load.d/robot_heartbeat.conf ]; then
  echo "==> Removing premature robot_heartbeat from /etc/modules-load.d/"
  rm -f /etc/modules-load.d/robot_heartbeat.conf
fi

echo "==> Enabling can-bringup.service"
systemctl daemon-reload
systemctl enable can-bringup.service

# Add the HAT's device-tree overlays to the stock config.txt (appends a managed block
# rather than replacing the file, so settings from newer OS releases are kept).
# Skip with SKIP_BOOT_CONFIG=1 if you manage config.txt yourself.
if [ "${SKIP_BOOT_CONFIG:-0}" != "1" ]; then
  echo "==> Configuring CAN overlays in config.txt"
  "$DIR/configure-boot.sh"
fi

echo
echo "Done. Reboot to load the CAN overlays and start the bring-up service:  sudo reboot"
echo "Verify after reboot with:   ls /dev/mrccan/ ; ip -br link show | grep can_"
