# DIY SystemCore CAN setup

Turns an **official FIRST SystemCore image** running on a Raspberry Pi 5 into a working
DIY substitute that drives CTRE Phoenix 6 devices over the **Waveshare 2-CH CAN FD HAT**
and/or a **CANivore** — with everything coming up automatically at boot.

This is a small **overlay installer**, not a full OS image (see *Why no full image?* below).

## What it does

On every boot, a oneshot service (`can-bringup.service` → `diy-can-setup.sh`):

1. Detects the two MCP2518FD SPI CAN controllers and names them by **stable SPI path**
   (probe-order independent), sets **1 Mbit**, and brings them up:
   - `spi0.0` → `can_s0`  (addressed in code as `new CANBus(CANPort.CAN_S0)`)
   - `spi1.0` → `can_s1`  (`new CANBus(CANPort.CAN_S1)`)
2. Creates `can_s2`/`can_s3`/`can_s4` as **virtual (vcan)** dummies — the WPILib HAL aborts
   at startup unless all of `can_s0`–`can_s4` exist.
3. Loads the `robot_heartbeat` kernel module **after** the CAN interfaces exist (it fails
   with *"No such device"* if loaded too early), which creates the `/dev/mrccan/*` enable
   interface the Phoenix native and HAL need.

It also removes `robot_heartbeat` from `/etc/modules-load.d/` (where the stock image loads
it too early).

### With or without the HAT

The script auto-detects per bus:

| Hardware | `can_s0` / `can_s1` | `can_s2`–`s4` | Drive devices via |
| --- | --- | --- | --- |
| CAN FD HAT fitted | physical @ 1 Mbit | vcan | `new CANBus(CANPort.CAN_S0 / CAN_S1)` |
| No HAT | vcan | vcan | CANivore: `new CANBus("reefmaster")` |

Either way the robot boots fully and the enable interface comes up.

**Force all buses virtual** even with the board fitted (CANivore-only):
```bash
sudo touch /etc/diy-can-virtual-only   # then reboot;  rm to go back to physical
```

## Requirements

- A Raspberry Pi 5 flashed with the **official SystemCore OS image, release 17**
  (`limelightosr-2027.0.0-beta17-233` / `-alpha17-403`) from
  https://github.com/LimelightVision/systemcore-os-public/releases — obtain it yourself,
  it is not redistributed here. Release 17 is the newest image CTRE publishes a CANivore
  package for; see the version table in the top-level README.
- For physical CAN: the **Waveshare 2-CH CAN FD HAT** in Mode A (`spi0.0`, `spi1.0`), with
  proper 120 Ω bus termination. (No HAT? It still works over a CANivore.)
- Phoenix 6 device firmware that **matches the Phoenix API version** in your robot project:
  vendordep `26.70.0-alpha-2` needs firmware `26.70.x` (mismatched versions give
  *"API too old / CAN frame too-stale"* — flash the device with **Phoenix Tuner X Preview**).

## Install

Copy this folder to the Pi and run the installer:
```bash
scp -r systemcore-can-fd-setup systemcore@<pi-address>:/home/systemcore/
ssh systemcore@<pi-address>
cd ~/systemcore-can-fd-setup
sudo ./install.sh
sudo reboot
```

`install.sh` installs the bring-up service **and** runs `configure-boot.sh`, which appends
the HAT's `dtoverlay` lines to the image's own `config.txt` in a marked block (it no
longer needs to be replaced by hand). It auto-detects the partition holding `config.txt`;
if that fails, find it with `lsblk -f` and run `sudo ./configure-boot.sh /dev/<partition>`.

**After any OS reflash or OTA update, re-run `sudo ./install.sh` and reboot** — updates
can rewrite `config.txt` and the root filesystem.

## Verify
```bash
ip -br link show | grep can_s          # can_s0/can_s1 up; can_s2-4 present
ip -br link show | grep -c 'can_[sd]'  # 25: the HAL opens can_s0-4 AND can_d0-19 (image creates can_d*)
ls /dev/mrccan/                        # controldata controldataro enabledro matchinfo matchinforo
systemctl is-active can-bringup robot  # both active
```
Driving a motor: deploy your robot code, then **enable from the Driver Station** (Enable
button — **not** Space/Enter, which are Emergency-Stop and latch the robot disabled).

## Pin / bus reference

| Code | SocketCAN | Hardware |
| --- | --- | --- |
| `new CANBus(CANPort.CAN_S0)` | `can_s0` | CAN_0 on the HAT (`spi0.0`) |
| `new CANBus(CANPort.CAN_S1)` | `can_s1` | CAN_1 on the HAT (`spi1.0`) |
| `new CANBus("reefmaster")` | `can2` | CANivore (USB) |

(Don't know which physical connector is which? Plug in a powered device and watch which
interface's `rx_packets` climbs: `cat /sys/class/net/can_s0/statistics/rx_packets`.)

## Uninstall
```bash
sudo systemctl disable --now can-bringup.service
sudo rm /etc/systemd/system/can-bringup.service /usr/local/sbin/diy-can-setup.sh
sudo systemctl daemon-reload
# then delete the "diy-systemcore-can" block from config.txt (a dated .bak copy sits next to it)
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
