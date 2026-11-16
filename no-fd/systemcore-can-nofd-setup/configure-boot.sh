#!/bin/bash
# Add the CAN HAT device-tree overlays to the SystemCore image's config.txt.
#
# Instead of replacing config.txt with a saved copy (which silently drops any settings
# newer SystemCore OS releases add), this appends a small managed block to the stock
# file. Idempotent: re-running replaces the block. Re-run it after every OS reflash or
# OTA update, since those can rewrite config.txt.
#
# Usage:  sudo ./configure-boot.sh            # auto-detect the partition holding config.txt
#         sudo ./configure-boot.sh /dev/XXX   # or name the partition explicitly
set -e

# ---- HAT-specific overlay block (MCP2515, no CAN FD) ---------------------------------
BLOCK='dtparam=spi=on
dtoverlay=mcp2515-can0,oscillator=16000000,interrupt=24,spimaxfrequency=10000000
dtoverlay=mcp2515-can1,oscillator=16000000,interrupt=25,spimaxfrequency=10000000'
# ---------------------------------------------------------------------------------------

BEGIN='# >>> diy-systemcore-can (managed by configure-boot.sh) >>>'
END='# <<< diy-systemcore-can <<<'
MNT=/mnt/hardware_boot

if [ "$(id -u)" != "0" ]; then
  echo "Please run as root:  sudo ./configure-boot.sh" >&2
  exit 1
fi

find_config_part() {
  local p fs mp
  for p in /dev/mmcblk0p* /dev/nvme0n1p* /dev/sd[a-z][0-9]*; do
    [ -b "$p" ] || continue
    fs="$(blkid -o value -s TYPE "$p" 2>/dev/null || true)"
    [ "$fs" = "vfat" ] || continue
    mp="$(mktemp -d)"
    if mount -o ro "$p" "$mp" 2>/dev/null; then
      if [ -f "$mp/config.txt" ] && grep -q '^kernel=' "$mp/config.txt"; then
        umount "$mp"; rmdir "$mp"; echo "$p"; return 0
      fi
      umount "$mp"
    fi
    rmdir "$mp"
  done
  return 1
}

PART="${1:-}"
if [ -z "$PART" ]; then
  PART="$(find_config_part)" || {
    echo "Could not find a vfat partition containing config.txt." >&2
    echo "List partitions with 'lsblk -f' and pass one: sudo ./configure-boot.sh /dev/mmcblk0p2" >&2
    exit 1
  }
fi
echo "==> Using boot config partition $PART"

mkdir -p "$MNT"
mountpoint -q "$MNT" && umount "$MNT"
mount "$PART" "$MNT"
trap 'umount "$MNT" 2>/dev/null || true' EXIT

CFG="$MNT/config.txt"
[ -f "$CFG" ] || { echo "No config.txt on $PART" >&2; exit 1; }

cp "$CFG" "$CFG.bak-$(date +%Y%m%d%H%M%S)"

# Drop a previous managed block, plus CAN lines left by the old copy-paste instructions.
TMP="$(mktemp)"
awk -v b="$BEGIN" -v e="$END" '
  $0 == b {skip=1; next}
  $0 == e {skip=0; next}
  skip {next}
  /^dtoverlay=(mcp2515|mcp251xfd|spi1-3cs)/ {next}
  {print}
' "$CFG" > "$TMP"
# trim trailing blank lines, then append our block
sed -i -e :a -e '/^\n*$/{$d;N;ba' -e '}' "$TMP"
{ cat "$TMP"; printf '\n%s\n%s\n%s\n' "$BEGIN" "$BLOCK" "$END"; } > "$CFG"
rm -f "$TMP"
sync

echo "==> config.txt now ends with:"
tail -n 6 "$CFG"
echo
echo "Done. Reboot to load the overlays:  sudo reboot"
