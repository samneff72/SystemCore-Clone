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
- You will be expected to know how to copy / "burn" an image to an sd card using either balena etcher or raspberry pi imager. The instructions to do that are not in the scope of this guide.
- You will be expected to know how to push files from your local device using SCP to the remote pi.

## What to burn

Use an **official** Systemcore image, **version 13 or newer**, from
https://github.com/LimelightVision/systemcore-os-public/releases — the beta asset
(`limelightsystemcorebetacm5-...zip`), unzipped to a `.img`. This guide was written and
tested against image 13.

The prebuilt Bobcat images linked from the [no-fd](../no-fd/README.md) / [fd](../fd/README.md)
pages predate this and are **not** compatible with the installer below; they are image 12,
which is missing the changes this overlay works around.

## Step By Step Instructions

- Put the card in your raspberry pi once its been burned, and power it on

- Connect to the wireless network "SYSTEMCORE" using the password "PASSWORD" (upper case sensitive).
  The pi is then reachable at `172.30.0.1` (or `robot.local`); the web dashboard is on port 80 and
  SSH uses the user `systemcore` with password `systemcore`.

- Copy the fd or no-fd folder to the home directory of the pi from your local device using command line.
```
For FD:
scp -r fd systemcore@172.30.0.1:/home/systemcore/

For NO FD:
scp -r no-fd systemcore@172.30.0.1:/home/systemcore/

```
- Execute the installer by entering the folder directory. It edits config.txt for you — on both
  boot partitions of the card, because the image keeps two and the OTA updater can switch which
  one is active — and installs the CAN services.
```
Use one of the below commands corresponding to your CAN Board
cd ~/fd/systemcore-can-fd-setup 
or 
cd ~/no-fd/systemcore-can-nofd-setup 

sudo ./install.sh
sudo reboot
```
    - The installer only touches the CAN lines: it comments out the stock ones and adds its own block between `# >>> diy-can` and `# <<< diy-can`. Everything else in config.txt is left as it was, and `sudo ./uninstall.sh` puts it back.
    - If you would rather do it by hand, copy that block out of config_with_fd.txt or config_no_fd.txt into config.txt yourself (on **both** boot partitions — `sudo mkdir -p /mnt/hardware_boot && sudo mount /dev/mmcblk0p2 /mnt/hardware_boot`, edit, `sudo umount /mnt/hardware_boot`, then the same for `/dev/mmcblk0p3`), and run `sudo ./install.sh --no-config`.

- If you are using a CANivore, install its drivers as an app from the "Add Package" card on the
  main dashboard. Skip this if you have no CANivore.
    - Reconnect to the systemcore network if necessary
    - Install the kernel package first, then the usb package — the second one depends on the first
    - Drag and drop the first canivore-usb-kernel_1.18_aarch64.ipk file to install
    - Drag and drop the second canivore-usb_1.16_aarch64.ipk file to install
    - reboot

- Verify all is running fine as expected
```
From terminal execute the following command to validate the bus is good and all channels are as expected . We expect only the first 2 channels to be listed as physical and all others to be virtual.

ip -br link show | grep can_s

Confirm the enable interface the robot program needs was created

ls /dev/mrccan/

From the terminal execute the following command to validate that the can bringup service is online and active 

systemctl is-active limelight_canbusprocess robot
```
    - If any of that is missing, `sudo ./diagnose.sh` collects the overlay, SPI, service and kernel-log state in one go.

- Update necessary firmware on the motor
    - CTRE
        - Open pheonix tuner application
        - Connect to the robot using dashboard or ip address
        - Update the firmeware to the latest 2026 Phoenix version ( I know this is confusing as we are supposed to be on 2027 ).
        - Tuner's firmware picker defaults to the 2027 files, and those do not work with the Phoenix version the example projects use — switch the year to 2026 first. A device left on 2027 firmware answers on the bus but every control request fails with `ApiTooOld` (-10030).

- Deploy robot code

    - We've built some robot code for you that is an example project for both the Commands v2 and V3 frameworks. You can find the projects in the project_examples folder of this repo. Pick the one matching the command framework your team uses; the hardware setup is the same either way. Deploy as normal.
    - Both examples drive a Talon FX on `CANBus.systemcore(1)`, which is `can_s1` — the second connector on the HAT.

- Optional extras, each installed on its own: a Robot Signal Light ([rsl/README.md](../rsl/README.md)) and the Pi 5 fan ([fan/README.md](../fan/README.md)).
