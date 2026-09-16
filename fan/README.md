# Pi 5 fan

Makes sure the Raspberry Pi 5 fan (Active Cooler / fan header) runs on the SystemCore image.
Independent of the CAN HAT overlays and of `rsl/`.

The Pi 5 device tree only enables its `cooling_fan` node when the bootloader detects a fan at
power-on, and the standard curve keeps the fan **off below 50 °C** — so a stopped fan on an
idle Pi is often not a fault. `install.sh` forces the node on (`dtparam=cooling_fan=on`) and
optionally changes the curve; the kernel then drives the fan from the CPU temperature.

Standard curve: level 1 (30 %) at 50 °C, 2 (50 %) at 60 °C, 3 (70 %) at 67.5 °C, 4 (100 %)
at 75 °C, each with 5 °C hysteresis.

## Check first

```bash
sudo ./status.sh          # temperature, fan node/driver state, current level, RPM
sudo ./status.sh --test   # spins the fan at full speed for 5 s
```

## Install

```bash
scp -r fan systemcore@<pi-address>:/home/systemcore/
ssh systemcore@<pi-address>
cd ~/fan
sudo ./install.sh          # stock curve, fan forced on
sudo reboot
```

| option | effect |
| --- | --- |
| `--start-temp T` | start the curve at `T` °C instead of 50 (e.g. `--start-temp 40`) |
| `--always-on` | lowest level from boot onward (first trip at 1 °C) |
| `--min-speed N` | PWM (0–255) of the lowest level, default 75 |
| `--temps T0,T1,T2,T3` | all four trip temperatures in °C |
| `--no-config` | leave `config.txt` alone |

`install.sh` writes a `# >>> diy-fan … # <<< diy-fan` block into `config.txt` on both boot
slots and touches nothing else, so it can be run before or after the other installers.
Re-running it replaces the previous settings.

## Uninstall

```bash
sudo ./uninstall.sh      # removes the diy-fan block from both slots
```
