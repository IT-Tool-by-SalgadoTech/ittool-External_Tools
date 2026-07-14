#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# ============================================================================
#  IT-Tool by SalgadoTech
#  Script: 99.Wifi_Manager.py
#  ScriptID: ST-LIN-0099-PY
#  Version: 1.0
#  Date: 2026-07-14
#  Category: Linux > WIFI
#  Description: Interactive WiFi manager menu (NetworkManager / nmcli).
#               5 options: internet status and radio check, turn radio ON,
#               saved connections and WiFi list, connect saved WiFi,
#               connect to a network (hidden password + ping test).
#               Select by number, runs the option and returns to the menu.
#               Press Q to exit.
#  (c) 2025 SalgadoTech - All Rights Reserved
#  Unauthorized distribution prohibited
#  Encoding: UTF-8 (no BOM)
# ============================================================================

import os
import sys
import shutil
import getpass
import subprocess

# ─── ANSI ───────────────────────────────────────────────────────
CYAN    = "\033[96m"
YELLOW  = "\033[93m"
GREEN   = "\033[92m"
RED     = "\033[91m"
WHITE   = "\033[97m"
GRAY    = "\033[90m"
RESET   = "\033[0m"
BOLD    = "\033[1m"
CLEAR   = "cls" if os.name == "nt" else "clear"  # shell clear command

# ─── Header ─────────────────────────────────────────────────────
HEADER = (
    f"\n"
    f"{CYAN} _____ _____  _______ ____   ____  _     {RESET}\n"
    f"{CYAN}|_   _|_   _||__   __/ __ \\ / __ \\| |    {RESET}\n"
    f"{CYAN}  | |   | |     | | | |  | | |  | | |    {RESET}\n"
    f"{CYAN}  | |   | |     | | | |  | | |  | | |    {RESET}\n"
    f"{CYAN} _| |_  | |     | | | |__| | |__| | |___ {RESET}\n"
    f"{CYAN}|_____| |_|     |_|  \\____/ \\____/|_____|{RESET}\n"
    f"\n"
    f"{WHITE}  {'=' * 64}{RESET}\n"
    f"{CYAN}  IT-Tool by SalgadoTech{RESET}\n"
    f"{GRAY}  Script: 99.Wifi_Manager.py  |  ScriptID: ST-LIN-0099-PY  |  v1.0{RESET}\n"
    f"{GRAY}  WiFi Manager (NetworkManager / nmcli) — Select option, Q to quit{RESET}\n"
    f"{WHITE}  {'=' * 64}{RESET}\n"
)

# ─── Helpers ────────────────────────────────────────────────────
def clear_screen():
    os.system(CLEAR)

def section(title, col=CYAN):
    print(f"\n{col}  ════════════════════ {title} ════════════════════{RESET}\n")

def run_cmd(cmd):
    """Run a command, stream its output to the terminal, return exit code."""
    print(f"{GRAY}  $ {' '.join(cmd)}{RESET}")
    try:
        result = subprocess.run(cmd)
        return result.returncode
    except FileNotFoundError:
        print(f"{RED}  [!] Command not found: {cmd[0]}{RESET}")
        return 127

def pause():
    print("")
    try:
        input(f"{GRAY}  Press ENTER to return to menu...{RESET}")
    except (KeyboardInterrupt, EOFError):
        pass

def confirm_execute():
    """Ask for ENTER to execute. Returns False if the user cancels (Ctrl+C)."""
    try:
        input(f"{YELLOW}  Press ENTER to execute (or Ctrl+C to cancel)...{RESET}")
        return True
    except (KeyboardInterrupt, EOFError):
        print(f"\n{YELLOW}  Cancelled.{RESET}")
        return False

def ok(msg):
    print(f"{GREEN}{BOLD}  [OK] {msg}{RESET}")

def fail(msg):
    print(f"{RED}{BOLD}  [X] {msg}{RESET}")

# ─── Option 1: Internet status and check WiFi radio ─────────────
def option_1():
    section("INTERNET STATUS AND WIFI RADIO")
    run_cmd(["nmcli", "device", "status"])
    print("")
    run_cmd(["nmcli", "radio", "wifi"])

# ─── Option 2: Turn ON WiFi radio ───────────────────────────────
def option_2():
    section("TURN ON WIFI RADIO")
    code = run_cmd(["nmcli", "radio", "wifi", "on"])
    print("")
    if code == 0:
        ok("WiFi radio command sent. Current state:")
        print("")
        run_cmd(["nmcli", "radio", "wifi"])
    else:
        fail(f"Failed to turn on WiFi radio (exit code: {code}).")

