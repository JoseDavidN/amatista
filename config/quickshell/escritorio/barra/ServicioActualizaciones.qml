// ==========================================================
// Actualizaciones pendientes de Arch y AUR (script "actualizaciones")
// Comprueba un minuto después de iniciar y luego cada hora.
//
//   qs -c escritorio ipc call actualizaciones comprobar
// ==========================================================
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: servicio

    readonly property string script: Quickshell.env("HOME") + "/.local/bin/actualizaciones"

    property var arch: []          // [{ nombre, actual, nueva }]
    property var aur: []
    readonly property int total: arch.length + aur.length
    property bool comprobando: false
    property bool falta: false     // pacman-contrib no está instalado
    property bool errorArch: false
    property bool errorAur: false
    property var hora: null        // Date de la última comprobación
    property bool repetir: false

    function comprobar() {
        if (consulta.running) {
            repetir = true;
            return;
        }
        comprobando = true;
        consulta.running = true;
    }

    function procesar(texto) {
        const r = [], a = [];
        let f = false, ea = false, eu = false;
        for (const l of texto.split("\n")) {
            const c = l.split("|");
            if (c[0] === "FALTA") f = true;
            else if (c[0] === "ERROR") { if (c[1] === "arch") ea = true; else eu = true; }
            else if ((c[0] === "R" || c[0] === "A") && c.length >= 4)
                (c[0] === "R" ? r : a).push({ nombre: c[1], actual: c[2], nueva: c[3] });
        }
        falta = f;
        errorArch = ea;
        errorAur = eu;
        // Si una consulta falló se conserva lo último que se supo
        if (!ea) arch = r;
        if (!eu) aur = a;
        hora = new Date();
    }

    function instalar() {
        // Suelta del escritorio: recargar Quickshell no debe cortar a pacman
        Quickshell.execDetached(["kitty", "--title", "Actualizar el sistema", "-e", script, "instalar"]);
    }

    Process {
        id: consulta
        command: [servicio.script, "listar"]
        stdout: StdioCollector { id: salida }
        onExited: codigo => {
            servicio.comprobando = false;
            if (codigo === 0) servicio.procesar(salida.text);
            if (servicio.repetir) {
                servicio.repetir = false;
                Qt.callLater(servicio.comprobar);
            }
        }
    }

    Timer {
        interval: 60000
        running: true
        onTriggered: servicio.comprobar()
    }
    Timer {
        interval: 3600000
        running: true
        repeat: true
        onTriggered: servicio.comprobar()
    }

    IpcHandler {
        target: "actualizaciones"
        function comprobar(): void { servicio.comprobar(); }
        function estado(): string {
            return "arch " + servicio.arch.length + ", aur " + servicio.aur.length + (servicio.falta ? ", falta pacman-contrib" : "")
                 + (servicio.errorArch ? ", error arch" : "") + (servicio.errorAur ? ", error aur" : "") + (servicio.comprobando ? ", comprobando" : "");
        }
    }
}
