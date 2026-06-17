#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# ============================================================================
#  IT-Tool by SalgadoTech
#  Script: 55.Check_ram.py
#  ScriptID: ST-WIN-0055-PY
#  Version: 3.0
#  Date: 2025-05-27
#  Category: Windows / Linux > Hardware
#  Description: Live RAM monitor - refreshes every 2s.
#               Top 30 processes sorted by consumption with
#               relative visual bars. Press Q or Ctrl+C to exit.
#  (c) 2025 SalgadoTech - All Rights Reserved
#  Unauthorized distribution prohibited
#  Encoding: UTF-8 (no BOM)
# ============================================================================

import psutil
import os
import sys
import time
import threading

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
HIDE_C  = "\033[?25l"           # hide cursor
SHOW_C  = "\033[?25h"           # show cursor

BAR_FULL  = "█"
BAR_EMPTY = "░"
BAR_WIDTH = 25
TOP_N     = 30
REFRESH   = 2.0                 # seconds between updates

# ─── Shared state ───────────────────────────────────────────────
_quit = threading.Event()

# ─── Helpers ────────────────────────────────────────────────────
def gb(b):  return b / (1024 ** 3)
def mb(b):  return b / (1024 ** 2)

def bar(pct, width=BAR_WIDTH, col=GREEN):
    filled = int((pct / 100) * width)
    return f"[{col}{BAR_FULL * filled}{GRAY}{BAR_EMPTY * (width - filled)}{RESET}]"

def col_pct(p):
    if p >= 80: return RED
    if p >= 50: return YELLOW
    return GREEN

# ─── Keyboard listener (Q to quit) ──────────────────────────────
def _key_listener():
    try:
        if os.name == "nt":
            import msvcrt
            while not _quit.is_set():
                if msvcrt.kbhit():
                    ch = msvcrt.getwch().lower()
                    if ch == "q":
                        _quit.set()
                time.sleep(0.05)
        else:
            import tty, termios
            fd = sys.stdin.fileno()
            old = termios.tcgetattr(fd)
            tty.setraw(fd)
            try:
                while not _quit.is_set():
                    ch = sys.stdin.read(1).lower()
                    if ch in ("q", "\x03"):
                        _quit.set()
            finally:
                termios.tcsetattr(fd, termios.TCSADRAIN, old)
    except Exception:
        pass

# ─── Snapshot ───────────────────────────────────────────────────
def snapshot():
    mem   = psutil.virtual_memory()
    procs = []
    for p in psutil.process_iter(['pid', 'name', 'memory_info', 'cpu_percent']):
        try:
            mi = p.info['memory_info']
            if mi is None: continue
            rss     = mi.rss
            private = getattr(mi, 'private', 0) or 0
            cpu     = p.info.get('cpu_percent') or 0.0
            procs.append({
                'pid':     p.info['pid'],
                'name':   (p.info['name'] or '<N/A>')[:22],
                'rss':     rss,
                'private': private,
                'cpu':     cpu,
                'pct_sys': (rss / mem.total) * 100,
            })
        except (psutil.NoSuchProcess, psutil.AccessDenied):
            continue
    procs.sort(key=lambda x: x['rss'], reverse=True)
    return mem, procs

# ─── Render ─────────────────────────────────────────────────────
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
    f"{GRAY}  Script: 55.Check_ram.py  |  ScriptID: ST-WIN-0055-PY  |  v3.0{RESET}\n"
    f"{GRAY}  Live RAM Monitor — Press Q or Ctrl+C to exit{RESET}\n"
    f"{WHITE}  {'=' * 64}{RESET}\n"
)

def render(mem, procs, elapsed):
    os.system(CLEAR)
    lines = [HEADER]

    # ── RAM overview ──
    pct = mem.percent
    c   = col_pct(pct)
    lines.append(f"{CYAN}  ════════════════════ RAM STATUS ════════════════════{RESET}")
    lines.append(f"")
    lines.append(f"  {WHITE}Total RAM   :{RESET} {gb(mem.total):>7.2f} GB")
    lines.append(f"  {WHITE}Used  RAM   :{RESET} {c}{gb(mem.used):>7.2f} GB{RESET}")
    lines.append(f"  {WHITE}Free  RAM   :{RESET} {GREEN}{gb(mem.available):>7.2f} GB{RESET}")
    lines.append(f"")
    lines.append(f"  {WHITE}Usage       :{RESET}  {bar(pct, BAR_WIDTH, c)}  {c}{BOLD}{pct:>5.1f}%{RESET}")
    lines.append(f"")

    # ── Process table ──
    top     = procs[:TOP_N]
    max_rss = top[0]['rss'] if top else 1

    lines.append(f"{YELLOW}  ══════════════ TOP PROCESSES BY RAM USAGE ══════════════{RESET}")
    lines.append(f"")

    hdr = (f"  {'#':>3}  {'PID':>6}  {'NAME':<22}  "
           f"{'RAM MB':>8}  {'%SYS':>5}  {'BAR (relative)':<{BAR_WIDTH+2}}  "
           f"{'PRIV MB':>8}  {'CPU%':>5}")
    lines.append(BOLD + WHITE + hdr + RESET)
    lines.append(GRAY + "  " + "─" * (len(hdr) - 2) + RESET)

    for i, p in enumerate(top, 1):
        rel  = (p['rss'] / max_rss) * 100
        c    = col_pct(rel)
        b    = bar(rel, BAR_WIDTH, c)
        cpu  = f"{p['cpu']:>5.1f}" if p['cpu'] else f"{GRAY} ─   {RESET}"
        ram_mb  = mb(p['rss'])
        priv_mb = mb(p['private'])
        lines.append(
            f"  {GRAY}{i:>3}{RESET}  "
            f"{GRAY}{p['pid']:>6}{RESET}  "
            f"{WHITE}{p['name']:<22}{RESET}  "
            f"{c}{ram_mb:>8.1f}{RESET}  "
            f"{c}{p['pct_sys']:>5.1f}{RESET}  "
            f"{b}  "
            f"{GRAY}{priv_mb:>8.1f}{RESET}  "
            f"{GRAY}{cpu}{RESET}"
        )

    lines.append(f"")
    lines.append(f"{GRAY}  Showing top {TOP_N} of {len(procs)} processes  │  "
                 f"Refresh: {REFRESH}s  │  Uptime: {elapsed}s  │  "
                 f"[Q] Quit{RESET}")

    sys.stdout.write("\n".join(lines) + "\n")
    sys.stdout.flush()

# ─── Main loop ──────────────────────────────────────────────────
def main():
    try:
        import psutil
    except ImportError:
        print("  [!] Run:  pip install psutil")
        sys.exit(1)

    sys.stdout.write(HIDE_C)
    sys.stdout.flush()

    t_key = threading.Thread(target=_key_listener, daemon=True)
    t_key.start()

    start = time.time()
    try:
        while not _quit.is_set():
            mem, procs = snapshot()
            elapsed    = int(time.time() - start)
            render(mem, procs, elapsed)
            # Sleep in small chunks so Q responds fast
            for _ in range(int(REFRESH / 0.1)):
                if _quit.is_set():
                    break
                time.sleep(0.1)
    except KeyboardInterrupt:
        _quit.set()
    finally:
        sys.stdout.write(SHOW_C + "\n")
        sys.stdout.flush()
        print(YELLOW + "\n  Monitor stopped." + RESET)

if __name__ == "__main__":
    main()