#!/usr/bin/env python3
"""Genera lib/logo.ansi: la gema del tema en "pixel art" con medios bloques (▀ ▄)
y colores truecolor, para el instalador. Cada celda de texto son dos píxeles
verticales, así los píxeles salen cuadrados.

Uso: herramientas/construir-logo-instalador.py > lib/logo.ansi
"""
ANCHO, ALTO = 22, 20          # píxeles (ALTO par)
CINTURA = 6                    # fila donde termina la corona
CORONA_IZQ, CORONA_DER = 5, 16 # mesa (parte plana de arriba)
PUNTA = 19

FONDO = None
CLARO = (232, 214, 255)
LILA = (208, 168, 255)
ACENTO = (185, 140, 255)
MEDIO = (150, 104, 230)
OSCURO = (108, 70, 190)
BRILLO = (255, 244, 255)

def color(x, y):
    cx = (ANCHO - 1) / 2
    if y < CINTURA:
        # corona: trapecio que se abre de la mesa a la cintura
        t = y / (CINTURA - 1)
        izq = CORONA_IZQ * (1 - t)
        der = CORONA_DER + (ANCHO - 1 - CORONA_DER) * t
        if not (izq - 0.5 <= x <= der + 0.5):
            return FONDO
        if y == 0:
            return BRILLO if x < cx else CLARO
        # tres facetas: izquierda, centro, derecha
        if x < izq + (cx - izq) * 0.55:
            return LILA
        if x > der - (der - cx) * 0.55:
            return MEDIO
        return CLARO
    # pabellón: triángulo hasta la punta
    t = (y - CINTURA) / (PUNTA - CINTURA)
    medio_ancho = cx * (1 - t)
    if abs(x - cx) > medio_ancho + 0.5:
        return FONDO
    if y == CINTURA:
        return ACENTO
    d = x - cx
    if abs(d) < 0.6 and t < 0.55:
        return LILA            # arista central iluminada (solo arriba)
    return ACENTO if d < 0 else OSCURO

def esc(c, plano):
    return f"\033[{38 if plano == 'fg' else 48};2;{c[0]};{c[1]};{c[2]}m"

lineas = []
for fila in range(0, ALTO, 2):
    s = ""
    for x in range(ANCHO):
        arriba, abajo = color(x, fila), color(x, fila + 1)
        if arriba is None and abajo is None:
            s += "\033[0m "
        elif arriba is None:
            s += "\033[0m" + esc(abajo, "fg") + "▄"
        elif abajo is None:
            s += "\033[0m" + esc(arriba, "fg") + "▀"
        else:
            s += esc(arriba, "fg") + esc(abajo, "bg") + "▀"
    lineas.append(s + "\033[0m")
print("\n".join(lineas))
