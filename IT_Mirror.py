#!/usr/bin/env python3
"""
IT-Tool PC Mirror — Touch Edition  v5
Receives the IT-Tool screen (320x480 portrait, RGB565) via USB Serial
and displays it scaled on your PC.

Hardware:  Waveshare ESP32-S3-Touch-LCD-3.5 (ST7796, 320x480 portrait)
Firmware:  ITTOOL_TOUCH_USB_Menus_v5_Mirror.txt
Port:      COM7 (USB CDC — TinyUSB, VID:PID=303A:1001)

Protocol (firmware → PC):
  Header : 0xFF 0xAA W_hi W_lo H_hi H_lo   (6 bytes)
  Pixels : W*H pixels, RGB565 big-endian    (W*H*2 bytes)
  Footer : 0xFF 0xBB                        (2 bytes)

Commands (PC → firmware):
  CMD:A\n    right-click  → A (Select/Run)
  CMD:B\n    left-click   → B (Back)
  CMD:UP\n   scroll up    → UP
  CMD:DOWN\n scroll down  → DOWN

Requirements:
    pip install pygame pyserial

Usage:
    python IT_Mirror_v2.py
    python IT_Mirror_v2.py --port COM7
    python IT_Mirror_v2.py --port COM7 --scale 2

Cambios v2:
  - scale default: 2 → 1 (320x480 nativo, mas manejable)
  - Ventana movible: drag con click izquierdo en barra de titulo (24px superior)
  - Modo diagnostico: al llegar el primer frame imprime en consola
      cuantos pixels son cero vs. con datos, y los primeros 10 valores
      → permite saber si el shadowFB del firmware esta vacio o lleno
  - pygame.RESIZABLE eliminado de recreacion de ventana (interferia con drag)
"""

import sys
import argparse
import threading
import time

# ── Dependency check ──────────────────────────────────────────────────────────
try:
    import serial
    import serial.tools.list_ports
except ImportError:
    print("ERROR: pyserial not installed.")
    print("  Run: pip install pyserial")
    sys.exit(1)

try:
    import pygame
except ImportError:
    print("ERROR: pygame not installed.")
    print("  Run: pip install pygame")
    sys.exit(1)

# ── Protocol constants ────────────────────────────────────────────────────────
BAUD        = 921600
HDR_MAGIC   = bytes([0xFF, 0xAA])
FTR_MAGIC   = bytes([0xFF, 0xBB])
HEADER_SIZE = 6   # 0xFF 0xAA W_hi W_lo H_hi H_lo

# Altura de la barra de titulo falsa (zona de drag)
TITLE_BAR_H = 24

# ── Safe input ────────────────────────────────────────────────────────────────
def safe_input(prompt=""):
    try:
        return input(prompt)
    except EOFError:
        pass
    try:
        import os
        if os.name == "nt":
            sys.stdin = open("CON", "r")
        else:
            sys.stdin = open("/dev/tty", "r")
        return input(prompt)
    except Exception:
        print("")
        return ""

# ── Serial port helpers ───────────────────────────────────────────────────────
def list_serial_ports():
    ports = []
    for p in serial.tools.list_ports.comports():
        ports.append((p.device, p.description or ""))
    return sorted(ports, key=lambda x: x[0])

# ── RGB565 → RGB888 ───────────────────────────────────────────────────────────
def rgb565_to_rgb888(px):
    r = ((px >> 11) & 0x1F) << 3
    g = ((px >>  5) & 0x3F) << 2
    b = ( px        & 0x1F) << 3
    return (r, g, b)

# ── Diagnostico de frame ──────────────────────────────────────────────────────
def diag_frame(pixels, fw, fh):
    """Imprime en consola info del frame para detectar shadowFB vacio."""
    total   = len(pixels)
    zeros   = sum(1 for p in pixels if p == (0, 0, 0))
    nonzero = total - zeros
    pct_zero = (zeros / total * 100) if total else 0

    print("")
    print("=" * 56)
    print("  [DIAG] Primer frame recibido")
    print(f"  Dimensiones  : {fw} x {fh}")
    print(f"  Total pixels : {total}")
    print(f"  Pixels cero  : {zeros}  ({pct_zero:.1f}%)")
    print(f"  Pixels datos : {nonzero}  ({100-pct_zero:.1f}%)")
    print("")
    print("  Primeros 10 valores RGB:")
    for i, (r, g, b) in enumerate(pixels[:10]):
        raw565 = ((r >> 3) << 11) | ((g >> 2) << 5) | (b >> 3)
        print(f"    [{i:2d}]  RGB=({r:3d},{g:3d},{b:3d})  RGB565=0x{raw565:04X}")
    print("")
    if pct_zero > 99.0:
        print("  *** ATENCION: frame casi completamente negro ***")
        print("  *** El shadowFB del firmware parece estar vacio. ***")
        print("  *** Bug en firmware: los overrides de MirrorGFX ***")
        print("  *** no se estan disparando para ese path de draw. ***")
    else:
        print("  Frame tiene datos validos. El bug es en el renderizado Python.")
    print("=" * 56)
    print("")

