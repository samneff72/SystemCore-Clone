# SystemCore Clone

A Raspberry Pi 5–based stand-in for a FIRST SystemCore, running the official SystemCore OS
with a **CAN HAT** so robot code can drive CTRE Phoenix 6 devices.

Every clone is built from the official SystemCore base image plus the setup scripts in this
repo. We do **not** distribute prebuilt SD-card images.

> [!TIP]
> **Inspired by the Bobcat Robotics SystemCore Clone.** This project builds on
> [BobcatRobotics/SystemCore-Clone](https://github.com/BobcatRobotics/SystemCore-Clone).
> Their original work on running SystemCore OS on a Raspberry Pi with a CAN HAT is the
> foundation of everything here. Thank you, Bobcats!

> [!NOTE]
> **Supported hardware:** the standard (no-FD) MCP2515 CAN HAT only.
> The CAN FD HAT setup in [`fd/`](./fd/README.md) is **deprecated** and unmaintained
> until we have an FD board to test against.

## Version Alignment

Everything is pinned to the **latest Phoenix 6 2027 vendordep**. The WPILib and
SystemCore OS versions below are the ones that vendordep supports, which are not
necessarily the newest releases of each.

| Component | Version | Notes |
|---|---|---|
| Phoenix 6 vendordep | `26.70.0-alpha-2` | Latest 2027 release; supports WPILib alpha-7/8 |
| Phoenix device firmware | `26.70.x` | Flash with **Phoenix Tuner X Preview** |
| WPILib | [`2027.0.0-alpha-8`](https://github.com/wpilibsuite/allwpilib/releases/tag/v2027.0.0-alpha-8) | Project year `2027_alpha7` (alpha-8 still uses it) |
| SystemCore OS | Release 17 ([`beta17-233`](https://github.com/LimelightVision/systemcore-os-public/releases/tag/limelightosr-2027.0.0-beta17-233) / [`alpha17-403`](https://github.com/LimelightVision/systemcore-os-public/releases/tag/limelightosr-2027.0.0-alpha17-403)) | Newest OS with a published CANivore package. OS 14+ is required for WPILib alpha-7+ |
| CANivore package | [`canivore-usb_1.18_systemcoreos_alphabeta_17.ipk`](https://ctre.download/files/systemcore/canivore-usb_1.18_systemcoreos_alphabeta_17.ipk) | One IPK now (the old kernel + userspace pair is for OS ≤ 13 only) |

Sources: [SystemcoreTesting CTR-Phoenix.md](https://github.com/wpilibsuite/SystemcoreTesting/blob/main/CTR-Phoenix.md)
and its software-compatibility table, and the
[SystemCore OS release notes](https://github.com/LimelightVision/systemcore-os-public).

## Required Software

### Raspberry Pi Imager
Used to flash the SystemCore base image to a microSD card.
- https://www.raspberrypi.com/software/

### WPILib 2027.0.0-alpha-8
- https://github.com/wpilibsuite/allwpilib/releases/tag/v2027.0.0-alpha-8

### SystemCore Base Image (OS release 17)
- https://github.com/LimelightVision/systemcore-os-public/releases

### CANivore package (only if you use a CANivore)
- https://ctre.download/files/systemcore/canivore-usb_1.18_systemcoreos_alphabeta_17.ipk

### Phoenix Tuner X Preview
Needed to flash 26.70.x firmware. It installs alongside the stable Tuner X.
- Windows: [Microsoft Store](https://apps.microsoft.com/detail/9n17ns6nm06v)
- macOS/iOS: [TestFlight](https://testflight.apple.com/join/1kftrjGW)

## Required Hardware

### Raspberry Pi 5 4 GB
- https://www.amazon.com/dp/B0FL21867J?ref=ppx_yo2ov_dt_b_fed_asin_title&th=1

### CAN HAT (no FD)
This is the exact HAT we bought and tested with.
- https://www.amazon.com/dp/B087RJ6XGG?ref=ppx_yo2ov_dt_b_fed_asin_title

## Documentation & Guides

- [New Build Guide](./setup/New%20Build.md): build a clone from the base image (start here)
- [CAN HAT setup scripts](./no-fd/systemcore-can-nofd-setup/README.md): what the installer does, verification, uninstall
- [Example robot projects](./project_examples/ctre): Commands v2 and v3, Phoenix 6 `26.70.0-alpha-2`

### Deprecated
- [CAN FD HAT setup](./fd/README.md): unmaintained until an FD board is available for testing
- [Prebuilt images](./no-fd/README.md) and [Copy Image to Share](./setup/Copy%20Image%20to%20Share.md): no longer provided
