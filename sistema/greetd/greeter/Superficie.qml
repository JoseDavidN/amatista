// ==========================================================
// Diseño del greeter: fondo del tema, usuario al centro,
// contraseña abajo y botones de apagar/reiniciar en la esquina
// ==========================================================
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Greetd
import qs.Comun

Rectangle {
    id: root

    required property var greeter
    required property bool principal

    color: Tema.fondo

    // ---------- Fondo: imagen original del tema (amatista.png) ----------
    Image {
        anchors.fill: parent
        source: Qt.resolvedUrl("fondo.png")
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
    }

    // ---------- Red (NetworkManager, cada 3 s) ----------
    // "cable", "wifi" o "" si no hay ninguna conexión activa
    property string red: ""

    Process {
        id: consultaRed
        command: ["nmcli", "-t", "-f", "TYPE,STATE", "device"]
        stdout: StdioCollector {
            onStreamFinished: {
                let tipo = "";
                for (const linea of this.text.split("\n")) {
                    const [t, estado] = linea.split(":");
                    if (estado !== "connected")
                        continue;
                    if (t === "ethernet") { tipo = "cable"; break; }
                    if (t === "wifi") tipo = "wifi";
                }
                root.red = tipo;
            }
        }
        // Sin nmcli o con error: se muestra como sin red
        onExited: code => { if (code !== 0) root.red = ""; }
    }

    Timer {
        running: root.principal
        interval: 3000
        repeat: true
        triggeredOnStart: true
        onTriggered: if (!consultaRed.running) consultaRed.running = true
    }

    // ---------- Contenido (solo en el monitor principal) ----------
    Item {
        id: contenido
        visible: root.principal
        anchors.fill: parent
        opacity: 0
        scale: 0.97

        Component.onCompleted: entrada.start()

        ParallelAnimation {
            id: entrada
            NumberAnimation { target: contenido; property: "opacity"; to: 1; duration: 450; easing.type: Easing.OutCubic }
            NumberAnimation { target: contenido; property: "scale"; to: 1; duration: 450; easing.type: Easing.OutCubic }
        }

        // ----- Arriba a la derecha: estado de la red -----
        Text {
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 24
            text: root.red === "wifi" ? "󰖩" : root.red === "cable" ? "󰈀" : "󰈂"
            color: root.red !== "" ? Tema.verde : Tema.error
            font.family: Tema.fuenteIconos
            font.pixelSize: 22
        }

        // ----- Centro: icono de usuario y nombre -----
        Column {
            anchors.centerIn: parent
            spacing: 18

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 140; height: 140; radius: 70
                color: Tema.conAlfa(Tema.fondo, 0.75)
                border.width: 2
                border.color: Tema.acento

                Text {
                    anchors.centerIn: parent
                    text: "󰀄"
                    color: Tema.morado
                    font.family: Tema.fuenteIconos
                    font.pixelSize: 76
                }
            }

            // Nombre de usuario (flechas para cambiar si hay varios)
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 14

                Text {
                    visible: root.greeter.usuarios.length > 1
                    anchors.verticalCenter: parent.verticalCenter
                    text: ""
                    color: zonaIzq.containsMouse ? Tema.acento : Tema.suave
                    font.family: Tema.fuenteIconos
                    font.pixelSize: 18
                    MouseArea {
                        id: zonaIzq
                        anchors.fill: parent
                        anchors.margins: -6
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.greeter.cambiarUsuario(-1)
                    }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.greeter.actual.usuario
                    color: Tema.texto
                    font.family: Tema.fuente
                    font.pixelSize: 26
                    font.weight: Font.Medium
                }

                Text {
                    visible: root.greeter.usuarios.length > 1
                    anchors.verticalCenter: parent.verticalCenter
                    text: ""
                    color: zonaDer.containsMouse ? Tema.acento : Tema.suave
                    font.family: Tema.fuenteIconos
                    font.pixelSize: 18
                    MouseArea {
                        id: zonaDer
                        anchors.fill: parent
                        anchors.margins: -6
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.greeter.cambiarUsuario(1)
                    }
                }
            }
        }

        // ----- Abajo: contraseña -----
        Rectangle {
            id: campo
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 60
            width: 320; height: 50; radius: Tema.radio
            color: Tema.campo
            border.width: 1
            border.color: root.greeter.mensaje !== "" ? Tema.error
                        : entradaTexto.activeFocus ? Tema.acento
                        : Tema.borde

            // Oculto hasta que se empieza a escribir (como el bloqueo).
            // Con opacidad 0 sigue recibiendo el teclado.
            opacity: (entradaTexto.text.length > 0
                    || root.greeter.verificando
                    || root.greeter.mensaje !== "") ? 1 : 0

            Behavior on opacity { NumberAnimation { duration: 200 } }
            Behavior on border.color { ColorAnimation { duration: 200 } }

            transform: Translate { id: sacudida }

            Text {
                anchors.left: parent.left
                anchors.leftMargin: 18
                anchors.right: parent.right
                anchors.rightMargin: 18
                anchors.verticalCenter: parent.verticalCenter
                visible: entradaTexto.text.length === 0 || root.greeter.verificando
                text: root.greeter.verificando ? "Iniciando sesión..."
                    : root.greeter.mensaje !== "" ? root.greeter.mensaje
                    : "Contraseña..."
                color: root.greeter.mensaje !== "" && !root.greeter.verificando ? Tema.error : Tema.tenue
                font.family: Tema.fuente
                font.pixelSize: 15
                font.italic: true
                elide: Text.ElideRight
            }

            TextInput {
                id: entradaTexto
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: 18
                anchors.rightMargin: 18
                anchors.verticalCenter: parent.verticalCenter
                echoMode: TextInput.Password
                passwordCharacter: "•"
                color: Tema.texto
                font.family: Tema.fuente
                font.pixelSize: 18
                font.letterSpacing: 2
                clip: true
                focus: root.principal
                enabled: !root.greeter.verificando
                opacity: root.greeter.verificando ? 0 : 1

                onTextChanged: {
                    root.greeter.contrasena = text;
                    if (text.length > 0)
                        root.greeter.mensaje = "";
                }
                onAccepted: root.greeter.entrar()
                Keys.onEscapePressed: {
                    // Sin greetd (prueba) Esc cierra; con greetd solo borra
                    if (!Greetd.available)
                        Qt.quit();
                    text = "";
                }
                Keys.onLeftPressed: event => {
                    if (text.length === 0) root.greeter.cambiarUsuario(-1);
                    else event.accepted = false;
                }
                Keys.onRightPressed: event => {
                    if (text.length === 0) root.greeter.cambiarUsuario(1);
                    else event.accepted = false;
                }
            }
        }

        // ----- Esquina inferior derecha: reiniciar y apagar -----
        Row {
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: 28
            spacing: 22

            Repeater {
                model: [
                    { icono: "󰜉", comando: ["systemctl", "reboot"] },
                    { icono: "󰐥", comando: ["systemctl", "poweroff"] }
                ]

                delegate: Text {
                    required property var modelData
                    text: modelData.icono
                    color: zona.containsMouse ? Tema.acento : Tema.texto
                    font.family: Tema.fuenteIconos
                    font.pixelSize: 26

                    MouseArea {
                        id: zona
                        anchors.fill: parent
                        anchors.margins: -8
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Quickshell.execDetached(modelData.comando)
                    }
                }
            }
        }
    }

    // ---------- Animación de error: el campo tiembla ----------
    SequentialAnimation {
        id: animSacudida
        NumberAnimation { target: sacudida; property: "x"; to: -14; duration: 50 }
        NumberAnimation { target: sacudida; property: "x"; to: 14; duration: 70 }
        NumberAnimation { target: sacudida; property: "x"; to: -8; duration: 60 }
        NumberAnimation { target: sacudida; property: "x"; to: 0; duration: 50 }
    }

    Connections {
        target: root.greeter
        function onFallo() {
            entradaTexto.text = "";
            animSacudida.restart();
        }
    }
}
