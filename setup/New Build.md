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
- You will be expected to know how to copy / "burn" an image to an sd card using either balena etcher or raspberry pi imager. The instructions to do that are not in the scope of this guide. Burn the default "base" image from the main readme (**beta 13 or newer**; unzip the `…betacm5…zip` and flash the `.img`).
- You will be expected to know how to push files from your local device using SCP to the remote pi.
- Pick the image / WPILib / vendor-library combination from the compatibility table in the main readme **before** you start (e.g. CTRE Phoenix 6 currently needs image 13 + WPILib alpha-6).


## Step By Step Instructions

- Fit the CAN HAT (no-FD HAT: VIO jumper on 3.3 V; 120 Ω termination on if the HAT is at the end of the bus), put the burned card in your raspberry pi and boot it.

- Connect to the wireless network "SYSTEMCORE" using the password "PASSWORD" (upper case sensitive). The Pi is at http://172.30.0.1 (or http://robot.local); SSH user `systemcore`, password `systemcore`.

- Copy the folder for your CAN board from this repo to the Pi from your local device using the command line. Copy the whole `fd` or `no-fd` folder — the installer needs the `config_*.txt` next to it.
```
For FD:
scp -r fd systemcore@172.30.0.1:/home/systemcore/

For NO FD:
scp -r no-fd systemcore@172.30.0.1:/home/systemcore/
```

- SSH in (or use the "terminal" app on the main dashboard) and run the installer
```
Use one of the below commands corresponding to your CAN Board
cd ~/fd/systemcore-can-fd-setup
or
cd ~/no-fd/systemcore-can-nofd-setup

sudo ./install.sh
sudo reboot
```
  The installer writes the matching `config_*.txt` into **both** boot slots of the card
  (`/dev/mmcblk0p2` and `/dev/mmcblk0p3` — the image is A/B; the OTA updater can switch
  slots, so editing only `p2` by hand is not enough after an OTA update), keeps the originals
  as `config.txt.stock`, installs the udev rule, the bring-up script and the systemd drop-ins.
  If your no-FD HAT's interrupt solder pads were moved, add `--int0 22 --int1 24`.

  <details>
  <summary>Editing config.txt by hand instead (optional, then run <code>sudo ./install.sh --no-config</code>)</summary>

  ```
  sudo mkdir -p /mnt/hardware_boot
  sudo mount /dev/mmcblk0p2 /mnt/hardware_boot      # repeat for p3 if you have OTA-updated
  sudo nano /mnt/hardware_boot/config.txt
  ```
  Remove the full contents of the file, paste in the contents of `config_with_fd.txt` or
  `config_no_fd.txt`, save (Ctrl+O, Enter, Ctrl+X), then
  ```
  sudo umount /mnt/hardware_boot
  ```
  </details>

- Install the CANivore drivers by installing the .ipk as an app in the 4th tile option on the main dashboard (only needed if you use a CANivore).
    - Reconnect to the systemcore network if necessary
    - Select add packages in the web dashboard
    - Drag and drop the first canivore-usb-kernel_1.18_aarch64.ipk file to install
    - Drag and drop the second canivore-usb_1.16_aarch64.ipk file to install
    - reboot

- Verify all is running fine as expected
```
From terminal execute the following command to validate the bus is good and all channels are as expected. We expect only the first 2 channels to be physical (type can) and all others to be virtual (vcan) - the web UI shows the virtual ones as DOWN, that is expected.

ip -br link show | grep can_s

Validate that the CAN bring-up service and robot service are active

systemctl is-active limelight_canbusprocess robot

Validate the enable interface exists

ls /dev/mrccan

If anything is missing, run the diagnostics and read (or share) the output:

sudo ./diagnose.sh
```
- Update necessary firmware on the motor
    - CTRE
        - Open Phoenix Tuner application
        - Connect to the robot using dashboard or ip address
        - Update the firmware to the Phoenix version matching your Phoenix API (26.x firmware for the 26.50.0-alpha-1 API — yes, the year numbers don't line up with WPILib 2027).

- Deploy robot code

    - We've built some robot code for you that is an example project for both the Commands v2 and V3 frameworks. You can find the projects in the project_examples folder of this repo. Select the version that corresponds to your hardware. Deploy as normal. In code, HAT CAN_0 is `CANBus.systemCore(0)` and HAT CAN_1 is `CANBus.systemCore(1)`.
