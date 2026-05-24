#!/usr/bin/env python3
# index_tree_txt.py
# Crea un índice .txt de carpetas/archivos con indentación tipo "tree" simple.

from __future__ import annotations
import os
from pathlib import Path

INDENT = "    "  # 4 espacios (cámbialo si quieres tabs: "\t")

def natural_key(s: str):
    # Orden simple case-insensitive (suficiente para la mayoría de casos)
    return s.lower()

def should_skip(name: str, skip_hidden: bool) -> bool:
    if not skip_hidden:
        return False
    # Skips comunes en Windows/Linux
    return name.startswith(".") or name in {"Thumbs.db", "desktop.ini"}

def write_index(root: Path, out_file: Path, strip_extensions: bool = True, skip_hidden: bool = True):
    root = root.resolve()
    lines: list[str] = []

    # Primera línea: nombre de la carpeta raíz
    lines.append(root.name)

    def walk(dir_path: Path, depth: int):
        try:
            entries = list(dir_path.iterdir())
        except PermissionError:
            lines.append(f"{INDENT * depth}[ACCESS DENIED] {dir_path.name}")
            return

        # Filtra y separa dirs / files
        dirs = [e for e in entries if e.is_dir() and not should_skip(e.name, skip_hidden)]
        files = [e for e in entries if e.is_file() and not should_skip(e.name, skip_hidden)]

        dirs.sort(key=lambda p: natural_key(p.name))
        files.sort(key=lambda p: natural_key(p.name))

        # Primero carpetas
        for d in dirs:
            lines.append(f"{INDENT * depth}{d.name}")
            walk(d, depth + 1)

        # Luego archivos
        for f in files:
            name = f.stem if strip_extensions else f.name
            lines.append(f"{INDENT * depth}{name}")

    walk(root, 1)

    out_file.parent.mkdir(parents=True, exist_ok=True)
    out_file.write_text("\n".join(lines) + "\n", encoding="utf-8")

def main():
    print("== TXT Index Generator ==")
    src = input("Origin (folder path): ").strip().strip('"')
    if not src:
        print("No se dio Origen. Saliendo.")
        return

    root = Path(src)
    if not root.exists() or not root.is_dir():
        print("Esa ruta no existe o no es carpeta.")
        return

    default_out = root / "index.txt"
    out = input(f"Salida .txt (ENTER = {default_out}): ").strip().strip('"')
    out_file = Path(out) if out else default_out

    strip = input("¿Quitar extensiones? (S/n): ").strip().lower()
    strip_extensions = (strip != "n")

    hidden = input("¿Omitir archivos/carpetas ocultos/comunes? (S/n): ").strip().lower()
    skip_hidden = (hidden != "n")

    write_index(root, out_file, strip_extensions=strip_extensions, skip_hidden=skip_hidden)
    print(f"Listo. Índice creado en: {out_file.resolve()}")

if __name__ == "__main__":
    main()