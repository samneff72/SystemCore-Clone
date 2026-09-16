# DIY SystemCore CAN setup

Turns an **official FIRST SystemCore image** running on a Raspberry Pi 5 into a working
DIY substitute that drives CTRE Phoenix 6 devices over **on-board MCP2515 CAN pins**
and/or a **CANivore** — with everything coming up automatically at boot.

This is a small **overlay installer**, not a full OS image (see *Why no full image?* below).
It needs **SystemCore image 13 or newer**.

## What it does

`install.sh`:

1. Edits `config.txt` in place on both boot slots (`/dev/mmcblk0p2` and `p3`): the stock
   SystemCore CAN lines are commented out with a `#diy-can: ` prefix and the block between
   `# >>> diy-can` and `# <<< diy-can` from `../config_no_fd.txt` is added. Nothing else in
   the file is touched.
2. Installs a udev rule that names the two MCP2515 buses by **stable SPI path**:
   - `spi0.0` → `can_s0`  (addressed in code as `CANBus.systemcore(0)`)
   - `spi0.1` → `can_s1`  (`CANBus.systemcore(1)`)
3. Points the stock `limelight_canbusprocess.service` at `diy-can-setup.sh` (systemd
   drop-in). On every boot that script sets **1 Mbit** and brings `can_s0`/`can_s1` up,
   creates `can_s2`/`can_s3`/`can_s4` as **virtual (vcan)** dummies — the WPILib HAL aborts
   at startup unless all of `can_s0`–`can_s4` exist — and then loads the `robot_heartbeat`
   kernel module, which creates the `/dev/mrccan/*` enable interface the Phoenix native
   and HAL need.

   The stock unit has to be overridden rather than supplemented: since image 13 it applies
   `ethtool` ring/coalesce settings the MCP2515 driver doesn't support, fails, and is
   restarted every 5 s — taking `can_s0` down each time.
4. Adds a `robot.service` drop-in so robot code starts as soon as the buses are up instead
   of waiting 15 s for the vcan dummies.

### With or without the pin board

The script auto-detects per bus:

| Hardware | `can_s0` / `can_s1` | `can_s2`–`s4` | Drive devices via |
| --- | --- | --- | --- |
| MCP2515 pin board fitted | physical @ 1 Mbit | vcan | `CANBus.systemcore(0/1)` |
| No pin board | vcan | vcan | CANivore: `new CANBus("reefmaster")` |

Either way the robot boots fully and the enable interface comes up. The web UI shows the
vcan dummies as DOWN; that is expected.

**Force all buses virtual** even with the board fitted (CANivore-only):
```bash
sudo touch /etc/diy-can-virtual-only   # then reboot;  rm to go back to physical
```

## Requirements

- A Raspberry Pi 5 flashed with the **official FIRST SystemCore image**, version 13 or
  newer (obtain it yourself from FIRST/CTRE — it is not redistributed here).
- For physical CAN: the **Waveshare 2-CH CAN HAT** (two MCP2515 on SPI0, `spi0.0`/`spi0.1`;
  VIO jumper on 3.3 V) with proper 120 Ω bus termination. Its default interrupt pins are
  GPIO 23 (CAN_0) and 25 (CAN_1); if you moved the solder pads, pass
  `--int0 22 --int1 24` to `install.sh`. (No board? It still works over a CANivore.)
- Phoenix 6 device firmware that **matches the Phoenix API version** in your robot project
  (mismatched versions give *"API too old / CAN frame too-stale"* — flash the device in
  Phoenix Tuner X to match).

## Install

Copy the `no-fd` folder to the Pi and run the installer:
```bash
scp -r no-fd systemcore@<pi-address>:/home/systemcore/
ssh systemcore@<pi-address>
cd ~/no-fd/systemcore-can-nofd-setup
sudo ./install.sh
sudo reboot
```
(`--no-config` skips the `config.txt` edit if you pasted `config_no_fd.txt` in by hand.)

## Verify
```bash
ip -br link show | grep can_s          # can_s0/can_s1 up; can_s2-4 present
ls /dev/mrccan/                        # controldata controldataro enabledro matchinfo matchinforo
systemctl is-active limelight_canbusprocess robot  # both active
sudo ./diagnose.sh                     # everything above plus dmesg/journal, for bug reports
```
Driving a motor: deploy your robot code, then **enable from the Driver Station** (Enable
button — **not** Space/Enter, which are Emergency-Stop and latch the robot disabled).

## Pin / bus reference

| Code | SocketCAN | Hardware |
| --- | --- | --- |
| `CANBus.systemcore(0)` | `can_s0` | HAT CAN_0 — MCP2515 on `spi0.0` (CE0, INT GPIO 23) |
| `CANBus.systemcore(1)` | `can_s1` | HAT CAN_1 — MCP2515 on `spi0.1` (CE1, INT GPIO 25) |
| `new CANBus("reefmaster")` | `can2` | CANivore (USB) |

(Don't know which physical connector is which? Plug in a powered device and watch which
interface's `rx_packets` climbs: `cat /sys/class/net/can_s0/statistics/rx_packets`.)

## Uninstall
```bash
sudo ./uninstall.sh   # removes the services/rules/scripts and restores the stock config.txt lines
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
