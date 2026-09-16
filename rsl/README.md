# Robot Signal Light (RSL)

Adds an RSL output to the Raspberry Pi 5 SystemCore clone: **solid when disabled, blinking
when enabled**, off until the robot services are up — the same behaviour as the RSL port on a
roboRIO or SystemCore. Robot code needs no changes. Independent of the CAN HAT overlays.

It reads the robot enable state from `/dev/mrccan/enabledro` (maintained by the stock
`MrcCommDaemon` from the Driver Station) and drives **GPIO26 (header pin 37)** as a kernel
LED (`dtoverlay=gpio-led`); blinking is done by the kernel's timer trigger.

## Wiring

The Pi pin is 3.3 V and a few mA, so it cannot switch the 12 V light directly. Use a
**logic-level** N-channel MOSFET module (one that turns fully on at 3.3 V — not the common
IRF520 boards) or a relay module with a 3.3 V-compatible input:

| RSL / module terminal | connect to |
| --- | --- |
| RSL `La` and `Lb` (jumpered together, as in the standard FRC wiring) | +12 V from a low-current PDH/PDP channel |
| RSL `N` | MOSFET drain / module `OUT-` (relay: NO contact, the other contact to 12 V ground) |
| module `GND` / source | robot ground (shared with the Pi's ground) |
| module `SIG` / gate | Pi header **pin 37 (GPIO26)**; module ground to **pin 39 (GND)** |

* No gate pull-down on the module? Add 10 kΩ gate→GND so the light stays off while the Pi boots.
* Module lights the RSL when the signal is **low**? Install with `--active-low`.
* Another pin? `--gpio N` (GPIO 26 is free with both CAN HATs).
* Bench test: a plain LED + 330 Ω from pin 37 to pin 39 shows the same behaviour.

## Install

```bash
scp -r rsl systemcore@<pi-address>:/home/systemcore/
ssh systemcore@<pi-address>
cd ~/rsl
sudo ./install.sh          # options: --gpio N   --active-low   --no-config
sudo reboot
```

`install.sh` writes a `# >>> diy-rsl … # <<< diy-rsl` block into `config.txt` on both boot
slots and installs `diy-rsl.py` + `diy-rsl.service`. It touches nothing else in `config.txt`,
so it can be run before or after the CAN HAT installer.

## Verify

```bash
systemctl status diy-rsl              # active; log lines "diy-rsl: solid|blink|off"
cat /dev/mrccan/enabledro             # 0 disabled / 1 enabled (from the Driver Station)
cat /sys/class/leds/rsl/trigger       # [none] while disabled, [timer] while enabled
```

Blink timing and poll rate are `Environment=` variables in `diy-rsl.service`.

## Uninstall

```bash
sudo ./uninstall.sh      # removes the service and the diy-rsl block from both slots
```
