# New Build Guide
A simple step by step guide to configuring the raspberry pi for a CAN HAT.

## The Mission

Our team uses summer projects to prepare our developers for the latest WPILib changes before
the competition season begins. However, as many teams know, a Systemcore is required for
much of this work—and obtaining one is currently not possible. Rather than letting that become
a roadblock, we set out to overcome it by creating a Systemcore clone using a Raspberry Pi
flashed with the Systemcore operating system.

If your team is in the same situation, you've come to the right place! This guide will walk you
through the process of building and setting up your own Systemcore clone so you can start
developing and testing earlier.

## Assumptions
- You know how to flash ("burn") an image to an SD card with Raspberry Pi Imager or balenaEtcher. That isn't covered here. Flash the **SystemCore OS release 17** base image (see the version table in the main [README](../README.md)).
- You know how to copy files from your computer to the Pi with `scp`.
- You are using the **no-FD CAN HAT**. The CAN FD HAT path is deprecated.

## Step By Step Instructions

- Put the flashed card in the Raspberry Pi and power it on.

- Connect to the Pi.
    - **OS 17 and later:** the Wi-Fi network is `SYSTEMCORE-<suffix>` and the password is unique per unit. (`PASSWORD` is no longer accepted.) Real SystemCore hardware shows the password on its built-in display, which the Pi doesn't have, so connect another way first:
        - **Ethernet:** plug the Pi into your network and browse to `http://robot.local`.
        - **USB-C:** connect the Pi's USB-C port to your computer and browse to `172.26.0.1` (Windows) or `172.27.0.1` (macOS/Linux).
    - Read the Wi-Fi name and password in the web UI, and change them if you like.
    - Not yet verified on a Pi: how OS 17 derives the per-unit suffix on non-SystemCore hardware. If Wi-Fi doesn't come up, use Ethernet or USB-C.

- Copy the setup folder from this repo to the Pi's home directory:
```
scp -r no-fd/systemcore-can-nofd-setup systemcore@<pi-address>:/home/systemcore/
```

- Run the installer and reboot. From the web dashboard's "terminal" app, or over `ssh systemcore@<pi-address>`:
```
cd ~/systemcore-can-nofd-setup
sudo ./install.sh
sudo reboot
```
`install.sh` installs the CAN bring-up service and adds the CAN HAT overlay lines to the image's own `config.txt` (in a marked block, with a dated backup). You no longer need to edit `config.txt` by hand.
If it can't find the boot partition, list partitions with `lsblk -f` and run `sudo ./configure-boot.sh /dev/<partition>`, then reboot.

- **After any OS reflash or OTA update, run `sudo ./install.sh` again and reboot.** Updates can overwrite `config.txt` and the installed service.

- Install the CANivore package (only if you use a CANivore):
    - Download `canivore-usb_1.18_systemcoreos_alphabeta_17.ipk` (link in the main README). On OS 15 and later this one IPK replaces the old kernel + userspace pair.
    - In the web dashboard, open **Add Package** and drag the `.ipk` in.
    - Reboot.

- Verify everything is running:
```
ip -br link show | grep can_s           # can_s0/can_s1 physical and UP; can_s2-4 virtual
ip -br link show | grep -c 'can_[sd]'   # expect 25: the WPILib HAL opens can_s0-4 and can_d0-19
ls /dev/mrccan/                         # enable interface from robot_heartbeat
systemctl is-active can-bringup robot   # both "active"
```

- Update motor firmware (CTRE):
    - Open **Phoenix Tuner X Preview** (the stable Tuner X doesn't support the 2027 alpha).
    - Connect to the robot by dashboard or IP address.
    - Flash firmware **26.70.x** to match the Phoenix 6 `26.70.0-alpha-2` vendordep. Mismatched firmware gives "API too old / CAN frame too stale" errors.

- Deploy robot code.
    - Example projects for Commands v2 and v3 are in [`project_examples/ctre`](../project_examples/ctre). They target WPILib 2027 alpha-8 and Phoenix 6 `26.70.0-alpha-2`. Open one in **2027_alpha8 WPILib VS Code**, set your team number, and deploy as normal.
    - Systemcore CAN buses are addressed as `new CANBus(CANPort.CAN_S0)` / `CAN_S1`. The old `CANBus.systemcore(n)` call was removed.
