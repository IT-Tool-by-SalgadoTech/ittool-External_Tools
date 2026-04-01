#!/usr/bin/env python3
"""
IT-Tool Android Mirror
Receives the IT-Tool screen (160x128 RGB565) via USB Serial
and displays it in the Android browser via HTTP + WebSocket.

Requirements (Termux):
    pkg install python
    pip install pyserial websockets

Usage:
    python IT_Mirror_Android.py
    python IT_Mirror_Android.py --port /dev/ttyACM0
    python IT_Mirror_Android.py --port /dev/ttyACM0 --scale 4
    python IT_Mirror_Android.py --httpport 8080

How to use:
    1. Connect IT-Tool via USB OTG cable
    2. Run this script in Termux
    3. Grant USB permission when Android prompts
    4. Open browser and go to: http://localhost:8080
    5. On IT-Tool: main menu -> PC_Mirror -> A
"""

import sys
import argparse
import threading
import time
import struct
import os
import json
import base64
import asyncio

# ── Dependency check ──────────────────────────────────────────────────────────
try:
    import serial
    import serial.tools.list_ports
except ImportError:
    print("ERROR: pyserial not installed.")
    print("  Run: pip install pyserial")
    sys.exit(1)

try:
    import websockets
except ImportError:
    print("ERROR: websockets not installed.")
    print("  Run: pip install websockets")
    sys.exit(1)

# Standard library HTTP server (no extra deps)
from http.server import HTTPServer, BaseHTTPRequestHandler
import socket

# ── Constants ─────────────────────────────────────────────────────────────────
FRAME_W      = 160
FRAME_H      = 128
FRAME_PIXELS = FRAME_W * FRAME_H
FRAME_BYTES  = FRAME_PIXELS * 2          # RGB565 = 2 bytes/pixel
BAUD         = 921600

HDR_MAGIC    = bytes([0xFF, 0xAA])
FTR_MAGIC    = bytes([0xFF, 0xBB])
HEADER_SIZE  = 6                         # 0xFF 0xAA W_hi W_lo H_hi H_lo

WS_PORT      = 8765
HTTP_PORT    = 8080

# ── Global state ──────────────────────────────────────────────────────────────
g_latest_frame_b64 = None      # latest frame as base64 PNG-like RGB data
g_latest_raw_rgb   = None      # latest frame as raw RGB bytes (for WS)
g_frame_lock       = threading.Lock()
g_fps              = 0
g_connected_port   = "N/A"
g_ws_clients       = set()
g_ws_loop          = None

# ── Port detection ────────────────────────────────────────────────────────────
def list_serial_ports():
    ports = []
    for p in serial.tools.list_ports.comports():
        ports.append((p.device, p.description or ""))
    return sorted(ports, key=lambda x: x[0])

def find_ittool_port():
    for p in serial.tools.list_ports.comports():
        desc = (p.description or "").lower()
        if any(k in desc for k in ("usb serial", "cp210", "ch340", "cdc", "acm")):
            return p.device
    return None

def select_port_interactive():
    ports = list_serial_ports()
    if not ports:
        print("\nNo serial ports found.")
        print("Make sure:")
        print("  1. USB OTG cable is connected")
        print("  2. IT-Tool is powered on")
        print("  3. You granted USB permission in Android")
        sys.exit(1)

    print("\n=== Available serial ports ===")
    for i, (dev, desc) in enumerate(ports):
        print(f"  [{i+1}] {dev}  —  {desc}")
    print("  [0] Type manually")
    print()

    while True:
        try:
            raw = input("Choose a number: ").strip()
            n = int(raw)
            if n == 0:
                manual = input("Port (e.g. /dev/ttyACM0): ").strip()
                if manual:
                    return manual
            elif 1 <= n <= len(ports):
                return ports[n-1][0]
            else:
                print(f"  Invalid. Choose between 0 and {len(ports)}.")
        except (ValueError, KeyboardInterrupt):
            print("\nCancelled.")
            sys.exit(0)

# ── RGB565 → RGB888 bytes ─────────────────────────────────────────────────────
def rgb565_frame_to_rgb888_bytes(raw_bytes):
    """Convert raw RGB565 frame bytes to flat RGB888 bytes."""
    out = bytearray(FRAME_PIXELS * 3)
    for i in range(FRAME_PIXELS):
        idx = i * 2
        px = (raw_bytes[idx] << 8) | raw_bytes[idx + 1]
        r = ((px >> 11) & 0x1F) << 3
        g = ((px >>  5) & 0x3F) << 2
        b = ( px        & 0x1F) << 3
        out[i*3]   = r
        out[i*3+1] = g
        out[i*3+2] = b
    return bytes(out)

