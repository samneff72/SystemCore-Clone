#!/bin/bash
# DIY SystemCore CAN bring-up for the Waveshare 2-CH CAN HAT (2x MCP2515 on SPI0), run in place of the
# stock limelight_canbusprocess.service command via a systemd drop-in.
#
# For each SystemCore bus can_s0..can_s4: bring the physical controller up at 1 Mbit
# under that name if it exists, otherwise create a vcan dummy (the WPILib HAL needs all
# five). Then load robot_heartbeat (needs the interfaces first) and i2c-dev.
# Force ALL buses virtual (e.g. CANivore-only) by creating /etc/diy-can-virtual-only
set +e

# Linux SPI device behind each physical SystemCore bus (see config_*.txt + udev rule)
BUS0_SPI=spi0.0   # HAT CAN_0 -> can_s0
BUS1_SPI=spi0.1   # HAT CAN_1 -> can_s1

FORCE_VIRTUAL=0
[ -e /etc/diy-can-virtual-only ] && FORCE_VIRTUAL=1

log() { echo "diy-can: $*"; }

ifname_for() { # $1 = spi path (e.g. spi0.0); prints the netdev bound to it, else empty
  local d
  for d in /sys/class/net/*/device; do
    [ -e "$d" ] || continue
    if [ "$(basename "$(readlink -f "$d")")" = "$1" ]; then
      basename "$(dirname "$d")"
      return 0
    fi
  done
  return 1
}

make_vcan() { # $1 = name
  if ! ip link show "$1" >/dev/null 2>&1; then
    ip link add "$1" type vcan 2>/dev/null
    ip link set "$1" mtu 16 2>/dev/null   # CAN 2.0 MTU, same as motioncoredaemon's can_d* vcans
  fi
  ip link set "$1" up 2>/dev/null
}

setup_bus() { # $1 = spi path ("" = none/virtual), $2 = target name
  local cur=""
  if [ "$FORCE_VIRTUAL" = "0" ] && [ -n "$1" ]; then
    cur="$(ifname_for "$1")"
  fi
  if [ -n "$cur" ]; then
    ip link set "$cur" down 2>/dev/null
    if [ "$cur" != "$2" ]; then
      # udev rule missing or raced; rename ourselves
      if ip link show "$2" >/dev/null 2>&1; then
        log "WARNING: $2 already exists (type $(ip -d link show "$2" | awk 'NR==3{print $1}')) - deleting it to make room for $cur ($1)"
        ip link set "$2" down 2>/dev/null
        ip link delete "$2" 2>/dev/null
      fi
      ip link set "$cur" name "$2" 2>/dev/null
    fi
    ip link set "$2" type can bitrate 1000000 fd off 2>/dev/null \
      || ip link set "$2" type can bitrate 1000000 2>/dev/null
    # same tuning the stock unit applies, best-effort (not supported by mcp251x)
    ethtool -G "$2" rx 32 tx 8 >/dev/null 2>&1
    ethtool -C "$2" rx-frames-irq 16 rx-usecs-irq 500 >/dev/null 2>&1
    ip link set "$2" txqueuelen 1000 2>/dev/null
    ip link set "$2" up 2>/dev/null
    log "$2 = PHYSICAL ($cur on $1) @ 1 Mbit, state $(cat /sys/class/net/$2/operstate 2>/dev/null)"
  else
    make_vcan "$2"
    log "$2 = VIRTUAL (vcan dummy)"
  fi
}

modprobe vcan 2>/dev/null

# Give the CAN controllers up to ~12 s to probe (the RP1 SPI controllers and the
# CAN driver are initialised asynchronously). With no HAT this just times out
# -> all virtual.
if [ "$FORCE_VIRTUAL" = "0" ]; then
  for i in $(seq 1 24); do
    [ -n "$(ifname_for $BUS0_SPI)" ] && [ -n "$(ifname_for $BUS1_SPI)" ] && break
    sleep 0.5
  done
fi

setup_bus $BUS0_SPI can_s0   # HAT CAN_0
setup_bus $BUS1_SPI can_s1   # HAT CAN_1
setup_bus ""        can_s2   # no physical controller on this board -> virtual
setup_bus ""        can_s3
setup_bus ""        can_s4

# robot_heartbeat depends on can_sender (modprobe pulls it in). It needs the
# CAN interfaces to exist first (real or vcan both satisfy it) and creates the
# /dev/mrccan/* enable interface that MrcCommDaemon and the HAL use.
if modprobe robot_heartbeat; then
  log "robot_heartbeat loaded ($(ls /dev/mrccan 2>/dev/null | tr '\n' ' '))"
else
  log "WARNING robot_heartbeat failed to load"
fi
modprobe i2c-dev 2>/dev/null

exit 0
