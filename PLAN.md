# Plan de implementación — tema Amatista

Lista de lo que falta para completar el tema. Marcar con `[x]` al terminar.

## 1. Fallas actuales

- [x] **Apps Qt con el tema** (Mitis, etc.): paquete `qt6ct` + `config/qt6ct`
      (paleta Amatista, iconos Colloid-Purple-Dark, diálogos del portal).
- [x] **Teclas multimedia**: paquete `playerctl` (siguiente / anterior / pausa).
- [x] **Atajos duplicados**: volumen y brillo estaban dos veces en `binds.lua`
      (el volumen subía 10 % en vez de 5 %, el brillo no mostraba el OSD).
- [x] **Capturas de pantalla**: `grim` + `slurp` + script `captura`
      (Imprimir: área · Shift+Imprimir: pantalla · Alt+Imprimir: ventana),
      guarda en `~/Imágenes/Capturas`, copia al portapapeles y notifica.
- [x] **Restos de pruebas**: `wayvnc` en `autostart.lua`,
      `bloqueo/SuperficieBloqueo.qml.copy`.
      (`quickshell/lock` se conserva: es el respaldo de `bloquear` si el
      escritorio de Quickshell no está corriendo.)
- [x] Instalar paquetes nuevos y verificar en el equipo.

## 2. Huecos para un tema completo

- [x] **Apps predeterminadas** livianas, con la paleta, y asignadas por `xdg-mime`:
  - [x] Imágenes: imv · Video y audio: mpv (controles con la paleta)
  - [x] PDF: zathura (Ctrl+R aplica los colores del tema al documento)
  - [x] Texto: Neovim dentro de kitty
  - [x] Verificar en el equipo tras instalar (`apps-livianas.sh`).
- [x] **Indexador de GNOME** (`localsearch`, lo trae Nautilus) bloqueado.
- [x] **Llavero**: `gnome-keyring` + PAM en greetd (`sistema/pam/`), sockets de
      usuario, agente SSH de gcr y git con libsecret.
  - [x] Verificar tras reiniciar sesión: greetd desbloquea el llavero, secret-tool y agente SSH funcionan.
- [x] **Fuentes**: `noto-fonts-emoji`. (`noto-fonts-cjk` opcional, sin instalar.)
- [x] **Arranque con el tema** (`etapas/06-tema-arranque.sh`):
  - [x] Plymouth Amatista (gema + puntos, contraseña de disco).
  - [x] GRUB Amatista.
  - [x] GRUB verificado; corregido el texto del temporizador tapado por la barra.
  - [x] Plymouth verificado (el error eran colores en hexadecimal, no admitidos).
- [x] **Consola TTY** con la paleta (`consola-amatista.service`).

## 3. Mejoras de identidad

- [x] **Capturas**: notificación con botones Abrir / Editar (`satty`, paleta Amatista) / Abrir carpeta.
- [x] **Selector de color**: `hyprpicker` + script `color` (Super+Alt+C), copia y notifica con muestra.
- [x] **Luz nocturna**: `hyprsunset` + píldora en la barra (Super+Alt+N), recuerda el estado.
- [x] **Grabación de pantalla**: `gpu-screen-recorder` (VA-API, `libva-intel-driver` en i5) + script
      `grabar` (Super+Alt+R pantalla, Super+Alt+Shift+R área) + indicador en la barra.
- [x] **Ayuda de atajos**: panel de Quickshell (Super+A), lee `hyprctl binds -j`.
      Convención: todo `hl.bind` lleva `{ description = "Categoría: Texto" }`.
- [x] **Prompt de zsh** con la paleta, git en un solo proceso; `fzf`, `zoxide`, `eza` con colores.
- [x] **fastfetch** con logo de gema (alias `ff`).
- [x] **Equipos con batería**: `power-profiles-daemon` + píldora que solo aparece con batería.
- [x] Paquetes instalados. Verificado en vivo: grabación (H.264 por VA-API + audio), luz
      nocturna, fzf/zoxide/eza, fastfetch con la gema en imagen (kitty).
- [x] Corregido: Editar captura (satty flotante al 90 %) y detener la grabación con clic en
      la barra (ruta completa de `grabar`).
- [x] Selector de color probado (tenía una opción inválida de hyprpicker).
- [x] Prompt: gema del tema (U+F0B8A), doble flecha  (U+F101) lila/roja en la línea
      de escritura, ruta en cian.
- [x] Carpetas de usuario: solo las de xdg-user-dirs (Imágenes, Vídeos, Descargas...);
      los scripts usan `xdg-user-dir` y el instalador las crea antes de copiar fondos.

