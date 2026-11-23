// Lista de actualizaciones pendientes y botón para instalarlas
import QtQuick
import Quickshell
import qs.Comun
import qs.paneles

PanelEmergente {
    id: panel

    readonly property var s: ServicioActualizaciones

    ancho: Math.min(480, (screen ? screen.width : 1920) - 24)
    titulo: "Actualizaciones"
    icono: String.fromCodePoint(0xf03d7)
    colorIcono: Tema.lima

    // Títulos y paquetes en una sola lista
    readonly property var filas: {
        let r = [];
        if (s.arch.length) r = r.concat([{ titulo: "Arch", extra: s.arch.length + "" }], s.arch);
        if (s.aur.length) r = r.concat([{ titulo: "AUR", extra: s.aur.length + "" }], s.aur);
        return r;
    }

    Text {
        visible: text !== ""
        width: parent.width
        wrapMode: Text.Wrap
        text: [panel.s.falta ? "Falta pacman-contrib: solo se comprueba el AUR" : "",
               panel.s.errorArch ? "No se pudo consultar los repositorios de Arch" : "",
               panel.s.errorAur ? "No se pudo consultar el AUR" : ""].filter(t => t).join("\n")
        color: Tema.error
        font.family: Tema.fuenteBarra
        font.pixelSize: 12
    }

    Text {
        visible: panel.filas.length === 0
        text: panel.s.comprobando ? "Comprobando…" : "El sistema está al día"
        color: Tema.tenue
        font.family: Tema.fuenteBarra
        font.pixelSize: 13
    }

    ListView {
        id: lista
        visible: count > 0
        width: parent.width
        height: Math.min(contentHeight, 420)
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        model: panel.filas

        delegate: Item {
            id: fila
            required property var modelData
            readonly property bool esTitulo: modelData.titulo !== undefined
            width: lista.width
            height: esTitulo ? 28 : 26

            TituloSeccion {
                visible: fila.esTitulo
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 4
                texto: fila.modelData.titulo || ""
                extra: fila.modelData.extra || ""
            }
            Text {
                visible: !fila.esTitulo
                anchors.left: parent.left
                anchors.right: versiones.left
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                text: fila.modelData.nombre || ""
                textFormat: Text.PlainText
                color: Tema.texto
                font.family: Tema.fuenteBarra
                font.pixelSize: 12
                elide: Text.ElideRight
            }
            Row {
                id: versiones
                visible: !fila.esTitulo
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6
                Text {
                    width: Math.min(implicitWidth, 120)
                    elide: Text.ElideRight
                    text: fila.modelData.actual || ""
                    color: Tema.tenue
                    font.family: Tema.fuenteBarra
                    font.pixelSize: 11
                }
                Text {
                    text: "→"
                    color: Tema.tenue
                    font.family: Tema.fuenteBarra
                    font.pixelSize: 11
                }
                Text {
                    width: Math.min(implicitWidth, 120)
                    elide: Text.ElideRight
                    text: fila.modelData.nueva || ""
                    color: Tema.lima
                    font.family: Tema.fuenteBarra
                    font.pixelSize: 11
                }
            }
        }
    }

    Item {
        width: parent.width
        height: 32

        Row {
            spacing: 8
            BotonTexto {
                visible: panel.s.total > 0
                principal: true
                icono: String.fromCodePoint(0xf06b0)
                texto: "Actualizar"
                onClic: {
                    panel.s.instalar();
                    panel.cerrar();
                }
            }
            BotonTexto {
                icono: "󰑐"
                texto: panel.s.comprobando ? "Comprobando…" : "Comprobar"
                onClic: panel.s.comprobar()
            }
        }
        Text {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            visible: panel.s.hora !== null
            text: panel.s.hora ? "Revisado " + Qt.formatTime(panel.s.hora, "HH:mm") : ""
            color: Tema.tenue
            font.family: Tema.fuenteBarra
            font.pixelSize: 11
        }
    }
}
