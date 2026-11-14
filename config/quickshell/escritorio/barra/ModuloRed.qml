// ==========================================================
// Red (estado de NetworkManager con nmcli cada 5 s)
//   Wi-Fi:  󰖩  78%   ·   Cable:  󰈀  192.168.1.5   ·   Sin red:    sin red
// Clic: panel de red · Derecho: editor de conexiones
// ==========================================================
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Comun
import qs.paneles

Pildora {
    id: mod

    property string tipo: "ninguna"   // "wifi", "cable" o "ninguna"
    property int senal: 0
    property string ip: ""

    // nmcli separa con ":" y escapa los ":" de los valores como "\\:"
    function campos(linea) {
        const r = [];
        let actual = "";
        for (let i = 0; i < linea.length; i++) {
            const ch = linea[i];
            if (ch === "\\" && i + 1 < linea.length) { actual += linea[i + 1]; i++; }
            else if (ch === ":") { r.push(actual); actual = ""; }
            else actual += ch;
        }
        r.push(actual);
        return r;
    }

    function procesar(salida) {
        const partes = salida.split("---");

        // 1) Dispositivos: DEVICE:TYPE:STATE
        let t = "ninguna", interfaz = "";
        for (const linea of (partes[0] || "").trim().split("\n")) {
            const c = campos(linea);
            if (c.length < 3 || c[2] !== "connected") continue;
            if (c[1] === "wifi") { t = "wifi"; interfaz = c[0]; }
            else if (c[1] === "ethernet" && t === "ninguna") { t = "cable"; interfaz = c[0]; }
        }

        // 2) Senal de la red Wi-Fi en uso: IN-USE:SIGNAL
        let s = 0;
        for (const linea of (partes[1] || "").trim().split("\n")) {
            const c = campos(linea);
            if (c.length >= 2 && c[0] === "*") s = parseInt(c[1]) || 0;
        }

        // 3) IP de la interfaz activa (salida de "ip -4 -o addr show")
        let direccion = "";
        for (const linea of (partes[2] || "").trim().split("\n")) {
            const c = linea.trim().split(/\s+/);
            if (c.length >= 4 && c[1] === interfaz && c[2] === "inet") direccion = c[3].split("/")[0];
        }

        tipo = t;
        senal = s;
        ip = direccion;
    }

    function refrescar() {
        if (!consulta.running) consulta.running = true;
    }

    Process {
        id: consulta
        command: ["sh", "-c", "nmcli -t -f DEVICE,TYPE,STATE device; echo ---; nmcli -t -f IN-USE,SIGNAL device wifi list --rescan no; echo ---; ip -4 -o addr show"]
        environment: ({ LC_ALL: "C" })
        stdout: StdioCollector {
            onStreamFinished: mod.procesar(this.text)
        }
    }

    Timer {
        interval: 5000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: mod.refrescar()
    }

    icono: tipo === "wifi" ? "󰖩" : tipo === "cable" ? "󰈀" : ""
    colorIcono: tipo === "ninguna" ? Tema.error : Tema.ambar
    texto: tipo === "wifi" ? senal + "%" : tipo === "cable" ? (ip || "cable") : "sin red"

    PanelRed {
        id: panel
        objetivo: mod
        // Al cerrar el panel, actualizar la pildora
        onAbiertoChanged: if (!abierto) mod.refrescar()
    }

    activa: panel.abierto
    onClicIzquierdo: panel.alternar()
    onClicDerecho: Quickshell.execDetached(["nm-connection-editor"])
}
