// ==========================================================
// Lanzador: aplicaciones, fondos y sesión en una lista con iconos
// - Aplicaciones: las que más abres primero, el resto por categoría
// - Fondos: Enter aplica al escritorio, Shift+Enter al bloqueo
// - Sesión: bloquear, suspender, cerrar sesión, reiniciar, apagar
//   (las tres últimas piden confirmación)
// - Al escribir se busca en todo a la vez
// - Empieza con ">" para ejecutar un comando (por ejemplo: >kitty -e htop)
// Teclas: flechas para moverse, Tab cambia de sección, Enter abrir,
// 1-5 eligen en Sesión, Escape cancela o cierra
//
//   qs -c escritorio ipc call lanzador alternar
// ==========================================================
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import qs.Comun

Scope {
    id: lanzador

    readonly property string home: Quickshell.env("HOME")
    readonly property string scriptFondos: home + "/.local/bin/fondos"
    readonly property int altoLista: 440
    readonly property int masUsadas: 5

    property var usos: ({})
    property string consulta: ""
    property string seccion: "apps"       // "apps", "fondos" o "sesion"
    property string porConfirmar: ""
    property string tiempoEncendido: ""

    property string carpeta: ""
    property var imagenes: []
    property string fondoEscritorio: ""
    property string fondoBloqueo: ""

    function glifo(c) { return String.fromCodePoint(c); }

    readonly property var secciones: [
        { id: "apps",   icono: glifo(0xf003b), texto: "Aplicaciones" },
        { id: "fondos", icono: glifo(0xf02e9), texto: "Fondos" },
        { id: "sesion", icono: glifo(0xf0425), texto: "Sesión" }
    ]

    readonly property var opcionesSesion: [
        { id: "bloquear",  icono: glifo(0xf033e), texto: "Bloquear",      detalle: "Pedir la contraseña para volver", claves: ["lock"] },
        { id: "suspender", icono: glifo(0xf0904), texto: "Suspender",     detalle: "Bloquear y dormir el equipo", claves: ["dormir", "sleep"] },
        { id: "salir",     icono: glifo(0xf0343), texto: "Cerrar sesión", detalle: "Volver a la pantalla de inicio", claves: ["salir", "logout"], confirmar: true },
        { id: "reiniciar", icono: glifo(0xf0709), texto: "Reiniciar",     detalle: "Reiniciar el equipo", claves: ["reboot"], confirmar: true },
        { id: "apagar",    icono: glifo(0xf0425), texto: "Apagar",        detalle: "Apagar el equipo", claves: ["poweroff", "shutdown"], confirmar: true, peligro: true }
    ]

    // Categorías de las apps, en el orden en que se muestran. Cada app va
    // a la primera que coincida con su archivo .desktop
    readonly property var categorias: [
        { nombre: "Internet",     claves: ["Network", "WebBrowser", "Email"] },
        { nombre: "Desarrollo",   claves: ["Development", "IDE"] },
        { nombre: "Multimedia",   claves: ["AudioVideo", "Audio", "Video", "Player"] },
        { nombre: "Gráficos",     claves: ["Graphics", "Photography"] },
        { nombre: "Oficina",      claves: ["Office", "Education"] },
        { nombre: "Juegos",       claves: ["Game"] },
        { nombre: "Configuración", claves: ["Settings", "DesktopSettings"] },
        { nombre: "Sistema",      claves: ["System", "TerminalEmulator", "Monitor", "FileManager"] },
        { nombre: "Utilidades",   claves: ["Utility", "Accessibility"] }
    ]

    function categoriaDe(e) {
        const c = e.categories || [];
        for (let i = 0; i < categorias.length; i++)
            for (let j = 0; j < c.length; j++)
                if (categorias[i].claves.indexOf(String(c[j])) >= 0) return categorias[i].nombre;
        return "Otras";
    }

    // ---------- Busqueda ----------
    function normalizar(t) {
        let s = String(t || "").toLowerCase();
        try { s = s.normalize("NFD").replace(/[̀-ͯ]/g, ""); } catch (e) {}
        return s;
    }

    function puntuar(titulo, extra, q, flexible) {
        const nombre = normalizar(titulo);
        if (nombre === q) return 1000;
        if (nombre.startsWith(q)) return 800;
        const palabras = nombre.split(/[\s\-_.]+/);
        for (let i = 0; i < palabras.length; i++) {
            if (palabras[i].startsWith(q)) return 600;
        }
        if (nombre.includes(q)) return 400;
        if (normalizar(extra).includes(q)) return 200;
        if (!flexible) return 0;
        // Letras en orden ("ffx" -> "firefox")
        let j = 0;
        for (let i = 0; i < nombre.length && j < q.length; i++) {
            if (nombre[i] === q[j]) j++;
        }
        return j === q.length ? 100 : 0;
    }

    readonly property var apps: {
        const vistos = {}, lista = [];
        const todas = DesktopEntries.applications.values;
        for (let i = 0; i < todas.length; i++) {
            const e = todas[i];
            if (!e || e.noDisplay || vistos[e.id]) continue;
            vistos[e.id] = true;
            lista.push(e);
        }
        lista.sort((a, b) => String(a.name).localeCompare(String(b.name)));
        return lista;
    }

    function filaApp(e) { return { tipo: "app", id: e.id, entrada: e, texto: String(e.name), detalle: String(e.comment || e.genericName || "") }; }
    function filaFondo(n) { return { tipo: "fondo", id: n, texto: n.replace(/\.[^.]+$/, ""), detalle: "", ruta: carpeta + "/" + n }; }
    function filaSesion(o) { return { tipo: "sesion", id: o.id, texto: o.texto, detalle: o.detalle, opcion: o }; }
    function titulo(t) { return { tipo: "titulo", texto: t }; }

    // Filas de la lista; las de tipo "titulo" no se pueden elegir
    readonly property var filas: {
        const texto = consulta.trim();

        if (texto.startsWith(">")) {
            const comando = texto.substring(1).trim();
            return comando === "" ? [] : [{ tipo: "comando", texto: comando, detalle: "Ejecutar comando" }];
        }

        if (texto !== "") return buscarTodo(texto);

        if (seccion === "fondos")
            return imagenes.length ? [titulo("Fondos de pantalla")].concat(imagenes.map(filaFondo)) : [];

        if (seccion === "sesion")
            return [titulo("Sesión")].concat(opcionesSesion.map(filaSesion));

        // Aplicaciones: más usadas y luego por categoría
        const usadas = apps.filter(e => usos[e.id] > 0)
                           .sort((a, b) => usos[b.id] - usos[a.id]).slice(0, masUsadas);
        let r = [];
        if (usadas.length) r = [titulo("Más usadas")].concat(usadas.map(filaApp));
        const grupos = {};
        for (const e of apps) {
            if (usadas.indexOf(e) >= 0) continue;
            const c = categoriaDe(e);
            (grupos[c] = grupos[c] || []).push(filaApp(e));
        }
        for (const c of categorias.map(x => x.nombre).concat(["Otras"]))
            if (grupos[c]) r = r.concat([titulo(c)], grupos[c]);
        return r;
    }

    function buscarTodo(texto) {
        const q = normalizar(texto);
        const grupos = [
            { nombre: "Aplicaciones", filas: apps.map(e => {
                const extra = [e.genericName || "", Array.from(e.keywords || []).join(" "), e.comment || ""].join(" ");
                const p = puntuar(e.name, extra, q, true);
                return { p: p > 0 ? p + Math.min((usos[e.id] || 0) * 15, 150) : 0, f: filaApp(e) };
            }) },
            { nombre: "Sesión", filas: opcionesSesion.map(o => ({ p: puntuar(o.texto, o.claves.join(" "), q, false), f: filaSesion(o) })) },
            { nombre: "Fondos", filas: imagenes.map(n => ({ p: puntuar(n, "", q, false), f: filaFondo(n) })) }
        ];
        let r = [];
        for (const g of grupos) {
            g.filas = g.filas.filter(x => x.p > 0).sort((a, b) => b.p - a.p);
            g.mejor = g.filas.length ? g.filas[0].p : 0;
        }
        // Primero el grupo con la mejor coincidencia
        grupos.sort((a, b) => b.mejor - a.mejor);
        for (const g of grupos)
            if (g.filas.length) r = r.concat([titulo(g.nombre)], g.filas.map(x => x.f));
        // Si no hay nada, ofrecer ejecutarlo como comando
        return r.length ? r : [{ tipo: "comando", texto: texto, detalle: "Ejecutar comando" }];
    }

    function iconoDe(e) {
        const i = String(e.icon || "");
        if (i === "") return "";
        if (i.startsWith("/")) return "file://" + i;
        return Quickshell.iconPath(i, true);
    }

    // ---------- Navegación ----------
    readonly property var actual: filas[lista.currentIndex] || null

    onFilasChanged: Qt.callLater(irAlInicio)

    function irAlInicio() {
        porConfirmar = "";
        let i = filas.findIndex(f => f.tipo !== "titulo");
        // En Fondos, empezar por el que está en uso
        if (seccion === "fondos" && consulta.trim() === "") {
            const j = filas.findIndex(f => f.ruta === fondoEscritorio);
            if (j >= 0) i = j;
        }
        lista.currentIndex = i;
        if (i <= 1) lista.positionViewAtBeginning();
        else lista.positionViewAtIndex(i, ListView.Center);
    }

    // El ratón quieto no elige: al abrir o desplazar la lista también llegan
    // eventos, pero con la misma posición en la pantalla
    property var ultimoRaton: null
    function ratonSeMovio(p) {
        const u = ultimoRaton;
        ultimoRaton = p;
        return u !== null && (Math.abs(u.x - p.x) > 1 || Math.abs(u.y - p.y) > 1);
    }

    function elegir(i) {
        if (i === lista.currentIndex) return;
        porConfirmar = "";
        lista.currentIndex = i;
    }

    function mover(paso) {
        const n = filas.length;
        let i = lista.currentIndex;
        for (let k = 0; k < n; k++) {
            i = (i + paso + n) % n;
            if (filas[i].tipo !== "titulo") { elegir(i); break; }
        }
        if (i <= 1) lista.positionViewAtBeginning();   // deja ver el primer título
        else lista.positionViewAtIndex(i, ListView.Contain);
    }

    function saltar(paso) {
        for (let k = 0; k < 6; k++) {
            const antes = lista.currentIndex;
            const siguiente = antes + paso;
            if (siguiente < 0 || siguiente >= filas.length) break;
            mover(paso);
            if ((lista.currentIndex - antes) * paso < 0) { mover(-paso); break; }
        }
    }

    function irASeccion(id) {
        porConfirmar = "";
        seccion = id;
        if (campo.text !== "") campo.text = "";
        Qt.callLater(irAlInicio);
        campo.forceActiveFocus();
    }

    function cambiarSeccion(paso) {
        const i = secciones.findIndex(s => s.id === seccion);
        irASeccion(secciones[(i + paso + secciones.length) % secciones.length].id);
    }

    function abrirEn(id) {
        seccion = id;
        sup.abrir();
    }

    // ---------- Abrir ----------
    function activar(f, alterno) {
        if (!f || f.tipo === "titulo") return;

        if (f.tipo === "fondo") {
            // Se queda abierto, para probar varios
            if (alterno) fondoBloqueo = f.ruta;
            else fondoEscritorio = f.ruta;
            Quickshell.execDetached([scriptFondos, alterno ? "bloqueo" : "escritorio", f.ruta]);
            return;
        }

        if (f.tipo === "sesion") {
            if (f.opcion.confirmar && porConfirmar !== f.id) {
                porConfirmar = f.id;
                return;
            }
            sup.cerrar();
            ejecutarSesion(f.id);
            return;
        }

        if (f.tipo === "comando") {
            Quickshell.execDetached(["sh", "-c", f.texto]);
        } else {
            const e = f.entrada;
            if (e.runInTerminal) {
                const cmd = [];
                const c = e.command || [];
                for (let i = 0; i < c.length; i++) {
                    if (!/^%[a-zA-Z]$/.test(String(c[i]))) cmd.push(String(c[i]));
                }
                Quickshell.execDetached(["kitty", "-e"].concat(cmd));
            } else {
                e.execute();
            }
            const u = Object.assign({}, usos);
            u[e.id] = (u[e.id] || 0) + 1;
            usos = u;
            archivoUsos.setText(JSON.stringify(u));
        }
        sup.cerrar();
    }

    function ejecutarSesion(id) {
        if (id === "bloquear") {
            Quickshell.execDetached([home + "/.local/bin/bloquear"]);
        } else if (id === "suspender") {
            Quickshell.execDetached(["sh", "-c", "\"$HOME/.local/bin/bloquear\" & sleep 1; systemctl suspend"]);
        } else if (id === "salir") {
            // Cierra Hyprland de forma ordenada; greetd vuelve a mostrar el inicio de sesion.
            // Con uwsm se usa "uwsm stop"; si Hyprland no responde, se termina la sesion de logind.
            Quickshell.execDetached(["sh", "-c", "if command -v uwsm >/dev/null 2>&1 && uwsm check is-active >/dev/null 2>&1; then uwsm stop; else hyprctl dispatch 'hl.dsp.exit()' || loginctl terminate-session \"$XDG_SESSION_ID\"; fi"]);
        } else if (id === "reiniciar") {
            Quickshell.execDetached(["systemctl", "reboot"]);
        } else if (id === "apagar") {
            Quickshell.execDetached(["systemctl", "poweroff"]);
        }
    }

    // Cuantas veces se ha abierto cada app (para ordenar)
    FileView {
        id: archivoUsos
        path: lanzador.home + "/.cache/quickshell-lanzador.json"
        printErrors: false
        onLoaded: {
            try { lanzador.usos = JSON.parse(text()); } catch (e) {}
        }
    }

    // Salida de "fondos listar": carpeta --- imagenes --- escritorio --- bloqueo
    Process {
        id: listarFondos
        command: [lanzador.scriptFondos, "listar"]
        stdout: StdioCollector {
            onStreamFinished: {
                const p = this.text.split("---\n");
                lanzador.carpeta = (p[0] || "").trim();
                lanzador.fondoEscritorio = (p[2] || "").trim();
                lanzador.fondoBloqueo = (p[3] || "").trim();
                const l = (p[1] || "").split("\n").map(s => s.trim()).filter(s => s !== "");
                // Solo si cambiaron, para no mover la selección
                if (JSON.stringify(l) !== JSON.stringify(lanzador.imagenes)) lanzador.imagenes = l;
            }
        }
    }

    // Tiempo encendido: "3h 12m"
    Process {
        id: lecturaUptime
        command: ["cat", "/proc/uptime"]
        stdout: StdioCollector {
            onStreamFinished: {
                const s = Math.floor(parseFloat(this.text) || 0);
                const h = Math.floor(s / 3600);
                const m = Math.floor((s % 3600) / 60);
                lanzador.tiempoEncendido = h > 0 ? h + "h " + m + "m" : m + "m";
            }
        }
    }

    IpcHandler {
        target: "lanzador"
        function alternar(): void { if (sup.abierto) sup.cerrar(); else lanzador.abrirEn("apps"); }
        function abrir(): void { lanzador.abrirEn("apps"); }
        function cerrar(): void { sup.cerrar(); }
    }

    Superposicion {
        id: sup
        ancho: 860
        posicionY: 0.18

        onAbrio: {
            lanzador.ultimoRaton = null;
            campo.text = "";
            lecturaUptime.running = true;
            listarFondos.running = true;
            Qt.callLater(lanzador.irAlInicio);
            Qt.callLater(() => campo.forceActiveFocus());
        }
        onCerro: lanzador.porConfirmar = ""

        // ---------- Barra de busqueda ----------
        Rectangle {
            width: parent.width
            height: 52
            radius: 14
            color: Tema.campo
            border.width: 1
            border.color: campo.activeFocus ? Tema.conAlfa(Tema.acento, 0.6) : Tema.borde

            Text {
                id: lupa
                anchors.left: parent.left
                anchors.leftMargin: 18
                anchors.verticalCenter: parent.verticalCenter
                text: lanzador.consulta.trim().startsWith(">") ? "󰆍" : "󰍉"
                color: Tema.acento
                font.family: Tema.fuenteBarra
                font.pixelSize: 20
            }

            TextInput {
                id: campo
                anchors.left: lupa.right
                anchors.leftMargin: 14
                anchors.right: parent.right
                anchors.rightMargin: 18
                anchors.verticalCenter: parent.verticalCenter
                color: Tema.texto
                selectionColor: Tema.acento
                font.family: Tema.fuenteBarra
                font.pixelSize: 16
                clip: true
                focus: true

                onTextChanged: lanzador.consulta = text

                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Escape) {
                        if (lanzador.porConfirmar !== "") lanzador.porConfirmar = "";
                        else sup.cerrar();
                    } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        // Mantener Enter presionado no confirma un apagado
                        if (!event.isAutoRepeat)
                            lanzador.activar(lanzador.actual, (event.modifiers & Qt.ShiftModifier) !== 0);
                    } else if (event.key === Qt.Key_Tab) {
                        lanzador.cambiarSeccion(1);
                    } else if (event.key === Qt.Key_Backtab) {
                        lanzador.cambiarSeccion(-1);
                    } else if (event.key === Qt.Key_Down) {
                        lanzador.mover(1);
                    } else if (event.key === Qt.Key_Up) {
                        lanzador.mover(-1);
                    } else if (event.key === Qt.Key_PageDown) {
                        lanzador.saltar(1);
                    } else if (event.key === Qt.Key_PageUp) {
                        lanzador.saltar(-1);
                    } else if (lanzador.seccion === "sesion" && text === "" && event.key >= Qt.Key_1 && event.key <= Qt.Key_5) {
                        lanzador.elegir(event.key - Qt.Key_1 + 1);   // la fila 0 es el título
                    } else {
                        return;
                    }
                    event.accepted = true;
                }
            }

            Text {
                anchors.left: campo.left
                anchors.verticalCenter: parent.verticalCenter
                visible: campo.text.length === 0
                text: "Buscar aplicaciones, fondos y acciones…"
                color: Tema.tenue
                font.family: Tema.fuenteBarra
                font.pixelSize: 16
            }
        }

        // ---------- Secciones y lista ----------
        Row {
            width: parent.width
            spacing: 14

            Item {
                id: lateral
                width: 176
                height: lanzador.altoLista

                Column {
                    width: parent.width
                    spacing: 6

                    Repeater {
                        model: lanzador.secciones

                        delegate: Rectangle {
                            id: boton

                            required property var modelData
                            readonly property bool activa: lanzador.seccion === modelData.id && lanzador.consulta.trim() === ""

                            width: lateral.width
                            height: 44
                            radius: 12
                            color: activa ? Tema.acento : zonaBoton.containsMouse ? Tema.campoHover : "transparent"
                            Behavior on color { ColorAnimation { duration: 120 } }

                            Row {
                                anchors.left: parent.left
                                anchors.leftMargin: 14
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 12
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: boton.modelData.icono
                                    color: boton.activa ? Tema.fondo : boton.modelData.id === "sesion" ? Tema.error : Tema.acento
                                    font.family: Tema.fuenteBarra
                                    font.pixelSize: 18
                                }
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: boton.modelData.texto
                                    color: boton.activa ? Tema.fondo : Tema.texto
                                    font.family: Tema.fuenteBarra
                                    font.pixelSize: 13
                                    font.bold: true
                                }
                            }

                            MouseArea {
                                id: zonaBoton
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: lanzador.irASeccion(boton.modelData.id)
                            }
                        }
                    }
                }

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 14
                    anchors.bottom: parent.bottom
                    text: "Encendido " + lanzador.tiempoEncendido
                    color: Tema.tenue
                    font.family: Tema.fuenteBarra
                    font.pixelSize: 11
                }
            }

            Rectangle {
                width: 1
                height: lanzador.altoLista
                color: Tema.borde
            }

            ListView {
                id: lista

                width: parent.width - lateral.width - 1 - parent.spacing * 2
                height: lanzador.altoLista
                clip: true
                spacing: 2
                model: lanzador.filas
                boundsBehavior: Flickable.StopAtBounds
                highlightFollowsCurrentItem: false
                keyNavigationEnabled: false

                Text {
                    anchors.centerIn: parent
                    width: parent.width - 40
                    visible: lista.count === 0
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                    text: lanzador.consulta.trim() !== "" ? "Escribe el comando a ejecutar"
                        : lanzador.seccion === "fondos" ? "No hay imágenes en " + lanzador.carpeta : "Sin elementos"
                    color: Tema.tenue
                    font.family: Tema.fuenteBarra
                    font.pixelSize: 13
                }

                delegate: Item {
                    id: fila

                    required property var modelData
                    required property int index

                    readonly property string tipo: modelData.tipo
                    readonly property bool elegida: index === lista.currentIndex
                    readonly property bool confirmando: tipo === "sesion" && lanzador.porConfirmar === modelData.id
                    readonly property bool peligro: tipo === "sesion" && modelData.opcion.peligro === true

                    width: lista.width
                    height: tipo === "titulo" ? 30 : tipo === "fondo" ? 66 : 50

                    // Título de categoría
                    Text {
                        visible: fila.tipo === "titulo"
                        anchors.left: parent.left
                        anchors.leftMargin: 10
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 6
                        text: fila.modelData.texto
                        color: Tema.acento
                        font.family: Tema.fuenteBarra
                        font.pixelSize: 12
                        font.bold: true
                    }

                    Rectangle {
                        visible: fila.tipo !== "titulo"
                        anchors.fill: parent
                        radius: 12
                        color: fila.confirmando ? Tema.conAlfa(Tema.error, 0.35)
                             : fila.elegida ? Tema.conAlfa(fila.peligro ? Tema.error : Tema.acento, 0.22) : "transparent"
                        border.width: fila.elegida ? 1 : 0
                        border.color: Tema.conAlfa(fila.peligro || fila.confirmando ? Tema.error : Tema.acento, 0.7)
                        Behavior on color { ColorAnimation { duration: 100 } }

                        // Icono, miniatura o símbolo
                        Item {
                            id: zonaIcono
                            anchors.left: parent.left
                            anchors.leftMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            width: fila.tipo === "fondo" ? 96 : 34
                            height: fila.tipo === "fondo" ? 54 : 34

                            Image {
                                id: imagen
                                anchors.fill: parent
                                visible: status === Image.Ready
                                source: fila.tipo === "app" ? lanzador.iconoDe(fila.modelData.entrada) : ""
                                sourceSize.width: 68
                                sourceSize.height: 68
                                asynchronous: true
                            }

                            ClippingRectangle {
                                anchors.fill: parent
                                visible: fila.tipo === "fondo"
                                radius: 8
                                color: Tema.campo
                                Image {
                                    anchors.fill: parent
                                    source: fila.tipo === "fondo" ? "file://" + fila.modelData.ruta : ""
                                    sourceSize.width: 192
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                }
                            }

                            Text {
                                anchors.centerIn: parent
                                visible: fila.tipo !== "fondo" && fila.tipo !== "titulo" && !imagen.visible
                                text: fila.confirmando ? lanzador.glifo(0xf002a)
                                    : fila.tipo === "sesion" ? fila.modelData.opcion.icono
                                    : fila.tipo === "comando" ? "󰆍" : "󰘔"
                                color: fila.peligro || fila.confirmando ? Tema.error : Tema.acento
                                font.family: Tema.fuenteBarra
                                font.pixelSize: 24
                            }
                        }

                        Column {
                            anchors.left: zonaIcono.right
                            anchors.leftMargin: 14
                            anchors.right: marcas.left
                            anchors.rightMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 1

                            Text {
                                width: parent.width
                                elide: Text.ElideRight
                                textFormat: Text.PlainText
                                text: fila.modelData.texto
                                color: fila.peligro ? Tema.error : Tema.texto
                                font.family: Tema.fuenteBarra
                                font.pixelSize: 14
                                font.bold: fila.elegida
                            }
                            Text {
                                width: parent.width
                                visible: text !== ""
                                elide: Text.ElideRight
                                textFormat: Text.PlainText
                                text: fila.confirmando ? "Presiona otra vez para confirmar" : fila.modelData.detalle || ""
                                color: fila.confirmando ? Tema.error : Tema.tenue
                                font.family: Tema.fuenteBarra
                                font.pixelSize: 11
                            }
                        }

                        // Marcas: fondo en uso o número de la opción
                        Row {
                            id: marcas
                            z: 1
                            anchors.right: parent.right
                            anchors.rightMargin: 14
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 12

                            Repeater {
                                model: fila.tipo !== "fondo" ? [] : [
                                    { alterno: false, icono: 0xf0379, texto: "Escritorio" },
                                    { alterno: true,  icono: 0xf033e, texto: "Bloqueo" }
                                ]
                                delegate: Rectangle {
                                    id: marca
                                    required property var modelData
                                    readonly property bool enUso: fila.modelData.ruta === (modelData.alterno ? lanzador.fondoBloqueo : lanzador.fondoEscritorio)
                                    visible: enUso || fila.elegida
                                    width: textoMarca.implicitWidth + 18
                                    height: 28
                                    radius: 14
                                    color: enUso ? Tema.acento : zonaMarca.containsMouse ? Tema.campoHover : Tema.campo
                                    Text {
                                        id: textoMarca
                                        anchors.centerIn: parent
                                        text: lanzador.glifo(marca.modelData.icono) + " " + marca.modelData.texto
                                        color: marca.enUso ? Tema.fondo : Tema.suave
                                        font.family: Tema.fuenteBarra
                                        font.pixelSize: 11
                                    }
                                    MouseArea {
                                        id: zonaMarca
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            lanzador.elegir(fila.index);
                                            lanzador.activar(fila.modelData, marca.modelData.alterno);
                                        }
                                    }
                                }
                            }

                            Text {
                                visible: fila.tipo === "sesion" && lanzador.consulta.trim() === ""
                                text: fila.index
                                color: Tema.tenue
                                font.family: Tema.fuenteBarra
                                font.pixelSize: 12
                            }
                        }

                        // Detrás de las marcas. Solo el movimiento real del ratón
                        // selecciona (no el desplazamiento bajo el cursor)
                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onPositionChanged: mouse => {
                                if (lanzador.ratonSeMovio(mapToItem(null, mouse.x, mouse.y))) lanzador.elegir(fila.index);
                            }
                            onClicked: {
                                lanzador.elegir(fila.index);
                                lanzador.activar(fila.modelData, false);
                            }
                        }
                    }
                }
            }
        }

        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: lanzador.actual && lanzador.actual.tipo === "fondo"
                  ? "Enter escritorio   ·   Shift+Enter bloqueo   ·   Tab sección   ·   Esc cerrar"
                  : lanzador.actual && lanzador.actual.tipo === "sesion"
                  ? "↑↓ o 1-5 elegir   ·   Enter ejecutar   ·   Tab sección   ·   Esc cerrar"
                  : "↑↓ moverse   ·   Enter abrir   ·   Tab sección   ·   >comando ejecutar   ·   Esc cerrar"
            color: Tema.conAlfa(Tema.tenue, 0.8)
            font.family: Tema.fuenteBarra
            font.pixelSize: 11
        }
    }
}
