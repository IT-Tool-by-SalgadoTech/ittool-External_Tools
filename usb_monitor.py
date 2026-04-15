#!/usr/bin/env python3
"""
USB Device Monitor
==================
Detects USB devices, their COM ports, MAC addresses, and metadata.
Listens in real-time for new connections/disconnections.

Requirements:
    pip install pyusb pyserial wmi psutil   # Windows
    pip install pyusb pyserial psutil        # Linux/macOS

Run:
    python usb_monitor.py
    python usb_monitor.py --json            # Output as JSON
    python usb_monitor.py --log usb_log.txt # Save log to file
"""

import sys
import time
import json
import argparse
import platform
import subprocess
import os
from datetime import datetime

# ── Dependency checks ──────────────────────────────────────────────────────────
try:
    import serial.tools.list_ports
except ImportError:
    sys.exit("❌  Missing dependency: pip install pyserial")

try:
    import psutil
except ImportError:
    sys.exit("❌  Missing dependency: pip install psutil")

OS = platform.system()  # "Windows" | "Linux" | "Darwin"

# ── Optional platform-specific imports ────────────────────────────────────────
if OS == "Windows":
    try:
        import wmi
        WMI_AVAILABLE = True
    except ImportError:
        WMI_AVAILABLE = False
        print("⚠️  wmi not found (pip install wmi). Some info will be limited on Windows.")
else:
    WMI_AVAILABLE = False

try:
    import usb.core
    import usb.util
    USB_LIB_AVAILABLE = True
except ImportError:
    USB_LIB_AVAILABLE = False
    print("⚠️  pyusb not found (pip install pyusb). Vendor/Product names may be limited.")


# ── Constants ──────────────────────────────────────────────────────────────────
POLL_INTERVAL = 2  # seconds between scans

# Known USB class codes → human-readable type
USB_CLASS_NAMES = {
    0x00: "Device",
    0x01: "Audio",
    0x02: "Communications (CDC)",
    0x03: "HID (Human Interface)",
    0x05: "Physical",
    0x06: "Image",
    0x07: "Printer",
    0x08: "Mass Storage",
    0x09: "USB Hub",
    0x0A: "CDC-Data",
    0x0B: "Smart Card",
    0x0D: "Content Security",
    0x0E: "Video",
    0x0F: "Personal Healthcare",
    0x10: "Audio/Video",
    0xDC: "Diagnostic",
    0xE0: "Wireless Controller",
    0xEF: "Miscellaneous",
    0xFE: "Application Specific",
    0xFF: "Vendor Specific",
}

# Rough USB speed lookup by bcdUSB value
USB_SPEEDS = {
    0x0100: "USB 1.0 (1.5 Mbps)",
    0x0110: "USB 1.1 (12 Mbps)",
    0x0200: "USB 2.0 (480 Mbps)",
    0x0201: "USB 2.0 (480 Mbps)",
    0x0300: "USB 3.0 (5 Gbps)",
    0x0310: "USB 3.1 (10 Gbps)",
    0x0320: "USB 3.2 (20 Gbps)",
}


# ── Helpers ───────────────────────────────────────────────────────────────────

def timestamp() -> str:
    return datetime.now().strftime("%Y-%m-%d %H:%M:%S")


def get_network_mac_map() -> dict:
    """Return {interface_name: mac_address} for all network interfaces."""
    macs = {}
    for iface, addrs in psutil.net_if_addrs().items():
        for addr in addrs:
            if addr.family == psutil.AF_LINK and addr.address not in ("", "00:00:00:00:00:00"):
                macs[iface] = addr.address.upper()
    return macs


def get_usb_device_info_pyusb(vid: int, pid: int) -> dict:
    """Query pyusb for extra device metadata."""
    info = {}
    if not USB_LIB_AVAILABLE:
        return info
    try:
        dev = usb.core.find(idVendor=vid, idProduct=pid)
        if dev is None:
            return info
        # Manufacturer / product strings
        try:
            info["manufacturer"] = usb.util.get_string(dev, dev.iManufacturer) if dev.iManufacturer else "N/A"
        except Exception:
            info["manufacturer"] = "N/A"
        try:
            info["product_name"] = usb.util.get_string(dev, dev.iProduct) if dev.iProduct else "N/A"
        except Exception:
            info["product_name"] = "N/A"
        try:
            info["serial_number"] = usb.util.get_string(dev, dev.iSerialNumber) if dev.iSerialNumber else "N/A"
        except Exception:
            info["serial_number"] = "N/A"
        # Speed
        bcd = getattr(dev, "bcdUSB", None)
        info["usb_version"] = USB_SPEEDS.get(bcd, f"USB bcdUSB=0x{bcd:04X}" if bcd else "Unknown")
        # Device class
        cls = getattr(dev, "bDeviceClass", 0xFF)
        info["device_class"] = USB_CLASS_NAMES.get(cls, f"Class 0x{cls:02X}")
    except Exception:
        pass
    return info