# ─── Option 3: Check saved connections and WiFi list ────────────
def option_3():
    section("SAVED CONNECTIONS")
    run_cmd(["nmcli", "connection", "show"])
    section("AVAILABLE WIFI NETWORKS", YELLOW)
    run_cmd(["nmcli", "device", "wifi", "list"])

# ─── Option 4: Connect saved WiFi ───────────────────────────────
def option_4():
    section("CONNECT SAVED WIFI")
    print(f"{WHITE}  === Saved connections ==={RESET}\n")
    run_cmd(["nmcli", "connection", "show"])
    print("")

    try:
        conn_name = input(f"{WHITE}  Enter the connection name to bring up: {RESET}").strip()
    except (KeyboardInterrupt, EOFError):
        print(f"\n{YELLOW}  Cancelled.{RESET}")
        return

    if not conn_name:
        fail("Connection name cannot be empty.")
        return

    print("")
    print(f'{WHITE}  Running: nmcli connection up "{conn_name}"{RESET}')
    if not confirm_execute():
        return

    print("")
    code = run_cmd(["nmcli", "connection", "up", conn_name])
    print("")
    if code == 0:
        ok("Connection activated successfully.")
        print("")
        run_cmd(["nmcli", "device", "status"])
    else:
        fail(f"Failed to activate connection (exit code: {code}).")

# ─── Option 5: Connect to a network ─────────────────────────────
def option_5():
    section("CONNECT TO A NETWORK")
    print(f"{WHITE}  === Available WiFi networks ==={RESET}\n")
    run_cmd(["nmcli", "device", "wifi", "list"])
    print("")

    try:
        ssid = input(f"{WHITE}  Enter the WiFi network name (SSID): {RESET}").strip()
    except (KeyboardInterrupt, EOFError):
        print(f"\n{YELLOW}  Cancelled.{RESET}")
        return

    if not ssid:
        fail("SSID cannot be empty.")
        return

    try:
        wifi_pass = getpass.getpass(f"{WHITE}  Enter the WiFi password (input hidden): {RESET}")
    except (KeyboardInterrupt, EOFError):
        print(f"\n{YELLOW}  Cancelled.{RESET}")
        return

    if not wifi_pass:
        fail("Password cannot be empty.")
        return

    print("")
    print(f'{WHITE}  Running: nmcli device wifi connect "{ssid}" password "********"{RESET}')
    if not confirm_execute():
        return

    print("")
    code = run_cmd(["nmcli", "device", "wifi", "connect", ssid, "password", wifi_pass])
    print("")
    if code == 0:
        ok("Connected successfully.")
        print("")
        run_cmd(["nmcli", "device", "status"])
        print("")
        print(f"{WHITE}  Testing internet connectivity...{RESET}")
        run_cmd(["ping", "-c", "4", "1.1.1.1"])
    else:
        fail(f"Failed to connect (exit code: {code}).")

# ─── Menu ───────────────────────────────────────────────────────
OPTIONS = {
    "1": ("Internet status and check WiFi radio", option_1),
    "2": ("Turn ON WiFi radio",                   option_2),
    "3": ("Check saved connections and WiFi list", option_3),
    "4": ("Connect saved WiFi",                   option_4),
    "5": ("Connect to a network",                 option_5),
}

def show_menu():
    clear_screen()
    print(HEADER)
    print(f"{CYAN}  ════════════════════ WIFI MANAGER MENU ════════════════════{RESET}")
    print("")
    for key, (label, _) in OPTIONS.items():
        print(f"  {YELLOW}[{key}]{RESET} {WHITE}{label}{RESET}")
    print(f"  {YELLOW}[Q]{RESET} {WHITE}Quit{RESET}")
    print("")

# ─── Main loop ──────────────────────────────────────────────────
def main():
    if not sys.platform.startswith("linux"):
        print(f"{RED}  [!] This script requires Linux (NetworkManager / nmcli).{RESET}")
        sys.exit(1)

    if shutil.which("nmcli") is None:
        print(f"{RED}  [!] nmcli not found. Install NetworkManager first.{RESET}")
        sys.exit(1)

    while True:
        show_menu()
        try:
            choice = input(f"{WHITE}  Select an option: {RESET}").strip().lower()
        except (KeyboardInterrupt, EOFError):
            print(f"\n{YELLOW}  Exiting WiFi Manager.{RESET}")
            break

        if choice == "q":
            print(f"{YELLOW}  Exiting WiFi Manager.{RESET}")
            break

        if choice in OPTIONS:
            label, func = OPTIONS[choice]
            try:
                func()
            except KeyboardInterrupt:
                print(f"\n{YELLOW}  Cancelled.{RESET}")
            pause()
        else:
            fail("Invalid option. Choose 1-5 or Q.")
            pause()

if __name__ == "__main__":
    main()