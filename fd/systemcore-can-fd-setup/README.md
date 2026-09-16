# DIY SystemCore CAN setup (Waveshare 2-CH CAN FD HAT, MCP2518FD)

Turns an **official FIRST SystemCore image** running on a Raspberry Pi 5 into a working
DIY substitute that drives Phoenix 6 / REVLib devices over the **Waveshare 2-CH CAN FD HAT**
(two MCP2518FD, Mode A: SPI0 CE0 + SPI1 CE0) and/or a **CANivore** — with everything coming up automatically at boot.

This is a small **overlay installer**, not a full OS image (see *Why no full image?* below).
It was rewritten for **SystemCore image beta 13 / beta 14**; the previous version
(`can-bringup.service`) only worked up to beta 12 — see *What changed in image 13* below.

## What it does

`install.sh`:

1. Writes `../config_with_fd.txt` to **both** A/B boot slots (`/dev/mmcblk0p2` and `p3`,
   originals kept as `config.txt.stock`). That config removes the real SystemCore's five
   `sc-mcp2518-*` buses (their pins collide with SPI0 and the HAT's SPI1 chip selects),
   enables SPI0 + SPI1 (`spi1-3cs`) with `mcp251xfd,spi0-0,interrupt=25` and
   `mcp251xfd,spi1-0,interrupt=24` (Waveshare "Mode A"), and moves `i2c1` off GPIO 10/11
   (SPI0 MOSI/SCLK).
2. Installs a udev rule that names the HAT's buses by **stable SPI path**, the same way
   the stock image names its own buses:
   - `spi0.0` (HAT **CAN_0**) → `can_s0`  (`CANBus.systemCore(0)` in robot code)
   - `spi1.0` (HAT **CAN_1**) → `can_s1`  (`CANBus.systemCore(1)`; the stock rule would
     have called it `can_s3`, the later rule wins)
3. Installs a systemd **drop-in** that makes the stock `limelight_canbusprocess.service`
   run `diy-can-setup.sh` instead of its built-in command. On every boot that script:
   - brings `can_s0` / `can_s1` up at **1 Mbit** CAN 2.0 (renaming them itself if udev
     didn't), with the same ethtool tuning the stock unit applies where the driver supports it;
   - creates `can_s2` / `can_s3` / `can_s4` as **virtual (vcan)** dummies — the WPILib HAL
     aborts at startup unless all of `can_s0`–`can_s4` (and `can_d0`–`can_d19`, which the stock
     `motioncoredaemon` creates) exist;
   - loads the `robot_heartbeat` kernel module **after** the CAN interfaces exist (it fails
     with *"No such device"* if loaded too early) — this creates the `/dev/mrccan/*` enable
     interface that `MrcCommDaemon`, Phoenix and the HAL need — and `i2c-dev`.
4. Installs a drop-in for `robot.service` so robot code doesn't wait 15 s for the vcan dummies
   to report `state UP` (vcan reports `UNKNOWN`).

### What changed in image 13 (why the old `can-bringup.service` stopped working)

Beta 13 added ring/coalesce tuning to the stock CAN bring-up:

```
ip link set can_sN down && ip link set can_sN type can bitrate 1000000 fd off &&
ethtool -G can_sN rx 32 tx 8 && ethtool -C can_sN rx-frames-irq 16 rx-usecs-irq 500 && … && up
```

That works for this HAT's two MCP2518FD buses, but `ip link set can_s2 type can` then fails
on the vcan dummy `can_s2`, the `&&` chain stops, the unit fails and `Restart=on-failure`
re-runs it every 5 s — bouncing `can_s0` / `can_s1` down and up every 5 s forever, so devices
keep dropping off the bus. A parallel unit can't win that fight, so the overlay now
**replaces the stock unit's command** via a drop-in (the unit itself has to stay: beta 14's
CAN watchdog depends on it).

> **Untested:** this FD variant was updated alongside the no-FD one from the beta 13/14 image
> contents but has not been run on an FD HAT yet. Please report results.

### With or without the HAT

The script auto-detects per bus:

| Hardware | `can_s0` / `can_s1` | `can_s2`–`s4` | Drive devices via |
| --- | --- | --- | --- |
| 2-CH CAN FD HAT fitted | physical @ 1 Mbit (CAN 2.0, FD off) | vcan | `CANBus.systemCore(0/1)` |
| No HAT | vcan | vcan | CANivore: `new CANBus("<name>")` |

Either way the robot boots fully and the enable interface comes up. The web UI shows the
vcan dummies as **DOWN** — that's expected and harmless.

**Force all buses virtual** even with the HAT fitted (CANivore-only):
```bash
sudo touch /etc/diy-can-virtual-only   # then reboot;  rm to go back to physical
```

## Requirements

- A Raspberry Pi 5 flashed with the **official SystemCore image, beta 13 or newer**
  (https://github.com/LimelightVision/systemcore-os-public/releases — not redistributed here).
  Pick the image to match your WPILib / vendor library versions — see the compatibility
  table in the [main README](../../README.md).
- The **Waveshare "2-CH CAN FD HAT"** (MCP2518FD ×2) in **Mode A** (CAN_0 on SPI0 CE0 with
  INT GPIO25, CAN_1 on SPI1 CE0 with INT GPIO24 — see the Waveshare wiki). 120 Ω termination
  jumper on if the HAT is at the end of the bus. If your board's interrupts differ, pass
  `--int0 N --int1 M` to `install.sh`.
- Device firmware that **matches the vendor API version** in your robot project (mismatches
  give *"API too old / CAN frame too-stale"* — flash the device in Phoenix Tuner X / REV
  Hardware Client to match).

## Install

Copy the config file and this folder to the Pi and run the installer:
```bash
scp -r fd systemcore@robot.local:/home/systemcore/          # password: systemcore
ssh systemcore@robot.local
cd ~/fd/systemcore-can-fd-setup
sudo ./install.sh
sudo reboot
```
(`install.sh` looks for `config_with_fd.txt` next to itself or one directory up. Use
`sudo ./install.sh --no-config` if you'd rather edit `config.txt` by hand — the manual steps
are in [setup/New Build.md](../../setup/New%20Build.md).)

## Verify
```bash
ip -br link show | grep can_s              # can_s0/can_s1 UP; can_s2-4 present
ls /proc/device-tree/chosen/overlays       # must list spi1-3cs and two mcp251xfd entries
ls /sys/bus/spi/drivers/mcp251xfd/         # spi0.0 spi1.0
ls /dev/mrccan/                            # controldata controldataro enabledro matchinfo matchinforo
systemctl is-active limelight_canbusprocess robot
grep mcp251xfd /proc/interrupts            # counts must climb with a powered device on the bus
candump can_s0                             # frames from your devices
```
Anything missing: `sudo ./diagnose.sh` prints everything relevant (applied overlays, SPI
binding, dmesg, interrupt counts, services, journal, 3 s of candump) — paste it into an issue.

Driving a motor: deploy your robot code, then **enable from the Driver Station** (Enable
button — **not** Space/Enter, which are Emergency-Stop and latch the robot disabled).

## Pin / bus reference

| Code | SocketCAN | Hardware |
| --- | --- | --- |
| `CANBus.systemCore(0)` | `can_s0` | HAT CAN_0 — MCP2518FD on `spi0.0` (SPI0 CE0, INT = GPIO25) |
| `CANBus.systemCore(1)` | `can_s1` | HAT CAN_1 — MCP2518FD on `spi1.0` (SPI1 CE0, INT = GPIO24) |
| `new CANBus("<name>")` | `can2` | CANivore (USB, needs CTRE's two `.ipk` packages) |

(Don't know which physical connector is which? Plug in a powered device and watch which
interface's `rx_packets` climbs: `cat /sys/class/net/can_s0/statistics/rx_packets`.)

## Uninstall
```bash
sudo rm -f /etc/systemd/system/limelight_canbusprocess.service.d/10-diy-can.conf \
           /etc/systemd/system/robot.service.d/10-diy-can.conf \
           /etc/udev/rules.d/71-diy-can-interface-names.rules \
           /usr/local/sbin/diy-can-setup.sh /usr/local/sbin/diy-can-wait.sh
sudo systemctl daemon-reload
# to restore the stock CAN lines: copy config.txt.stock back over config.txt on /dev/mmcblk0p2 and p3
```

## Why no full SD-card image?

The SystemCore base contains **proprietary** FIRST/CTRE software (`robot_heartbeat.ko`,
`MrcCommDaemon`, the Phoenix native libraries, the SystemCore HAL). Redistributing a full
`.img` would redistribute those, which isn't permitted. So the shareable artifact is this
overlay; everyone brings their own official base image.

### Making a personal full image (for your own backup)

Best done with the **card in a reader on a separate Linux machine** (not over SSH on the
live Pi — a mounted root produces an inconsistent image):

```bash
# 1) Power off the Pi, put the SD card in a Linux machine. Find the device (e.g. /dev/sdX).
sudo dd if=/dev/sdX of=systemcore-diy.img bs=4M status=progress

# 2) Shrink it so it flashes to any >= size card (PiShrink also re-expands on first boot):
#    https://github.com/Drewsif/PiShrink
sudo pishrink.sh -a systemcore-diy.img    # -a also regenerates SSH host keys on first boot

# 3) Flash with Raspberry Pi Imager / balenaEtcher to another card.
```
Before sharing **any** image, also change the default `systemcore`/`systemcore` password
and clear `~/logs`. And remember the licensing note above — keep full images for personal
use only.
