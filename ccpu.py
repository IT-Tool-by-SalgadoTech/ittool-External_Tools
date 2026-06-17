#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# ============================================================================
#  IT-Tool by SalgadoTech
#  Script: ccpu.py
#  ScriptID: ST-WIN-0056-PY
#  Version: 1.0
#  Date: 2025-05-27
#  Category: Windows / Linux > Hardware
#  Description: Live CPU monitor - refreshes every 2s.
#               Per-core usage bars, frequency,
#               and top 20 processes by CPU. Press Q or Ctrl+C.
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
ORANGE  = "\033[38;5;208m"
WHITE   = "\033[97m"
GRAY    = "\033[90m"
RESET   = "\033[0m"
BOLD    = "\033[1m"
CLEAR   = "cls" if os.name == "nt" else "clear"
HIDE_C  = "\033[?25l"
SHOW_C  = "\033[?25h"

BAR_FULL  = "█"
BAR_EMPTY = "░"
BAR_WIDTH = 30
TOP_N     = 20
REFRESH   = 2.0

_quit = threading.Event()

# ─── Helpers ────────────────────────────────────────────────────
def col_pct(p):
    if p >= 90: return RED
    if p >= 70: return ORANGE
    if p >= 40: return YELLOW
    return GREEN

def bar(pct, width=BAR_WIDTH, col=GREEN, log_scale=False):
    """pct: 0-100. log_scale=True compresses high vals, expands low vals."""
    if log_scale and pct > 0:
        import math
        # map 0-100 via log so small values still show
        scaled = math.log1p(pct) / math.log1p(100) * 100
    else:
        scaled = pct
    filled = max(0, min(width, int((scaled / 100) * width)))
    # Always show at least 1 block if pct > 0
    if pct > 0 and filled == 0:
        filled = 1
    empty  = width - filled
    parts  = ["["]
    if filled > 0:
        parts.append(col + BAR_FULL * filled + RESET)
    if empty > 0:
        parts.append(GRAY + BAR_EMPTY * empty + RESET)
    parts.append("]")
    return "".join(parts)

# ─── Keyboard listener ──────────────────────────────────────────
def _key_listener():
    try:
        if os.name == "nt":
            import msvcrt
            while not _quit.is_set():
                if msvcrt.kbhit():
                    if msvcrt.getwch().lower() == "q":
                        _quit.set()
                time.sleep(0.05)
        else:
            import tty, termios
            fd  = sys.stdin.fileno()
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
    # CPU overall & per-core (interval=None = non-blocking, uses cached)
    cpu_total  = psutil.cpu_percent(interval=None)
    cpu_cores  = psutil.cpu_percent(interval=None, percpu=True)
    cpu_freq   = psutil.cpu_freq()
    cpu_count  = psutil.cpu_count(logical=True)
    cpu_phys   = psutil.cpu_count(logical=False)
    cpu_times  = psutil.cpu_times_percent(interval=None)

    procs = []
    for p in psutil.process_iter(['pid', 'name', 'cpu_percent', 'memory_info', 'status']):
        try:
            cpu = p.info.get('cpu_percent') or 0.0
            mi  = p.info.get('memory_info')
            ram = mi.rss if mi else 0
            procs.append({
                'pid':    p.info['pid'],
                'name':  (p.info['name'] or '<N/A>')[:22],
                'cpu':    cpu,
                'ram':    ram,
                'status': p.info.get('status', ''),
            })
        except (psutil.NoSuchProcess, psutil.AccessDenied):
            continue

    # Exclude System Idle Process and cap CPU% per-core at logical_count*100
    logical = psutil.cpu_count(logical=True) or 1
    procs = [p for p in procs if p['name'].lower() != 'system idle process']
    for p in procs:
        if p['cpu'] > logical * 100:
            p['cpu'] = 0.0
    procs.sort(key=lambda x: x['cpu'], reverse=True)
    return {
        'cpu_total': cpu_total,
        'cpu_cores': cpu_cores,
        'cpu_freq':  cpu_freq,
        'cpu_count': cpu_count,
        'cpu_phys':  cpu_phys,
        'cpu_times': cpu_times,
        'procs':     procs,
    }

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
    f"{GRAY}  Script: ccpu.py  |  ScriptID: ST-WIN-0056-PY  |  v1.2{RESET}\n"
    f"{GRAY}  Live CPU Monitor — Press Q or Ctrl+C to exit{RESET}\n"
    f"{WHITE}  {'=' * 64}{RESET}\n"
)

