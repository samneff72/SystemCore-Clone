# SystemCore Clone

A simple Raspberry Pi–based project for running **CAN** or **CAN FD** interfaces.

> **Image 13 / 14 users:** the overlay was rewritten for SystemCore images **beta 13 and
> newer** (the stock CAN service changed in 13 and the old `can-bringup.service` approach
> stops working — details in [no-fd/systemcore-can-nofd-setup/README.md](./no-fd/systemcore-can-nofd-setup/README.md)).
> The prebuilt Bobcat images linked below predate that and are only good for image 12.


## Required Software
The following software is required to create, flash, and use the SystemCore image.

### Raspberry Pi Imager
Used to flash the operating system image to a microSD card.
- https://www.raspberrypi.com/software/

### WPILib 2027 alpha
Match the WPILib release to the SystemCore image and vendor libraries you need
(from [wpilibsuite/SystemcoreTesting](https://github.com/wpilibsuite/SystemcoreTesting#software-compatibility)):

| SystemCore image | WPILib | CTRE Phoenix 6 | REVLib |
|---|---|---|---|
| beta 13 | [2027.0.0-alpha-6](https://github.com/wpilibsuite/allwpilib/releases/tag/v2027.0.0-alpha-6) | 26.50.0-alpha-1 (used by the example projects here) | 2027.0.0-alpha-2 |
| beta 14 | [2027.0.0-alpha-7](https://github.com/wpilibsuite/allwpilib/releases/tag/v2027.0.0-alpha-7) (required, breaking) | none yet (as of 2026-09-12) | 2027.0.0-alpha-7 |

### SystemCore Base Image
This is the base OS image used if you are preparing or setting up your own image instead of using Bobcat's prebuilt image. Use the **beta** `…betacm5…zip` (unzip it, flash the `.img`).
- https://github.com/LimelightVision/systemcore-os-public/releases

### CANivore USB drivers
These two driver files are needed for the CANivore USB (install `usb-kernel` first, then `usb`, via the web UI "Add Package" card).
- https://ctre.download/files/systemcore/canivore-usb-kernel_1.18_aarch64.ipk
- https://ctre.download/files/systemcore/canivore-usb_1.16_aarch64.ipk


## Required Hardware
The following hardware that we have tested with

### Raspberry Pi 5 4 GB
A standard Raspberry Pi 5 with 4GB of memory is as close to the specs as you will get.
- https://www.amazon.com/dp/B0FL21867J?ref=ppx_yo2ov_dt_b_fed_asin_title&th=1

### CAN HAT - NO FD
This is the exact hat that was purchased from amazon for this project that does not support FD.
It is the Waveshare **"2-CH CAN HAT"** (MCP2515 ×2 on SPI0) — not the newer "2-CH CAN HAT+",
which is a different board (SPI1) and needs a different config. Set the VIO jumper to 3.3 V.
- https://www.amazon.com/dp/B087RJ6XGG?ref=ppx_yo2ov_dt_b_fed_asin_title
- Wiki (pinout, interrupt pads): https://www.waveshare.com/wiki/2-CH_CAN_HAT

### CAN HAT - FD
This is the exact hat that was purchased from amazon for this project that supports CAN FD
(Waveshare "2-CH CAN FD HAT", MCP2518FD ×2, used in Mode A).
- https://www.amazon.com/dp/B07YQTMQTR?ref=ppx_yo2ov_dt_b_fed_asin_title
- Wiki: https://www.waveshare.com/wiki/2-CH_CAN_FD_HAT

## Documentation & Guides

#### CAN HAT Setup
Follow the instructions for configuring the standard CAN HAT.

- [CAN HAT Instructions](./no-fd/README.md)
- [Overlay installer + troubleshooting](./no-fd/systemcore-can-nofd-setup/README.md)

#### CAN FD HAT Setup
Follow the instructions for configuring the CAN FD HAT.

- [CAN FD HAT Instructions](./fd/README.md)
- [Overlay installer + troubleshooting](./fd/systemcore-can-fd-setup/README.md)

#### SD Card Setup & Cloning
Instructions for preparing a new SD card or cloning an existing SystemCore installation.

- [Setup & Build Guide](./setup/README.md)

> Windows users: the repo now carries a `.gitattributes` that keeps the scripts and
> `config_*.txt` with LF line endings on checkout. If you copied files from an older clone,
> re-clone (or run `dos2unix`) before `scp`-ing them to the Pi — CRLF breaks bash scripts.