# ── Frame receiver thread ─────────────────────────────────────────────────────
class FrameReceiver(threading.Thread):
    def __init__(self, port, baud):
        super().__init__(daemon=True)
        self.port    = port
        self.baud    = baud
        self.running = True
        self.error   = None
        self._fps_cnt = 0
        self._fps_ts  = time.time()

    def run(self):
        global g_latest_raw_rgb, g_fps, g_frame_lock

        try:
            ser = serial.Serial(self.port, self.baud, timeout=2)
        except serial.SerialException as e:
            self.error = str(e)
            return

        buf = bytearray()

        while self.running:
            try:
                chunk = ser.read(512)
                if not chunk:
                    continue
                buf.extend(chunk)

                while True:
                    idx = buf.find(HDR_MAGIC)
                    if idx == -1:
                        buf = buf[-1:]
                        break
                    if idx > 0:
                        buf = buf[idx:]

                    needed = HEADER_SIZE + FRAME_BYTES + 2
                    if len(buf) < needed:
                        break

                    w = (buf[2] << 8) | buf[3]
                    h = (buf[4] << 8) | buf[5]
                    if w != FRAME_W or h != FRAME_H:
                        buf = buf[2:]
                        continue

                    ftr_pos = HEADER_SIZE + FRAME_BYTES
                    if buf[ftr_pos:ftr_pos+2] != FTR_MAGIC:
                        buf = buf[2:]
                        continue

                    # Valid frame — convert RGB565 → RGB888
                    raw565 = bytes(buf[HEADER_SIZE:HEADER_SIZE + FRAME_BYTES])
                    rgb888 = rgb565_frame_to_rgb888_bytes(raw565)

                    with g_frame_lock:
                        g_latest_raw_rgb = rgb888

                    # Broadcast to all WebSocket clients
                    if g_ws_loop and g_ws_clients:
                        asyncio.run_coroutine_threadsafe(
                            broadcast_frame(rgb888), g_ws_loop
                        )

                    # FPS counter
                    self._fps_cnt += 1
                    now = time.time()
                    if now - self._fps_ts >= 1.0:
                        g_fps = self._fps_cnt
                        self._fps_cnt = 0
                        self._fps_ts  = now

                    buf = buf[HEADER_SIZE + FRAME_BYTES + 2:]

            except serial.SerialException as e:
                self.error = str(e)
                break

        try:
            ser.close()
        except Exception:
            pass

# ── WebSocket broadcast ───────────────────────────────────────────────────────
async def broadcast_frame(rgb888_bytes):
    """Send raw RGB888 frame to all connected WebSocket clients."""
    if not g_ws_clients:
        return
    # Send as binary: 4 bytes header (W, H as uint16 BE) + RGB data
    header = struct.pack(">HH", FRAME_W, FRAME_H)
    message = header + rgb888_bytes
    dead = set()
    for ws in list(g_ws_clients):
        try:
            await ws.send(message)
        except Exception:
            dead.add(ws)
    g_ws_clients.difference_update(dead)

async def ws_handler(websocket, path=None):
    """Handle new WebSocket connection."""
    global g_ws_clients, g_latest_raw_rgb
    g_ws_clients.add(websocket)
    print(f"[WS] Client connected. Total: {len(g_ws_clients)}")
    try:
        # Send current frame immediately if available
        with g_frame_lock:
            frame = g_latest_raw_rgb
        if frame:
            header = struct.pack(">HH", FRAME_W, FRAME_H)
            await websocket.send(header + frame)
        # Keep connection alive
        async for _ in websocket:
            pass
    except Exception:
        pass
    finally:
        g_ws_clients.discard(websocket)
        print(f"[WS] Client disconnected. Total: {len(g_ws_clients)}")

async def run_ws_server(host, port):
    global g_ws_loop
    g_ws_loop = asyncio.get_event_loop()
    print(f"[WS]  WebSocket server on ws://{host}:{port}")
    async with websockets.serve(ws_handler, host, port):
        await asyncio.Future()  # run forever

def start_ws_server(host, port):
    loop = asyncio.new_event_loop()
    asyncio.set_event_loop(loop)
    global g_ws_loop
    g_ws_loop = loop
    loop.run_until_complete(run_ws_server(host, port))

