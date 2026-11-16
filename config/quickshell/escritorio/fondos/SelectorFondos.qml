// ==========================================================
// Selector de fondos de pantalla
// - Carrusel de una fila en la parte inferior de la pantalla
// - Pestana "Escritorio": aplica el fondo al instante (hyprpaper)
// - Pestana "Bloqueo": elige el fondo de la pantalla de bloqueo
// - Las imagenes se leen de ~/Imágenes/wallpaper (script ~/.local/bin/fondos)
//
// Teclas: flechas para moverse, Enter aplicar, Tab cambiar de
// pestana, Inicio/Fin para ir al extremo, Escape cerrar.
//
//   qs -c escritorio ipc call fondos alternar
// ==========================================================
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Widgets
import qs.Comun
import qs.paneles

Scope {
    id: selector

    readonly property string home: Quickshell.env("HOME")
    readonly property string script: home + "/.local/bin/fondos"
    readonly property int anchoMiniatura: 256
    readonly property int altoMiniatura: 144

    property bool abierto: false
    property string pestana: "escritorio"   // "escritorio" o "bloqueo"
    property string carpeta: ""
    property var imagenes: []
    property string actualEscritorio: ""
    property string actualBloqueo: ""

    readonly property string actual: pestana === "escritorio" ? actualEscritorio : actualBloqueo

    function ruta(nombre) {
        return carpeta + "/" + nombre;
    }

    function pantallaEnfocada() {
        const m = Hyprland.focusedMonitor;
        const pantallas = Quickshell.screens;
        for (let i = 0; i < pantallas.length; i++) {
            if (m && pantallas[i].name === m.name) return pantallas[i];
        }
        return pantallas.length > 0 ? pantallas[0] : null;
    }

    function abrir() {
        ventana.screen = pantallaEnfocada();
        abierto = true;
        recargar();
        tarjeta.opacity = 0;
        deslizamiento.y = 40;
        entrada.restart();
        Qt.callLater(() => lista.forceActiveFocus());
    }

    function cerrar() {
        abierto = false;
    }

    function alternar() {
        if (abierto) cerrar();
        else abrir();
    }

    function recargar() {
        if (!listar.running) listar.running = true;
    }

    // Salida de "fondos listar": carpeta --- imagenes --- escritorio --- bloqueo
    function procesar(texto) {
        const partes = texto.split("---\n");
        carpeta = (partes[0] || "").trim();
        imagenes = (partes[1] || "").split("\n").map(s => s.trim()).filter(s => s !== "");
        actualEscritorio = (partes[2] || "").trim();
        actualBloqueo = (partes[3] || "").trim();
        irAActual();
    }

    // Deja seleccionada (y a la vista) la imagen en uso
    function irAActual() {
        let i = 0;
        for (let j = 0; j < imagenes.length; j++) {
            if (ruta(imagenes[j]) === actual) { i = j; break; }
        }
        lista.currentIndex = i;
        Qt.callLater(() => lista.positionViewAtIndex(i, ListView.Center));
    }

    function cambiarPestana(p) {
        if (pestana === p) return;
        pestana = p;
        irAActual();
    }

    function aplicar(nombre) {
        if (!nombre) return;
        const r = ruta(nombre);
        if (pestana === "escritorio") {
            actualEscritorio = r;
            Quickshell.execDetached([script, "escritorio", r]);
        } else {
            actualBloqueo = r;
            Quickshell.execDetached([script, "bloqueo", r]);
        }
    }

    Process {
        id: listar
        command: [selector.script, "listar"]
        stdout: StdioCollector {
            onStreamFinished: selector.procesar(this.text)
        }
    }

    IpcHandler {
        target: "fondos"
        function alternar(): void { selector.alternar(); }
        function abrir(): void { selector.abrir(); }
        function cerrar(): void { selector.cerrar(); }
    }

    // ---------- Ventana ----------
    // Capa transparente de pantalla completa (sin oscurecer, para ver el
    // fondo nuevo en vivo). Clic fuera de la tarjeta = cerrar.
    PanelWindow {
        id: ventana

        visible: selector.abierto
        color: "transparent"

        WlrLayershell.namespace: "selector-fondos"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: selector.abierto ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        exclusionMode: ExclusionMode.Ignore

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        MouseArea {
            anchors.fill: parent
            onClicked: selector.cerrar()
        }

        ParallelAnimation {
            id: entrada
            NumberAnimation { target: tarjeta; property: "opacity"; to: 1; duration: 200; easing.type: Easing.OutCubic }
            NumberAnimation { target: deslizamiento; property: "y"; to: 0; duration: 260; easing.type: Easing.OutCubic }
        }

        Rectangle {
            id: tarjeta

            // Centrada, sin ocupar todo el ancho de la pantalla
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 24
            width: Math.min(parent.width - 2 * 120, 1400)
            height: contenido.implicitHeight + 32
            radius: 20
            color: Tema.fondoTarjeta
            border.width: 1
            border.color: Tema.borde

            transform: Translate { id: deslizamiento }

            // Evita que los clics dentro cierren el selector
            MouseArea {
                anchors.fill: parent
            }

            Column {
                id: contenido

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 16
                spacing: 14

                // ----- Encabezado: pestanas y acciones -----
                Item {
                    width: parent.width
                    height: 34

                    Row {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 6

                        Repeater {
                            model: [
                                { id: "escritorio", icono: "󰍹", texto: "Escritorio" },
                                { id: "bloqueo", icono: "󰍁", texto: "Bloqueo" }
                            ]

                            delegate: Rectangle {
                                id: pestanaBoton

                                required property var modelData
                                readonly property bool activa: selector.pestana === modelData.id

                                width: filaPestana.implicitWidth + 28
                                height: 34
                                radius: 17
                                color: activa ? Tema.acento : zonaPestana.containsMouse ? Tema.campoHover : Tema.campo

                                Behavior on color { ColorAnimation { duration: 140 } }

                                Row {
                                    id: filaPestana
                                    anchors.centerIn: parent
                                    spacing: 8

                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: pestanaBoton.modelData.icono
                                        color: pestanaBoton.activa ? Tema.fondo : Tema.texto
                                        font.family: Tema.fuenteBarra
                                        font.pixelSize: 16
                                    }

                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: pestanaBoton.modelData.texto
                                        color: pestanaBoton.activa ? Tema.fondo : Tema.texto
                                        font.family: Tema.fuenteBarra
                                        font.pixelSize: 13
                                        font.bold: true
                                    }
                                }

                                MouseArea {
                                    id: zonaPestana
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        selector.cambiarPestana(pestanaBoton.modelData.id);
                                        lista.forceActiveFocus();
                                    }
                                }
                            }
                        }
                    }

                    Row {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 8

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "󰋯  " + selector.imagenes.length + (selector.imagenes.length === 1 ? " imagen" : " imágenes")
                            color: Tema.tenue
                            font.family: Tema.fuenteBarra
                            font.pixelSize: 12
                        }

                        BotonTexto {
                            visible: selector.pestana === "bloqueo"
                            icono: "󰌾"
                            texto: "Probar bloqueo"
                            onClic: {
                                selector.cerrar();
                                Quickshell.execDetached([selector.home + "/.local/bin/bloquear"]);
                            }
                        }

                        BotonTexto {
                            icono: "󰝰"
                            texto: "Abrir carpeta"
                            onClic: {
                                Quickshell.execDetached(["nautilus", "--new-window", selector.carpeta]);
                                selector.cerrar();
                            }
                        }
                    }
                }

                // ----- Carrusel -----
                ListView {
                    id: lista

                    width: parent.width
                    height: selector.altoMiniatura + 46
                    visible: selector.imagenes.length > 0
                    orientation: ListView.Horizontal
                    spacing: 16
                    clip: true
                    focus: true
                    leftMargin: 14
                    rightMargin: 14
                    boundsBehavior: Flickable.StopAtBounds
                    highlightMoveDuration: 200
                    model: selector.imagenes

                    // true mientras la seleccion cambia por pasar el raton:
                    // asi el carrusel no se mueve bajo el cursor
                    property bool porRaton: false

                    onCurrentIndexChanged: if (!porRaton) positionViewAtIndex(currentIndex, ListView.Contain)

                    function seleccionarConRaton(i) {
                        porRaton = true;
                        currentIndex = i;
                        porRaton = false;
                    }

                    // ----- Rueda del raton: desplaza el carrusel una imagen por paso -----
                    property real destinoX: contentX
                    property real acumulado: 0

                    function desplazar(event) {
                        // Rueda vertical u horizontal (touchpad); 120 = un paso de rueda
                        const delta = event.angleDelta.y !== 0 ? event.angleDelta.y : event.angleDelta.x;
                        acumulado += delta;
                        const pasos = Math.trunc(acumulado / 120);
                        if (pasos === 0) return;
                        acumulado -= pasos * 120;

                        const minimo = -leftMargin;
                        const maximo = Math.max(minimo, contentWidth + rightMargin - width);
                        const base = animDesplazar.running ? destinoX : contentX;
                        destinoX = Math.max(minimo, Math.min(maximo,
                                   base - pasos * (selector.anchoMiniatura + spacing)));
                        animDesplazar.to = destinoX;
                        animDesplazar.restart();
                    }

                    NumberAnimation {
                        id: animDesplazar
                        target: lista
                        property: "contentX"
                        duration: 220
                        easing.type: Easing.OutCubic
                    }

                    // Rueda en los espacios entre imagenes
                    WheelHandler {
                        target: null
                        onWheel: event => lista.desplazar(event)
                    }

                    Keys.onPressed: event => {
                        const total = count;
                        if (event.key === Qt.Key_Escape) {
                            selector.cerrar();
                        } else if (event.key === Qt.Key_Right || event.key === Qt.Key_L) {
                            if (total > 0) currentIndex = Math.min(total - 1, currentIndex + 1);
                        } else if (event.key === Qt.Key_Left || event.key === Qt.Key_H) {
                            if (total > 0) currentIndex = Math.max(0, currentIndex - 1);
                        } else if (event.key === Qt.Key_Home) {
                            currentIndex = 0;
                        } else if (event.key === Qt.Key_End) {
                            currentIndex = Math.max(0, total - 1);
                        } else if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
                            selector.cambiarPestana(selector.pestana === "escritorio" ? "bloqueo" : "escritorio");
                        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
                            selector.aplicar(selector.imagenes[currentIndex]);
                        } else {
                            return;
                        }
                        event.accepted = true;
                    }

                    delegate: Item {
                        id: elemento

                        required property string modelData
                        required property int index

                        readonly property string rutaImagen: selector.ruta(modelData)
                        readonly property bool enUso: rutaImagen === selector.actual
                        readonly property bool elegido: index === lista.currentIndex
                        readonly property bool resaltado: elegido

                        width: selector.anchoMiniatura
                        height: lista.height

                        Item {
                            id: marco

                            // Resaltada: sube un poco (sin agrandarse, para no
                            // salirse por los lados en la primera y la última)
                            anchors.top: parent.top
                            anchors.topMargin: elemento.resaltado ? 2 : 8
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: selector.anchoMiniatura
                            height: selector.altoMiniatura

                            Behavior on anchors.topMargin { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

                            // Mientras carga
                            Rectangle {
                                anchors.fill: parent
                                radius: 12
                                color: Tema.campo
                                visible: miniatura.status !== Image.Ready

                                Text {
                                    anchors.centerIn: parent
                                    text: miniatura.status === Image.Error ? "No se pudo abrir" : "Cargando…"
                                    color: Tema.tenue
                                    font.family: Tema.fuenteBarra
                                    font.pixelSize: 11
                                }
                            }

                            // Miniatura recortada con esquinas redondeadas
                            ClippingRectangle {
                                anchors.fill: parent
                                radius: 12
                                color: "transparent"
                                visible: miniatura.status === Image.Ready

                                Image {
                                    id: miniatura
                                    anchors.fill: parent
                                    source: "file://" + elemento.rutaImagen
                                    sourceSize.width: 512
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                }
                            }

                            // Borde: en uso (grueso, acento) o elegido con el teclado
                            Rectangle {
                                anchors.fill: parent
                                radius: 12
                                color: "transparent"
                                border.width: elemento.enUso ? 3 : elemento.resaltado ? 2 : 1
                                border.color: elemento.enUso ? Tema.acento
                                            : elemento.resaltado ? Tema.suave
                                            : Tema.borde
                            }

                            // Marca de "en uso"
                            Rectangle {
                                visible: elemento.enUso
                                anchors.top: parent.top
                                anchors.right: parent.right
                                anchors.margins: 8
                                width: 26
                                height: 26
                                radius: 13
                                color: Tema.acento

                                Text {
                                    anchors.centerIn: parent
                                    text: "󰄬"
                                    color: Tema.fondo
                                    font.family: Tema.fuenteBarra
                                    font.pixelSize: 15
                                }
                            }

                            MouseArea {
                                id: zona
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor

                                // Pasar el raton por encima = seleccionarla
                                onContainsMouseChanged: if (containsMouse) lista.seleccionarConRaton(elemento.index)

                                // Rueda sobre la imagen: desplazar el carrusel
                                onWheel: wheel => lista.desplazar(wheel)

                                // Clic = ponerla de fondo
                                onClicked: {
                                    lista.currentIndex = elemento.index;
                                    selector.aplicar(elemento.modelData);
                                    lista.forceActiveFocus();
                                }
                            }
                        }

                        Text {
                            anchors.top: marco.bottom
                            anchors.topMargin: 10
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: parent.width - 8
                            horizontalAlignment: Text.AlignHCenter
                            text: elemento.modelData.replace(/\.[^.]+$/, "")
                            color: elemento.enUso ? Tema.acento : Tema.suave
                            font.family: Tema.fuenteBarra
                            font.pixelSize: 12
                            font.bold: elemento.enUso
                            elide: Text.ElideMiddle
                        }
                    }
                }

                // ----- Carpeta vacia -----
                Text {
                    visible: selector.imagenes.length === 0
                    width: parent.width
                    height: 80
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    wrapMode: Text.Wrap
                    text: "No hay imágenes en " + selector.carpeta + "\nCopia ahí tus fondos (PNG, JPG o WebP) y vuelve a abrir el selector."
                    color: Tema.tenue
                    font.family: Tema.fuenteBarra
                    font.pixelSize: 13
                }

                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: selector.pestana === "escritorio"
                          ? "←→ o rueda moverse   ·   Enter o clic aplicar al escritorio   ·   Tab pestaña Bloqueo   ·   Esc cerrar"
                          : "←→ o rueda moverse   ·   Enter o clic usar al bloquear   ·   Tab pestaña Escritorio   ·   Esc cerrar"
                    color: Tema.tenue
                    font.family: Tema.fuenteBarra
                    font.pixelSize: 11
                }
            }
        }
    }
}
