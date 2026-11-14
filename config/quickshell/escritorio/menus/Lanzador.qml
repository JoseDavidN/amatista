// ==========================================================
// Lanzador de aplicaciones (reemplaza a rofi -show drun)
// - Busca por nombre, nombre generico, palabras clave y descripcion
// - Las apps que mas abres suben en la lista
// - Empieza con ">" para ejecutar un comando (por ejemplo: >kitty -e htop)
// Teclas: flechas o Tab para moverse, Enter abrir, Escape cerrar
//
//   qs -c escritorio ipc call lanzador alternar
// ==========================================================
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Comun

Scope {
    id: lanzador

    readonly property int filasVisibles: 7
    readonly property int altoFila: 46

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
        ancho: 560

        onAbrio: {
            campo.text = "";
            lista.currentIndex = 0;
            Qt.callLater(() => campo.forceActiveFocus());
        }

        // ---------- Barra de busqueda ----------
        Rectangle {
            width: parent.width
            height: 48
            radius: 12
            color: Tema.campo

            Row {
                anchors.left: parent.left
                anchors.leftMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                spacing: 12

                Text {
                    id: prompt
                    anchors.verticalCenter: parent.verticalCenter
                    text: lanzador.consulta.trim().startsWith(">") ? "󰆍  Ejecutar" : "󰍉  Apps"
                    color: Tema.acento
                    font.family: Tema.fuenteBarra
                    font.pixelSize: 14
                    font.bold: true
                }
            }

            TextInput {
                id: campo
                anchors.left: parent.left
                anchors.leftMargin: 16 + prompt.implicitWidth + 14
                anchors.right: parent.right
                anchors.rightMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                color: Tema.texto
                font.family: Tema.fuenteBarra
                font.pixelSize: 15
                clip: true
                focus: true

                onTextChanged: {
                    lanzador.consulta = text;
                    lista.currentIndex = 0;
                }

                Keys.onPressed: event => {
                    const total = lista.count;
                    if (event.key === Qt.Key_Escape) {
                        sup.cerrar();
                    } else if (event.key === Qt.Key_Down || event.key === Qt.Key_Tab) {
                        if (total > 0) lista.currentIndex = (lista.currentIndex + 1) % total;
                    } else if (event.key === Qt.Key_Up || event.key === Qt.Key_Backtab) {
                        if (total > 0) lista.currentIndex = (lista.currentIndex - 1 + total) % total;
                    } else if (event.key === Qt.Key_PageDown) {
                        lista.currentIndex = Math.min(total - 1, lista.currentIndex + lanzador.filasVisibles);
                    } else if (event.key === Qt.Key_PageUp) {
                        lista.currentIndex = Math.max(0, lista.currentIndex - lanzador.filasVisibles);
                    } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        lanzador.lanzar(lanzador.resultados[lista.currentIndex]);
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
                text: "Buscar..."
                color: Tema.tenue
                font.family: Tema.fuenteBarra
                font.pixelSize: 15
            }
        }

        // ---------- Resultados ----------
        ListView {
            id: lista

            width: parent.width
            height: Math.max(1, Math.min(count, lanzador.filasVisibles)) * (lanzador.altoFila + spacing)
            spacing: 4
            clip: true
            model: lanzador.resultados
            boundsBehavior: Flickable.StopAtBounds

            onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)

            delegate: Rectangle {
                id: fila

                required property var modelData
                required property int index

                readonly property bool elegida: index === lista.currentIndex
                readonly property bool esComando: modelData.tipo === "comando"

                width: lista.width
                height: lanzador.altoFila
                radius: 10
                color: elegida ? Tema.acento : zona.containsMouse ? Tema.campo : "transparent"

                Item {
                    id: caja
                    anchors.left: parent.left
                    anchors.leftMargin: 14
                    anchors.verticalCenter: parent.verticalCenter
                    width: 26
                    height: 26

                    Image {
                        id: imagen
                        anchors.fill: parent
                        visible: !fila.esComando && status === Image.Ready
                        source: fila.esComando ? "" : lanzador.iconoDe(fila.modelData.entrada)
                        sourceSize.width: 52
                        sourceSize.height: 52
                        asynchronous: true
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: !imagen.visible
                        text: fila.esComando ? "󰆍" : "󰘔"
                        color: fila.elegida ? Tema.fondo : Tema.acento
                        font.family: Tema.fuenteBarra
                        font.pixelSize: 20
                    }
                }

                Column {
                    anchors.left: caja.right
                    anchors.leftMargin: 14
                    anchors.right: parent.right
                    anchors.rightMargin: 14
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 1

                    Text {
                        width: parent.width
                        text: fila.esComando ? "Ejecutar: " + fila.modelData.comando : String(fila.modelData.entrada.name)
                        color: fila.elegida ? Tema.fondo : Tema.texto
                        font.family: Tema.fuenteBarra
                        font.pixelSize: 14
                        font.bold: fila.elegida
                        elide: Text.ElideRight
                    }

                    Text {
                        width: parent.width
                        visible: text !== ""
                        text: fila.esComando ? "" : String(fila.modelData.entrada.genericName || fila.modelData.entrada.comment || "")
                        color: fila.elegida ? Tema.campo : Tema.tenue
                        font.family: Tema.fuenteBarra
                        font.pixelSize: 11
                        elide: Text.ElideRight
                    }
                }

                MouseArea {
                    id: zona
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: lista.currentIndex = fila.index
                    onClicked: lanzador.lanzar(fila.modelData)
                }
            }
        }

        Text {
            visible: lista.count === 0
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: "Escribe para buscar · empieza con > para ejecutar un comando"
            color: Tema.tenue
            font.family: Tema.fuenteBarra
            font.pixelSize: 12
        }

        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: "↑↓ moverse   ·   Enter abrir   ·   Esc cerrar"
            color: Tema.tenue
            font.family: Tema.fuenteBarra
            font.pixelSize: 11
        }
    }
}
