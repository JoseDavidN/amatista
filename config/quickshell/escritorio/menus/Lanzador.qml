// ==========================================================
// Lanzador de aplicaciones (reemplaza a rofi -show drun)
// - Cuadricula de iconos; las que mas abres aparecen primero
// - Busca por nombre, nombre generico, palabras clave y descripcion
// - Las apps que mas abres suben en la lista
// - Empieza con ">" para ejecutar un comando (por ejemplo: >kitty -e htop)
// Teclas: flechas o Tab para moverse, Enter abrir, Escape cerrar
// Raton: pasar por encima selecciona, clic abre, rueda desplaza
//
//   qs -c escritorio ipc call lanzador alternar
// ==========================================================
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Comun

Scope {
    id: lanzador

    readonly property int columnas: 6
    readonly property int filasVisibles: 3
    readonly property int altoCelda: 118

    readonly property bool modoComando: resultados.length === 1 && resultados[0].tipo === "comando"

    property var usos: ({})
    property string consulta: ""

    // ---------- Busqueda ----------
    function normalizar(t) {
        let s = String(t || "").toLowerCase();
        try { s = s.normalize("NFD").replace(/[\u0300-\u036f]/g, ""); } catch (e) {}
        return s;
    }

    function puntuar(e, q) {
        if (q === "") return 1;
        const nombre = normalizar(e.name);
        if (nombre === q) return 1000;
        if (nombre.startsWith(q)) return 800;
        const palabras = nombre.split(/[\s\-_.]+/);
        for (let i = 0; i < palabras.length; i++) {
            if (palabras[i].startsWith(q)) return 600;
        }
        if (nombre.includes(q)) return 400;
        const claves = [];
        const k = e.keywords || [];
        for (let i = 0; i < k.length; i++) claves.push(k[i]);
        const extra = normalizar(String(e.genericName || "") + " " + claves.join(" ") + " " + String(e.comment || ""));
        if (extra.includes(q)) return 200;
        // Letras en orden ("ffx" -> "firefox")
        let j = 0;
        for (let i = 0; i < nombre.length && j < q.length; i++) {
            if (nombre[i] === q[j]) j++;
        }
        return j === q.length ? 100 : 0;
    }

    readonly property var resultados: {
        const texto = consulta.trim();
        if (texto.startsWith(">")) {
            const comando = texto.substring(1).trim();
            return comando === "" ? [] : [{ tipo: "comando", comando: comando }];
        }

        const q = normalizar(texto);
        const vistos = {};
        const lista = [];
        const apps = DesktopEntries.applications.values;
        for (let i = 0; i < apps.length; i++) {
            const e = apps[i];
            if (!e || e.noDisplay || vistos[e.id]) continue;
            vistos[e.id] = true;
            const p = puntuar(e, q);
            if (p <= 0) continue;
            const veces = usos[e.id] || 0;
            lista.push({ tipo: "app", entrada: e, puntos: p + Math.min(veces * 15, 150) });
        }
        lista.sort((a, b) => (b.puntos - a.puntos) || String(a.entrada.name).localeCompare(String(b.entrada.name)));

        // Si no hay ninguna app, ofrecer ejecutarlo como comando
        if (lista.length === 0 && texto !== "")
            return [{ tipo: "comando", comando: texto }];
        return lista;
    }

    function iconoDe(e) {
        const i = String(e.icon || "");
        if (i === "") return "";
        if (i.startsWith("/")) return "file://" + i;
        return Quickshell.iconPath(i, true);
    }

    // ---------- Abrir ----------
    function lanzar(item) {
        if (!item) return;
        if (item.tipo === "comando") {
            Quickshell.execDetached(["sh", "-c", item.comando]);
        } else {
            const e = item.entrada;
            const u = Object.assign({}, usos);
            u[e.id] = (u[e.id] || 0) + 1;
            usos = u;
            archivoUsos.setText(JSON.stringify(u));

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
        }
        sup.cerrar();
    }

    // Cuantas veces se ha abierto cada app (para ordenar)
    FileView {
        id: archivoUsos
        path: Quickshell.env("HOME") + "/.cache/quickshell-lanzador.json"
        printErrors: false
        onLoaded: {
            try { lanzador.usos = JSON.parse(text()); } catch (e) {}
        }
    }

    IpcHandler {
        target: "lanzador"
        function alternar(): void { sup.alternar(); }
        function abrir(): void { sup.abrir(); }
        function cerrar(): void { sup.cerrar(); }
    }

    Superposicion {
        id: sup
        ancho: 760

        onAbrio: {
            campo.text = "";
            cuadricula.currentIndex = 0;
            cuadricula.positionViewAtBeginning();
            Qt.callLater(() => campo.forceActiveFocus());
        }

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
                anchors.right: contador.left
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                color: Tema.texto
                font.family: Tema.fuenteBarra
                font.pixelSize: 16
                clip: true
                focus: true

                onTextChanged: {
                    lanzador.consulta = text;
                    cuadricula.currentIndex = 0;
                    cuadricula.positionViewAtBeginning();
                }

                Keys.onPressed: event => {
                    const total = cuadricula.count;
                    const c = lanzador.columnas;
                    const i = cuadricula.currentIndex;
                    if (event.key === Qt.Key_Escape) {
                        sup.cerrar();
                    } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        lanzador.lanzar(lanzador.resultados[lanzador.modoComando ? 0 : i]);
                    } else if (total === 0 || lanzador.modoComando) {
                        return;
                    } else if (event.key === Qt.Key_Right || event.key === Qt.Key_Tab) {
                        cuadricula.currentIndex = (i + 1) % total;
                    } else if (event.key === Qt.Key_Left || event.key === Qt.Key_Backtab) {
                        cuadricula.currentIndex = (i - 1 + total) % total;
                    } else if (event.key === Qt.Key_Down) {
                        cuadricula.currentIndex = Math.min(total - 1, i + c);
                    } else if (event.key === Qt.Key_Up) {
                        cuadricula.currentIndex = Math.max(0, i - c);
                    } else if (event.key === Qt.Key_PageDown) {
                        cuadricula.currentIndex = Math.min(total - 1, i + c * lanzador.filasVisibles);
                    } else if (event.key === Qt.Key_PageUp) {
                        cuadricula.currentIndex = Math.max(0, i - c * lanzador.filasVisibles);
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
                text: "Buscar aplicaciones…"
                color: Tema.tenue
                font.family: Tema.fuenteBarra
                font.pixelSize: 16
            }

            // Cuantas apps coinciden
            Text {
                id: contador
                anchors.right: parent.right
                anchors.rightMargin: 18
                anchors.verticalCenter: parent.verticalCenter
                visible: !lanzador.modoComando && cuadricula.count > 0
                text: cuadricula.count + (cuadricula.count === 1 ? " app" : " apps")
                color: Tema.tenue
                font.family: Tema.fuenteBarra
                font.pixelSize: 12
            }
        }

        // ---------- Titulo de la seccion ----------
        Text {
            visible: !lanzador.modoComando && cuadricula.count > 0
            leftPadding: 6
            text: lanzador.consulta.trim() === "" ? "Aplicaciones" : "Resultados"
            color: Tema.suave
            font.family: Tema.fuenteBarra
            font.pixelSize: 12
            font.bold: true
        }

        // ---------- Cuadricula de apps ----------
        GridView {
            id: cuadricula

            visible: !lanzador.modoComando && count > 0
            width: parent.width
            height: Math.min(Math.ceil(count / lanzador.columnas), lanzador.filasVisibles) * cellHeight
            cellWidth: Math.floor(width / lanzador.columnas)
            cellHeight: lanzador.altoCelda
            clip: true
            model: lanzador.modoComando ? [] : lanzador.resultados
            boundsBehavior: Flickable.StopAtBounds
            highlightFollowsCurrentItem: false

            // true mientras la seleccion cambia por pasar el raton:
            // asi la cuadricula no se desplaza bajo el cursor
            property bool porRaton: false
            onCurrentIndexChanged: if (!porRaton) positionViewAtIndex(currentIndex, GridView.Contain)

            delegate: Item {
                id: celda

                required property var modelData
                required property int index

                readonly property bool elegida: index === cuadricula.currentIndex

                width: cuadricula.cellWidth
                height: cuadricula.cellHeight

                Rectangle {
                    id: fondoCelda
                    anchors.fill: parent
                    anchors.margins: 4
                    radius: 14
                    color: celda.elegida ? Tema.conAlfa(Tema.acento, 0.22) : "transparent"
                    border.width: celda.elegida ? 1 : 0
                    border.color: Tema.conAlfa(Tema.acento, 0.7)

                    Behavior on color { ColorAnimation { duration: 120 } }
                }

                // Icono en un fondo redondeado
                Rectangle {
                    id: marco
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    anchors.topMargin: 14
                    width: 56; height: 56; radius: 16
                    color: celda.elegida ? Tema.campoHover : Tema.campo
                    scale: celda.elegida ? 1.06 : 1

                    Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

                    Image {
                        id: imagen
                        anchors.centerIn: parent
                        width: 40; height: 40
                        visible: status === Image.Ready
                        source: lanzador.iconoDe(celda.modelData.entrada)
                        sourceSize.width: 80
                        sourceSize.height: 80
                        asynchronous: true
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: !imagen.visible
                        text: "󰘔"
                        color: Tema.acento
                        font.family: Tema.fuenteBarra
                        font.pixelSize: 26
                    }
                }

                Text {
                    anchors.top: marco.bottom
                    anchors.topMargin: 10
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: parent.width - 16
                    horizontalAlignment: Text.AlignHCenter
                    text: String(celda.modelData.entrada.name)
                    color: celda.elegida ? Tema.texto : Tema.suave
                    font.family: Tema.fuenteBarra
                    font.pixelSize: 12
                    font.bold: celda.elegida
                    wrapMode: Text.Wrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                    lineHeight: 0.95
                }

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: 4
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onContainsMouseChanged: if (containsMouse) {
                        cuadricula.porRaton = true;
                        cuadricula.currentIndex = celda.index;
                        cuadricula.porRaton = false;
                    }
                    onClicked: lanzador.lanzar(celda.modelData)
                }
            }
        }

        // ---------- Descripcion de la app seleccionada ----------
        Text {
            readonly property var actual: lanzador.modoComando ? null : lanzador.resultados[cuadricula.currentIndex]
            visible: !lanzador.modoComando && cuadricula.count > 0
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: actual && actual.entrada
                  ? String(actual.entrada.comment || actual.entrada.genericName || actual.entrada.name)
                  : " "
            color: Tema.tenue
            font.family: Tema.fuenteBarra
            font.pixelSize: 12
            elide: Text.ElideRight
        }

        // ---------- Modo comando (empieza con ">" o no hay apps) ----------
        Rectangle {
            visible: lanzador.modoComando
            width: parent.width
            height: 56
            radius: 14
            color: Tema.conAlfa(Tema.acento, 0.22)
            border.width: 1
            border.color: Tema.conAlfa(Tema.acento, 0.7)

            Row {
                anchors.left: parent.left
                anchors.leftMargin: 18
                anchors.verticalCenter: parent.verticalCenter
                spacing: 14

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "󰆍"
                    color: Tema.acento
                    font.family: Tema.fuenteBarra
                    font.pixelSize: 22
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2
                    Text {
                        text: "Ejecutar comando"
                        color: Tema.suave
                        font.family: Tema.fuenteBarra
                        font.pixelSize: 11
                    }
                    Text {
                        text: lanzador.modoComando ? lanzador.resultados[0].comando : ""
                        color: Tema.texto
                        font.family: Tema.fuenteBarra
                        font.pixelSize: 15
                        font.bold: true
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: lanzador.lanzar(lanzador.resultados[0])
            }
        }

        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: lanzador.modoComando
                  ? "Enter ejecutar   ·   Esc cerrar"
                  : "Flechas moverse   ·   Enter abrir   ·   >comando ejecutar   ·   Esc cerrar"
            color: Tema.conAlfa(Tema.tenue, 0.8)
            font.family: Tema.fuenteBarra
            font.pixelSize: 11
        }
    }
}
