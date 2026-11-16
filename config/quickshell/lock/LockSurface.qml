// ==========================================================
// Diseno de la pantalla de bloqueo (una por monitor)
// ==========================================================
import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Services.Mpris
import Quickshell.Services.UPower

Rectangle {
    id: root

    required property LockContext context

    // ---------- Paleta Amatista (copia fija: este es el respaldo independiente) ----------
    readonly property color cFondo:   "#2a1f3d"
    readonly property color cTarjeta: Qt.rgba(42 / 255, 31 / 255, 61 / 255, 0.45)
    readonly property color cCampo:   "#40305c"
    readonly property color cBorde:   "#52406f"
    readonly property color cTexto:   "#f3eaff"
    readonly property color cSuave:   "#d4c2f0"
    readonly property color cTenue:   "#a08cc0"
    readonly property color cAcento:  "#b98cff"
    readonly property color cMorado:  "#ff9ad5"
    readonly property color cError:   "#ff7a9a"
    readonly property color cAmbar:   "#ffcf85"
    readonly property color cOk:      "#9ee6b0"

    readonly property string fuente: "JetBrains Mono"
    readonly property string fuenteIconos: "Symbols Nerd Font"

    readonly property string home: Quickshell.env("HOME")
    readonly property string usuario: Quickshell.env("USER")

    color: cFondo

    // ---------- Reloj ----------
    SystemClock {
        id: reloj
        precision: SystemClock.Minutes
    }

    // ---------- Bateria (UPower) ----------
    readonly property var bateria: UPower.displayDevice
    readonly property bool hayBateria: bateria !== null && bateria.isLaptopBattery
    readonly property int porcentaje: {
        if (!hayBateria)
            return 0;
        const p = bateria.percentage;
        return Math.round(p <= 1 ? p * 100 : p);
    }
    readonly property bool cargando: hayBateria && bateria.state === UPowerDeviceState.Charging
    readonly property var iconosBateria: ["󰂎", "󰁺", "󰁻", "󰁼", "󰁽", "󰁾", "󰁿", "󰂀", "󰂁", "󰂂", "󰁹"]

    // ---------- Musica (MPRIS) ----------
    readonly property var reproductor: {
        const lista = Mpris.players.values;
        for (let i = 0; i < lista.length; i++) {
            if (lista[i].isPlaying)
                return lista[i];
        }
        return lista.length > 0 ? lista[0] : null;
    }
    readonly property real progreso: {
        if (!reproductor || !reproductor.lengthSupported || reproductor.length <= 0)
            return 0;
        return Math.min(1, reproductor.position / reproductor.length);
    }

    // La posicion de MPRIS no se actualiza sola: se refresca cada segundo
    Timer {
        running: root.reproductor !== null && root.reproductor.isPlaying
        interval: 1000
        repeat: true
        onTriggered: root.reproductor.positionChanged()
    }

    // ---------- Fondo ----------
    // Se usa el fondo de pantalla desenfocado;
    // si no, se dibujan dos destellos de color.
    Image {
        id: imagenFondo
        anchors.fill: parent
        source: "file://" + root.home + "/Imágenes/wallpaper/amatista.png"
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        visible: false
    }

    MultiEffect {
        anchors.fill: parent
        source: imagenFondo
        visible: imagenFondo.status === Image.Ready
        blurEnabled: true
        blur: 1.0
        blurMax: 64
        brightness: -0.25
    }

    Rectangle {
        visible: imagenFondo.status !== Image.Ready
        width: 620; height: 620; radius: 310
        x: -180; y: -160
        color: root.cAcento
        opacity: 0.10
    }

    Rectangle {
        visible: imagenFondo.status !== Image.Ready
        width: 560; height: 560; radius: 280
        x: root.width - 380; y: root.height - 360
        color: root.cMorado
        opacity: 0.10
    }

    // ---------- Contenido (aparece con una animacion suave) ----------
    Item {
        id: contenido
        anchors.fill: parent
        opacity: 0
        scale: 0.97

        Component.onCompleted: entrada.start()

        ParallelAnimation {
            id: entrada
            NumberAnimation { target: contenido; property: "opacity"; to: 1; duration: 450; easing.type: Easing.OutCubic }
            NumberAnimation { target: contenido; property: "scale"; to: 1; duration: 450; easing.type: Easing.OutCubic }
        }

        // ----- Barra superior: estado -----
        Row {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.margins: 24
            spacing: 8

            Text {
                text: "󰌾"
                color: root.cAcento
                font.family: root.fuenteIconos
                font.pixelSize: 16
            }
            Text {
                text: "Bloqueado"
                color: root.cSuave
                font.family: root.fuente
                font.pixelSize: 14
            }
        }

        Row {
            visible: root.hayBateria
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 24
            spacing: 8

            Text {
                text: root.cargando ? "󰂄" : root.iconosBateria[Math.min(10, Math.floor(root.porcentaje / 10))]
                color: root.cargando ? root.cAcento
                     : root.porcentaje <= 15 ? root.cError
                     : root.porcentaje <= 30 ? root.cAmbar
                     : root.cOk
                font.family: root.fuenteIconos
                font.pixelSize: 16
            }
            Text {
                text: root.porcentaje + "%"
                color: root.cSuave
                font.family: root.fuente
                font.pixelSize: 14
            }
        }

        // ----- Centro: reloj, usuario y contrasena -----
        Column {
            anchors.centerIn: parent
            spacing: 6
            
            // Reloj
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatDateTime(reloj.date, "HH:mm")
                color: root.cTexto
                font.family: root.fuente
                font.pixelSize: 120
                font.weight: Font.Bold
            }
            
            // Fecha
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: reloj.date.toLocaleString(Qt.locale("es_CO"), "dddd, d 'de' MMMM")
                color: root.cSuave
                font.family: root.fuente
                font.pixelSize: 20
            }
        }

        // Contraseña
        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 60
            spacing: 12

            // Saludo
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Hola, " + root.usuario.charAt(0).toUpperCase() + root.usuario.slice(1)
                color: root.cTexto
                font.family: root.fuente
                font.pixelSize: 22
                font.weight: Font.Medium
            }
            
            Item { width: 1; height: 10 }
            
            // Input contraseña
            Rectangle {
                id: campo
                anchors.horizontalCenter: parent.horizontalCenter
                width: 320; height: 50; radius: 14
                color: root.cCampo
                border.width: 1
                border.color: root.context.showFailure ? root.cError
                            : entradaTexto.activeFocus ? root.cAcento
                            : root.cBorde

                opacity: (entradaTexto.text.length > 0
                        || root.context.unlockInProgress
                        || root.context.showFailure) ? 1 : 0

                Behavior on opacity { NumberAnimation { duration: 200 } }
                Behavior on border.color { ColorAnimation { duration: 200 } }

                transform: Translate { id: sacudida }

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 18
                    anchors.verticalCenter: parent.verticalCenter
                    visible: entradaTexto.text.length === 0 || root.context.unlockInProgress
                    text: root.context.showFailure ? "Contraseña incorrecta"
                        : root.context.unlockInProgress ? "Verificando..." 
                        : "Contraseña..."
                    color: root.cTenue
                    font.family: root.fuente
                    font.pixelSize: 15
                    font.italic: true
                }

                TextInput {
                    id: entradaTexto
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: 18
                    anchors.rightMargin: 18
                    anchors.verticalCenter: parent.verticalCenter
                    echoMode: TextInput.Password
                    passwordCharacter: "\u2022"
                    color: root.cTexto
                    font.family: root.fuente
                    font.pixelSize: 18
                    font.letterSpacing: 2
                    clip: true
                    focus: true
                    enabled: !root.context.unlockInProgress

                    onTextChanged: root.context.currentText = text
                    onAccepted: root.context.tryUnlock()
                    Keys.onEscapePressed: text = ""
                    opacity: root.context.unlockInProgress ? 0 : 1
                }
            }
        }

        // ----- Tarjeta de musica (solo si hay algo abierto) -----
        Rectangle {
            visible: root.reproductor !== null
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 28
            anchors.topMargin: 64
            width: 400; height: 104; radius: 18
            color: root.cTarjeta
            border.color: root.cBorde
            border.width: 1

            Rectangle {
                id: portada
                anchors.left: parent.left
                anchors.leftMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                width: 68; height: 68; radius: 12
                color: root.cCampo

                Image {
                    id: imagenPortada
                    anchors.fill: parent
                    source: root.reproductor ? root.reproductor.trackArtUrl : ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    visible: status === Image.Ready
                }

                Text {
                    anchors.centerIn: parent
                    visible: imagenPortada.status !== Image.Ready
                    text: ""
                    color: root.cAmbar
                    font.family: root.fuenteIconos
                    font.pixelSize: 26
                }
            }

            Column {
                anchors.left: portada.right
                anchors.leftMargin: 14
                anchors.right: controles.left
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4

                Text {
                    width: parent.width
                    text: root.reproductor ? (root.reproductor.trackTitle || "Sin título") : ""
                    color: root.cTexto
                    font.family: root.fuente
                    font.pixelSize: 14
                    elide: Text.ElideRight
                }

                Text {
                    width: parent.width
                    text: root.reproductor ? (root.reproductor.trackArtist || root.reproductor.identity) : ""
                    color: root.cTenue
                    font.family: root.fuente
                    font.pixelSize: 12
                    elide: Text.ElideRight
                }

                Item { width: 1; height: 4 }

                Rectangle {
                    width: parent.width
                    height: 4; radius: 2
                    color: root.cBorde

                    Rectangle {
                        width: parent.width * root.progreso
                        height: parent.height
                        radius: 2
                        color: root.cAcento
                        Behavior on width { NumberAnimation { duration: 900 } }
                    }
                }
            }

            Row {
                id: controles
                anchors.right: parent.right
                anchors.rightMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                spacing: 10

                Repeater {
                    model: [
                        { icono: "", accion: "anterior" },
                        { icono: "", accion: "pausa" },
                        { icono: "", accion: "siguiente" }
                    ]

                    delegate: Text {
                        required property var modelData
                        text: modelData.accion === "pausa"
                              ? (root.reproductor && root.reproductor.isPlaying ? "" : "")
                              : modelData.icono
                        color: zona.containsMouse ? root.cAcento : root.cTexto
                        font.family: root.fuenteIconos
                        font.pixelSize: modelData.accion === "pausa" ? 36 : 35
                        anchors.verticalCenter: parent.verticalCenter

                        MouseArea {
                            id: zona
                            anchors.fill: parent
                            anchors.margins: -6
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                const r = root.reproductor;
                                if (!r) return;
                                if (modelData.accion === "anterior" && r.canGoPrevious) r.previous();
                                else if (modelData.accion === "siguiente" && r.canGoNext) r.next();
                                else if (modelData.accion === "pausa" && r.canTogglePlaying) r.togglePlaying();
                            }
                        }
                    }
                }
            }
        }
    }

    // ---------- Animacion de error: el campo tiembla ----------
    SequentialAnimation {
        id: animSacudida
        NumberAnimation { target: sacudida; property: "x"; to: -14; duration: 50 }
        NumberAnimation { target: sacudida; property: "x"; to: 14; duration: 70 }
        NumberAnimation { target: sacudida; property: "x"; to: -8; duration: 60 }
        NumberAnimation { target: sacudida; property: "x"; to: 0; duration: 50 }
    }

    Connections {
        target: root.context
        function onFailed() {
            entradaTexto.text = "";
            animSacudida.restart();
        }
    }
}
