// ==========================================================
// Luz nocturna con hyprsunset (estado compartido por todas las barras)
//
// Encendida: temperatura de color cálida · Apagada: identidad (sin filtro).
// El estado se recuerda en ~/.local/state/amatista/luznocturna ("1" / "0")
// y se vuelve a aplicar al iniciar la sesión.
// Horario opcional (luznocturna-horario.json en la misma carpeta): se enciende
// y se apaga en cada hora programada. Cambiarla a mano vale hasta la siguiente
// hora programada, aunque se reinicie el escritorio.
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

    // Horario, en minutos desde medianoche
    property bool horarioActivo: false
    property int inicio: 19 * 60
    property int fin: 6 * 60
    // Última hora programada que ya se aplicó (milisegundos)
    property real aplicada: 0
    readonly property bool horarioValido: inicio !== fin
    readonly property string archivoHorario: Quickshell.env("HOME") + "/.local/state/amatista/luznocturna-horario.json"

    function hora(m) {
        return String(Math.floor(m / 60)).padStart(2, "0") + ":" + String(m % 60).padStart(2, "0");
    }

    function ahora() { return new Date(); }

    // La hora programada más reciente: { cuando, encender }
    function ultimoCambio() {
        const n = ahora();
        const momento = min => {
            const d = new Date(n.getFullYear(), n.getMonth(), n.getDate(), Math.floor(min / 60), min % 60);
            return d <= n ? d : new Date(n.getFullYear(), n.getMonth(), n.getDate() - 1, Math.floor(min / 60), min % 60);
        };
        const i = momento(inicio).getTime(), f = momento(fin).getTime();
        return { cuando: Math.max(i, f), encender: i > f };
    }

    // Aplica el horario si se pasó por una hora programada. true si lo aplicó
    function revisarHorario() {
        if (!horarioActivo || !horarioValido) return false;
        const c = ultimoCambio();
        if (c.cuando === aplicada) return false;
        aplicada = c.cuando;
        guardarHorario();
        aplicar(c.encender);
        return true;
    }

    function cambiarHorario(activo, desde, hasta) {
        horarioActivo = activo;
        inicio = desde;
        fin = hasta;
        if (!activo || !horarioValido) {
            guardarHorario();
            return;
        }
        // Un horario nuevo se aplica enseguida
        const c = ultimoCambio();
        aplicada = c.cuando;
        guardarHorario();
        if (encendida !== c.encender) aplicar(c.encender);
    }

    function guardarHorario() {
        fileHorario.setText(JSON.stringify({ activo: horarioActivo, inicio: inicio, fin: fin, aplicada: aplicada }) + "\n");
    }

    Process {
        running: true
        command: ["mkdir", "-p", Quickshell.env("HOME") + "/.local/state/amatista"]
    }

    FileView {
        id: fileHorario
        path: servicio.archivoHorario
        blockLoading: true
        printErrors: false
    }

    function leerHorario() {
        const minuto = v => Number.isInteger(v) && v >= 0 && v < 1440;
        try {
            const h = JSON.parse(fileHorario.text());
            if (!minuto(h.inicio) || !minuto(h.fin)) return;
            inicio = h.inicio;
            fin = h.fin;
            aplicada = Number(h.aplicada) || 0;
            horarioActivo = h.activo === true;
        } catch (e) {}
    }

    Timer {
        interval: 20000
        repeat: true
        running: servicio.horarioActivo && servicio.comprobado
        onTriggered: servicio.revisarHorario()
    }

    function alternar() {
        aplicar(!encendida);
    }

    // Se comprueba en cada uso (y no solo al iniciar) si hyprsunset existe:
    // así funciona aunque se instale con el escritorio ya abierto.
    function aplicar(valor) {
        encendida = valor;
        // Si hay un cambio en curso, se aplica el último al terminar
        if (orden.running) {
            orden.pendiente = true;
            return;
        }
        orden.command = ["sh", "-c", orden.script, "sh",
                         valor ? "temperature " + temperatura : "identity",
                         valor ? "1" : "0", archivo];
        orden.running = true;
    }

    // $1: orden IPC · $2: estado a guardar · $3: archivo de estado
    Process {
        id: orden
        property bool pendiente: false
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
        onExited: codigo => {
            if (pendiente) {
                pendiente = false;
                Qt.callLater(() => servicio.aplicar(servicio.encendida));
            } else if (codigo !== 0) {
                servicio.encendida = !servicio.encendida;
            }
        }
    }

    // Al iniciar: saber si hyprsunset existe y recuperar el último estado
    Process {
        running: true
        command: ["sh", "-c", "command -v hyprsunset >/dev/null"]
        onExited: codigo => {
            servicio.instalado = codigo === 0;
            servicio.leerHorario();
            // Si pasó una hora programada, manda el horario y no el estado guardado
            if (servicio.instalado) archivoEstado.restaurar = !servicio.revisarHorario();
            servicio.comprobado = true;
        }
    }

    FileView {
        id: archivoEstado
        property bool restaurar: true
        // Solo se lee tras comprobar que hyprsunset existe
        path: servicio.comprobado && servicio.instalado && restaurar ? servicio.archivo : ""
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
