// ==========================================================
// Red (estado de NetworkManager con nmcli cada 5 s)
// Icono de la conexión y velocidad de bajada y subida en vivo
// Con una VPN activa (Tailscale, WireGuard...) se agrega un escudo
// La IP, la señal y las VPN van en el tooltip
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
    // En pantallas angostas solo los iconos; la velocidad va en el tooltip
    property bool compacta: false
    property string ip: ""
    property string interfaz: ""
    property var vpns: []             // nombres de las VPN activas
    property real bajada: 0           // bytes por segundo
    property real subida: 0
    property var previa: null

    function nombreVpn(n) {
        return /^tailscale/.test(n) ? "Tailscale" : /^zt/.test(n) ? "ZeroTier" : /^wt\d/.test(n) ? "NetBird"
             : n === "CloudflareWARP" ? "Cloudflare WARP" : n === "nordlynx" ? "NordVPN" : /^proton/.test(n) ? "Proton VPN"
             : /^wg/.test(n) ? "WireGuard" : n;
    }

    // Ancho fijo (4 caracteres), para que la píldora no baile: "  0K" " 85K" "1.2M" " 12M"
    function corta(b) {
        const k = b / 1000, m = k / 1000, g = m / 1000;
        const t = k < 999.5 ? Math.round(k) + "K" : m < 9.95 ? m.toFixed(1) + "M" : m < 999.5 ? Math.round(m) + "M" : g.toFixed(1) + "G";
        return t.padStart(4, " ");
    }

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
        let t = "ninguna", activa = "";
        const tuneles = [];
        for (const linea of (partes[0] || "").trim().split("\n")) {
            const c = campos(linea);
            if (c.length < 3 || !c[2].startsWith("connected")) continue;
            if (c[1] === "wifi") { t = "wifi"; activa = c[0]; }
            else if (c[1] === "ethernet" && t === "ninguna") { t = "cable"; activa = c[0]; }
            else if (c[1] === "wireguard") tuneles.push(c[0]);
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
            if (c.length < 4 || c[2] !== "inet") continue;
            if (c[1] === activa) direccion = c[3].split("/")[0];
            // Una VPN con dirección está activa
            if (/^(tailscale|tun|tap|wg|ppp|zt|wt\d|nordlynx|proton|CloudflareWARP)/.test(c[1]) && tuneles.indexOf(c[1]) < 0)
                tuneles.push(c[1]);
        }

        tipo = t;
        senal = s;
        ip = direccion;
        if (interfaz !== activa) {
            interfaz = activa;
            previa = null;
            bajada = subida = 0;
        }
        const nombres = tuneles.map(nombreVpn);
        if (nombres.join() !== vpns.join()) vpns = nombres;
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

    // Velocidad: contadores de la interfaz cada 2 s
    FileView {
        id: contadores
        path: "/proc/net/dev"
        printErrors: false
        onLoaded: {
            const l = text().split("\n").find(x => x.trim().startsWith(mod.interfaz + ":"));
            if (mod.interfaz === "" || !l) { mod.previa = null; mod.bajada = mod.subida = 0; return; }
            const c = l.slice(l.indexOf(":") + 1).trim().split(/\s+/).map(Number);
            const ahora = Date.now(), a = mod.previa;
            if (a) {
                const s = Math.max(0.2, (ahora - a.hora) / 1000);
                mod.bajada = Math.max(0, (c[0] - a.rx) / s);
                mod.subida = Math.max(0, (c[8] - a.tx) / s);
            }
            mod.previa = { hora: ahora, rx: c[0], tx: c[8] };
        }
    }

    Timer {
        interval: 2000
        running: mod.interfaz !== ""
        repeat: true
        triggeredOnStart: true
        onTriggered: contadores.reload()
    }

    icono: tipo === "wifi" ? "󰖩" : tipo === "cable" ? "󰈀" : ""
    colorIcono: tipo === "ninguna" ? Tema.error : Tema.ambar
    readonly property string velocidad: corta(bajada) + "↓" + corta(subida) + "↑"
    texto: tipo === "ninguna" ? (compacta ? "" : "sin red") : compacta ? "" : velocidad
    icono2: vpns.length > 0 ? String.fromCodePoint(0xf0565) : ""
    colorIcono2: Tema.verde
    tooltip: tipo === "ninguna" ? "Sin red"
           : [(tipo === "wifi" ? "Wi-Fi" + (senal > 0 ? " " + senal + "%" : "") : "Cable") + (ip !== "" ? " · " + ip : ""),
              compacta ? velocidad.replace(/ +/g, " ") : "",
              vpns.length > 0 ? "VPN activa: " + vpns.join(", ") : ""].filter(t => t).join("\n")

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
