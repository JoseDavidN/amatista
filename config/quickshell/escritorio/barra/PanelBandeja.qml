// Menú de una app de la bandeja, con el tema. Los submenús se abren
// en el mismo panel, con una fila para volver.
import QtQuick
import QtQml
import Quickshell
import Quickshell.Widgets
import qs.Comun
import qs.paneles

PanelEmergente {
    id: panel

    required property var elemento
    property var pila: []          // submenús abiertos

    ancho: 280
    icono: String.fromCodePoint(0xf003b)

    Connections {
        target: panel
        function onAbiertoChanged() { panel.pila = []; }
    }

    // Todos los niveles siguen abiertos: si se cerrara el menú padre, la app
    // descartaría el submenú
    QsMenuOpener {
        id: raiz
        menu: panel.abierto && panel.elemento ? panel.elemento.menu : null
    }
    Instantiator {
        id: niveles
        model: panel.pila
        delegate: QsMenuOpener {
            required property var modelData
            menu: modelData
        }
    }
    // niveles.count avisa cuando cambia el nivel
    readonly property var entradas: niveles.count > 0 && niveles.objectAt(niveles.count - 1)
                                    ? niveles.objectAt(niveles.count - 1).children : raiz.children

    component Fila: Rectangle {
        id: f
        property string texto: ""
        property string simbolo: ""
        property string imagen: ""
        property bool habilitada: true
        property bool submenu: false
        signal clic()

        width: parent ? parent.width : 240
        height: 34
        radius: 8
        color: zonaF.containsMouse && habilitada ? Tema.campoHover : "transparent"
        opacity: habilitada ? 1 : 0.45

        Text {
            x: 10
            anchors.verticalCenter: parent.verticalCenter
            visible: f.simbolo !== ""
            text: f.simbolo
            color: Tema.acento
            font.family: Tema.fuenteBarra
            font.pixelSize: 15
        }
        IconImage {
            x: 10
            anchors.verticalCenter: parent.verticalCenter
            visible: f.simbolo === "" && f.imagen !== ""
            implicitSize: 16
            source: f.imagen
        }
        Text {
            anchors.left: parent.left
            anchors.leftMargin: 36
            anchors.right: parent.right
            anchors.rightMargin: f.submenu ? 30 : 10
            anchors.verticalCenter: parent.verticalCenter
            text: f.texto
            textFormat: Text.PlainText
            color: Tema.texto
            font.family: Tema.fuenteBarra
            font.pixelSize: 13
            elide: Text.ElideRight
        }
        Text {
            visible: f.submenu
            anchors.right: parent.right
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            text: String.fromCodePoint(0xf0142)
            color: Tema.tenue
            font.family: Tema.fuenteBarra
            font.pixelSize: 15
        }
        MouseArea {
            id: zonaF
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: f.habilitada ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: if (f.habilitada) f.clic()
        }
    }

    Column {
        width: parent.width
        spacing: 2

        Fila {
            visible: panel.pila.length > 0
            simbolo: String.fromCodePoint(0xf0141)
            texto: "Volver"
            onClic: panel.pila = panel.pila.slice(0, -1)
        }

        Repeater {
            model: panel.entradas

            delegate: Item {
                id: entrada
                required property var modelData
                width: parent.width
                height: modelData.isSeparator ? 9 : 34

                Rectangle {
                    visible: entrada.modelData.isSeparator
                    anchors.centerIn: parent
                    width: parent.width - 12
                    height: 1
                    color: Tema.borde
                }
                Fila {
                    visible: !entrada.modelData.isSeparator
                    // "&" marca la tecla de acceso en los menús clásicos
                    texto: String(entrada.modelData.text || "").replace(/_(?=\S)/, "").replace(/&(?=\S)/, "")
                    habilitada: entrada.modelData.enabled
                    submenu: entrada.modelData.hasChildren
                    imagen: String(entrada.modelData.icon || "")
                    simbolo: entrada.modelData.buttonType === QsMenuButtonType.None ? ""
                           : entrada.modelData.checkState === Qt.Checked ? String.fromCodePoint(0xf012c)
                           : String.fromCodePoint(entrada.modelData.buttonType === QsMenuButtonType.RadioButton ? 0xf0130 : 0xf0131)
                    onClic: {
                        if (entrada.modelData.hasChildren) {
                            panel.pila = panel.pila.concat([entrada.modelData]);
                        } else {
                            entrada.modelData.triggered();
                            panel.cerrar();
                        }
                    }
                }
            }
        }
    }
}