# ─── Render ─────────────────────────────────────────────────────
def render(data, elapsed):
    os.system(CLEAR)
    lines = [HEADER]

    ct   = data['cpu_total']
    freq = data['cpu_freq']
    c    = col_pct(ct)

    # ── CPU Overview ──
    lines.append(f"{CYAN}  ════════════════════ CPU STATUS ════════════════════{RESET}")
    lines.append("")

    freq_cur  = f"{freq.current:.0f} MHz" if freq else "N/A"
    freq_max  = f"{freq.max:.0f} MHz"     if freq else "N/A"
    lines.append(f"  {WHITE}Physical cores :{RESET} {data['cpu_phys']}     "
                 f"{WHITE}Logical cores :{RESET} {data['cpu_count']}")
    lines.append(f"  {WHITE}Frequency      :{RESET} {CYAN}{freq_cur}{RESET}  /  max {GRAY}{freq_max}{RESET}")
    lines.append("")

    # Overall bar
    lines.append(f"  {WHITE}Total CPU      :{RESET}  {bar(ct, BAR_WIDTH, c)}  "
                 f"{c}{BOLD}{ct:>5.1f}%{RESET}")
    lines.append("")

    # CPU times breakdown
    tm = data['cpu_times']
    lines.append(f"  {GRAY}User: {tm.user:.1f}%  System: {tm.system:.1f}%  "
                 f"Idle: {tm.idle:.1f}%{RESET}")
    lines.append("")

    # ── Per-core bars ──
    cores = data['cpu_cores']
    lines.append(f"{CYAN}  ════════════════════ PER CORE ═════════════════════{RESET}")
    lines.append("")

    # Print cores in two columns
    pairs = []
    for i in range(0, len(cores), 2):
        left_pct  = cores[i]
        left_c    = col_pct(left_pct)
        left_bar  = bar(left_pct, BAR_WIDTH, left_c, log_scale=True)
        left_str  = (f"  {GRAY}Core {i:>2}{RESET}  {left_bar}  "
                     f"{left_c}{left_pct:>5.1f}%{RESET}")
        if i + 1 < len(cores):
            right_pct = cores[i + 1]
            right_c   = col_pct(right_pct)
            right_bar = bar(right_pct, BAR_WIDTH, right_c, log_scale=True)
            right_str = (f"    {GRAY}Core {i+1:>2}{RESET}  {right_bar}  "
                         f"{right_c}{right_pct:>5.1f}%{RESET}")
            lines.append(left_str + right_str)
        else:
            lines.append(left_str)
    lines.append("")



    # ── Top processes by CPU ──
    top     = data['procs'][:TOP_N]
    max_cpu = max((p['cpu'] for p in top if p['cpu'] > 0), default=1)

    lines.append(f"{YELLOW}  ══════════════ TOP PROCESSES BY CPU USAGE ══════════════{RESET}")
    lines.append("")

    hdr = (f"  {'#':>3}  {'PID':>6}  {'NAME':<22}  "
           f"{'CPU%':>6}  {'BAR (relative)':<{BAR_WIDTH+2}}  {'RAM MB':>8}  {'STATUS':<10}")
    lines.append(BOLD + WHITE + hdr + RESET)
    lines.append(GRAY + "  " + "─" * (len(hdr) - 2) + RESET)

    for i, p in enumerate(top, 1):
        rel   = (p['cpu'] / max_cpu) * 100 if max_cpu > 0 else 0
        c     = col_pct(rel)
        b     = bar(rel, BAR_WIDTH, c, log_scale=True)
        ram_m = p['ram'] / (1024 ** 2)
        lines.append(
            f"  {GRAY}{i:>3}{RESET}  "
            f"{GRAY}{p['pid']:>6}{RESET}  "
            f"{WHITE}{p['name']:<22}{RESET}  "
            f"{c}{p['cpu']:>6.1f}{RESET}  "
            f"{b}  "
            f"{GRAY}{ram_m:>8.1f}{RESET}  "
            f"{GRAY}{p['status']:<10}{RESET}"
        )

    lines.append("")
    lines.append(f"{GRAY}  Showing top {TOP_N} of {len(data['procs'])} processes  │  "
                 f"Refresh: {REFRESH}s  │  Uptime: {elapsed}s  │  [Q] Quit{RESET}")

    sys.stdout.write("\n".join(lines) + "\n")
    sys.stdout.flush()

# ─── Main ───────────────────────────────────────────────────────
def main():
    try:
        import psutil
    except ImportError:
        print("  [!] Run:  pip install psutil")
        sys.exit(1)

    # Prime cpu_percent (first call always returns 0.0)
    psutil.cpu_percent(interval=1)
    psutil.cpu_percent(interval=None, percpu=True)

    sys.stdout.write(HIDE_C)
    sys.stdout.flush()

    t_key = threading.Thread(target=_key_listener, daemon=True)
    t_key.start()

    start = time.time()
    try:
        while not _quit.is_set():
            data    = snapshot()
            elapsed = int(time.time() - start)
            render(data, elapsed)
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