## 4. Instalador

- [x] Tema universal: sin elegir máquina. `lib/hardware.sh` detecta touchpad, batería,
      GPU y correcciones (`sistema/hardware/*/detectar`, p. ej. audio ASUS VT1708S).
- [x] Touchpad y gestos en `input.lua` para todos (sin `hardware.lua`).
- [x] Etapas sin preguntas (`--noconfirm`); etapa 01 instala yay si falta.
- [x] Interfaz con gum: gema en pixel art, resumen del hardware, confirmación,
      etapas en vivo con registro, Reintentar / Omitir / Salir si algo falla,
      reinicio al final. Registro en `~/.local/state/amatista/`.
- [x] Modo `./install.sh --demo` (etapas simuladas, no instala nada).
- [x] Demo vista y aprobada.
- [x] Instalación real probada en máquina virtual (Arch limpio, UEFI): las 6 etapas OK;
      GRUB, Plymouth, inicio de sesión, escritorio, lanzador, atajos, terminal y
      detección de hardware verificados. Correcciones salidas de la prueba:
      reintentos de descarga, `splash` en GRUB, código de salida del instalador,
      Colloid solo en su variante oscura, modo `--automatico`.
- [x] Pantallas pequeñas: barra compacta por debajo de 1366 px (reproductor, fecha e IP
      pasan al tooltip), menús nunca más anchos que la pantalla, panel de atajos con
      3, 2 o 1 columna según el espacio.
- [ ] Subir a GitHub cuando esté listo (pospuesto por decisión del usuario).

## Pendientes de verificación

- [x] Auriculares del panel frontal del chasis (i5) tras reiniciar
      (firmware `hda-jack-retask.fw`).
- [x] Cambio automático de audio al conectar y desconectar los auriculares traseros (probado).

## Añadidos

- [x] **Clima**: clic en la fecha y hora (módulo `clima` de Quickshell, Open-Meteo, ubicación
      por IP o ciudad elegida). Solo consulta con el panel abierto. Panel horizontal: lluvia y
      humedad, lluvia en 24 horas y próximos días.
- [x] **Lanzador por secciones**: Aplicaciones (por categoría), Fondos y Sesión en una lista
      con iconos. El menú de apagado se integró aquí (`MenuApagado.qml`, su IPC y el botón de la
      barra eliminados).
- [x] **Panel de red por pestañas**: Ethernet, Wi-Fi y VPN (Tailscale y similares); solo las
      que el equipo tiene. Datos copiables, tráfico en vivo y equipos de Tailscale. Los
      paneles que no caben en la pantalla se desplazan.
- [x] **Panel de luz nocturna**: encender / apagar y horario automático (clic en la píldora;
      clic derecho alterna directo).

### Barra completa

- [x] 1. Bandeja del sistema (menús con el tema y submenús; solo si hay apps)
- [x] 2. Centro de notificaciones (campana, historial, no molestar)
- [x] 3. Indicador de modo café
- [x] 4. Privacidad: micrófono y captura de pantalla
- [x] 5. Panel de hardware con temperaturas; la píldora muestra la CPU (sin alertas, por decisión del usuario)
- ~~6. Clima visible en la barra y calendario mensual~~ (descartado por decisión del usuario)
- [x] 7. Indicador de actualizaciones de Arch y AUR (script `actualizaciones`, necesita `pacman-contrib`)
- [x] 8. Aviso de respaldos: píldora solo si hay un problema o uno en marcha, panel con historial
- ~~9. Título de la ventana activa~~ (descartado por decisión del usuario)
- [x] 10. Red: indicador de VPN activa y velocidad en vivo en la píldora (la IP va en el tooltip)
- ~~11. Bluetooth: batería de los dispositivos~~ (descartado por decisión del usuario)
- ~~12. Workspaces: vista previa de ventanas~~ (descartado por decisión del usuario)

### Mantenimiento del equipo i5 (no forma parte del tema)

- [x] **SATA en modo AHCI** (23 nov 2026): controlador `ahci`, NCQ 32, SSD a 6 Gb/s y disco de
      respaldos a 3 Gb/s (puerto SATA 2). Comprobado tras reiniciar.
- [x] **`/etc/fstab` corregido** (23 nov 2026): sin duplicados, `/home` en `@home` y `/var/log`
      en `@var_log`, comprobado tras reiniciar. Copia anterior: `/etc/fstab.respaldo`. Se perdió
      el `pacman.log` de la instalación inicial (28 KB) al copiar los registros.
  - [x] Retirados los registros viejos que quedaron en `/home`.
