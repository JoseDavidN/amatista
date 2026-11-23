// ==========================================================
// Panel de hardware: procesador, memoria, gráficos, discos y equipo
// Los datos salen de ~/.local/bin/info-hardware. Solo se consulta con el
// panel abierto: cada 2 s lo que cambia, una vez al abrir lo que no.
// Clic en un dato = copiarlo.
// ==========================================================
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Comun
import qs.paneles

PanelEmergente {
    id: panel

    readonly property string script: Quickshell.env("HOME") + "/.local/bin/info-hardware"
    readonly property int muestras: 60

    property string pestana: "cpu"
    readonly property var pestanas: [
        { id: "cpu",     icono: 0xf0ee0, texto: "CPU" },
        { id: "memoria", icono: 0xf035b, texto: "Memoria" },
        { id: "gpu",     icono: 0xf08ae, texto: "Gráficos" },
        { id: "discos",  icono: 0xf02ca, texto: "Discos" },
        { id: "equipo",  icono: 0xf0322, texto: "Equipo" }
    ]

    ancho: Math.min(560, (screen ? screen.width : 1920) - 24)
    titulo: "Hardware"
    icono: String.fromCodePoint(0xf0ee0)
    colorIcono: Tema.rosa

    // ---------- Datos fijos ----------
    property var cpuInfo: ({})
    property var gobernador: []
    property var dmi: ({})
    property var modulos: []        // módulos de RAM
    property int ranuras: 0
    property real ramMaxima: 0
    property var so: []
    property string arranque: ""
    property var pci: []
    property var usb: []
    property var monitores: []

    // ---------- Datos vivos ----------
    property int uso: 0
    property var nucleos: []        // [{ uso, mhz }]
    property var historia: []       // uso de CPU
    property var historiaRam: []
    property var carga: []
    property real encendido: 0
    property var mem: ({})          // en KiB
    property var swaps: []
    property var temperaturas: []
    property var ventiladores: []
    property var gpus: []
    property var nvidia: []
    property var discos: []
    property var procesosCpu: []
    property var procesosMem: []
    property var previa: null       // lectura anterior, para calcular diferencias

    function json(t) { try { return JSON.parse(t); } catch (e) { return null; } }

    function poner(propiedad, valor) {
        if (JSON.stringify(panel[propiedad]) !== JSON.stringify(valor)) panel[propiedad] = valor;
    }

    // Memoria en potencias de 1024; los discos, como los anuncia el fabricante
    function tamano(b, base) {
        const k = base || 1024;
        const u = ["B", "KB", "MB", "GB", "TB"];
        let i = 0;
        while (b >= k && i < u.length - 1) { b /= k; i++; }
        return (i === 0 || b >= 100 ? Math.round(b) : b.toFixed(1).replace(/\.0$/, "")) + " " + u[i];
    }
    function mhz(m) { return m >= 1000 ? (m / 1000).toFixed(2) + " GHz" : Math.round(m) + " MHz"; }
    function grados(m) { return Math.round(m / 1000) + " °C"; }
    function duracion(s) {
        const d = Math.floor(s / 86400), h = Math.floor(s % 86400 / 3600), m = Math.floor(s % 3600 / 60);
        return (d ? d + " d " : "") + (d || h ? h + " h " : "") + m + " min";
    }

    // Temperatura del procesador: la del conjunto
    readonly property var tempCpu: temperaturas.find(t => /^(coretemp|k10temp|zenpower|cpu_thermal)$/.test(t.sensor))
                                || temperaturas.find(t => t.sensor === "acpitz")

    function procesarFija(texto) {
        const c = {}, d = {}, r = {}, p = [], u = [];
        for (const l of texto.split("\n")) {
            const v = l.split("|");
            if (v[0] === "CPU") c[v[1]] = v.slice(2).join("|");
            else if (v[0] === "GOBERNADOR") gobernador = v.slice(1);
            else if (v[0] === "DMI") d[v[1]] = v.slice(2).join("|").trim();
            else if (v[0] === "RAM") r[v[1]] = v.slice(2).join("|").trim();
            else if (v[0] === "SO") so = v.slice(1);
            else if (v[0] === "ARRANQUE") arranque = v[1];
            else if (v[0] === "USB") u.push({ fabricante: v[1], producto: v[2], velocidad: Number(v[3]) || 0 });
            else if (v[0] === "MONITORES") monitores = json(v.slice(1).join("|")) || [];
            else if (v[0] === "PCI") {
                // 0000:00:02.0 "clase" "fabricante" "dispositivo" ...
                const linea = v.slice(2).join("|");
                const q = (linea.match(/"([^"]*)"/g) || []).map(x => x.slice(1, -1));
                if (q.length >= 3) p.push({ ranura: linea.split(" ")[0], driver: v[1], clase: q[0], fabricante: q[1], nombre: q[2] });
            }
        }
        const m = [];
        let n = 0;
        for (; n < 64 && Object.keys(r).some(k => k.startsWith("DEVICE_" + n + "_")); n++) {
            const x = k => r["DEVICE_" + n + "_" + k] || "";
            if (Number(x("SIZE")) > 0)
                m.push({ lugar: x("LOCATOR") || "Ranura " + (n + 1), tamano: Number(x("SIZE")), tipo: x("TYPE"),
                         velocidad: Number(x("CONFIGURED_SPEED_MTS") || x("SPEED_MTS")), pieza: x("PART_NUMBER"), forma: x("FORM_FACTOR") });
        }
        cpuInfo = c; dmi = d; modulos = m; ranuras = n; ramMaxima = Number(r["ARRAY_MAX_CAPACITY"]) || 0; pci = p; usb = u;
    }

    function procesarViva(texto) {
        const ahora = Date.now(), stat = {}, frec = {}, m = {}, sw = [], t = [], ve = [], g = [], nv = [], io = {}, pr = {};
        let arbol = null;
        for (const l of texto.split("\n")) {
            const v = l.split("|");
            switch (v[0]) {
                case "STAT": {
                    const x = v[2].split(/\s+/).map(Number);
                    // guest ya está contado en user
                    stat[v[1]] = { total: x.slice(0, 8).reduce((a, b) => a + (b || 0), 0), ocio: x[3] + (x[4] || 0) };
                    break;
                }
                case "FREC":   frec[v[1]] = Number(v[2]) / 1000; break;
                case "CARGA":  poner("carga", v[1].split(" ").slice(0, 4)); break;
                case "TIEMPO": encendido = parseFloat(v[1]) || 0; break;
                case "MEM":    m[v[1]] = Number(v[2]); break;
                case "SWAP":   sw.push({ nombre: v[1].replace("/dev/", ""), tipo: v[2], total: Number(v[3]) * 1024, usado: Number(v[4]) * 1024 }); break;
                case "TEMP":   t.push({ sensor: v[1], nombre: v[2], valor: Number(v[3]), disco: v[4] }); break;
                case "VENT":   ve.push({ sensor: v[1], nombre: v[2], rpm: Number(v[3]) }); break;
                case "GPU":    g.push({ tarjeta: v[1], driver: v[2], mhz: v[3], max: v[4], uso: v[5], vramUsada: Number(v[6]), vramTotal: Number(v[7]), ranura: v[8] }); break;
                case "NVIDIA": nv.push({ nombre: v[1], mhz: v[2], max: v[3], uso: v[4], usada: v[5], total: v[6], temp: v[7] }); break;
                case "DISCOIO": {
                    const x = v[2].trim().split(/\s+/).map(Number);
                    io[v[1]] = { leido: x[2] * 512, escrito: x[6] * 512, ocupado: x[9] };
                    break;
                }
                case "DISCOS": arbol = json(v.slice(1).join("|")); break;
                case "PROC":   pr[v[1]] = { tics: Number(v[2]), mem: Number(v[3]) * 4096, nombre: v.slice(4).join("|") }; break;
            }
        }

        const a = previa, s = a ? Math.max(0.2, (ahora - a.hora) / 1000) : 1;
        const porcentaje = k => {
            const x = stat[k], y = a ? a.stat[k] : null;
            if (!x || !y || x.total <= y.total) return 0;
            return Math.max(0, Math.min(100, Math.round(100 * (1 - (x.ocio - y.ocio) / (x.total - y.total)))));
        };
        const ids = Object.keys(stat).filter(k => k !== "cpu");
        poner("nucleos", ids.map(k => ({ uso: porcentaje(k), mhz: frec[k] || 0 })));
        if (a) {
            uso = porcentaje("cpu");
            historia = historia.concat([uso]).slice(-muestras);
        }
        mem = m;
        if (m.MemTotal > 0) historiaRam = historiaRam.concat([100 * (m.MemTotal - m.MemAvailable) / m.MemTotal]).slice(-muestras);
        poner("swaps", sw);
        poner("temperaturas", t);
        poner("ventiladores", ve);
        poner("gpus", g);
        poner("nvidia", nv);

        // Discos, con sus particiones montadas y su actividad
        if (arbol && arbol.blockdevices) {
            poner("discos", arbol.blockdevices.filter(d => d.type === "disk" && d.size > 0 && !/^(zram|loop|ram|fd)/.test(d.name)).map(d => {
                const x = io[d.name], y = a ? a.io[d.name] : null, calor = t.find(k => k.disco === d.name);
                const partes = [], vistas = {};
                const recorrer = n => {
                    const donde = (n.mountpoints || []).filter(p => p);
                    if (!vistas[n.name] && n.fssize && donde.length) {
                        vistas[n.name] = true;
                        // La ruta más corta representa a los subvolúmenes
                        const orden = donde.slice().sort((p, q) => p.length - q.length);
                        partes.push({ nombre: n.name, donde: orden[0], otras: orden.length - 1, fs: n.fstype || "",
                                      usado: Number(n.fsused), total: Number(n.fssize) });
                    } else if (!vistas[n.name] && n.fstype === "swap") {
                        vistas[n.name] = true;
                        partes.push({ nombre: n.name, donde: "Intercambio", otras: 0, fs: "swap", usado: (sw.find(k => k.nombre === n.name) || { usado: 0 }).usado, total: Number(n.size) });
                    }
                    (n.children || []).forEach(recorrer);
                };
                recorrer(d);
                return {
                    nombre: d.name, modelo: String(d.model || d.name).trim(), tamano: Number(d.size),
                    clase: d.tran === "nvme" ? "SSD NVMe" : d.tran === "usb" ? "USB" : d.rota ? "Disco duro" : "SSD",
                    conexion: d.tran === "ata" || d.tran === "sata" ? "SATA" : String(d.tran || "").toUpperCase(),
                    temp: calor ? calor.valor : 0, partes: partes,
                    lee: x && y ? Math.max(0, (x.leido - y.leido) / s) : 0,
                    escribe: x && y ? Math.max(0, (x.escrito - y.escrito) / s) : 0,
                    ocupado: x && y ? Math.max(0, Math.min(100, Math.round((x.ocupado - y.ocupado) / s / 10))) : 0,
                    leido: x ? x.leido : 0, escrito: x ? x.escrito : 0
                };
            }));
        }

        // Procesos: % de un núcleo (100 tics por segundo)
        const lista = [];
        for (const k in pr) {
            const y = a ? a.pr[k] : null;
            lista.push({ pid: k, nombre: pr[k].nombre, mem: pr[k].mem,
                         cpu: y && y.nombre === pr[k].nombre ? Math.max(0, (pr[k].tics - y.tics) / s) : 0 });
        }
        if (a) poner("procesosCpu", lista.slice().sort((x, y) => y.cpu - x.cpu).slice(0, 5).map(x => ({ nombre: x.nombre, pid: x.pid, valor: x.cpu.toFixed(1) + " %" })));
        poner("procesosMem", lista.slice().sort((x, y) => y.mem - x.mem).slice(0, 6).map(x => ({ nombre: x.nombre, pid: x.pid, valor: tamano(x.mem) })));

        previa = { hora: ahora, stat: stat, io: io, pr: pr };
    }

    // Nombre comercial entre corchetes si lo hay: "GA104 [GeForce RTX 3070]"
    function corto(n) {
        const m = /\[([^\]]+)\]/.exec(n);
        return m ? m[1] : n;
    }
    function fabrica(f) {
        return f.replace(/\b(Corporation|Corp\.?|Inc\.?|Co\.,? Ltd\.?|Technologies|Semiconductor)\b/g, "").replace(/[ ,.]+$/, "").replace(/\s+/g, " ").trim();
    }

    onAbrio: {
        previa = null;
        historia = [];
        historiaRam = [];
        lecturaFija.running = true;
        if (!lecturaViva.running) lecturaViva.running = true;
        pronto.restart();
    }

    Process {
        id: lecturaFija
        command: [panel.script, "fija"]
        stdout: StdioCollector { onStreamFinished: panel.procesarFija(this.text) }
    }
    Process {
        id: lecturaViva
        command: [panel.script, "viva"]
        stdout: StdioCollector { onStreamFinished: if (panel.abierto) panel.procesarViva(this.text) }
    }
    // La segunda lectura llega antes: el uso necesita dos
    Timer {
        id: pronto
        interval: 700
        onTriggered: if (!lecturaViva.running) lecturaViva.running = true
    }
    Timer {
        interval: 2000
        repeat: true
        running: panel.abierto
        onTriggered: if (!lecturaViva.running) lecturaViva.running = true
    }

    // ---------- Piezas ----------
    component Barra: Rectangle {
        property real valor: 0        // 0 a 100
        property color tono: Tema.acento
        width: parent ? parent.width : 100
        height: 6
        radius: 3
        color: Tema.campo
        Rectangle {
            width: parent.width * Math.max(0, Math.min(100, parent.valor)) / 100
            height: parent.height
            radius: 3
            color: parent.tono
            Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
        }
    }

    // Cifra grande + gráfica de los últimos 2 minutos
    component Grafica: Item {
        id: gr
        property string cifra: ""
        property string detalle: ""
        property string detalle2: ""
        property var puntos: []
        property color tono: Tema.rosa
        width: parent ? parent.width : 400
        height: 72
        Column {
            id: textoGr
            width: 190
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1
            Text { text: gr.cifra; color: Tema.texto; font.family: Tema.fuenteBarra; font.pixelSize: 28; font.bold: true }
            Text { width: parent.width; elide: Text.ElideRight; text: gr.detalle; color: Tema.suave; font.family: Tema.fuenteBarra; font.pixelSize: 11 }
            Text { width: parent.width; elide: Text.ElideRight; visible: text !== ""; text: gr.detalle2; color: Tema.tenue; font.family: Tema.fuenteBarra; font.pixelSize: 11 }
        }
        Rectangle {
            anchors.left: textoGr.right
            anchors.leftMargin: 10
            anchors.right: parent.right
            height: parent.height
            radius: 10
            color: Tema.conAlfa(Tema.campo, 0.55)
            Canvas {
                id: lienzo
                anchors.fill: parent
                anchors.margins: 6
                readonly property var datos: gr.puntos
                onDatosChanged: requestPaint()
                onVisibleChanged: if (visible) requestPaint()
                onWidthChanged: requestPaint()
                onPaint: {
                    const c = getContext("2d");
                    c.reset();
                    const n = datos.length;
                    if (n < 2) return;
                    const paso = width / (panel.muestras - 1), x0 = width - (n - 1) * paso;
                    const y = v => height - 1 - Math.max(0, Math.min(100, v)) / 100 * (height - 2);
                    c.beginPath();
                    for (let i = 0; i < n; i++) c.lineTo(x0 + i * paso, y(datos[i]));
                    c.strokeStyle = gr.tono;
                    c.lineWidth = 2;
                    c.lineJoin = "round";
                    c.stroke();
                    c.lineTo(width, height);
                    c.lineTo(x0, height);
                    c.closePath();
                    c.fillStyle = Tema.conAlfa(gr.tono, 0.18);
                    c.fill();
                }
            }
        }
    }

    component Procesos: Column {
        id: pcs
        property string titulo: ""
        property var lista: []
        width: parent ? parent.width : 400
        spacing: 3
        TituloSeccion { texto: pcs.titulo }
        Repeater {
            model: pcs.lista
            Item {
                id: proceso
                required property var modelData
                width: pcs.width
                height: 20
                Text {
                    anchors.left: parent.left
                    anchors.right: valorP.left
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    elide: Text.ElideRight
                    textFormat: Text.PlainText
                    text: proceso.modelData.nombre
                    color: Tema.texto
                    font.family: Tema.fuenteBarra
                    font.pixelSize: 12
                }
                Text {
                    id: valorP
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: proceso.modelData.valor
                    color: Tema.suave
                    font.family: Tema.fuenteBarra
                    font.pixelSize: 12
                }
            }
        }
    }

    // Nombre del aparato con una línea de detalle
    component Aparato: FilaLista { resaltada: true }

    component Dispositivo: Item {
        id: dsp
        property string nombre: ""
        property string clase: ""
        property string extra: ""
        width: parent ? parent.width : 400
        height: 36
        Column {
            anchors.left: parent.left
            anchors.right: extraD.left
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            Text { width: parent.width; elide: Text.ElideRight; textFormat: Text.PlainText; text: dsp.nombre; color: Tema.texto; font.family: Tema.fuenteBarra; font.pixelSize: 12 }
            Text { width: parent.width; elide: Text.ElideRight; textFormat: Text.PlainText; text: dsp.clase; color: Tema.tenue; font.family: Tema.fuenteBarra; font.pixelSize: 10 }
        }
        Text { id: extraD; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; text: dsp.extra; color: Tema.suave; font.family: Tema.fuenteBarra; font.pixelSize: 11 }
    }

    // ---------- Pestañas ----------
    Row {
        id: filaPestanas
        width: parent.width
        spacing: 6
        Repeater {
            model: panel.pestanas
            Rectangle {
                id: pest
                required property var modelData
                readonly property bool activa: panel.pestana === modelData.id
                width: (filaPestanas.width - 4 * filaPestanas.spacing) / 5
                height: 34
                radius: 17
                color: activa ? Tema.acento : zonaP.containsMouse ? Tema.campoHover : Tema.campo
                Behavior on color { ColorAnimation { duration: 140 } }
                Row {
                    anchors.centerIn: parent
                    spacing: 6
                    Text { anchors.verticalCenter: parent.verticalCenter; text: String.fromCodePoint(pest.modelData.icono); color: pest.activa ? Tema.fondo : Tema.texto; font.family: Tema.fuenteBarra; font.pixelSize: 15 }
                    Text { anchors.verticalCenter: parent.verticalCenter; text: pest.modelData.texto; color: pest.activa ? Tema.fondo : Tema.texto; font.family: Tema.fuenteBarra; font.pixelSize: 12; font.bold: true }
                }
                MouseArea { id: zonaP; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: panel.pestana = pest.modelData.id }
            }
        }
    }

    // ---------- CPU ----------
    Column {
        visible: panel.pestana === "cpu"
        width: parent.width
        spacing: 10

        Aparato {
            icono: String.fromCodePoint(0xf0ee0)
            colorIcono: Tema.rosa
            titulo: String(panel.cpuInfo["Model name"] || "Procesador").replace(/\((R|TM)\)/g, "").replace(/\s+CPU\s+@.*/, "")
            subtitulo: {
                const i = panel.cpuInfo, n = Number(i["Core(s) per socket"]) * Number(i["Socket(s)"]);
                return n > 0 ? n + " núcleos · " + i["CPU(s)"] + " hilos · " + (i["Architecture"] || "") : " ";
            }
            detalle: panel.tempCpu ? panel.grados(panel.tempCpu.valor) : ""
            colorDetalle: Tema.ambar
        }
        Grafica {
            cifra: panel.uso + " %"
            detalle: panel.carga.length ? "Carga " + panel.carga.slice(0, 3).join(" · ") : ""
            detalle2: panel.carga.length > 3 ? "Tareas " + panel.carga[3] + " (activas/total)" : ""
            puntos: panel.historia
            tono: Tema.rosa
        }

        TituloSeccion { texto: "Núcleos" }
        Grid {
            id: rejillaN
            width: parent.width
            columns: panel.nucleos.length > 8 ? 4 : 2
            columnSpacing: 14
            rowSpacing: 8
            Repeater {
                // Por cantidad: las barras se animan en vez de rehacerse
                model: panel.nucleos.length
                Column {
                    id: nuc
                    required property int index
                    readonly property var d: panel.nucleos[index] || { uso: 0, mhz: 0 }
                    width: (rejillaN.width - rejillaN.columnSpacing * (rejillaN.columns - 1)) / rejillaN.columns
                    spacing: 3
                    Item {
                        width: parent.width
                        height: 15
                        Text { text: rejillaN.columns > 2 ? nuc.index : "Núcleo " + nuc.index; color: Tema.suave; font.family: Tema.fuenteBarra; font.pixelSize: 11 }
                        Text {
                            anchors.right: parent.right
                            text: (nuc.d.mhz > 0 && rejillaN.columns === 2 ? panel.mhz(nuc.d.mhz) + " · " : "") + nuc.d.uso + " %"
                            color: Tema.texto
                            font.family: Tema.fuenteBarra
                            font.pixelSize: 11
                        }
                    }
                    Barra { valor: nuc.d.uso; tono: Tema.rosa }
                }
            }
        }

        DatosRed {
            datos: {
                const i = panel.cpuInfo, c = k => String(i[k] || "").replace(/ \(\d+ instances?\)/, "");
                const f = k => Number(i[k]) > 0 ? panel.mhz(Number(i[k])) : "";
                return [
                    { n: "Frecuencia máxima", v: f("CPU max MHz") },
                    { n: "Frecuencia mínima", v: f("CPU min MHz") },
                    { n: "Gobernador", v: panel.gobernador.length ? panel.gobernador.filter(x => x).join(" · ") : "" },
                    { n: "Virtualización", v: i["Virtualization"] || "" },
                    { n: "Caché L1 (datos / instr.)", v: [c("L1d cache"), c("L1i cache")].filter(x => x).join(" / ") },
                    { n: "Caché L2", v: c("L2 cache") },
                    { n: "Caché L3", v: c("L3 cache") },
                    { n: "Familia y modelo", v: i["CPU family"] ? "Familia " + i["CPU family"] + ", modelo " + i["Model"] : "" }
                ];
            }
        }
        Procesos { titulo: "Procesos que más CPU usan"; lista: panel.procesosCpu }
    }

    // ---------- Memoria ----------
    Column {
        visible: panel.pestana === "memoria"
        width: parent.width
        spacing: 10

        Grafica {
            readonly property real usada: panel.mem.MemTotal ? (panel.mem.MemTotal - panel.mem.MemAvailable) * 1024 : 0
            cifra: panel.mem.MemTotal ? Math.round(usada / panel.mem.MemTotal / 10.24) + " %" : "—"
            detalle: panel.mem.MemTotal ? panel.tamano(usada) + " de " + panel.tamano(panel.mem.MemTotal * 1024) : ""
            puntos: panel.historiaRam
            tono: Tema.durazno
        }
        DatosRed {
            readonly property var m: panel.mem
            function t(k) { return m[k] !== undefined ? panel.tamano(m[k] * 1024) : ""; }
            datos: [
                { n: "Disponible", v: t("MemAvailable") },
                { n: "Libre", v: t("MemFree") },
                { n: "Caché", v: t("Cached") },
                { n: "Compartida", v: t("Shmem") }
            ]
        }
        TituloSeccion { visible: panel.swaps.length > 0; texto: "Intercambio" }
        Repeater {
            model: panel.swaps
            Column {
                id: sw
                required property var modelData
                width: parent.width
                spacing: 3
                Item {
                    width: parent.width
                    height: 15
                    Text { text: sw.modelData.nombre + (/^zram/.test(sw.modelData.nombre) ? " (memoria comprimida)" : ""); color: Tema.suave; font.family: Tema.fuenteBarra; font.pixelSize: 11 }
                    Text { anchors.right: parent.right; text: panel.tamano(sw.modelData.usado) + " de " + panel.tamano(sw.modelData.total); color: Tema.texto; font.family: Tema.fuenteBarra; font.pixelSize: 11 }
                }
                Barra { valor: 100 * sw.modelData.usado / sw.modelData.total; tono: Tema.durazno }
            }
        }
        TituloSeccion {
            visible: panel.modulos.length > 0
            texto: "Módulos instalados"
            extra: panel.modulos.length + " de " + panel.ranuras + " ranuras" + (panel.ramMaxima > 0 ? " · máximo " + panel.tamano(panel.ramMaxima) : "")
        }
        Repeater {
            model: panel.modulos
            Dispositivo {
                required property var modelData
                nombre: panel.tamano(modelData.tamano) + " " + modelData.tipo + (modelData.pieza ? " · " + modelData.pieza : "")
                clase: modelData.lugar + (modelData.forma ? " · " + modelData.forma : "")
                extra: modelData.velocidad > 0 ? modelData.velocidad + " MT/s" : ""
            }
        }
        Procesos { titulo: "Procesos que más memoria usan"; lista: panel.procesosMem }
    }

    // ---------- Gráficos ----------
    Column {
        visible: panel.pestana === "gpu"
        width: parent.width
        spacing: 10

        Repeater {
            model: panel.gpus
            Column {
                id: gpu
                required property var modelData
                readonly property var disp: panel.pci.find(p => p.ranura === modelData.ranura)
                readonly property var calor: panel.temperaturas.find(t => t.sensor === modelData.driver)
                readonly property var nv: modelData.driver === "nvidia" && panel.nvidia.length ? panel.nvidia[0] : null
                width: parent.width
                spacing: 8
                Aparato {
                    icono: String.fromCodePoint(0xf08ae)
                    colorIcono: Tema.verde
                    titulo: gpu.nv ? gpu.nv.nombre : gpu.disp ? panel.corto(gpu.disp.nombre) : gpu.modelData.tarjeta
                    subtitulo: gpu.disp ? panel.fabrica(gpu.disp.fabricante) : " "
                    detalle: gpu.nv ? gpu.nv.temp + " °C" : gpu.calor ? panel.grados(gpu.calor.valor) : ""
                    colorDetalle: Tema.ambar
                }
                DatosRed {
                    readonly property var g: gpu.modelData
                    datos: [
                        { n: "Controlador", v: g.driver },
                        { n: "Uso", v: gpu.nv ? gpu.nv.uso + " %" : g.uso !== "" ? g.uso + " %" : "" },
                        { n: "Frecuencia", v: gpu.nv ? gpu.nv.mhz + " MHz" : g.mhz !== "" ? g.mhz + " MHz" : "" },
                        { n: "Frecuencia máxima", v: gpu.nv ? gpu.nv.max + " MHz" : g.max !== "" ? g.max + " MHz" : "" },
                        { n: "Memoria de video", v: gpu.nv ? gpu.nv.usada + " de " + gpu.nv.total + " MiB" : g.vramTotal > 0 ? panel.tamano(g.vramUsada) + " de " + panel.tamano(g.vramTotal) : "Compartida con la RAM" },
                        { n: "Ranura PCI", v: g.ranura }
                    ]
                }
            }
        }
        TituloSeccion { visible: panel.monitores.length > 0; texto: "Monitores" }
        Repeater {
            model: panel.monitores
            Column {
                id: mon
                required property var modelData
                width: parent.width
                spacing: 8
                Aparato {
                    icono: String.fromCodePoint(0xf0379)
                    colorIcono: Tema.cian
                    titulo: [mon.modelData.make, mon.modelData.model].filter(x => x).join(" ") || mon.modelData.name
                    subtitulo: mon.modelData.name
                    detalle: mon.modelData.width + "×" + mon.modelData.height
                    colorDetalle: Tema.cian
                }
                DatosRed {
                    readonly property var m: mon.modelData
                    readonly property real pulgadas: Math.sqrt(m.physicalWidth * m.physicalWidth + m.physicalHeight * m.physicalHeight) / 25.4
                    datos: [
                        { n: "Frecuencia", v: Number(m.refreshRate).toFixed(2) + " Hz" },
                        { n: "Escala", v: m.scale !== undefined ? "" + m.scale : "" },
                        { n: "Tamaño físico", v: m.physicalWidth > 0 ? (m.physicalWidth / 10) + " × " + (m.physicalHeight / 10) + " cm (" + pulgadas.toFixed(1) + "″)" : "" },
                        { n: "Formato", v: m.currentFormat || "" }
                    ]
                }
            }
        }
    }

    // ---------- Discos ----------
    Column {
        visible: panel.pestana === "discos"
        width: parent.width
        spacing: 10

        Repeater {
            model: panel.discos.length
            Column {
                id: disco
                required property int index
                readonly property var d: panel.discos[index] || { partes: [], modelo: "", clase: "", conexion: "", nombre: "", tamano: 0, temp: 0, lee: 0, escribe: 0, ocupado: 0, leido: 0, escrito: 0 }
                width: parent.width
                spacing: 8
                Aparato {
                    icono: String.fromCodePoint(disco.d.clase === "USB" ? 0xf129e : 0xf02ca)
                    colorIcono: Tema.cian
                    titulo: disco.d.modelo
                    subtitulo: [disco.d.clase, disco.d.conexion !== disco.d.clase ? disco.d.conexion : "", disco.d.nombre].filter(x => x).join(" · ")
                    detalle: panel.tamano(disco.d.tamano, 1000) + (disco.d.temp > 0 ? " · " + panel.grados(disco.d.temp) : "")
                    colorDetalle: Tema.cian
                }
                Row {
                    spacing: 18
                    leftPadding: 10
                    Repeater {
                        model: [
                            ["Lectura", panel.tamano(disco.d.lee, 1000) + "/s"], ["Escritura", panel.tamano(disco.d.escribe, 1000) + "/s"],
                            ["Actividad", disco.d.ocupado + " %"],
                            ["Leído / escrito", panel.tamano(disco.d.leido, 1000) + " / " + panel.tamano(disco.d.escrito, 1000)]
                        ]
                        Column {
                            id: cifraD
                            required property var modelData
                            width: 104
                            Text { text: cifraD.modelData[0]; color: Tema.tenue; font.family: Tema.fuenteBarra; font.pixelSize: 10 }
                            Text { text: cifraD.modelData[1]; color: Tema.texto; font.family: Tema.fuenteBarra; font.pixelSize: 12 }
                        }
                    }
                }
                Repeater {
                    model: disco.d.partes.length
                    Column {
                        id: parte
                        required property int index
                        readonly property var p: disco.d.partes[index] || { donde: "", otras: 0, fs: "", nombre: "", usado: 0, total: 1 }
                        x: 10
                        width: disco.width - 20
                        spacing: 3
                        Item {
                            width: parent.width
                            height: 15
                            Text {
                                anchors.left: parent.left
                                anchors.right: usoParte.left
                                anchors.rightMargin: 8
                                elide: Text.ElideRight
                                text: parte.p.donde + (parte.p.otras > 0 ? " (+" + parte.p.otras + ")" : "") + "  " + parte.p.nombre + " · " + parte.p.fs
                                color: Tema.suave
                                font.family: Tema.fuenteBarra
                                font.pixelSize: 11
                            }
                            Text {
                                id: usoParte
                                anchors.right: parent.right
                                text: panel.tamano(parte.p.usado, 1000) + " de " + panel.tamano(parte.p.total, 1000) + " · " + Math.round(100 * parte.p.usado / parte.p.total) + " %"
                                color: Tema.texto
                                font.family: Tema.fuenteBarra
                                font.pixelSize: 11
                            }
                        }
                        Barra { valor: 100 * parte.p.usado / parte.p.total; tono: Tema.cian }
                    }
                }
            }
        }
    }

    // ---------- Equipo ----------
    Column {
        visible: panel.pestana === "equipo"
        width: parent.width
        spacing: 10

        DatosRed {
            // Muchas placas traen textos de relleno
            function limpio(t) { return /^(system manufacturer|system product name|to be filled|default string|o\.e\.m)/i.test(t || "") ? "" : t || ""; }
            datos: [
                { n: "Equipo", v: [limpio(panel.dmi.sys_vendor), limpio(panel.dmi.product_name)].filter(x => x).join(" ") },
                { n: "Placa base", v: [limpio(panel.dmi.board_vendor), limpio(panel.dmi.board_name)].filter(x => x).join(" ") },
                { n: "BIOS", v: panel.dmi.bios_version ? [panel.dmi.bios_vendor, panel.dmi.bios_version].filter(x => x).join(" ") : "" },
                { n: "Fecha de la BIOS", v: panel.dmi.bios_date || "" },
                { n: "Sistema", v: panel.so.length ? panel.so[0] + " (" + panel.so[2] + ")" : "" },
                { n: "Kernel", v: panel.so.length ? panel.so[1] : "" },
                { n: "Nombre del equipo", v: panel.so.length ? panel.so[3] : "" },
                { n: "Arranque", v: panel.arranque },
                { n: "Encendido", v: panel.encendido > 0 ? panel.duracion(panel.encendido) : "" }
            ]
        }

        TituloSeccion { visible: panel.temperaturas.length + panel.ventiladores.length > 0; texto: "Sensores" }
        DatosRed {
            visible: datos.length > 0
            readonly property var nombres: ({ coretemp: "Procesador", k10temp: "Procesador", zenpower: "Procesador", acpitz: "Placa", amdgpu: "Gráficos", nouveau: "Gráficos", nvme: "Disco", drivetemp: "Disco", iwlwifi_1: "Wi-Fi" })
            datos: panel.temperaturas.map((t, i) => ({
                n: (nombres[t.sensor] || t.sensor) + " · " + (t.disco || t.nombre.replace("Package id 0", "conjunto").replace("Core ", "núcleo ") || "sensor " + (i + 1)),
                v: panel.grados(t.valor)
            })).concat(panel.ventiladores.map((v, i) => ({ n: v.nombre || "Ventilador " + (i + 1), v: v.rpm + " rpm" })))
        }

        TituloSeccion { texto: "Dispositivos internos (PCI)" }
        Repeater {
            // Sin los puentes y piezas internas del chipset
            model: panel.pci.filter(p => !/bridge|communication controller|signal processing|smbus|system peripheral|host/i.test(p.clase))
            Dispositivo {
                required property var modelData
                nombre: panel.fabrica(modelData.fabricante) + " " + (/VGA|3D|Display/.test(modelData.clase) ? panel.corto(modelData.nombre) : modelData.nombre)
                clase: {
                    const t = { "VGA compatible controller": "Gráficos", "3D controller": "Gráficos 3D", "Display controller": "Gráficos", "Audio device": "Audio",
                                "Ethernet controller": "Ethernet", "Network controller": "Wi-Fi", "SATA controller": "SATA", "USB controller": "USB",
                                "Non-Volatile memory controller": "NVMe", "IDE interface": "IDE" };
                    return t[modelData.clase] || modelData.clase;
                }
                extra: modelData.driver
            }
        }
        TituloSeccion { visible: panel.usb.length > 0; texto: "Dispositivos USB" }
        Repeater {
            model: panel.usb
            Dispositivo {
                required property var modelData
                nombre: modelData.producto
                clase: modelData.fabricante
                extra: modelData.velocidad >= 1000 ? modelData.velocidad / 1000 + " Gb/s" : modelData.velocidad > 0 ? modelData.velocidad + " Mb/s" : ""
            }
        }
    }
}