def get_serial_ports() -> dict:
    """Return {(vid, pid): port_info_dict} from pyserial."""
    ports = {}
    for port in serial.tools.list_ports.comports():
        key = (port.vid, port.pid)
        ports[key] = {
            "com_port": port.device,
            "description": port.description,
            "hwid": port.hwid,
            "manufacturer": port.manufacturer or "N/A",
            "serial_number": port.serial_number or "N/A",
        }
    return ports


def scan_devices() -> list:
    """
    Gather all currently connected USB-related devices.
    Returns a list of device dicts.
    """
    devices = []
    serial_ports = get_serial_ports()
    mac_map = get_network_mac_map()
    seen_keys = set()

    # ── 1. COM / Serial port devices (via pyserial) ───────────────────────────
    for port in serial.tools.list_ports.comports():
        vid = port.vid or 0
        pid = port.pid or 0
        key = f"serial:{port.device}"
        if key in seen_keys:
            continue
        seen_keys.add(key)

        extra = get_usb_device_info_pyusb(vid, pid)
        device = {
            "type": "Serial / COM",
            "name": port.description or extra.get("product_name", "Unknown"),
            "com_port": port.device,
            "vid": f"0x{vid:04X}" if vid else "N/A",
            "pid": f"0x{pid:04X}" if pid else "N/A",
            "manufacturer": extra.get("manufacturer") or port.manufacturer or "N/A",
            "serial_number": extra.get("serial_number") or port.serial_number or "N/A",
            "mac_address": "N/A",
            "usb_version": extra.get("usb_version", "Unknown"),
            "device_class": extra.get("device_class", "Communications (CDC)"),
            "hwid": port.hwid or "N/A",
            "connected_at": timestamp(),
        }
        devices.append(device)

    # ── 2. Network adapters that are USB (detect via name heuristics + MAC) ───
    for iface, mac in mac_map.items():
        low = iface.lower()
        is_usb = any(kw in low for kw in ("usb", "rndis", "gadget", "android", "tethering", "mobile"))
        if not is_usb:
            continue
        key = f"net:{mac}"
        if key in seen_keys:
            continue
        seen_keys.add(key)

        device = {
            "type": "USB Network Adapter",
            "name": iface,
            "com_port": "N/A",
            "vid": "N/A",
            "pid": "N/A",
            "manufacturer": "N/A",
            "serial_number": "N/A",
            "mac_address": mac,
            "usb_version": "Unknown",
            "device_class": "Communications (CDC)",
            "hwid": "N/A",
            "connected_at": timestamp(),
        }
        devices.append(device)

    # ── 3. Any other pyusb devices not already captured ───────────────────────
    if USB_LIB_AVAILABLE:
        try:
            all_usb = usb.core.find(find_all=True)
            for dev in all_usb:
                vid = dev.idVendor
                pid = dev.idProduct
                # Skip if already captured as serial port
                if (vid, pid) in serial_ports:
                    continue
                key = f"usb:{vid:04X}:{pid:04X}"
                if key in seen_keys:
                    continue
                seen_keys.add(key)

                extra = get_usb_device_info_pyusb(vid, pid)
                cls = getattr(dev, "bDeviceClass", 0xFF)
                bcd = getattr(dev, "bcdUSB", None)

                device = {
                    "type": USB_CLASS_NAMES.get(cls, "USB Device"),
                    "name": extra.get("product_name", f"USB Device {vid:04X}:{pid:04X}"),
                    "com_port": "N/A",
                    "vid": f"0x{vid:04X}",
                    "pid": f"0x{pid:04X}",
                    "manufacturer": extra.get("manufacturer", "N/A"),
                    "serial_number": extra.get("serial_number", "N/A"),
                    "mac_address": "N/A",
                    "usb_version": USB_SPEEDS.get(bcd, f"bcdUSB 0x{bcd:04X}" if bcd else "Unknown"),
                    "device_class": USB_CLASS_NAMES.get(cls, f"Class 0x{cls:02X}"),
                    "hwid": f"{vid:04X}:{pid:04X}",
                    "connected_at": timestamp(),
                }
                devices.append(device)
        except Exception as e:
            pass  # pyusb may need sudo on Linux

    return devices


def device_key(d: dict) -> str:
    """Unique fingerprint for a device to detect changes."""
    return f"{d['vid']}:{d['pid']}:{d['com_port']}:{d['mac_address']}:{d['serial_number']}"


# ── Display helpers ────────────────────────────────────────────────────────────

