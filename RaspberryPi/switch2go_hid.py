#!/usr/bin/env python3
"""
Switch2GO USB HID Keyboard — Raspberry Pi Zero 2 W

This script makes the Raspberry Pi Zero 2 W appear as a USB keyboard
to an iPad. Physical switches wired to the Pi's GPIO pins send
specific keypresses over the USB cable when activated.

HARDWARE SETUP:
  - Raspberry Pi Zero 2 W
  - Connect the Pi's Micro-USB "data" port (not the power port) to the
    iPad's USB-C port (use a Micro-USB to USB-C cable or adapter).
  - Wire up to 4 switches between the GPIO pins and GND:
      Switch 1 → GPIO 17  (Pin 11) + GND
      Switch 2 → GPIO 27  (Pin 13) + GND
      Switch 3 → GPIO 22  (Pin 15) + GND
      Switch 4 → GPIO 23  (Pin 16) + GND
  - Each GPIO pin uses an internal pull-up resistor. The switch connects
    the pin to GND when pressed (active-low).

FIRST-TIME SETUP:

  1. Flash Raspberry Pi OS Lite to an SD card.

  2. Enable USB gadget mode:
       sudo nano /boot/firmware/config.txt
     Add at the bottom:
       dtoverlay=dwc2

  3. Load required kernel modules:
       sudo nano /etc/modules
     Add these two lines:
       dwc2
       libcomposite

  4. Create the USB gadget setup script:
       sudo nano /usr/bin/switch_usb_setup.sh
     (see the setup script content below or use the companion file)
       sudo chmod +x /usr/bin/switch_usb_setup.sh

  5. Copy this script to the Pi:
       nano ~/switch_listener.py

  6. Create systemd service (see AUTO-START section below).

  7. Reboot:
       sudo reboot

USB GADGET SETUP SCRIPT (/usr/bin/switch_usb_setup.sh):
  See the companion file switch_usb_setup.sh, or create it with:

    #!/bin/bash
    cd /sys/kernel/config/usb_gadget/
    mkdir -p g1 && cd g1
    echo 0x1d6b > idVendor
    echo 0x0104 > idProduct
    echo 0x0100 > bcdDevice
    echo 0x0200 > bcdUSB
    mkdir -p strings/0x409
    echo "fedcba9876543210" > strings/0x409/serialnumber
    echo "MrGraham" > strings/0x409/manufacturer
    echo "Switch2GO-Pi" > strings/0x409/product
    mkdir -p functions/hid.usb0
    echo 1 > functions/hid.usb0/protocol
    echo 1 > functions/hid.usb0/subclass
    echo 8 > functions/hid.usb0/report_length
    echo -ne \\x05\\x01\\x09\\x06\\xa1\\x01\\x05\\x07\\x19\\xe0\\x29\\xe7\\x15\\x00\\x25\\x01\\x75\\x01\\x95\\x08\\x81\\x02\\x95\\x01\\x75\\x08\\x81\\x03\\x95\\x05\\x75\\x01\\x05\\x08\\x19\\x01\\x29\\x05\\x91\\x02\\x95\\x01\\x75\\x03\\x91\\x03\\x95\\x06\\x75\\x08\\x15\\x00\\x25\\x65\\x05\\x07\\x19\\x00\\x29\\x65\\x81\\x00\\xc0 > functions/hid.usb0/report_desc
    mkdir -p configs/c.1/strings/0x409
    echo "Config 1: USB HID" > configs/c.1/strings/0x409/configuration
    echo 250 > configs/c.1/bmAttributes
    echo 100 > configs/c.1/bMaxPower
    ln -s functions/hid.usb0 configs/c.1/
    ls /sys/class/udc > UDC

AUTO-START (systemd service):
  Create /etc/systemd/system/switch2go.service:

    [Unit]
    Description=Switch2GO USB Keyboard Service
    After=network.target

    [Service]
    Type=simple
    ExecStartPre=/usr/bin/switch_usb_setup.sh
    ExecStart=/usr/bin/python3 /home/YOUR_USERNAME/switch_listener.py
    Restart=on-failure
    User=root

    [Install]
    WantedBy=multi-user.target

  Then:
    sudo systemctl daemon-reload
    sudo systemctl enable switch2go.service
    sudo reboot

KEY MAPPING (must match Switch2GO → Settings → Switch Control):
  Switch to Phrase (2–4 switches): keys "1"–"4" (HID 30–33)
  Scan & Select (2 switches): key "1" = Select, key "2" = Next
"""

from gpiozero import Button
from signal import pause

# GPIO pins for each switch (BCM numbering)
btn1 = Button(17, pull_up=True, bounce_time=0.05)
btn2 = Button(27, pull_up=True, bounce_time=0.05)
btn3 = Button(22, pull_up=True, bounce_time=0.05)
btn4 = Button(23, pull_up=True, bounce_time=0.05)


def send_key(key_code):
    """Send a key press + release HID report to the iPad."""
    # 8-byte HID report: [Modifier, Reserved, Key, 0, 0, 0, 0, 0]
    report = bytes([0, 0, key_code, 0, 0, 0, 0, 0])
    null_report = bytes([0] * 8)

    try:
        with open('/dev/hidg0', 'rb+') as fd:
            fd.write(report)       # Key press
            fd.write(null_report)  # Key release
    except BlockingIOError:
        pass


# Key Mappings — these must match the iPad app settings
# 0x1E = '1', 0x1F = '2', 0x20 = '3', 0x21 = '4'
btn1.when_pressed = lambda: send_key(0x1E)
btn2.when_pressed = lambda: send_key(0x1F)
btn3.when_pressed = lambda: send_key(0x20)
btn4.when_pressed = lambda: send_key(0x21)

print("Switch2GO USB HID — Listening for switch presses...")
print("  Switch 1 (GPIO 17) → Key '1'")
print("  Switch 2 (GPIO 27) → Key '2'")
print("  Switch 3 (GPIO 22) → Key '3'")
print("  Switch 4 (GPIO 23) → Key '4'")

pause()
