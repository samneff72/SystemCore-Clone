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
- You will be expected to know how to copy / "burn" an image to an sd card using either balena etcher or raspberry pi. The instructions to do that are not in the scope of this guide. Burn the default "base" image on the main readme (image 13 or newer). 
- You will be expected to know how to push files from your local device using SCP to the remote pi.


## Step By Step Instructions

- Put the card in your raspberry pi once its been burned

- Connect to the wireless network "SYSTEMCORE" using the password "PASSWORD" (upper case sensitive)

- Copy the fd or no-fd folder to the home directory of the pi from your local device using command line.
```
For FD:
scp -r fd systemcore@<pi-address>:/home/systemcore/

For NO FD:
scp -r no-fd systemcore@<pi-address>:/home/systemcore/

```
- Execute the installer in the command by entering the folder directory. It edits config.txt for you (on both boot partitions of the card) and installs the CAN services.
```
Use one of the below commands corresponding to your CAN Board
cd ~/fd/systemcore-can-fd-setup 
or 
cd ~/no-fd/systemcore-can-nofd-setup 

sudo ./install.sh
sudo reboot
```
    - If you would rather edit config.txt by hand: mount the hidden boot partition (`sudo mount /dev/mmcblk0p2 /mnt/hardware_boot`), replace its config.txt with the contents of config_with_fd.txt or config_no_fd.txt, unmount, and run `sudo ./install.sh --no-config` instead.

- Install the canivore drivers by installing the .ipk as an app in the 4th tile option on the main dashboard.
    - Reconnect to the systemcore network if necessary
    - Select add packages in the web dashboard (install the two packages in this order: kernel first, then usb)
    - Drag and drop the first canivore-usb-kernel_1.18_aarch64.ipk file to install
    - Drag and drop the second canivore-usb_1.16_aarch64.ipk file to install
    - reboot

- Verify all is running fine as expected
```
From terminal execute the following command to validate the bus is good and all channels are as expected . We expect only the first 2 channels to be listed as physical and all others to be virtual.

ip -br link show | grep can_s

From the terminal execute the following command to validate that the can bringup service is online and active 

systemctl is-active limelight_canbusprocess robot
```
- Update necessary firmware on the motor
    - CTRE
        - Open pheonix tuner application
        - Connect to the robot using dashboard or ip address
        - Update the firmeware to the latest 2026 Phoenix version ( I know this is confusing as we are supposed to be on 2027 ).

- Deploy robot code

    - We've built some robot code for you that is an example project for both the Commands v2 and V3 frameworks. You can find the projects in the project_examples folder of this repo. Select the version that corresponds to your hardware. Deploy as normal.

- Optional: a Robot Signal Light, installed on its own ([rsl/README.md](../rsl/README.md)).