# ── Frame receiver thread ─────────────────────────────────────────────────────
class FrameReceiver(threading.Thread):
    def __init__(self, port, baud):
        super().__init__(daemon=True)
        self.port          = port
        self.baud          = baud
        # frame es tupla (pixels, w, h) o None
        self.frame         = None
        self.lock          = threading.Lock()
        self.running       = True
        self.fps           = 0
        self._fps_cnt      = 0
        self._fps_ts       = time.time()
        self.error         = None
        self._ser          = None
        self._ser_lock     = threading.Lock()
        self.runner_active = False
        self._diag_done    = False   # diagnostico ejecutado solo una vez

    def send_cmd(self, cmd):
        """Envía CMD:<cmd>\n al ESP32. Thread-safe."""
        with self._ser_lock:
            if self._ser and self._ser.is_open:
                try:
                    self._ser.write(f"CMD:{cmd}\n".encode())
                except Exception:
                    pass

    def run(self):
        try:
            ser = serial.Serial(self.port, self.baud, timeout=2)
        except serial.SerialException as e:
            self.error = str(e)
            return

        with self._ser_lock:
            self._ser = ser

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
                        # Sin header — parsear STATE: y descartar buffer
                        text = buf.decode("utf-8", errors="ignore")
                        for line in text.splitlines():
                            line = line.strip()
                            if line == "STATE:RUNNING":
                                self.runner_active = True
                            elif line == "STATE:IDLE":
                                self.runner_active = False
                        buf = buf[-1:]
                        break

                    if idx > 0:
                        # Texto antes del header — parsear STATE:
                        pre = buf[:idx].decode("utf-8", errors="ignore")
                        for line in pre.splitlines():
                            line = line.strip()
                            if line == "STATE:RUNNING":
                                self.runner_active = True
                            elif line == "STATE:IDLE":
                                self.runner_active = False
                        buf = buf[idx:]

                    # Necesitamos al menos el header completo
                    if len(buf) < HEADER_SIZE:
                        break

                    # Leer dimensiones del header — 2 bytes reales por dimensión
                    w = (buf[2] << 8) | buf[3]
                    h = (buf[4] << 8) | buf[5]

                    # Validar dimensiones básicas
                    if w == 0 or h == 0 or w > 2048 or h > 2048:
                        buf = buf[2:]   # header inválido, avanzar
                        continue

                    frame_bytes = w * h * 2   # RGB565 = 2 bytes/pixel

                    # Necesitamos header + pixels + footer completos
                    needed = HEADER_SIZE + frame_bytes + 2
                    if len(buf) < needed:
                        break   # esperar más datos

                    # Verificar footer en la posición exacta
                    ftr_pos = HEADER_SIZE + frame_bytes
                    if buf[ftr_pos:ftr_pos + 2] != FTR_MAGIC:
                        buf = buf[2:]   # frame corrupto, avanzar
                        continue

                    # Frame válido — decodificar pixels RGB565 → RGB888
                    raw = buf[HEADER_SIZE:HEADER_SIZE + frame_bytes]
                    pixels = []
                    for i in range(0, len(raw), 2):
                        px = (raw[i] << 8) | raw[i + 1]
                        pixels.append(rgb565_to_rgb888(px))

                    with self.lock:
                        self.frame = (pixels, w, h)

                    # Diagnostico: solo la primera vez
                    if not self._diag_done:
                        self._diag_done = True
                        diag_frame(pixels, w, h)

                    # Contador FPS
                    self._fps_cnt += 1
                    now = time.time()
                    if now - self._fps_ts >= 1.0:
                        self.fps      = self._fps_cnt
                        self._fps_cnt = 0
                        self._fps_ts  = now

                    buf = buf[HEADER_SIZE + frame_bytes + 2:]

            except serial.SerialException as e:
                self.error = str(e)
                break

        try:
            ser.close()
        except Exception:
            pass

    def get_frame(self):
        with self.lock:
            return self.frame

