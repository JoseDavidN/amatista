// ==========================================================
// Luz nocturna con hyprsunset (estado compartido por todas las barras)
//
// Encendida: temperatura de color cálida · Apagada: identidad (sin filtro).
// El estado se recuerda en ~/.local/state/amatista/luznocturna ("1" / "0")
// y se vuelve a aplicar al iniciar la sesión.
// Si hyprsunset no está corriendo, se arranca al usarlo (hyprsunset -i).
//
//   qs -c escritorio ipc call luznocturna alternar
// ==========================================================
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: servicio

    readonly property int temperatura: 4000
    readonly property string archivo: Quickshell.env("HOME") + "/.local/state/amatista/luznocturna"

    property bool encendida: false
    property bool instalado: true
    property bool comprobado: false

    function alternar() {
        aplicar(!encendida);
    }

    // Se comprueba en cada uso (y no solo al iniciar) si hyprsunset existe:
    // así funciona aunque se instale con el escritorio ya abierto.
    function aplicar(valor) {
        encendida = valor;
        orden.command = ["sh", "-c", orden.script, "sh",
                         valor ? "temperature " + temperatura : "identity",
                         valor ? "1" : "0", archivo];
        orden.running = true;
    }

    // $1: orden IPC · $2: estado a guardar · $3: archivo de estado
    Process {
        id: orden
        readonly property string script:
            "if ! command -v hyprsunset >/dev/null; then " +
            "  notify-send -a 'Luz nocturna' 'Luz nocturna' 'hyprsunset no está instalado'; exit 1; " +
            "fi; " +
            "mkdir -p \"$(dirname \"$3\")\" && echo \"$2\" > \"$3\"; " +
            "s=\"$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.hyprsunset.sock\"; " +
            "if ! pgrep -x hyprsunset >/dev/null; then " +
            "  setsid -f hyprsunset -i >/dev/null 2>&1; " +
            "  i=0; while [ ! -S \"$s\" ] && [ $i -lt 20 ]; do sleep 0.1; i=$((i+1)); done; " +
            "fi; " +
            "hyprctl hyprsunset $1 >/dev/null"
        // Si falló, el icono vuelve a mostrar el estado anterior
        onExited: codigo => { if (codigo !== 0) servicio.encendida = !servicio.encendida; }
    }

    // Al iniciar: saber si hyprsunset existe y recuperar el último estado
    Process {
        running: true
        command: ["sh", "-c", "command -v hyprsunset >/dev/null"]
        onExited: codigo => {
            servicio.instalado = codigo === 0;
            servicio.comprobado = true;
        }
    }

    FileView {
        id: archivoEstado
        // Solo se lee tras comprobar que hyprsunset existe
        path: servicio.comprobado && servicio.instalado ? servicio.archivo : ""
        printErrors: false
        onLoaded: if (text().trim() === "1") servicio.aplicar(true)
    }

    IpcHandler {
        target: "luznocturna"
        function alternar(): void { servicio.alternar(); }
        function encender(): void { servicio.aplicar(true); }
        function apagar(): void { servicio.aplicar(false); }
        function estado(): string { return servicio.encendida ? "encendida" : "apagada"; }
    }
}