# ── HTTP server ───────────────────────────────────────────────────────────────
HTML_PAGE = """<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0, user-scalable=no">
<title>IT-Tool Mirror</title>
<style>
  * { margin: 0; padding: 0; box-sizing: border-box; }
  body {
    background: #0a0a0a;
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    min-height: 100vh;
    font-family: monospace;
    color: #fd9000;
    touch-action: manipulation;
  }
  #header {
    width: 100%;
    max-width: 500px;
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 8px 12px;
    background: #111;
    border-bottom: 1px solid #fd9000;
  }
  #title { font-size: 14px; font-weight: bold; letter-spacing: 1px; }
  #status { font-size: 12px; }
  #fps { font-size: 12px; color: #fd9000; }
  #canvas-wrap {
    display: flex;
    align-items: center;
    justify-content: center;
    flex: 1;
    padding: 16px;
    width: 100%;
  }
  canvas {
    image-rendering: pixelated;
    image-rendering: crisp-edges;
    border: 2px solid #fd9000;
    border-radius: 4px;
    max-width: 100%;
    max-height: calc(100vh - 120px);
    width: auto;
    height: auto;
  }
  #waiting {
    position: absolute;
    top: 50%;
    left: 50%;
    transform: translate(-50%, -50%);
    text-align: center;
    line-height: 2;
    font-size: 14px;
  }
  #waiting span { color: #fd9000; font-size: 18px; font-weight: bold; }
  #footer {
    width: 100%;
    max-width: 500px;
    padding: 6px 12px;
    background: #111;
    border-top: 1px solid #333;
    font-size: 11px;
    color: #555;
    text-align: center;
  }
  .dot { display: inline-block; animation: blink 1s infinite; }
  @keyframes blink { 0%,100%{opacity:1} 50%{opacity:0.2} }
</style>
</head>
<body>
<div id="header">
  <div id="title">&#9679; IT-TOOL MIRROR</div>
  <div id="status">Connecting<span class="dot">...</span></div>
  <div id="fps">-- fps</div>
</div>
<div id="canvas-wrap">
  <canvas id="screen" width="160" height="128"></canvas>
  <div id="waiting">
    <span>IT-Tool Mirror</span><br>
    Waiting for IT-Tool...<br><br>
    On your IT-Tool:<br>
    Main Menu → PC_Mirror → A
  </div>
</div>
<div id="footer">IT-Tool by SalgadoTech &nbsp;|&nbsp; USB Mirror</div>

<script>
const canvas  = document.getElementById('screen');
const ctx     = canvas.getContext('2d');
const waiting = document.getElementById('waiting');
const status  = document.getElementById('status');
const fpsEl   = document.getElementById('fps');

const FRAME_W = 160;
const FRAME_H = 128;

let frameCount = 0;
let lastFpsTime = Date.now();
let hasFrame = false;
let ws;

function resizeCanvas() {
  const wrap = document.getElementById('canvas-wrap');
  const maxW = wrap.clientWidth  - 32;
  const maxH = wrap.clientHeight - 32;
  const scaleX = maxW / FRAME_W;
  const scaleY = maxH / FRAME_H;
  const scale  = Math.max(1, Math.floor(Math.min(scaleX, scaleY)));
  canvas.style.width  = (FRAME_W * scale) + 'px';
  canvas.style.height = (FRAME_H * scale) + 'px';
}
window.addEventListener('resize', resizeCanvas);
resizeCanvas();

function connect() {
  const wsUrl = 'ws://' + location.hostname + ':WS_PORT_PLACEHOLDER';
  ws = new WebSocket(wsUrl);
  ws.binaryType = 'arraybuffer';

  ws.onopen = () => {
    status.innerHTML = '<span style="color:#4f4">Connected</span>';
  };

  ws.onmessage = (event) => {
    const data = new Uint8Array(event.data);
    if (data.length < 4) return;

    // Header: W_hi W_lo H_hi H_lo (4 bytes)
    const w = (data[0] << 8) | data[1];
    const h = (data[2] << 8) | data[3];
    if (w !== FRAME_W || h !== FRAME_H) return;

    const rgb = data.slice(4);
    if (rgb.length < w * h * 3) return;

    // Paint frame
    const imgData = ctx.createImageData(w, h);
    const pixels  = imgData.data;
    for (let i = 0; i < w * h; i++) {
      pixels[i*4]   = rgb[i*3];
      pixels[i*4+1] = rgb[i*3+1];
      pixels[i*4+2] = rgb[i*3+2];
      pixels[i*4+3] = 255;
    }
    ctx.putImageData(imgData, 0, 0);

    if (!hasFrame) {
      hasFrame = true;
      waiting.style.display = 'none';
    }

    frameCount++;
    const now = Date.now();
    if (now - lastFpsTime >= 1000) {
      fpsEl.textContent = frameCount + ' fps';
      frameCount = 0;
      lastFpsTime = now;
    }
  };

  ws.onclose = () => {
    status.innerHTML = 'Disconnected &mdash; reconnecting<span class="dot">...</span>';
    setTimeout(connect, 2000);
  };

  ws.onerror = () => {
    ws.close();
  };
}

connect();
</script>
</body>
</html>
"""

class MirrorHTTPHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path in ("/", "/index.html"):
            page = HTML_PAGE.replace("WS_PORT_PLACEHOLDER", str(WS_PORT))
            data = page.encode("utf-8")
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.send_header("Content-Length", str(len(data)))
            self.end_headers()
            self.wfile.write(data)
        else:
            self.send_response(404)
            self.end_headers()

    def log_message(self, fmt, *args):
        pass  # suppress HTTP access logs

def start_http_server(host, port):
    server = HTTPServer((host, port), MirrorHTTPHandler)
    print(f"[HTTP] Web UI on http://{host}:{port}")
    server.serve_forever()

# ── Utility ───────────────────────────────────────────────────────────────────
def get_local_ip():
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(("8.8.8.8", 80))
        ip = s.getsockname()[0]
        s.close()
        return ip
    except Exception:
        return "127.0.0.1"

# ── Main ──────────────────────────────────────────────────────────────────────
def main():
    parser = argparse.ArgumentParser(description="IT-Tool Android Mirror")
    parser.add_argument("--port",     default=None,     help="Serial port (auto-detect if omitted)")
    parser.add_argument("--httpport", type=int, default=HTTP_PORT, help=f"HTTP port (default {HTTP_PORT})")
    parser.add_argument("--wsport",   type=int, default=WS_PORT,   help=f"WebSocket port (default {WS_PORT})")
    args = parser.parse_args()

    global WS_PORT, HTTP_PORT
    WS_PORT   = args.wsport
    HTTP_PORT = args.httpport

    print("")
    print("=" * 46)
    print("   IT-Tool Android Mirror")
    print("=" * 46)

    # ── Port selection ────────────────────────────────────────────────────────
    port = args.port
    if port is None:
        auto = find_ittool_port()
        if auto:
            print(f"\nIT-Tool detected: {auto}")
            ans = input("Use it? [Y/n]: ").strip().lower()
            if ans in ("", "y"):
                port = auto
            else:
                port = select_port_interactive()
        else:
            print("\nIT-Tool not auto-detected.")
            port = select_port_interactive()

    print(f"\nUsing port: {port}")
    global g_connected_port
    g_connected_port = port

    # ── Start HTTP server (background thread) ─────────────────────────────────
    http_thread = threading.Thread(
        target=start_http_server, args=("0.0.0.0", HTTP_PORT), daemon=True
    )
    http_thread.start()

    # ── Start WebSocket server (background thread) ────────────────────────────
    ws_thread = threading.Thread(
        target=start_ws_server, args=("0.0.0.0", WS_PORT), daemon=True
    )
    ws_thread.start()

    # ── Start frame receiver ──────────────────────────────────────────────────
    receiver = FrameReceiver(port, BAUD)
    receiver.start()

    local_ip = get_local_ip()

    print("")
    print("─" * 46)
    print(f"  Open in your browser:")
    print(f"  → http://localhost:{HTTP_PORT}")
    print(f"  → http://{local_ip}:{HTTP_PORT}")
    print("─" * 46)
    print(f"  On IT-Tool: Main Menu → PC_Mirror → A")
    print("─" * 46)
    print("  Press Ctrl+C to stop.")
    print("")

    # ── Keep main thread alive, print status ─────────────────────────────────
    try:
        while True:
            time.sleep(5)
            if receiver.error:
                print(f"\n[ERROR] Serial: {receiver.error}")
                print("Check USB connection and restart.")
                sys.exit(1)
    except KeyboardInterrupt:
        print("\nStopped.")
        receiver.running = False
        sys.exit(0)

if __name__ == "__main__":
    main()
