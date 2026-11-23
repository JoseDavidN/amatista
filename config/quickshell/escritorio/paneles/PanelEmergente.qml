// ==========================================================
// Panel desplegable bajo una pildora de la barra (base de todos los paneles)
//
// Es una capa transparente de pantalla completa (igual que el lanzador):
// la tarjeta se dibuja debajo de la pildora y un clic en cualquier otro
// lugar la cierra. Escape tambien la cierra.
// ==========================================================
import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Comun

PanelWindow {
    id: panel

    required property Item objetivo
    property int ancho: 380
    property bool abierto: false
    property string titulo: ""
    property string icono: ""
    property color colorIcono: Tema.acento

    // Lo que se declare dentro del panel va al cuerpo
    default property alias contenido: cuerpo.data
    // Elemento opcional a la derecha del titulo (por ejemplo, un interruptor)
    property alias accesorio: zonaAccesorio.data

    signal abrio()
    signal cerro()

    readonly property var ventanaBarra: objetivo.QsWindow.window

    property real posX: 0
    property real posY: 0

    // Ubica la tarjeta centrada bajo la pildora, sin salirse de la pantalla
    function calcularPosicion() {
        const v = ventanaBarra;
        if (!v) return;
        const p = objetivo.mapToItem(v.contentItem, 0, 0);
        const centro = Tema.barraMargenLados + p.x + objetivo.width / 2;
        const anchoPantalla = v.screen ? v.screen.width : 1920;
        posX = Math.round(Math.max(Tema.margenPantalla,
                          Math.min(centro - ancho / 2, anchoPantalla - ancho - Tema.margenPantalla)));
        posY = Tema.barraMargenArriba + Tema.barraAlto + 8;
    }

    function abrir() {
        if (ventanaBarra) screen = ventanaBarra.screen;
        calcularPosicion();
        abierto = true;
        abrio();
    }

    function cerrar() {
        if (!abierto) return;
        abierto = false;
        cerro();
    }

    function alternar() {
        if (abierto) cerrar();
        else abrir();
    }

    visible: abierto
    color: "transparent"

    WlrLayershell.namespace: "panel"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: abierto ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    // Se usa Connections (y no onAbiertoChanged) para que los paneles
    // que heredan de este puedan tener sus propios manejadores
    Connections {
        target: panel
        function onAbiertoChanged() {
            if (!panel.abierto) return;
            marco.opacity = 0;
            desplazamiento.y = -8;
            entrada.restart();
            Qt.callLater(() => marco.forceActiveFocus());
        }
    }

    ParallelAnimation {
        id: entrada
        NumberAnimation { target: marco; property: "opacity"; to: 1; duration: 180; easing.type: Easing.OutCubic }
        NumberAnimation { target: desplazamiento; property: "y"; to: 0; duration: 220; easing.type: Easing.OutCubic }
    }

    // Clic fuera de la tarjeta = cerrar
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        onClicked: panel.cerrar()
    }

    Rectangle {
        id: marco

        x: panel.posX
        y: panel.posY
        width: panel.ancho
        height: columna.implicitHeight + 32
        radius: 16
        color: Tema.fondoPanel
        border.width: 1
        border.color: Tema.borde
        focus: true

        transform: Translate { id: desplazamiento }

        Keys.onEscapePressed: panel.cerrar()

        // Evita que los clics dentro de la tarjeta la cierren
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
        }

        Column {
            id: columna

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 16
            spacing: 14

            // Encabezado
            Item {
                width: parent.width
                height: 28

                Row {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 10

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: panel.icono
                        color: panel.colorIcono
                        font.family: Tema.fuenteBarra
                        font.pixelSize: 18
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: panel.titulo
                        color: Tema.texto
                        font.family: Tema.fuenteBarra
                        font.pixelSize: 16
                        font.bold: true
                    }
                }

                Item {
                    id: zonaAccesorio
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: childrenRect.width
                    height: childrenRect.height
                }
            }

            // Si no cabe en la pantalla, el cuerpo se desplaza
            Flickable {
                id: vista
                width: parent.width
                height: Math.min(cuerpo.implicitHeight, Math.max(200,
                        panel.height - panel.posY - Tema.margenPantalla - 32 - 28 - columna.spacing))
                contentHeight: cuerpo.implicitHeight
                interactive: contentHeight > height + 1
                clip: interactive
                boundsBehavior: Flickable.StopAtBounds

                Column {
                    id: cuerpo
                    width: vista.width
                    spacing: 10
                }
            }
        }
    }
}
