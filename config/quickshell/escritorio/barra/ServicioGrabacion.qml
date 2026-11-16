// ==========================================================
// Estado de la grabación de pantalla (script ~/.local/bin/grabar)
//
// El script escribe "<pid> <inicio epoch> <archivo>" en
// $XDG_RUNTIME_DIR/grabacion mientras graba y lo vacía al terminar.
// Aquí solo se vigila ese archivo (sin sondear procesos).
//
//   qs -c escritorio ipc call grabacion alternar
// ==========================================================
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: servicio

    readonly property string archivo: Quickshell.env("XDG_RUNTIME_DIR") + "/grabacion"
    // Ruta completa: Quickshell no tiene ~/.local/bin en su PATH
    readonly property string grabar: Quickshell.env("HOME") + "/.local/bin/grabar"

    property bool grabando: false
    property real inicio: 0          // epoch en segundos
    property string destino: ""
    property bool listo: false

    function alternar() {
        Quickshell.execDetached([servicio.grabar, "alternar"]);
    }

    function detener() {
        Quickshell.execDetached([servicio.grabar, "detener"]);
    }

    function leer(contenido) {
        const partes = contenido.trim().split(" ");
        grabando = partes.length >= 2 && partes[0] !== "";
        inicio = grabando ? Number(partes[1]) : 0;
        destino = grabando ? partes.slice(2).join(" ") : "";
    }

    // El archivo debe existir para poder vigilarlo; además se limpia
    // un estado huérfano de una sesión anterior.
    Process {
        running: true
        command: ["sh", "-c",
            "touch \"$1\"; [ -x \"$2\" ] && \"$2\" estado >/dev/null; true",
            "sh", servicio.archivo, servicio.grabar]
        onExited: servicio.listo = true
    }

    FileView {
        id: vista
        path: servicio.listo ? servicio.archivo : ""
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: servicio.leer(text())
        onLoadFailed: servicio.leer("")
    }

    IpcHandler {
        target: "grabacion"
        function alternar(): void { servicio.alternar(); }
        function detener(): void { servicio.detener(); }
        function pantalla(): void { Quickshell.execDetached([servicio.grabar, "iniciar", "pantalla"]); }
        function area(): void { Quickshell.execDetached([servicio.grabar, "iniciar", "area"]); }
        function estado(): string { return servicio.grabando ? "grabando" : "detenido"; }
    }
}
