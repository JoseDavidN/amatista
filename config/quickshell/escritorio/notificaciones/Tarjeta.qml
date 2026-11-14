// ==========================================================
// Tarjeta de una notificacion
// ==========================================================
import QtQuick
import Quickshell
import qs.Comun

Rectangle {
    id: tarjeta

    // Datos que llegan del modelo
    required property int nid
    required property string app
    required property string resumen
    required property string cuerpo
    required property string icono
    required property int urgencia
    required property int duracion
    required property string acciones
    required property real valor
    required property bool restaurada

    signal cerrar(int nid)
    signal expirar(int nid)
    signal cerrarTodas()
    signal accion(int nid, string accionId)

    readonly property var todasLasAcciones: {
        try { return JSON.parse(acciones); } catch (e) { return []; }
    }
    readonly property var botones: restaurada ? [] : todasLasAcciones.filter(a => a.id !== "default" && a.texto !== "")
    readonly property bool tieneDefault: !restaurada && todasLasAcciones.some(a => a.id === "default")
    readonly property bool critica: urgencia === 2
    readonly property bool encima: hover.hovered

    // 1 = recien llegada, 0 = se acabo el tiempo
    property real restante: 1

    width: Tema.anchoNotificacion
    height: contenido.implicitHeight + 28
    radius: Tema.radio
    color: Tema.fondoTarjeta
    border.width: critica ? 2 : 1
    border.color: critica ? Tema.error
                : app === "networkmanager_dmenu" || app === "Red" ? Tema.acento
                : encima ? Tema.bordeFuerte
                : Tema.borde

    Behavior on border.color { ColorAnimation { duration: 150 } }

    // ---------- Tiempo en pantalla (se pausa con el raton encima) ----------
    NumberAnimation {
        id: cuenta
        target: tarjeta
        property: "restante"
        from: 1
        to: 0
        duration: Math.max(1, tarjeta.duracion)
        paused: running && tarjeta.encima
        onFinished: tarjeta.expirar(tarjeta.nid)
    }

    Component.onCompleted: {
        if (duracion > 0) cuenta.start();
    }

    HoverHandler { id: hover }

    // ---------- Clics sobre la tarjeta ----------
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        cursorShape: Qt.PointingHandCursor

        onClicked: mouse => {
            if (mouse.button === Qt.RightButton)
                tarjeta.cerrar(tarjeta.nid);
            else if (mouse.button === Qt.MiddleButton)
                tarjeta.cerrarTodas();
            else if (tarjeta.tieneDefault)
                tarjeta.accion(tarjeta.nid, "default");
            else
                tarjeta.cerrar(tarjeta.nid);
        }
    }

    // ---------- Contenido ----------
    Row {
        id: contenido

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.topMargin: 14
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        spacing: 12

        // Icono de la app o imagen de la notificacion
        Item {
            width: 40
            height: 40

            Image {
                id: imagen
                anchors.fill: parent
                source: tarjeta.icono
                fillMode: Image.PreserveAspectFit
                asynchronous: true
                sourceSize.width: 80
                sourceSize.height: 80
                visible: status === Image.Ready
            }

            Text {
                anchors.centerIn: parent
                visible: imagen.status !== Image.Ready
                text: tarjeta.critica ? "󰀦" : "󰂚"
                color: tarjeta.critica ? Tema.error : Tema.acento
                font.family: Tema.fuenteIconos
                font.pixelSize: 26
            }
        }

        Column {
            width: contenido.width - 52
            spacing: 4

            // Encabezado: nombre de la app y boton de cerrar
            Item {
                width: parent.width
                height: 16

                Text {
                    anchors.left: parent.left
                    anchors.right: botonCerrar.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: tarjeta.app
                    color: Tema.tenue
                    font.family: Tema.fuente
                    font.pixelSize: 11
                    elide: Text.ElideRight
                }

                Text {
                    id: botonCerrar
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    opacity: tarjeta.encima ? 1 : 0
                    text: "󰅖"
                    color: zonaCerrar.containsMouse ? Tema.error : Tema.tenue
                    font.family: Tema.fuenteIconos
                    font.pixelSize: 14

                    Behavior on opacity { NumberAnimation { duration: 150 } }

                    MouseArea {
                        id: zonaCerrar
                        anchors.fill: parent
                        anchors.margins: -6
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: tarjeta.cerrar(tarjeta.nid)
                    }
                }
            }

            Text {
                width: parent.width
                text: tarjeta.resumen
                color: Tema.texto
                font.family: Tema.fuente
                font.pixelSize: 14
                font.bold: true
                elide: Text.ElideRight
                textFormat: Text.PlainText
            }

            Text {
                width: parent.width
                visible: tarjeta.cuerpo !== ""
                // Se quitan las imagenes del cuerpo para no cargar nada externo
                text: tarjeta.cuerpo.replace(/<img[^>]*>/gi, "")
                color: Tema.suave
                font.family: Tema.fuente
                font.pixelSize: 13
                wrapMode: Text.Wrap
                maximumLineCount: 4
                elide: Text.ElideRight
                textFormat: Text.StyledText
                linkColor: Tema.acento
                onLinkActivated: link => Qt.openUrlExternally(link)
            }

            // Barra de progreso (por ejemplo: notify-send -h int:value:65)
            Rectangle {
                visible: tarjeta.valor >= 0
                width: parent.width
                height: 6
                radius: 3
                color: Tema.borde

                Rectangle {
                    width: parent.width * Math.max(0, Math.min(1, tarjeta.valor / 100))
                    height: parent.height
                    radius: 3
                    color: Tema.acento

                    Behavior on width { NumberAnimation { duration: 150 } }
                }
            }

            // Botones de acciones (por ejemplo: "Responder", "Abrir")
            Flow {
                visible: tarjeta.botones.length > 0
                width: parent.width
                spacing: 6
                topPadding: 4

                Repeater {
                    model: tarjeta.botones

                    delegate: Rectangle {
                        id: botonAccion
                        required property var modelData

                        height: 28
                        width: textoAccion.implicitWidth + 22
                        radius: Tema.radioPequeno
                        color: zonaAccion.containsMouse ? Tema.campoHover : Tema.campo
                        border.width: 1
                        border.color: Tema.borde

                        Text {
                            id: textoAccion
                            anchors.centerIn: parent
                            text: botonAccion.modelData.texto
                            color: Tema.texto
                            font.family: Tema.fuente
                            font.pixelSize: 12
                        }

                        MouseArea {
                            id: zonaAccion
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: tarjeta.accion(tarjeta.nid, botonAccion.modelData.id)
                        }
                    }
                }
            }
        }
    }

    // ---------- Barra de tiempo restante ----------
    Rectangle {
        visible: tarjeta.duracion > 0
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.leftMargin: 16
        anchors.bottomMargin: 6
        width: (parent.width - 32) * tarjeta.restante
        height: 2
        radius: 1
        color: tarjeta.critica ? Tema.error : Tema.acento
        opacity: 0.6
    }
}