# ── Main ──────────────────────────────────────────────────────────────────────
def main():
    parser = argparse.ArgumentParser(description="IT-Tool PC Mirror — Touch Edition v2")
    parser.add_argument("--port",  default=None,
                        help="Puerto serial (ej: COM7 o /dev/ttyACM0)")
    parser.add_argument("--scale", type=int, default=1,
                        help="Factor de escala (default 1 → 320x480 nativo)")
    args = parser.parse_args()

    # ── Selección de puerto ───────────────────────────────────────────────────
    port = args.port
    if port is None:
        print("")
        print("=" * 50)
        print("   IT-Tool PC Mirror — Touch Edition  v4")
        print("   Hardware: Waveshare ESP32-S3-Touch-LCD-3.5")
        print("   Screen:   320x480 portrait")
        print("=" * 50)
        print("")
        print("Antes de continuar:")
        print("  1. Desconecta el cable USB del IT-Tool")
        print("  2. Vuelve a conectarlo")
        print("")
        safe_input("Vuelve aqui y presiona ENTER...")
        print("")

        ports = list_serial_ports()
        if not ports:
            print("No se detectaron puertos COM. Verifica la conexion USB.")
            safe_input("Presiona ENTER para cerrar.")
            sys.exit(1)

        print("Puertos disponibles:")
        for i, (dev, desc) in enumerate(ports):
            print(f"  {i+1}. {dev}  —  {desc}")
        print("")

        if len(ports) == 1:
            print(f"Un solo puerto encontrado: {ports[0][0]}")
            ans = safe_input("Usar este? [Y/n]: ").strip().lower()
            if ans in ("", "y", "s"):
                port = ports[0][0]
            else:
                safe_input("Conecta el IT-Tool y reinicia el script. ENTER para cerrar.")
                sys.exit(0)
        else:
            while True:
                try:
                    n = int(safe_input("Selecciona numero de puerto: ").strip())
                    if 1 <= n <= len(ports):
                        port = ports[n - 1][0]
                        break
                    else:
                        print("  Opcion invalida.")
                except (ValueError, KeyboardInterrupt):
                    print("\nCancelado.")
                    sys.exit(0)

        print(f"Usando {port}")
        print("")
    else:
        print(f"Usando puerto: {port}")

    scale = max(1, args.scale)

    # ── Iniciar receiver ──────────────────────────────────────────────────────
    receiver = FrameReceiver(port, BAUD)
    receiver.start()

    # ── Pygame ───────────────────────────────────────────────────────────────
    # Ventana con barra de titulo propia (TITLE_BAR_H px) para poder arrastrarla.
    # La imagen del IT-Tool ocupa el area debajo de la barra.
    INIT_W   = 320 * scale
    INIT_H   = 480 * scale + TITLE_BAR_H   # +24px barra de titulo

    pygame.init()
    screen = pygame.display.set_mode((INIT_W, INIT_H), pygame.RESIZABLE)
    pygame.display.set_caption("IT-Tool PC Mirror v4 — Touch 320x480")
    clock = pygame.time.Clock()
    font  = pygame.font.SysFont("monospace", 14)
    font_title = pygame.font.SysFont("monospace", 13)

    frame_surf     = None
    frame_w        = 0
    frame_h        = 0
    win_w          = INIT_W
    win_h          = INIT_H
    img_h          = INIT_H - TITLE_BAR_H   # altura del area de imagen
    last_frame_ref = None

    # Drag de ventana
    dragging      = False
    drag_offset_x = 0
    drag_offset_y = 0

    # Debounce botón A (click derecho) — evita doble disparo de CMD:A
    _last_cmd_a_ms    = 0
    CMD_A_DEBOUNCE_MS = 500   # ms mínimos entre CMD:A consecutivos

    # Eje del scroll: 'Y' = arriba/abajo (default), 'X' = izquierda/derecha
    # Click del scroll (botón medio) alterna entre los dos modos.
    scroll_axis = 'Y'

    print("Ve al menu del IT-Tool → PC_Mirror → Mirror ON.")
    print("Al llegar el primer frame veras info de diagnostico en esta consola.")

    running = True
    while running:
        # ── Eventos ───────────────────────────────────────────────────────────
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                running = False

            elif event.type == pygame.KEYDOWN:
                if event.key == pygame.K_ESCAPE:
                    running = False

            elif event.type == pygame.VIDEORESIZE:
                win_w  = event.w
                win_h  = event.h
                img_h  = win_h - TITLE_BAR_H
                if img_h < 1: img_h = 1
                screen = pygame.display.set_mode((win_w, win_h), pygame.RESIZABLE)

            # ── Drag de ventana (solo en la barra de titulo) ──────────────────
            elif event.type == pygame.MOUSEBUTTONDOWN:
                mx, my = event.pos
                if event.button == 1 and my < TITLE_BAR_H:
                    # Click en la barra de titulo → iniciar drag
                    dragging = True
                    wx, wy = pygame.display.get_window_size()
                    # Guardar offset relativo al origen de la ventana
                    abs_mouse = pygame.mouse.get_pos()
                    import ctypes
                    if hasattr(ctypes, 'windll'):
                        # Windows: mover via SetWindowPos
                        hwnd = pygame.display.get_wm_info().get('window', None)
                    drag_offset_x = mx
                    drag_offset_y = my
                elif event.button == 3 and my >= TITLE_BAR_H:
                    # Click derecho en area imagen → A (con debounce)
                    now_ms = pygame.time.get_ticks()
                    if not receiver.runner_active and (now_ms - _last_cmd_a_ms) >= CMD_A_DEBOUNCE_MS:
                        _last_cmd_a_ms = now_ms
                        receiver.send_cmd("A")
                elif event.button == 1 and my >= TITLE_BAR_H:
                    # Click izquierdo en area imagen → B
                    if not receiver.runner_active:
                        receiver.send_cmd("B")
                elif event.button == 2:
                    # Click del scroll (botón medio) → alternar eje del scroll
                    scroll_axis = 'X' if scroll_axis == 'Y' else 'Y'
                    axis_label = "← →  LEFT/RIGHT" if scroll_axis == 'X' else "↑ ↓  UP/DOWN"
                    print(f"[Mirror] Scroll axis: {axis_label}")

            elif event.type == pygame.MOUSEBUTTONUP:
                if event.button == 1:
                    dragging = False

            elif event.type == pygame.MOUSEMOTION:
                if dragging:
                    # Mover ventana siguiendo el mouse
                    # pygame no expone move_window directamente en todas las versiones;
                    # usamos SDL via ctypes en Windows o el metodo disponible
                    try:
                        import os
                        if os.name == "nt":
                            import ctypes
                            user32 = ctypes.windll.user32
                            hwnd_info = pygame.display.get_wm_info()
                            hwnd = hwnd_info.get('window')
                            if hwnd:
                                # Posicion actual del cursor en coordenadas de pantalla
                                pt = ctypes.wintypes.POINT()
                                user32.GetCursorPos(ctypes.byref(pt))
                                new_x = pt.x - drag_offset_x
                                new_y = pt.y - drag_offset_y
                                SWP_NOSIZE = 0x0001
                                user32.SetWindowPos(hwnd, 0,
                                                    new_x, new_y, 0, 0,
                                                    SWP_NOSIZE | 0x0004)
                    except Exception:
                        pass

            elif event.type == pygame.MOUSEWHEEL:
                if not receiver.runner_active:
                    if scroll_axis == 'Y':
                        # Modo vertical (default): UP / DOWN
                        if event.y > 0:
                            receiver.send_cmd("UP")
                        elif event.y < 0:
                            receiver.send_cmd("DOWN")
                    else:
                        # Modo horizontal (activado con click del scroll): LEFT / RIGHT
                        if event.y > 0:
                            receiver.send_cmd("LEFT")
                        elif event.y < 0:
                            receiver.send_cmd("RIGHT")

        # ── Barra de titulo ───────────────────────────────────────────────────
        pygame.draw.rect(screen, (20, 20, 40), (0, 0, win_w, TITLE_BAR_H))
        pygame.draw.line(screen, (0, 170, 200), (0, TITLE_BAR_H - 1), (win_w, TITLE_BAR_H - 1))
        title_lbl = font_title.render(
            f"IT-Tool Mirror  {frame_w}x{frame_h}  (x{scale})  — arrastra aqui",
            True, (0, 212, 255))
        screen.blit(title_lbl, (8, (TITLE_BAR_H - title_lbl.get_height()) // 2))

        # Indicador de eje del scroll — badge en la barra de titulo
        # Verde = Y (vertical, default) | Naranja = X (horizontal)
        axis_txt  = "↑↓" if scroll_axis == 'Y' else "←→"
        axis_col  = (0, 220, 120) if scroll_axis == 'Y' else (255, 160, 0)
        axis_surf = font_title.render(axis_txt, True, axis_col)
        axis_x    = win_w - axis_surf.get_width() - 52  # a la izquierda del fps
        screen.blit(axis_surf, (axis_x, (TITLE_BAR_H - axis_surf.get_height()) // 2))

        # ── Error de serial ───────────────────────────────────────────────────
        if receiver.error:
            pygame.draw.rect(screen, (30, 0, 0), (0, TITLE_BAR_H, win_w, win_h - TITLE_BAR_H))
            msg = font.render(f"Serial error: {receiver.error}", True, (255, 80, 80))
            screen.blit(msg, (10, TITLE_BAR_H + (win_h - TITLE_BAR_H) // 2 - 10))
            pygame.display.flip()
            clock.tick(5)
            continue

        # ── Obtener último frame ──────────────────────────────────────────────
        frame_data = receiver.get_frame()

        if frame_data is None:
            # Sin frame aún — pantalla de espera
            pygame.draw.rect(screen, (10, 10, 30), (0, TITLE_BAR_H, win_w, win_h - TITLE_BAR_H))
            lines = [
                "IT-Tool PC Mirror  v4",
                "Touch Edition",
                "",
                f"Puerto: {port}",
                "Screen: 320x480 portrait",
                "",
                "Esperando IT-Tool...",
                "Activa Mirror ON desde",
                "PC_Mirror en el menu.",
                "",
                "(diagnostico en consola al recibir primer frame)",
            ]
            base_y = TITLE_BAR_H + (win_h - TITLE_BAR_H) // 2 - len(lines) * 11
            for line in lines:
                surf = font.render(line, True, (253, 160, 32))
                screen.blit(surf, (win_w // 2 - surf.get_width() // 2, base_y))
                base_y += 22
            pygame.display.flip()
            clock.tick(10)
            continue

        pixels, fw, fh = frame_data

        # ── Ventana siempre 320x480 — independiente de las dimensiones recibidas ──
        # El firmware puede enviar subsampled (ej. 160x240) pero la ventana
        # se mantiene fija en 320x480. pygame.transform.scale hace el upscale.
        DISPLAY_W = 320
        DISPLAY_H = 480
        if fw != frame_w or fh != frame_h:
            frame_w = fw
            frame_h = fh
            img_h   = DISPLAY_H
            win_w   = DISPLAY_W
            win_h   = DISPLAY_H + TITLE_BAR_H
            screen  = pygame.display.set_mode((win_w, win_h), pygame.RESIZABLE)
            pygame.display.set_caption(
                f"IT-Tool PC Mirror v4 — Touch {fw}x{fh} (x{scale})"
            )
            frame_surf     = pygame.Surface((fw, fh), 0, 24)
            frame_surf.fill((0, 0, 0))
            last_frame_ref = None   # forzar redibujado

        # ── Renderizar frame si es nuevo ──────────────────────────────────────
        if frame_data is not last_frame_ref:
            last_frame_ref = frame_data
            try:
                import numpy as np
                # pixels: lista de (r,g,b) en orden row-major ESP32 (y*fw+x)
                # numpy reshape → (fh, fw, 3), transponer → (fw, fh, 3) para pygame surfarray
                arr = np.array(pixels, dtype=np.uint8).reshape((fh, fw, 3))
                arr_t = np.transpose(arr, (1, 0, 2)).copy()  # (fw, fh, 3) contiguo
                pygame.surfarray.blit_array(frame_surf, arr_t)
            except ImportError:
                # Fallback sin numpy: lento pero correcto
                pa = pygame.PixelArray(frame_surf)
                for y in range(fh):
                    for x in range(fw):
                        r, g, b = pixels[y * fw + x]
                        pa[x][y] = frame_surf.map_rgb(r, g, b)
                del pa

        # ── Escalar y dibujar en pantalla (bajo la barra de titulo) ──────────
        scaled = pygame.transform.scale(frame_surf, (win_w, img_h))
        screen.blit(scaled, (0, TITLE_BAR_H))

        # FPS — esquina superior derecha (dentro de la barra)
        fps_txt = font.render(f"{receiver.fps} fps", True, (0, 212, 255))
        screen.blit(fps_txt, (win_w - fps_txt.get_width() - 6, (TITLE_BAR_H - fps_txt.get_height()) // 2))

        # Indicador RUNNING — sobre la imagen
        if receiver.runner_active:
            run_txt = font.render("RUNNING - mouse frozen", True, (255, 80, 80))
            screen.blit(run_txt, (6, TITLE_BAR_H + 4))

        pygame.display.flip()
        clock.tick(60)

    # Avisar al firmware que el mirror se cerró en el PC para que reactive
    # el screen saver (swipe izq->der). Cubre cierre por la X y por ESC.
    try:
        receiver.send_cmd("MIRROR_OFF")
        time.sleep(0.15)   # flush antes de cerrar el puerto
    except Exception:
        pass
    receiver.running = False
    pygame.quit()
    print("Cerrado.")

if __name__ == "__main__":
    main()
