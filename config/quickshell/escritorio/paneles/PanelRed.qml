// ==========================================================
// Panel de red: una pestaña por tipo de conexión del equipo
//   Ethernet  estado, IP, máscara, velocidad, DNS, tráfico...
//   Wi-Fi     lo mismo, y encender / apagar, buscar y conectar redes
//             (si la red pide contraseña se abre un diálogo central)
//   VPN       Tailscale (con sus equipos) y otras: WireGuard, OpenVPN,
//             ZeroTier, NetBird... Con solo Tailscale la pestaña lleva su nombre
// Solo aparecen las pestañas de lo que el equipo tiene.
// ==========================================================
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Comun

PanelEmergente {
    id: panel

    ancho: Math.min(460, (screen ? screen.width : 1920) - 24)
    titulo: "Red"
    icono: String.fromCodePoint(0xf06f3)
    colorIcono: Tema.ambar

    property bool wifiActivo: true
    property string interfazWifi: ""
    property string conectadaA: ""
    property bool buscando: false

    // Conexiones del equipo
    property var cables: []         // interfaces Ethernet
    property var wifi: null         // interfaz Wi-Fi o null
    property var vpns: []           // túneles activos (sin Tailscale)
    property var perfilesVpn: []    // VPN guardadas en NetworkManager
    property bool hayTailscale: false
    property var tailscale: null    // estado de Tailscale o null si no responde
    property var equipos: []        // equipos de la red de Tailscale
    property bool tailscaleOcupado: false
    property string errorVpn: ""
    property var trafico: ({})      // por interfaz: { bajada, subida, rx, tx }

    property bool listo: false
    property bool elegida: false    // la pestaña se eligió a mano
    property string pestana: ""
    property string principal: ""   // pestaña de la salida a internet

    readonly property var pestanas: {
        const l = [];
        if (cables.length) l.push({ id: "cable", icono: String.fromCodePoint(0xf0200), texto: "Ethernet" });
        if (wifi) l.push({ id: "wifi", icono: "󰖩", texto: "Wi-Fi" });
        if (hayTailscale || vpns.length || perfilesVpn.length)
            l.push({ id: "vpn", icono: String.fromCodePoint(0xf0582),
                     texto: hayTailscale && !vpns.length && !perfilesVpn.length ? "Tailscale" : "VPN" });
        return l;
    }
    property var redes: []

    property string conectando: ""
    property var redEnCurso: null
    property bool eraNueva: false
    property string error: ""

    readonly property var iconosWifi: ["󰤯", "󰤟", "󰤢", "󰤥", "󰤨"]

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

    function lineas(texto) {
        return (texto || "").trim().split("\n").filter(l => l !== "");
    }

    function json(texto) {
        try { return JSON.parse(texto); } catch (e) { return null; }
    }

    // Asigna solo si cambió, para no rehacer listas a cada consulta
    function poner(propiedad, valor) {
        if (JSON.stringify(panel[propiedad]) !== JSON.stringify(valor)) panel[propiedad] = valor;
    }

    // 24 -> 255.255.255.0
    function mascara(prefijo) {
        const o = [];
        for (let i = 0; i < 4; i++) {
            const bits = Math.max(0, Math.min(8, prefijo - i * 8));
            o.push(256 - Math.pow(2, 8 - bits));
        }
        return o.join(".");
    }

    function procesar(salida) {
        const partes = salida.split("@@@\n");

        wifiActivo = (partes[0] || "").trim() === "enabled";

        // Datos del sistema: NOMBRE|fisica|velocidad|duplex
        const fisico = {};
        for (const l of lineas(partes[5])) {
            const c = l.split("|");
            fisico[c[0]] = { fisica: c[1] === "1", velocidad: parseInt(c[2]) || 0, duplex: c[3] || "" };
        }

        // Puerta de enlace y DNS de cada dispositivo (bloques de nmcli)
        const nm = {};
        let bloque = null;
        for (const l of lineas(partes[6])) {
            const c = campos(l), clave = c[0], valor = c.slice(1).join(":");
            if (clave === "GENERAL.DEVICE") bloque = nm[valor] = { dns: [], puerta: "", controlador: "", dominio: "" };
            else if (!bloque || valor === "") continue;
            else if (clave === "GENERAL.DRIVER") bloque.controlador = valor;
            else if (clave === "IP4.GATEWAY") bloque.puerta = valor;
            else if (clave.startsWith("IP4.DNS")) bloque.dns.push(valor);
            else if (clave.startsWith("IP4.DOMAIN")) bloque.dominio = valor;
        }

        // Direcciones: ip -j -d addr
        const direcciones = {};
        for (const d of json(partes[4]) || []) {
            const v4 = (d.addr_info || []).find(a => a.family === "inet");
            const v6s = (d.addr_info || []).filter(a => a.family === "inet6");
            const v6 = v6s.find(a => a.scope === "global") || v6s[0];
            direcciones[d.ifname] = {
                ip: v4 ? v4.local : "", prefijo: v4 ? v4.prefixlen : 0,
                asignacion: v4 ? (v4.dynamic ? "DHCP" : "Manual") : "",
                difusion: v4 && v4.broadcast ? v4.broadcast : "",
                v6: v6 ? v6.local : "", mac: d.address || "", mtu: d.mtu || 0,
                subida: (d.flags || []).indexOf("UP") >= 0,
                tipo: d.linkinfo ? d.linkinfo.info_kind : ""
            };
        }

        // Dispositivos: DEVICE:TYPE:STATE:CONNECTION
        const cablesN = [], vpnsN = [];
        let wifiN = null;
        const reunir = (nombre, estado, conexion) => Object.assign(
            { nombre: nombre, conectada: estado.startsWith("connected"), estado: estado, conexion: conexion },
            direcciones[nombre] || {}, nm[nombre] || { dns: [], puerta: "" }, fisico[nombre] || {});
        const vistos = {};
        for (const l of lineas(partes[1])) {
            const c = campos(l);
            if (c.length < 4) continue;
            vistos[c[0]] = c;
            if (c[1] === "wifi" && !wifiN) wifiN = reunir(c[0], c[2], c[3]);
            if (c[1] === "ethernet" && fisico[c[0]] && fisico[c[0]].fisica) cablesN.push(reunir(c[0], c[2], c[3]));
        }
        // Túneles: por su tipo o por el nombre que les da cada programa
        for (const n in direcciones) {
            if (n === "lo" || n.startsWith("tailscale") || /^(vnet|virbr|docker|veth|br-)/.test(n)) continue;
            const d = direcciones[n];
            if (d.tipo !== "wireguard" && !/^(tun|tap|wg|ppp|zt|wt\d|nordlynx|proton|CloudflareWARP)/.test(n)) continue;
            const v = reunir(n, d.subida ? "connected" : "disconnected", vistos[n] ? vistos[n][3] : "");
            v.clase = /^zt/.test(n) ? "ZeroTier" : /^wt\d/.test(n) ? "NetBird" : n === "CloudflareWARP" ? "Cloudflare WARP"
                    : n === "nordlynx" ? "NordVPN" : /^proton/.test(n) ? "Proton VPN" : d.tipo === "wireguard" ? "WireGuard"
                    : /^ppp/.test(n) ? "PPP" : "Túnel";
            vpnsN.push(v);
        }

        // Conexiones guardadas: TYPE:UUID:ACTIVE:NAME
        const guardadas = {}, perfiles = [];
        for (const l of lineas(partes[3])) {
            const c = campos(l);
            if (c.length < 4) continue;
            if (c[0] === "802-11-wireless") guardadas[c[3]] = true;
            if (c[0] === "vpn" || c[0] === "wireguard")
                perfiles.push({ nombre: c[3], uuid: c[1], activa: c[2] === "yes", tipo: c[0] === "vpn" ? "VPN" : "WireGuard" });
        }

        // Redes visibles: IN-USE:SIGNAL:CHAN:FREQ:RATE:SECURITY:BSSID:SSID
        // (una por nombre, la de mejor senal)
        const porNombre = {};
        let enUso = null;
        for (const l of lineas(partes[2])) {
            const c = campos(l);
            if (c.length < 8 || c[7] === "") continue;
            const red = {
                ssid: c[7],
                senal: parseInt(c[1]) || 0,
                canal: c[2], frecuencia: c[3], ritmo: c[4], bssid: c[6],
                segura: c[5] !== "" && c[5] !== "--",
                seguridad: c[5] === "--" ? "" : c[5],
                conocida: guardadas[c[7]] === true,
                enUso: c[0] === "*"
            };
            if (red.enUso) enUso = red;
            const previa = porNombre[red.ssid];
            if (!previa || red.enUso || (red.senal > previa.senal && !previa.enUso)) porNombre[red.ssid] = red;
        }
        const lista = Object.keys(porNombre).map(k => porNombre[k]).filter(r => !enUso || r.ssid !== enUso.ssid);
        lista.sort((a, b) => (b.conocida - a.conocida) || (b.senal - a.senal));

        if (wifiN) wifiN.red = enUso;
        interfazWifi = wifiN ? wifiN.nombre : "";
        conectadaA = enUso ? enUso.ssid : wifiN && wifiN.conectada ? wifiN.conexion : "";
        poner("redes", lista.slice(0, 8));
        poner("cables", cablesN);
        poner("wifi", wifiN);
        poner("vpns", vpnsN);
        poner("perfilesVpn", perfiles);

        // Tailscale: "no" si no está instalado; si no, su JSON (o vacío si no responde)
        const ts = (partes[7] || "").trim();
        hayTailscale = ts !== "no";
        procesarTailscale(hayTailscale ? json(ts) : null, direcciones);

        // Pestaña inicial: la de la salida a internet
        const ruta = (json(partes[8]) || []).slice().sort((a, b) => (a.metric || 0) - (b.metric || 0))[0];
        const dev = ruta ? ruta.dev : "";
        principal = wifiN && wifiN.nombre === dev ? "wifi" : cablesN.some(x => x.nombre === dev) ? "cable"
                  : dev !== "" ? "vpn" : "";
        listo = true;
        const ids = pestanas.map(x => x.id);
        if (ids.indexOf(pestana) < 0 || !elegida)
            pestana = ids.indexOf(principal) >= 0 ? principal : ids[0] || "";
    }

    function procesarTailscale(t, direcciones) {
        if (!t) {
            tailscale = null;
            poner("equipos", []);
            return;
        }
        const yo = t.Self || {}, ips = yo.TailscaleIPs || t.TailscaleIPs || [];
        const d = direcciones["tailscale0"] || {};
        const usuario = t.User && t.User[yo.UserID] ? t.User[yo.UserID].LoginName : "";
        const lista = Object.keys(t.Peer || {}).map(k => t.Peer[k]);
        const salida = lista.find(p => p.ExitNode);
        const corto = p => String(p.DNSName || "").split(".")[0] || p.HostName || "";
        poner("tailscale", {
            estado: t.BackendState || "",
            activo: t.BackendState === "Running",
            nombre: corto(yo),
            dns: String(yo.DNSName || "").replace(/\.$/, ""),
            ip: ips.find(i => i.indexOf(":") < 0) || "",
            v6: ips.find(i => i.indexOf(":") >= 0) || "",
            prefijo: d.prefijo || 0,
            mtu: d.mtu || 0,
            red: t.CurrentTailnet ? t.CurrentTailnet.Name : "",
            usuario: usuario,
            rele: yo.Relay || "",
            salida: salida ? corto(salida) : "",
            version: String(t.Version || "").split("-")[0],
            enLinea: lista.filter(p => p.Online).length,
            total: lista.length
        });
        poner("equipos", lista.map(p => ({
            nombre: corto(p),
            ip: (p.TailscaleIPs || []).find(i => i.indexOf(":") < 0) || "",
            so: p.OS || "",
            enLinea: p.Online === true,
            via: !p.Online || !p.Active ? "" : p.CurAddr ? "directo" : p.Relay ? "relé " + p.Relay : "",
            salida: p.ExitNode === true
        })).sort((a, b) => (b.enLinea - a.enLinea) || a.nombre.localeCompare(b.nombre)));
    }

    readonly property string textoTailscale: {
        if (!tailscale) return "El servicio no responde";
        switch (tailscale.estado) {
            case "Running":          return "Conectado";
            case "Stopped":          return "Desconectado";
            case "Starting":         return "Conectando…";
            case "NeedsLogin":       return "Falta iniciar sesión: sudo tailscale up";
            case "NeedsMachineAuth": return "Falta aprobar este equipo";
            default:                 return tailscale.estado;
        }
    }

    function alternarTailscale() {
        if (accionTailscale.running || !tailscale) return;
        errorVpn = "";
        accionTailscale.command = ["timeout", "20", "tailscale", tailscale.activo ? "down" : "up"];
        accionTailscale.running = true;
    }

    function alternarPerfil(p) {
        if (accionVpn.running) return;
        errorVpn = "";
        accionVpn.command = ["nmcli", "connection", p.activa ? "down" : "up", "uuid", p.uuid];
        accionVpn.running = true;
    }

    Process {
        id: accionTailscale
        environment: ({ LC_ALL: "C" })
        stderr: StdioCollector { id: errorTailscale }
        onExited: codigo => {
            if (codigo !== 0)
                panel.errorVpn = /access denied|permission|operator/i.test(errorTailscale.text)
                    ? "Tailscale pide permisos. Ejecuta una sola vez:\nsudo tailscale set --operator=$USER"
                    : "Tailscale: " + (errorTailscale.text.trim().split("\n")[0] || "no respondió");
            panel.refrescar();
        }
    }

    Process {
        id: accionVpn
        environment: ({ LC_ALL: "C" })
        onExited: codigo => {
            if (codigo !== 0) panel.errorVpn = "No se pudo cambiar la VPN (revisa el editor de conexiones)";
            panel.refrescar();
        }
    }

    // Tráfico en vivo: /proc/net/dev cada segundo, solo con el panel abierto
    property var lecturaPrevia: null
    FileView {
        id: contadores
        path: "/proc/net/dev"
        printErrors: false
        onLoaded: {
            if (!panel.abierto) return;
            const ahora = Date.now(), actual = {}, r = {};
            const prev = panel.lecturaPrevia;
            for (const l of text().split("\n").slice(2)) {
                const i = l.indexOf(":");
                if (i < 0) continue;
                const n = l.slice(0, i).trim(), c = l.slice(i + 1).trim().split(/\s+/);
                const rx = Number(c[0]), tx = Number(c[8]);
                actual[n] = { rx: rx, tx: tx };
                const p = prev ? prev.datos[n] : null;
                const s = prev ? Math.max(0.2, (ahora - prev.hora) / 1000) : 1;
                r[n] = { rx: rx, tx: tx,
                         bajada: p ? Math.max(0, (rx - p.rx) / s) : 0,
                         subida: p ? Math.max(0, (tx - p.tx) / s) : 0 };
            }
            panel.lecturaPrevia = { hora: ahora, datos: actual };
            panel.trafico = r;
        }
    }

    Timer {
        interval: 1000
        running: panel.abierto
        repeat: true
        triggeredOnStart: true
        onTriggered: contadores.reload()
    }

    // Datos de una interfaz física para DatosRed
    function datosInterfaz(i) {
        return [
            { n: "Dirección IP", v: i.ip },
            { n: "Máscara", v: i.ip ? mascara(i.prefijo) + " (/" + i.prefijo + ")" : "" },
            { n: "Puerta de enlace", v: i.puerta },
            { n: "Asignación", v: i.asignacion },
            { n: "DNS", v: (i.dns || [])[0] || "" },
            { n: "DNS 2", v: (i.dns || [])[1] || "" },
            { n: "Difusión", v: i.difusion },
            { n: "IPv6", v: i.v6 },
            { n: "MAC", v: i.mac },
            { n: "Interfaz", v: i.nombre + (i.controlador ? " (" + i.controlador + ")" : "") },
            { n: "MTU", v: i.mtu ? "" + i.mtu : "" },
            { n: "Dominio", v: i.dominio || "" }
        ];
    }

    function velocidad(mbps) {
        return mbps <= 0 ? "" : mbps >= 1000 ? (mbps / 1000) + " Gb/s" : mbps + " Mb/s";
    }

    function estadoTexto(e) {
        if (e.startsWith("connected")) return "Conectado";
        if (e.startsWith("connecting")) return "Conectando…";
        if (e === "unavailable") return "Cable desconectado";
        if (e === "unmanaged") return "No administrada";
        return "Desconectado";
    }

    function refrescar() {
        if (!consulta.running) consulta.running = true;
    }

    function buscar() {
        buscando = true;
        Quickshell.execDetached(["nmcli", "device", "wifi", "rescan"]);
        finBusqueda.restart();
    }

    function radio(encender) {
        Quickshell.execDetached(["nmcli", "radio", "wifi", encender ? "on" : "off"]);
        refrescoDiferido.restart();
    }

    // Clic en una red: si necesita contrasena se abre el dialogo central
    function conectar(red) {
        error = "";
        if (red.segura && !red.conocida) {
            cerrar();
            dialogo.abrir(red, "");
            return;
        }
        iniciar(red, ["nmcli", "device", "wifi", "connect", red.ssid], !red.conocida);
    }

    // Desde el dialogo. Si la red ya estaba guardada (contrasena cambiada),
    // se borra el perfil viejo antes de conectar con la nueva.
    function conectarConClave(red, clave) {
        if (red.conocida) {
            iniciar(red, ["sh", "-c",
                'nmcli connection delete id "$1" >/dev/null 2>&1; exec nmcli device wifi connect "$1" password "$2"',
                "sh", red.ssid, clave], true);
        } else {
            iniciar(red, ["nmcli", "device", "wifi", "connect", red.ssid, "password", clave], true);
        }
    }

    function iniciar(red, comando, nueva) {
        if (accion.running) return;
        conectando = red.ssid;
        redEnCurso = red;
        eraNueva = nueva;
        accion.command = comando;
        accion.running = true;
    }

    function desconectar() {
        if (interfazWifi !== "")
            Quickshell.execDetached(["nmcli", "device", "disconnect", interfazWifi]);
        refrescoDiferido.restart();
    }

    Connections {
        target: panel
        function onAbrio() {
            panel.error = "";
            panel.errorVpn = "";
            panel.elegida = false;
            panel.lecturaPrevia = null;
            panel.refrescar();
        }
    }

    Process {
        id: consulta
        command: ["sh", "-c",
            "nmcli radio wifi; echo @@@; " +
            "nmcli -t -f DEVICE,TYPE,STATE,CONNECTION device; echo @@@; " +
            "nmcli -t -f IN-USE,SIGNAL,CHAN,FREQ,RATE,SECURITY,BSSID,SSID device wifi list 2>/dev/null; echo @@@; " +
            "nmcli -t -f TYPE,UUID,ACTIVE,NAME connection show; echo @@@; " +
            "ip -j -d addr show; echo; echo @@@; " +
            "for d in /sys/class/net/*/; do n=${d%/}; f=0; [ -e \"$d/device\" ] && f=1; " +
            "echo \"${n##*/}|$f|$(cat \"$d/speed\" 2>/dev/null)|$(cat \"$d/duplex\" 2>/dev/null)\"; done; echo @@@; " +
            "nmcli -t -f GENERAL.DEVICE,GENERAL.DRIVER,IP4.GATEWAY,IP4.DNS,IP4.DOMAIN device show; echo @@@; " +
            "if command -v tailscale >/dev/null; then timeout 3 tailscale status --json 2>/dev/null; else echo no; fi; echo; echo @@@; " +
            "ip -j -4 route show default"]
        environment: ({ LC_ALL: "C" })
        stdout: StdioCollector {
            onStreamFinished: panel.procesar(this.text)
        }
    }

    Process {
        id: accion
        environment: ({ LC_ALL: "C" })
        stderr: StdioCollector { id: errores }

        onExited: codigo => {
            const red = panel.redEnCurso;
            const nombre = panel.conectando;
            panel.conectando = "";
            panel.redEnCurso = null;

            if (codigo === 0) {
                dialogo.cerrar();
                Quickshell.execDetached(["notify-send", "-a", "Red", "-i", "network-wireless", "Wi-Fi", "Conectado a " + nombre]);
            } else {
                // Si el perfil era nuevo, borrarlo para poder reintentar
                if (panel.eraNueva)
                    Quickshell.execDetached(["nmcli", "connection", "delete", "id", nombre]);

                if (dialogo.visible) {
                    dialogo.fallo("Contraseña incorrecta o la red no respondió");
                } else if (red && red.segura) {
                    // Una red guardada cuya contrasena ya no sirve
                    dialogo.abrir(red, "La contraseña guardada no funcionó. Escríbela de nuevo.");
                } else {
                    panel.error = "No se pudo conectar a " + nombre;
                }
            }
            panel.refrescar();
        }
    }

    Timer {
        interval: 5000
        running: panel.abierto
        repeat: true
        onTriggered: panel.refrescar()
    }

    Timer {
        id: finBusqueda
        interval: 4000
        onTriggered: { panel.buscando = false; panel.refrescar(); }
    }

    Timer {
        id: refrescoDiferido
        interval: 2500
        onTriggered: panel.refrescar()
    }

    accesorio: Interruptor {
        visible: panel.pestana === "wifi"
        activo: panel.wifiActivo
        onAlternado: panel.radio(!panel.wifiActivo)
    }

    // ---------- Pestañas ----------
    Row {
        id: filaPestanas
        visible: panel.pestanas.length > 0
        width: parent.width
        spacing: 6

        Repeater {
            model: panel.pestanas

            delegate: Rectangle {
                id: botonPestana

                required property var modelData
                readonly property bool activa: panel.pestana === modelData.id
                // Punto de estado
                readonly property bool conectada: modelData.id === "cable" ? panel.cables.some(c => c.conectada)
                    : modelData.id === "wifi" ? panel.conectadaA !== ""
                    : (panel.tailscale !== null && panel.tailscale.activo) || panel.vpns.some(v => v.conectada) || panel.perfilesVpn.some(p => p.activa)

                width: (filaPestanas.width - filaPestanas.spacing * (panel.pestanas.length - 1)) / panel.pestanas.length
                height: 36
                radius: 18
                color: activa ? Tema.acento : zonaPestana.containsMouse ? Tema.campoHover : Tema.campo
                Behavior on color { ColorAnimation { duration: 140 } }

                Row {
                    anchors.centerIn: parent
                    spacing: 8
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: botonPestana.modelData.icono
                        color: botonPestana.activa ? Tema.fondo : Tema.texto
                        font.family: Tema.fuenteBarra
                        font.pixelSize: 16
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: botonPestana.modelData.texto
                        color: botonPestana.activa ? Tema.fondo : Tema.texto
                        font.family: Tema.fuenteBarra
                        font.pixelSize: 13
                        font.bold: true
                    }
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 8
                        height: 8
                        radius: 4
                        color: botonPestana.conectada ? (botonPestana.activa ? "#1f7a43" : Tema.verde)
                                                      : (botonPestana.activa ? Tema.bordeFuerte : Tema.tenue)
                    }
                }

                MouseArea {
                    id: zonaPestana
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        panel.elegida = true;
                        panel.pestana = botonPestana.modelData.id;
                    }
                }
            }
        }
    }

    Text {
        visible: panel.pestanas.length === 0
        text: panel.listo ? "Este equipo no tiene conexiones de red" : "Consultando…"
        color: Tema.tenue
        font.family: Tema.fuenteBarra
        font.pixelSize: 13
    }

    // ---------- Ethernet ----------
    Column {
        visible: panel.pestana === "cable"
        width: parent.width
        spacing: 10

        Repeater {
            model: panel.cables

            delegate: Column {
                id: cable
                required property var modelData
                width: parent.width
                spacing: 8

                FilaLista {
                    icono: String.fromCodePoint(0xf0200)
                    colorIcono: cable.modelData.conectada ? Tema.ambar : Tema.tenue
                    titulo: cable.modelData.conexion || cable.modelData.nombre
                    subtitulo: panel.estadoTexto(cable.modelData.estado)
                    colorSubtitulo: cable.modelData.conectada ? Tema.verde : Tema.tenue
                    resaltada: true
                    detalle: !cable.modelData.conectada ? "" : panel.velocidad(cable.modelData.velocidad)
                        + (cable.modelData.duplex === "full" ? " dúplex" : cable.modelData.duplex === "half" ? " semidúplex" : "")
                    colorDetalle: Tema.ambar
                }
                TraficoRed {
                    visible: cable.modelData.conectada
                    valores: panel.trafico[cable.modelData.nombre] || null
                }
                DatosRed { datos: panel.datosInterfaz(cable.modelData) }
            }
        }
    }

    // ---------- Wi-Fi ----------
    FilaLista {
        visible: panel.pestana === "wifi" && panel.conectadaA !== ""
        icono: "󰖩"
        colorIcono: Tema.ambar
        titulo: panel.conectadaA
        subtitulo: panel.wifi && panel.wifi.red ? "Conectado · señal " + panel.wifi.red.senal + "% · " + panel.wifi.red.ritmo : "Conectado"
        colorSubtitulo: Tema.verde
        resaltada: true
        detalle: "Desconectar"
        colorDetalle: Tema.error
        onClic: panel.desconectar()
    }

    TraficoRed {
        visible: panel.pestana === "wifi" && panel.conectadaA !== ""
        valores: panel.trafico[panel.interfazWifi] || null
    }

    DatosRed {
        readonly property var r: panel.wifi ? panel.wifi.red : null
        visible: panel.pestana === "wifi" && panel.conectadaA !== ""
        datos: panel.wifi ? panel.datosInterfaz(panel.wifi).concat(r ? [
            { n: "Frecuencia", v: r.frecuencia + (r.canal ? " (canal " + r.canal + ")" : "") },
            { n: "Seguridad", v: r.seguridad || "Abierta" },
            { n: "Punto de acceso", v: r.bssid }
        ] : []) : []
    }

    Text {
        visible: panel.pestana === "wifi" && !panel.wifiActivo
        width: parent.width
        text: "Wi-Fi apagado"
        color: Tema.tenue
        font.family: Tema.fuenteBarra
        font.pixelSize: 13
    }

    // ---------- Redes disponibles ----------
    TituloSeccion {
        visible: panel.pestana === "wifi" && panel.wifiActivo
        texto: "Redes disponibles"
        extra: panel.buscando ? "Buscando…" : ""
    }

    Repeater {
        model: panel.pestana === "wifi" && panel.wifiActivo ? panel.redes : []

        delegate: FilaLista {
            required property var modelData

            icono: panel.iconosWifi[Math.min(4, Math.floor(modelData.senal / 20))]
            titulo: modelData.ssid
            subtitulo: panel.conectando === modelData.ssid ? "Conectando…"
                     : modelData.conocida ? "Guardada"
                     : modelData.segura ? "Protegida"
                     : "Abierta"
            colorSubtitulo: panel.conectando === modelData.ssid ? Tema.ambar : Tema.tenue
            detalle: modelData.segura ? "󰌾" : ""
            onClic: panel.conectar(modelData)
        }
    }

    Text {
        visible: panel.pestana === "wifi" && panel.error !== ""
        width: parent.width
        wrapMode: Text.Wrap
        text: panel.error
        color: Tema.error
        font.family: Tema.fuenteBarra
        font.pixelSize: 12
    }

    // ---------- VPN ----------
    Column {
        visible: panel.pestana === "vpn"
        width: parent.width
        spacing: 8

        FilaLista {
            visible: panel.hayTailscale
            icono: String.fromCodePoint(0xf0582)
            colorIcono: panel.tailscale && panel.tailscale.activo ? Tema.ambar : Tema.tenue
            titulo: "Tailscale" + (panel.tailscale && panel.tailscale.nombre ? " · " + panel.tailscale.nombre : "")
            subtitulo: panel.textoTailscale
            colorSubtitulo: panel.tailscale && panel.tailscale.activo ? Tema.verde : Tema.tenue
            resaltada: true
            detalle: accionTailscale.running ? "…" : !panel.tailscale ? ""
                   : panel.tailscale.activo ? "Desconectar" : panel.tailscale.estado === "Stopped" ? "Conectar" : ""
            colorDetalle: panel.tailscale && panel.tailscale.activo ? Tema.error : Tema.verde
            onClic: if (detalle.length > 1) panel.alternarTailscale()
        }
        TraficoRed {
            visible: panel.tailscale !== null && panel.tailscale.activo
            valores: panel.trafico["tailscale0"] || null
        }
        DatosRed {
            readonly property var t: panel.tailscale
            visible: t !== null && t.activo
            datos: t === null ? [] : [
                { n: "Dirección IP", v: t.ip },
                { n: "Máscara", v: t.prefijo ? panel.mascara(t.prefijo) + " (/" + t.prefijo + ")" : "" },
                { n: "IPv6", v: t.v6 },
                { n: "Nombre DNS", v: t.dns },
                { n: "Red", v: t.red },
                { n: "Cuenta", v: t.usuario !== t.red ? t.usuario : "" },
                { n: "Nodo de salida", v: t.salida || "Ninguno" },
                { n: "Relé cercano", v: t.rele },
                { n: "MTU", v: t.mtu ? "" + t.mtu : "" },
                { n: "Versión", v: t.version }
            ]
        }

        TituloSeccion {
            visible: panel.equipos.length > 0
            texto: "Equipos"
            extra: panel.tailscale ? panel.tailscale.enLinea + " de " + panel.tailscale.total + " en línea" : ""
        }
        ListView {
            visible: count > 0
            width: parent.width
            height: Math.min(contentHeight, 212)
            clip: true
            spacing: 4
            boundsBehavior: Flickable.StopAtBounds
            model: panel.equipos
            delegate: FilaLista {
                required property var modelData
                width: ListView.view.width
                icono: String.fromCodePoint(/ios|android/i.test(modelData.so) ? 0xf011c : 0xf0379)
                colorIcono: modelData.enLinea ? Tema.verde : Tema.tenue
                titulo: modelData.nombre
                subtitulo: [modelData.enLinea ? "En línea" : "Sin conexión", modelData.so, modelData.via,
                            modelData.salida ? "nodo de salida" : ""].filter(x => x).join(" · ")
                detalle: modelData.ip
                onClic: Quickshell.execDetached(["wl-copy", "--", modelData.ip])
            }
        }

        // Otros túneles activos
        Repeater {
            model: panel.vpns
            delegate: Column {
                id: tunel
                required property var modelData
                width: parent.width
                spacing: 8
                FilaLista {
                    icono: String.fromCodePoint(0xf0582)
                    colorIcono: tunel.modelData.conectada ? Tema.ambar : Tema.tenue
                    titulo: tunel.modelData.clase + " · " + (tunel.modelData.conexion || tunel.modelData.nombre)
                    subtitulo: tunel.modelData.conectada ? "Conectado" : "Desconectado"
                    colorSubtitulo: tunel.modelData.conectada ? Tema.verde : Tema.tenue
                    resaltada: true
                }
                TraficoRed {
                    visible: tunel.modelData.conectada
                    valores: panel.trafico[tunel.modelData.nombre] || null
                }
                DatosRed { datos: panel.datosInterfaz(tunel.modelData) }
            }
        }

        // VPN guardadas en NetworkManager
        TituloSeccion { visible: panel.perfilesVpn.length > 0; texto: "VPN guardadas" }
        Repeater {
            model: panel.perfilesVpn
            delegate: FilaLista {
                required property var modelData
                icono: String.fromCodePoint(0xf0582)
                titulo: modelData.nombre
                subtitulo: modelData.tipo + (modelData.activa ? " · Conectada" : "")
                detalle: modelData.activa ? "Desconectar" : "Conectar"
                colorDetalle: modelData.activa ? Tema.error : Tema.verde
                onClic: panel.alternarPerfil(modelData)
            }
        }

        Text {
            visible: panel.errorVpn !== ""
            width: parent.width
            wrapMode: Text.Wrap
            text: panel.errorVpn
            color: Tema.error
            font.family: Tema.fuenteBarra
            font.pixelSize: 12
        }
    }

    // ---------- Pie ----------
    Item { width: 1; height: 2 }

    Row {
        spacing: 8

        BotonTexto {
            visible: panel.pestana === "wifi" && panel.wifiActivo
            icono: "󰑐"
            texto: "Buscar redes"
            onClic: panel.buscar()
        }

        BotonTexto {
            icono: "󰒓"
            texto: "Editor de conexiones"
            onClic: {
                Quickshell.execDetached(["nm-connection-editor"]);
                panel.cerrar();
            }
        }
    }

    // ==========================================================
    // Dialogo de contrasena, centrado en la pantalla
    // Enter: conectar · Escape o clic fuera: cancelar
    // ==========================================================
    PanelWindow {
        id: dialogo

        property var red: null
        property string mensaje: ""
        property bool mostrarClave: false

        function abrir(r, aviso) {
            red = r;
            mensaje = aviso;
            mostrarClave = false;
            campoClave.text = "";
            if (panel.ventanaBarra) screen = panel.ventanaBarra.screen;
            visible = true;
            tarjetaDialogo.opacity = 0;
            tarjetaDialogo.scale = 0.96;
            entradaDialogo.restart();
            Qt.callLater(() => campoClave.forceActiveFocus());
        }

        function cerrar() {
            visible = false;
            red = null;
        }

        function enviar() {
            if (!red || panel.conectando !== "") return;
            const clave = campoClave.text;
            if (clave === "") {
                fallo("Escribe la contraseña");
                return;
            }
            if (red.seguridad.includes("WPA") && clave.length < 8) {
                fallo("La contraseña debe tener al menos 8 caracteres");
                return;
            }
            mensaje = "";
            panel.conectarConClave(red, clave);
        }

        function fallo(texto) {
            mensaje = texto;
            campoClave.selectAll();
            sacudida.restart();
            campoClave.forceActiveFocus();
        }

        visible: false
        color: "transparent"

        WlrLayershell.namespace: "dialogo-wifi"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        exclusionMode: ExclusionMode.Ignore

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        ParallelAnimation {
            id: entradaDialogo
            NumberAnimation { target: tarjetaDialogo; property: "opacity"; to: 1; duration: 180; easing.type: Easing.OutCubic }
            NumberAnimation { target: tarjetaDialogo; property: "scale"; to: 1; duration: 200; easing.type: Easing.OutCubic }
        }

        SequentialAnimation {
            id: sacudida
            NumberAnimation { target: desplazamientoCampo; property: "x"; to: -12; duration: 50 }
            NumberAnimation { target: desplazamientoCampo; property: "x"; to: 12; duration: 70 }
            NumberAnimation { target: desplazamientoCampo; property: "x"; to: -6; duration: 60 }
            NumberAnimation { target: desplazamientoCampo; property: "x"; to: 0; duration: 50 }
        }

        // Fondo oscurecido: clic = cancelar (si no se esta conectando)
        Rectangle {
            anchors.fill: parent
            color: Tema.velo

            MouseArea {
                anchors.fill: parent
                onClicked: if (panel.conectando === "") dialogo.cerrar()
            }
        }

        Rectangle {
            id: tarjetaDialogo

            anchors.centerIn: parent
            width: 420
            height: contenidoDialogo.implicitHeight + 40
            radius: 18
            color: Tema.fondoTarjeta
            border.width: 1
            border.color: Tema.borde

            // Evita que los clics dentro cierren el dialogo
            MouseArea {
                anchors.fill: parent
            }

            Column {
                id: contenidoDialogo

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 20
                spacing: 16

                // ----- Encabezado: red elegida -----
                Row {
                    spacing: 14

                    Rectangle {
                        width: 48
                        height: 48
                        radius: 14
                        color: Tema.campo

                        Text {
                            anchors.centerIn: parent
                            text: dialogo.red ? panel.iconosWifi[Math.min(4, Math.floor(dialogo.red.senal / 20))] : ""
                            color: Tema.ambar
                            font.family: Tema.fuenteBarra
                            font.pixelSize: 24
                        }
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 3

                        Text {
                            text: "Conectar a"
                            color: Tema.tenue
                            font.family: Tema.fuenteBarra
                            font.pixelSize: 12
                        }

                        Text {
                            width: 300
                            text: dialogo.red ? dialogo.red.ssid : ""
                            color: Tema.texto
                            font.family: Tema.fuenteBarra
                            font.pixelSize: 17
                            font.bold: true
                            elide: Text.ElideRight
                        }

                        Text {
                            text: dialogo.red
                                  ? "󰌾 " + (dialogo.red.seguridad || "Protegida") + "  ·  señal " + dialogo.red.senal + "%"
                                  : ""
                            color: Tema.tenue
                            font.family: Tema.fuenteBarra
                            font.pixelSize: 11
                        }
                    }
                }

                // ----- Campo de contrasena -----
                Rectangle {
                    width: parent.width
                    height: 46
                    radius: 12
                    color: Tema.campo
                    border.width: 1
                    border.color: dialogo.mensaje !== "" && panel.conectando === "" ? Tema.error
                                : campoClave.activeFocus ? Tema.acento
                                : Tema.borde

                    Behavior on border.color { ColorAnimation { duration: 150 } }

                    transform: Translate { id: desplazamientoCampo }

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 14
                        anchors.verticalCenter: parent.verticalCenter
                        visible: campoClave.text.length === 0
                        text: "Contraseña"
                        color: Tema.tenue
                        font.family: Tema.fuenteBarra
                        font.pixelSize: 14
                        font.italic: true
                    }

                    TextInput {
                        id: campoClave

                        anchors.left: parent.left
                        anchors.right: ojo.left
                        anchors.leftMargin: 14
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        echoMode: dialogo.mostrarClave ? TextInput.Normal : TextInput.Password
                        color: Tema.texto
                        font.family: Tema.fuenteBarra
                        font.pixelSize: 15
                        clip: true
                        enabled: panel.conectando === ""

                        onTextChanged: if (panel.conectando === "") dialogo.mensaje = ""
                        onAccepted: dialogo.enviar()
                        Keys.onEscapePressed: if (panel.conectando === "") dialogo.cerrar()
                    }

                    // Mostrar / ocultar la contrasena
                    Text {
                        id: ojo
                        anchors.right: parent.right
                        anchors.rightMargin: 14
                        anchors.verticalCenter: parent.verticalCenter
                        text: dialogo.mostrarClave ? "󰈉" : "󰈈"
                        color: zonaOjo.containsMouse ? Tema.acento : Tema.tenue
                        font.family: Tema.fuenteBarra
                        font.pixelSize: 18

                        MouseArea {
                            id: zonaOjo
                            anchors.fill: parent
                            anchors.margins: -6
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                dialogo.mostrarClave = !dialogo.mostrarClave;
                                campoClave.forceActiveFocus();
                            }
                        }
                    }
                }

                // ----- Mensaje de error o estado -----
                Text {
                    visible: text !== ""
                    width: parent.width
                    wrapMode: Text.Wrap
                    text: panel.conectando !== "" ? "Conectando, esto puede tardar unos segundos…" : dialogo.mensaje
                    color: panel.conectando !== "" ? Tema.ambar : Tema.error
                    font.family: Tema.fuenteBarra
                    font.pixelSize: 12
                }

                // ----- Botones -----
                Item {
                    width: parent.width
                    height: 34

                    Row {
                        anchors.right: parent.right
                        spacing: 8

                        BotonTexto {
                            texto: "Cancelar"
                            opacity: panel.conectando === "" ? 1 : 0.5
                            onClic: if (panel.conectando === "") dialogo.cerrar()
                        }

                        BotonTexto {
                            principal: true
                            icono: panel.conectando !== "" ? "" : "󰁔"
                            texto: panel.conectando !== "" ? "Conectando…" : "Conectar"
                            onClic: dialogo.enviar()
                        }
                    }
                }
            }
        }
    }
}
