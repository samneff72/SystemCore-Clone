#!/usr/bin/env python3
"""DIY SystemCore Robot Signal Light driver.

Polls /dev/mrccan/enabledro (the robot enable state maintained by MrcCommDaemon, the same
source the real SystemCore's RSL uses) and drives the kernel LED at /sys/class/leds/rsl:
solid while disabled, blinking (kernel timer trigger) while enabled, off until the
heartbeat module is loaded. Tunables: RSL_LED, RSL_ON_MS, RSL_OFF_MS, RSL_POLL_MS.
"""
import os
import sys
import time

LED = os.environ.get("RSL_LED", "/sys/class/leds/rsl")
ENABLED = "/dev/mrccan/enabledro"
ON_MS = int(os.environ.get("RSL_ON_MS", "250"))
OFF_MS = int(os.environ.get("RSL_OFF_MS", "250"))
POLL = int(os.environ.get("RSL_POLL_MS", "100")) / 1000.0


def sysfs_write(name, value):
    with open(os.path.join(LED, name), "w") as f:
        f.write(str(value))


def robot_enabled():
    """True/False from /dev/mrccan/enabledro ("%d\n"), None if not available."""
    try:
        with open(ENABLED) as f:
            return f.read().strip() not in ("", "0")
    except OSError:
        return None


def apply(state):
    if state == "blink":
        sysfs_write("trigger", "timer")
        sysfs_write("delay_on", ON_MS)
        sysfs_write("delay_off", OFF_MS)
    elif state == "solid":
        sysfs_write("trigger", "none")
        sysfs_write("brightness", 1)
    else:
        sysfs_write("trigger", "none")
        sysfs_write("brightness", 0)


def main():
    if not os.path.isdir(LED):
        print(f"diy-rsl: {LED} not found - is 'dtoverlay=gpio-led,...,label=rsl' in config.txt?",
              file=sys.stderr)
        return 1
    state = None
    while True:
        en = robot_enabled()
        new = "off" if en is None else ("blink" if en else "solid")
        if new != state:
            try:
                apply(new)
                print(f"diy-rsl: {new}", flush=True)
                state = new
            except OSError as e:
                print(f"diy-rsl: failed to set LED: {e}", file=sys.stderr, flush=True)
        time.sleep(POLL)


if __name__ == "__main__":
    sys.exit(main())
