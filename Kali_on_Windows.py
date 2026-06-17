#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# ============================================================================
#  IT-Tool by SalgadoTech
#  Script: Kali_on_Windows.py
#  ScriptID: (pending)
#  Version: 1.0
#  Date: 2026-06-16
#  Category: Windows > WSL
#  Description: Installs and configures Kali Linux on Windows via WSL
#  (c) 2025 SalgadoTech - All Rights Reserved
#  Unauthorized distribution prohibited
#  Encoding: UTF-8 (no BOM), ASCII content only.
# ============================================================================

import os
import sys
import subprocess
import ctypes

# ---------------------------------------------------------------------------
# ANSI color codes
# ---------------------------------------------------------------------------
CYAN    = "\033[96m"
DCYAN   = "\033[36m"
WHITE   = "\033[97m"
GREEN   = "\033[92m"
RED     = "\033[91m"
YELLOW  = "\033[93m"
DGRAY   = "\033[90m"
RESET   = "\033[0m"


def enable_ansi():
    """Enable ANSI escape codes on Windows terminal."""
    if os.name == "nt":
        kernel32 = ctypes.windll.kernel32
        kernel32.SetConsoleMode(kernel32.GetStdHandle(-11), 7)


# ---------------------------------------------------------------------------
# Output helpers (green = ok, red = fail, yellow = warning, cyan = info)
# ---------------------------------------------------------------------------
def write_ok(msg):
    print(f"{GREEN}[ OK ] {msg}{RESET}")

def write_err(msg):
    print(f"{RED}[FAIL] {msg}{RESET}")

def write_warn(msg):
    print(f"{YELLOW}[WARN] {msg}{RESET}")

def write_info(msg):
    print(f"{CYAN}[INFO] {msg}{RESET}")


# ---------------------------------------------------------------------------
# Admin check
# ---------------------------------------------------------------------------
def is_admin():
    try:
        return ctypes.windll.shell32.IsUserAnAdmin() != 0
    except Exception:
        return False


# ---------------------------------------------------------------------------
# Header
# ---------------------------------------------------------------------------
def show_header():
    print()
    print(f"{CYAN} _____ _____  _______ ____   ____  _     {RESET}")
    print(f"{CYAN}|_   _|_   _||__   __/ __ \\ / __ \\| |    {RESET}")
    print(f"{CYAN}  | |   | |     | | | |  | | |  | | |    {RESET}")
    print(f"{CYAN}  | |   | |     | | | |  | | |  | | |    {RESET}")
    print(f"{CYAN} _| |_  | |     | | | |__| | |__| | |___ {RESET}")
    print(f"{CYAN}|_____| |_|     |_|  \\____/ \\____/|_____|{RESET}")
    print()
    print(f"  {WHITE}=================================================================={RESET}")
    print(f"  {CYAN}IT-Tool by SalgadoTech{RESET}")
    print(f"  {DCYAN}Script: Kali_on_Windows.py{RESET}")
    print(f"  {CYAN}ScriptID: (pending){RESET}")
    print(f"  {DCYAN}Version: 1.0{RESET}")
    print(f"  {DCYAN}Date: 2026-06-16{RESET}")
    print(f"  {DCYAN}Category: Windows > WSL{RESET}")
    print(f"  {DCYAN}Description: Installs and configures Kali Linux on Windows via WSL{RESET}")
    print(f"  {DCYAN}(c) 2025 SalgadoTech - All Rights Reserved{RESET}")
    print(f"  {DCYAN}Unauthorized distribution prohibited{RESET}")
    print(f"  {WHITE}=================================================================={RESET}")
    print()


# ---------------------------------------------------------------------------
# Menu
# ---------------------------------------------------------------------------
def show_menu():
    print()
    print(f"  {WHITE}================================================={RESET}")
    print(f"  {WHITE}  Kali Linux on Windows{RESET}")
    print(f"  {WHITE}================================================={RESET}")
    print("  [A] Enable Windows Sub System for Linux")
    print("  [B] WSL Functions")
    print("  [C] Install Kali Linux")
    print("  [D] Update Linux")
    print("  [E] Install all Kali Packages")
    print("  [F] Install Kali Graphic Version")
    print("  [G] Open Kali on PowerShell")
    print("  [H] Open Kali Graphic Version on Windows")
    print("  [0] Exit")
    print(f"  {WHITE}================================================={RESET}")


# ---------------------------------------------------------------------------
# [B] WSL Functions (sub-menu)
# ---------------------------------------------------------------------------
def wsl_functions_submenu():
    print()
    print(f"  {WHITE}  ----------------------------------------{RESET}")
    print(f"  {WHITE}  WSL Functions{RESET}")
    print(f"  {WHITE}  ----------------------------------------{RESET}")
    print("  [1] Status")
    print("  [2] Version")
    print("  [3] Install")
    print("  [4] Linux Versions")
    print("  [0] Back to main menu")
    print(f"  {WHITE}  ----------------------------------------{RESET}")
    sub = input("  Select an option: ").strip()
    print()
    if sub == "1":
        subprocess.run(["wsl", "--status"])
    elif sub == "2":
        subprocess.run(["wsl", "--version"])
    elif sub == "3":
        subprocess.run(["wsl", "--install"])
    elif sub == "4":
        subprocess.run(["wsl", "-l", "-v"])
    elif sub == "0":
        return
    else:
        write_warn("Invalid option.")


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
def main():
    enable_ansi()

    if not is_admin():
        write_err("This script must run in an ELEVATED PowerShell (Run as administrator).")
        write_info("Right-click PowerShell, choose 'Run as administrator', then run it again.")
        input("Press ENTER to close...")
        sys.exit(1)

    show_header()
    write_ok("Running with administrator rights.")

    while True:
        show_menu()
        choice = input("  Select an option: ").strip().upper()

        if choice == "A":
            print()
            write_info("Enabling Windows Subsystem for Linux...")
            print()
            subprocess.run(["wsl.exe", "--install", "--no-distribution"])

        elif choice == "B":
            wsl_functions_submenu()

        elif choice == "C":
            print()
            write_info("Installing Kali Linux...")
            print()
            subprocess.run(["wsl", "--install", "Kali-Linux"])

        elif choice == "D":
            print()
            write_info("Updating Linux...")
            print()
            subprocess.run(["wsl", "-d", "Kali-Linux", "--", "sudo", "apt", "update"])

        elif choice == "E":
            print()
            write_info("Installing all Kali packages (this may take a while)...")
            print()
            subprocess.run(["wsl", "-d", "Kali-Linux", "--", "sudo", "apt", "install", "kali-linux-default", "-y"])

        elif choice == "F":
            print()
            write_info("Installing Kali graphic version...")
            print()
            subprocess.run(["wsl", "-d", "Kali-Linux", "--", "sudo", "apt", "install", "kali-desktop-xfce", "xorg", "kali-win-kex", "-y"])

        elif choice == "G":
            print()
            write_info("Opening Kali Linux...")
            print()
            subprocess.run(["wsl", "-d", "Kali-Linux"])

        elif choice == "H":
            print()
            write_warn("When asked 'Would you like to enter a view-only password (y/n)?' answer: n (NO)")
            print()
            subprocess.run(["wsl", "-d", "Kali-Linux", "--", "kex", "--win", "-s"])

        elif choice == "0":
            write_info("Exiting.")
            break

        else:
            write_warn("Invalid option.")

        if choice != "0":
            print()
            input("Press ENTER to return to the menu...")


if __name__ == "__main__":
    main()
