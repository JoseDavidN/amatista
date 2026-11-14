// ==========================================================
// Historial del portapapeles (usa cliphist + wl-clipboard)
// - Busca entre lo copiado y vuelve a copiarlo con Enter o clic
// - Supr: borrar la entrada elegida · Ctrl+Supr: borrar todo
//
//   qs -c escritorio ipc call portapapeles alternar
// ==========================================================
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Comun
import qs.menus

Scope {
    id: pp

    readonly property int filasVisibles: 8
    readonly property int altoFila: 44

    property var entradas: []
    property string consulta: ""
    property bool confirmarBorrado: false

    readonly property var filtradas: {
        const q = consulta.trim().toLowerCase();
        if (q === "") return entradas;
        return entradas.filter(e => e.vista.toLowerCase().includes(q));
    }

    // Cada linea de "cliphist list" es: id<TAB>vista previa
    function procesar(texto) {
        const lista = [];
        const lineas = texto.split("\n");
        for (let i = 0; i < lineas.length; i++) {
            const l = lineas[i];
            const tab = l.indexOf("\t");
            if (tab < 0) continue;
            const vista = l.substring(tab + 1);
            const imagen = /^\[\[ binary data .* (png|jpe?g|gif|webp|bmp) /i.exec(vista);
            lista.push({
                linea: l,
                vista: imagen ? "Imagen " + imagen[1].toUpperCase() + vista.replace(/^.*\s(\d+x\d+).*$/, " · $1") : vista.replace(/\s+/g, " ").trim(),
                imagen: imagen !== null
            });
        }
        entradas = lista;
    }

    function recargar() {
        if (!listar.running) listar.running = true;
    }

    function copiar(e) {
        if (!e) return;
        Quickshell.execDetached(["sh", "-c", 'printf "%s" "$1" | cliphist decode | wl-copy', "sh", e.linea]);
        sup.cerrar();
    }

    function borrar(e) {
        if (!e) return;
        borrador.command = ["sh", "-c", 'printf "%s" "$1" | cliphist delete', "sh", e.linea];
        borrador.running = true;
    }

    function borrarTodo() {
        borrador.command = ["cliphist", "wipe"];
        borrador.running = true;
        confirmarBorrado = false;
    }

    Process {
        id: listar
        command: ["cliphist", "list"]
        stdout: StdioCollector {
            onStreamFinished: pp.procesar(this.text)
        }
    }

    Process {
        id: borrador
        onExited: pp.recargar()
    }

    IpcHandler {
        target: "portapapeles"
        function alternar(): void { sup.alternar(); }
        function abrir(): void { sup.abrir(); }
        function cerrar(): void { sup.cerrar(); }
    }

    Superposicion {
        id: sup
        ancho: 600

        onAbrio: {
            campo.text = "";
            pp.confirmarBorrado = false;
            lista.currentIndex = 0;
            pp.recargar();
            Qt.callLater(() => campo.forceActiveFocus());
        }

        // ---------- Busqueda ----------
        Rectangle {
            width: parent.width
            height: 48
            radius: 12
            color: Tema.campo

            Text {
                id: prompt
                anchors.left: parent.left
                anchors.leftMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                text: "󰆒  Portapapeles"
                color: Tema.acento
                font.family: Tema.fuenteBarra
                font.pixelSize: 14
                font.bold: true
            }

            TextInput {
                id: campo
                anchors.left: prompt.right
                anchors.leftMargin: 14
                anchors.right: parent.right
                anchors.rightMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                color: Tema.texto
                font.family: Tema.fuenteBarra
                font.pixelSize: 15
                clip: true
                focus: true

                onTextChanged: {
                    pp.consulta = text;
                    lista.currentIndex = 0;
                }

                Keys.onPressed: event => {
                    const total = lista.count;
                    if (event.key === Qt.Key_Escape) {
                        if (pp.confirmarBorrado) pp.confirmarBorrado = false;
                        else sup.cerrar();
                    } else if (event.key === Qt.Key_Down || event.key === Qt.Key_Tab) {
                        if (total > 0) lista.currentIndex = (lista.currentIndex + 1) % total;
                    } else if (event.key === Qt.Key_Up || event.key === Qt.Key_Backtab) {
                        if (total > 0) lista.currentIndex = (lista.currentIndex - 1 + total) % total;
                    } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        if (pp.confirmarBorrado) pp.borrarTodo();
                        else pp.copiar(pp.filtradas[lista.currentIndex]);
                    } else if (event.key === Qt.Key_Delete && (event.modifiers & Qt.ControlModifier)) {
                        pp.confirmarBorrado = true;
                    } else if (event.key === Qt.Key_Delete) {
                        pp.borrar(pp.filtradas[lista.currentIndex]);
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
                text: "Buscar en lo copiado..."
                color: Tema.tenue
                font.family: Tema.fuenteBarra
                font.pixelSize: 15
            }
        }

        // ---------- Entradas ----------
        ListView {
            id: lista

            width: parent.width
            height: Math.max(1, Math.min(count, pp.filasVisibles)) * (pp.altoFila + spacing)
            spacing: 4
            clip: true
            model: pp.filtradas
            boundsBehavior: Flickable.StopAtBounds

            onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)

            delegate: Rectangle {
                id: fila

                required property var modelData
                required property int index

                readonly property bool elegida: index === lista.currentIndex

                width: lista.width
                height: pp.altoFila
                radius: 10
                color: elegida ? Tema.acento : zona.containsMouse ? Tema.campo : "transparent"

                Text {
                    id: tipo
                    anchors.left: parent.left
                    anchors.leftMargin: 14
                    anchors.verticalCenter: parent.verticalCenter
                    width: 22
                    horizontalAlignment: Text.AlignHCenter
                    text: fila.modelData.imagen ? "󰥶" : "󰊄"
                    color: fila.elegida ? Tema.fondo : fila.modelData.imagen ? Tema.morado : Tema.tenue
                    font.family: Tema.fuenteBarra
                    font.pixelSize: 17
                }

                Text {
                    anchors.left: tipo.right
                    anchors.leftMargin: 12
                    anchors.right: botonBorrar.left
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    text: fila.modelData.vista
                    color: fila.elegida ? Tema.fondo : Tema.texto
                    font.family: Tema.fuenteBarra
                    font.pixelSize: 13
                    elide: Text.ElideRight
                    textFormat: Text.PlainText
                }

                Text {
                    id: botonBorrar
                    anchors.right: parent.right
                    anchors.rightMargin: 14
                    anchors.verticalCenter: parent.verticalCenter
                    opacity: zona.containsMouse || fila.elegida ? 1 : 0
                    text: "󰧧"
                    color: zonaBorrar.containsMouse ? Tema.error : fila.elegida ? Tema.fondo : Tema.tenue
                    font.family: Tema.fuenteBarra
                    font.pixelSize: 16
                }

                MouseArea {
                    id: zona
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: lista.currentIndex = fila.index
                    onClicked: pp.copiar(fila.modelData)
                }

                MouseArea {
                    id: zonaBorrar
                    anchors.fill: botonBorrar
                    anchors.margins: -6
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: pp.borrar(fila.modelData)
                }
            }
        }

        Text {
            visible: lista.count === 0
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: pp.entradas.length === 0 ? "El historial está vacío" : "Sin resultados"
            color: Tema.tenue
            font.family: Tema.fuenteBarra
            font.pixelSize: 12
        }

        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: pp.confirmarBorrado
                  ? "¿Borrar todo el historial? Enter para confirmar · Esc para cancelar"
                  : "Enter copiar   ·   Supr borrar   ·   Ctrl+Supr borrar todo   ·   Esc cerrar"
            color: pp.confirmarBorrado ? Tema.error : Tema.tenue
            font.family: Tema.fuenteBarra
            font.pixelSize: 11
        }
    }
}