def print_device(d: dict, index: int, prefix: str = ""):
    G = "\033[92m"   # green
    Y = "\033[93m"   # yellow
    C = "\033[96m"   # cyan
    R = "\033[0m"    # reset
    B = "\033[1m"    # bold

    print(f"\n  {B}[{index}] {C}{d['name']}{R}  {Y}({d['type']}){R} {prefix}")
    print(f"       COM Port     : {G}{d['com_port']}{R}")
    print(f"       MAC Address  : {G}{d['mac_address']}{R}")
    print(f"       Vendor ID    : {d['vid']}   Product ID : {d['pid']}")
    print(f"       Manufacturer : {d['manufacturer']}")
    print(f"       Serial #     : {d['serial_number']}")
    print(f"       USB Version  : {d['usb_version']}")
    print(f"       Device Class : {d['device_class']}")
    print(f"       HW ID        : {d['hwid']}")
    print(f"       Connected At : {d['connected_at']}")


def clear_screen():
    """Clear terminal screen properly on all platforms including PowerShell."""
    if OS == "Windows":
        os.system("cls")
    else:
        os.system("clear")


def print_header(started_at: str):
    clear_screen()
    W = "\033[97m"   # bright white
    C = "\033[96m"   # cyan
    G = "\033[92m"   # green
    B = "\033[1m"    # bold
    R = "\033[0m"    # reset
    line = "=" * 72
    print(f"{C}{line}{R}")
    print(f"{B}{C}  USB DEVICE MONITOR{R}   OS: {OS}   Refresh: every {POLL_INTERVAL}s")
    print(f"  Started : {started_at}")
    print(f"  Now     : {timestamp()}")
    print(f"{C}{line}{R}")


# ── Main monitor loop ──────────────────────────────────────────────────────────

def monitor(output_json: bool = False, log_file: str = None):
    log_handle = open(log_file, "a") if log_file else None
    known = {}       # key → device dict
    history = []     # event log
    started_at = timestamp()

    GREEN  = "\033[92m"
    RED    = "\033[91m"
    YELLOW = "\033[93m"
    RESET  = "\033[0m"

    def log_event(msg, color=""):
        line = f"[{timestamp()}] {msg}"
        if log_handle:
            # Write plain text (no color codes) to log file
            import re
            plain = re.sub(r'\033\[[0-9;]*m', '', line)
            log_handle.write(plain + "\n")
            log_handle.flush()

    print_header(started_at)
    print("  Scanning... Press Ctrl+C to quit.\n")

    while True:
        current_devices = scan_devices()
        current_keys = {device_key(d): d for d in current_devices}

        # Detect new connections
        for k, d in current_keys.items():
            if k not in known:
                known[k] = d
                event = f"CONNECTED    {d['name']:<40} | COM: {d['com_port']}"
                history.append(("connected", d, timestamp()))
                log_event(event, GREEN)

        # Detect disconnections
        for k in list(known.keys()):
            if k not in current_keys:
                d = known.pop(k)
                event = f"DISCONNECTED {d['name']:<40} | COM: {d['com_port']}"
                history.append(("disconnected", d, timestamp()))
                log_event(event, RED)

        # ── Redraw full screen ────────────────────────────────────────────────
        print_header(started_at)
        print(f"  {len(known)} device(s) currently connected:\n")

        if output_json:
            print(json.dumps(list(known.values()), indent=2))
        else:
            for i, d in enumerate(known.values(), 1):
                print_device(d, i)

        # Event history (last 10)
        SEP = "-" * 72
        if history:
            print(f"\n  {SEP}")
            print("  Recent Events:")
            for ev_type, ev_d, ev_ts in history[-10:]:
                marker = f"{GREEN}[+]{RESET}" if ev_type == "connected" else f"{RED}[-]{RESET}"
                label  = "CONNECTED   " if ev_type == "connected" else "DISCONNECTED"
                print(f"    {marker} {ev_ts}  {label}  {ev_d['name']} | COM: {ev_d['com_port']}")

        print(f"\n  {SEP}")
        print(f"  Next scan in {POLL_INTERVAL}s...  (Ctrl+C to quit)")

        time.sleep(POLL_INTERVAL)


# ── Entry point ────────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(description="Real-time USB device monitor")
    parser.add_argument("--json",  action="store_true", help="Output device list as JSON")
    parser.add_argument("--log",   metavar="FILE",      help="Append event log to FILE")
    parser.add_argument("--once",  action="store_true", help="Scan once and exit (no loop)")
    args = parser.parse_args()

    if args.once:
        devices = scan_devices()
        if args.json:
            print(json.dumps(devices, indent=2))
        else:
            print_header(timestamp())
            print(f"  {len(devices)} device(s) found:\n")
            for i, d in enumerate(devices, 1):
                print_device(d, i)
        return

    try:
        monitor(output_json=args.json, log_file=args.log)
    except KeyboardInterrupt:
        print("\n\n  Monitor stopped. Goodbye!\n")


if __name__ == "__main__":
    main()
