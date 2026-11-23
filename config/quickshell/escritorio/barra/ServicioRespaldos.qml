// ==========================================================
// Vigila los respaldos automáticos (script estado-respaldo, cada 10 minutos)
// Avisa si el último falló o se interrumpió, si llevan más de dos días sin
// hacerse, si el disco no está montado o casi lleno, o si el temporizador
// está apagado. En equipos sin respaldo.timer no hace nada.
//
//   qs -c escritorio ipc call respaldos alternar   (abrir el panel)
// ==========================================================
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: servicio

    readonly property string script: Quickshell.env("HOME") + "/.local/bin/estado-respaldo"
    readonly property real maximoAtraso: 48 * 3600 * 1000

    property bool hay: false            // el equipo tiene respaldos configurados
    property bool leido: false
    property bool corriendo: false
    property bool habilitado: true
    property real proximo: 0            // ms, 0 si no se sabe
    property real ultimoBueno: 0
    property var discos: []             // [{ ruta, montado, usado, total }]
    property var historial: []          // [{ hora, ok, interrumpido, detalle, guardado }], lo nuevo primero
    property var problemas: []
    readonly property bool mal: problemas.length > 0

    property int revisionesAtrasado: 0
    property string avisado: ""

    signal pedirPanel()

    function comprobar() {
        if (!consulta.running) consulta.running = true;
    }

    function ahora() { return Date.now(); }

    function procesar(texto, esRevision) {
        const ds = [], hs = [];
        let t = null, s = ["", ""], actual = null;
        for (const l of texto.split("\n")) {
            const c = l.split("|");
            if (c[0] === "TEMPORIZADOR") t = c.slice(1);
            else if (c[0] === "SERVICIO") s = c.slice(1);
            else if (c[0] === "DISCO") ds.push({ ruta: c[1], montado: c[2] === "1", usado: Number(c[3]) || 0, total: Number(c[4]) || 0 });
            else if (c[0] === "R") {
                const hora = Number(c[1]) * 1000, m = c.slice(2).join("|");
                if (m.startsWith("Starting ")) {
                    actual = { hora: hora, ok: false, interrumpido: true, detalle: "", guardado: "", error: "" };
                    hs.unshift(actual);
                } else if (!actual) continue;
                else if (m.startsWith("Finished ")) { actual.ok = true; actual.interrumpido = false; actual = null; }
                else if (m.startsWith("Failed to start ")) { actual.interrumpido = false; actual = null; }
                else if (m.startsWith("processed ")) actual.detalle = m.replace(/^processed (\d+) files, (.*) in (.*)$/, "$1 archivos, $2, en $3");
                else if (m.startsWith("Added to the repository")) actual.guardado = m.replace(/^.*?: ([^(]+?) *(\(.*)?$/, "$1");
                else if (/^(Fatal|error|unable)/i.test(m) && actual.error === "") actual.error = m;
            }
        }
        hay = t !== null && t[0] === "loaded";
        leido = true;
        if (!hay) {
            problemas = [];
            return;
        }

        corriendo = s[0] === "activating" || s[0] === "active";
        if (corriendo && hs.length && hs[0].interrumpido) hs.shift();   // el que está en marcha
        habilitado = t[1] === "active" && t[2] === "enabled";
        proximo = (Number(t[4]) || 0) * 1000;
        discos = ds;
        historial = hs.slice(0, 10);
        const bueno = hs.find(h => h.ok);
        ultimoBueno = bueno ? bueno.hora : 0;

        const p = [];
        for (const d of ds) {
            if (!d.montado) p.push("El disco " + d.ruta + " no está montado");
            else if (d.total > 0 && d.usado / d.total > 0.95) p.push("El disco " + d.ruta + " está casi lleno");
        }
        if (!habilitado) p.push("El temporizador de respaldos está apagado");
        if (!corriendo && (s[1] !== "success" || (hs.length && !hs[0].ok)))
            p.push(hs.length && hs[0].interrumpido && s[1] === "success" ? "El último respaldo se interrumpió"
                 : "El último respaldo falló" + (hs.length && hs[0].error ? ": " + hs[0].error : ""));

        // Atraso: se confirma en la revisión siguiente, para dar tiempo al
        // temporizador cuando el equipo acaba de despertar o encenderse
        const referencia = ultimoBueno || (Number(t[3]) || 0) * 1000;
        const porCorrer = proximo > 0 && proximo - ahora() < 20 * 60000;
        const atrasado = !corriendo && !porCorrer && referencia > 0 && ahora() - referencia > maximoAtraso;
        if (!atrasado) revisionesAtrasado = 0;
        else if (esRevision) revisionesAtrasado++;
        if (revisionesAtrasado >= 2)
            p.push("Hace " + Math.floor((ahora() - referencia) / 86400000) + " días que no se hace un respaldo");

        if (JSON.stringify(p) !== JSON.stringify(problemas)) problemas = p;
        const clave = p.join("\n");
        if (clave !== "" && clave !== avisado)
            Quickshell.execDetached(["notify-send", "-a", "Respaldos", "-u", "critical", "Problema con los respaldos", clave]);
        avisado = clave;
    }

    // Arranca el servicio; pide la contraseña con el agente de polkit
    function respaldar() {
        if (corriendo || inicio.running) return;
        inicio.running = true;
        seguir.restart();
    }

    Process {
        id: inicio
        command: ["systemctl", "start", "--no-block", "respaldo.service"]
        onExited: servicio.comprobar()
    }

    Process {
        id: consulta
        property bool revision: false
        command: [servicio.script]
        stdout: StdioCollector {
            onStreamFinished: {
                servicio.procesar(this.text, consulta.revision);
                consulta.revision = false;
            }
        }
    }

    Timer {
        interval: 90000
        running: true
        onTriggered: { consulta.revision = true; servicio.comprobar(); }
    }
    // Sin respaldos configurados basta con la primera vez
    Timer {
        interval: 600000
        running: !servicio.leido || servicio.hay
        repeat: true
        onTriggered: { consulta.revision = true; servicio.comprobar(); }
    }
    // Mientras corre, seguirlo de cerca
    Timer {
        id: seguir
        interval: 4000
        running: servicio.corriendo
        repeat: servicio.corriendo
        onTriggered: servicio.comprobar()
    }

    IpcHandler {
        target: "respaldos"
        function alternar(): void { servicio.pedirPanel(); }
        function comprobar(): void { servicio.comprobar(); }
        function estado(): string {
            return !servicio.hay ? "sin respaldos configurados" : servicio.mal ? servicio.problemas.join("; ")
                 : servicio.corriendo ? "en marcha" : "al día (" + Qt.formatDateTime(new Date(servicio.ultimoBueno), "dd/MM HH:mm") + ")";
        }
    }
}
