#!/usr/bin/env python3
"""Construye el cursor "Amatista" a partir de los SVG de Bibata Modern.

Uso: construir-cursor.py <carpeta-bibata> <salida> [relleno] [borde] [fondo-espera]
     (por defecto: relleno #B98CFF, borde #1E1530, fondo del reloj #1E1530)

  <carpeta-bibata>  clon de https://github.com/ful1e5/Bibata_Cursor
  <salida>          carpeta del tema (por ejemplo assets/cursor/Amatista)

Bibata dibuja sus SVG con colores marcadores: #00FF00 relleno, #0000FF borde
y #FF0000 fondo del reloj de espera. Aquí se reemplazan por los del tema, se
rasterizan con rsvg-convert y se escriben los archivos XCursor directamente
(sin clickgen ni xcursorgen). Incluye todas las formas: flecha, texto, mano,
espera, redimensionar, mover, copiar, prohibido, etc.
"""
import glob, os, re, struct, subprocess, sys, tempfile, tomllib, zlib

TAMANOS = [16, 20, 22, 24, 28, 32, 40, 48, 56, 64, 72, 80, 88, 96]


def leer_png(datos):
    """Decodifica el PNG RGBA de 8 bits que produce rsvg-convert."""
    pos, idat, ancho, alto = 8, b"", 0, 0
    while pos < len(datos):
        largo, tipo = struct.unpack(">I4s", datos[pos:pos + 8])
        cuerpo = datos[pos + 8:pos + 8 + largo]
        if tipo == b"IHDR":
            ancho, alto, prof, color, _, _, entrelazado = struct.unpack(">IIBBBBB", cuerpo)
            assert prof == 8 and color == 6 and entrelazado == 0, "PNG no RGBA8"
        elif tipo == b"IDAT":
            idat += cuerpo
        pos += 12 + largo
    crudo, fila, bpp = zlib.decompress(idat), ancho * 4, 4
    pix, previa, i = bytearray(), bytearray(fila), 0
    for _ in range(alto):
        filtro, linea = crudo[i], bytearray(crudo[i + 1:i + 1 + fila])
        i += 1 + fila
        for x in range(fila):
            a = linea[x - bpp] if x >= bpp else 0
            b = previa[x]
            c = previa[x - bpp] if x >= bpp else 0
            if filtro == 1: linea[x] = (linea[x] + a) & 255
            elif filtro == 2: linea[x] = (linea[x] + b) & 255
            elif filtro == 3: linea[x] = (linea[x] + (a + b) // 2) & 255
            elif filtro == 4:
                p = a + b - c
                pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
                linea[x] = (linea[x] + (a if pa <= pb and pa <= pc else b if pb <= pc else c)) & 255
        pix += linea
        previa = linea
    return ancho, alto, pix


def argb(pix):
    """RGBA -> ARGB premultiplicado en little-endian (formato XCursor)."""
    salida = bytearray(len(pix))
    for i in range(0, len(pix), 4):
        r, g, b, a = pix[i:i + 4]
        salida[i:i + 4] = bytes((b * a // 255, g * a // 255, r * a // 255, a))
    return bytes(salida)


def xcursor(cuadros):
    """cuadros: lista de (tamaño, ancho, alto, xhot, yhot, retardo, pixeles)."""
    cab = struct.pack("<4sIII", b"Xcur", 16, 0x10000, len(cuadros))
    pos = 16 + 12 * len(cuadros)
    toc, cuerpos = b"", b""
    for tam, an, al, xh, yh, ret, px in cuadros:
        cuerpo = struct.pack("<IIIIIIIII", 36, 0xfffd0002, tam, 1, an, al, xh, yh, ret) + px
        toc += struct.pack("<III", 0xfffd0002, tam, pos)
        pos += len(cuerpo)
        cuerpos += cuerpo
    return cab + toc + cuerpos


def main():
    bibata, salida = sys.argv[1], sys.argv[2]
    relleno = sys.argv[3] if len(sys.argv) > 3 else "#B98CFF"
    borde = sys.argv[4] if len(sys.argv) > 4 else "#1E1530"
    espera = sys.argv[5] if len(sys.argv) > 5 else "#1E1530"
    colores = {"#00FF00": relleno, "#0000FF": borde, "#FF0000": espera}

    with open(os.path.join(bibata, "configs/normal/x.build.toml"), "rb") as f:
        conf = tomllib.load(f)["cursors"]
    base = conf.pop("fallback_settings")
    svgs = os.path.join(bibata, "svg/modern")
    destino = os.path.join(salida, "cursors")
    os.makedirs(destino, exist_ok=True)

    with tempfile.TemporaryDirectory() as tmp:
        for clave, c in conf.items():
            patron = c["png"].replace(".png", ".svg")
            archivos = sorted(glob.glob(os.path.join(svgs, patron))
                              + glob.glob(os.path.join(svgs, "*", patron)))
            if not archivos:
                print("sin svg:", clave, file=sys.stderr)
                continue
            xh = c.get("x_hotspot", base["x_hotspot"])
            yh = c.get("y_hotspot", base["y_hotspot"])
            retardo = c.get("x11_delay", base["x11_delay"])
            cuadros = []
            for tam in TAMANOS:
                for svg in archivos:
                    texto = open(svg).read()
                    for marca, nuevo in colores.items():
                        texto = re.sub(marca, nuevo, texto, flags=re.I)
                    ruta = os.path.join(tmp, "c.svg")
                    open(ruta, "w").write(texto)
                    png = subprocess.run(["rsvg-convert", "-w", str(tam), "-h", str(tam), ruta],
                                         check=True, capture_output=True).stdout
                    an, al, px = leer_png(png)
                    cuadros.append((tam, an, al, xh * tam // 256, yh * tam // 256,
                                    retardo, argb(px)))
            nombre = c["x11_name"]
            open(os.path.join(destino, nombre), "wb").write(xcursor(cuadros))
            for alias in c.get("x11_symlinks", []):
                enlace = os.path.join(destino, alias)
                if os.path.lexists(enlace):
                    os.remove(enlace)
                os.symlink(nombre, enlace)
            print("cursor:", nombre)

    with open(os.path.join(salida, "index.theme"), "w") as f:
        f.write("[Icon Theme]\nName=Amatista\n"
                "Comment=Cursor Amatista: Bibata Modern, lila con borde oscuro\n"
                "Inherits=hicolor\n")


if __name__ == "__main__":
    main()
