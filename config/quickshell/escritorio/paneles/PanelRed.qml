// ==========================================================
// Panel de red (NetworkManager con nmcli)
// - Encender / apagar Wi-Fi, buscar redes
// - Conectar con un clic; si la red pide contrasena se abre un
//   dialogo en el centro de la pantalla
// - Desconectar, ver la IP
// ==========================================================
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Comun

PanelEmergente {
    id: panel

    titulo: "Red"
    icono: "󰖩"
    colorIcono: Tema.ambar

    property bool wifiActivo: true
    property string interfazWifi: ""
    property string conectadaA: ""
    property string interfazCable: ""
    property string ip: ""
    property var redes: []
    property bool buscando: false

    property string conectando: ""
    property var redEnCurso: null
    property bool eraNueva: false
    property string error: ""

    readonly property var iconosWifi: ["󰤯", "󰤟", "󰤢", "󰤥", "󰤨"]

    // nmcli separa con ":" y escapa los ":" de los valores como "\\:"
    function campos(linea) {
        const r = [];
        let actual = "";
        for (let i = 0; i < linea.length; i++) {
            const ch = linea[i];
            if (ch === "\\" && i + 1 < linea.length) { actual += linea[i + 1]; i++; }
            else if (ch === ":") { r.push(actual); actual = ""; }
            else actual += ch;
        }
        r.push(actual);
        return r;
    }

    function lineas(texto) {
        return (texto || "").trim().split("\n").filter(l => l !== "");
    }

    function procesar(salida) {
        const partes = salida.split("---");

        wifiActivo = (partes[0] || "").trim() === "enabled";

        // Dispositivos: DEVICE:TYPE:STATE:CONNECTION
        let wifiDev = "", wifiCon = "", cableDev = "";
        for (const l of lineas(partes[1])) {
            const c = campos(l);
            if (c.length < 4) continue;
            if (c[1] === "wifi") {
                wifiDev = c[0];
                if (c[2] === "connected") wifiCon = c[3];
            }
            if (c[1] === "ethernet" && c[2] === "connected") cableDev = c[0];
        }

        // Conexiones guardadas: NAME:TYPE
        const guardadas = {};
        for (const l of lineas(partes[3])) {
            const c = campos(l);
            if (c.length >= 2 && c[1] === "802-11-wireless") guardadas[c[0]] = true;
        }

        // Redes visibles: IN-USE:SIGNAL:SECURITY:SSID (una por nombre, la de mejor senal)
        const porNombre = {};
        let enUso = "";
        for (const l of lineas(partes[2])) {
            const c = campos(l);
            if (c.length < 4 || c[3] === "") continue;
            const red = {
                ssid: c[3],
                senal: parseInt(c[1]) || 0,
                segura: c[2] !== "" && c[2] !== "--",
                seguridad: c[2] === "--" ? "" : c[2],
                conocida: guardadas[c[3]] === true,
                enUso: c[0] === "*"
            };
            if (red.enUso) enUso = red.ssid;
            const previa = porNombre[red.ssid];
            if (!previa || red.senal > previa.senal || red.enUso) porNombre[red.ssid] = red;
        }
        const lista = Object.keys(porNombre).map(k => porNombre[k]).filter(r => r.ssid !== enUso);
        lista.sort((a, b) => (b.conocida - a.conocida) || (b.senal - a.senal));

        // IP de la interfaz activa
        const activa = cableDev || (wifiCon ? wifiDev : "");
        let direccion = "";
        for (const l of lineas(partes[4])) {
            const c = l.trim().split(/\s+/);
            if (c.length >= 4 && c[1] === activa && c[2] === "inet") direccion = c[3].split("/")[0];
        }

        interfazWifi = wifiDev;
        conectadaA = enUso || wifiCon;
        interfazCable = cableDev;
        ip = direccion;
        redes = lista.slice(0, 10);
    }

    function refrescar() {
        if (!consulta.running) consulta.running = true;
    }

    function buscar() {
        buscando = true;
        Quickshell.execDetached(["nmcli", "device", "wifi", "rescan"]);
        finBusqueda.restart();
    }

    function radio(encender) {
        Quickshell.execDetached(["nmcli", "radio", "wifi", encender ? "on" : "off"]);
        refrescoDiferido.restart();
    }

    // Clic en una red: si necesita contrasena se abre el dialogo central
    function conectar(red) {
        error = "";
        if (red.segura && !red.conocida) {
            cerrar();
            dialogo.abrir(red, "");
            return;
        }
        iniciar(red, ["nmcli", "device", "wifi", "connect", red.ssid], !red.conocida);
    }

    // Desde el dialogo. Si la red ya estaba guardada (contrasena cambiada),
    // se borra el perfil viejo antes de conectar con la nueva.
    function conectarConClave(red, clave) {
        if (red.conocida) {
            iniciar(red, ["sh", "-c",
                'nmcli connection delete id "$1" >/dev/null 2>&1; exec nmcli device wifi connect "$1" password "$2"',
                "sh", red.ssid, clave], true);
        } else {
            iniciar(red, ["nmcli", "device", "wifi", "connect", red.ssid, "password", clave], true);
        }
    }

    function iniciar(red, comando, nueva) {
        if (accion.running) return;
        conectando = red.ssid;
        redEnCurso = red;
        eraNueva = nueva;
        accion.command = comando;
        accion.running = true;
    }

    function desconectar() {
        if (interfazWifi !== "")
            Quickshell.execDetached(["nmcli", "device", "disconnect", interfazWifi]);
        refrescoDiferido.restart();
    }

    Connections {
        target: panel
        function onAbrio() {
            panel.error = "";
            panel.refrescar();
        }
    }

    Process {
        id: consulta
        command: ["sh", "-c", "nmcli radio wifi; echo ---; nmcli -t -f DEVICE,TYPE,STATE,CONNECTION device; echo ---; nmcli -t -f IN-USE,SIGNAL,SECURITY,SSID device wifi list; echo ---; nmcli -t -f NAME,TYPE connection show; echo ---; ip -4 -o addr show"]
        environment: ({ LC_ALL: "C" })
        stdout: StdioCollector {
            onStreamFinished: panel.procesar(this.text)
        }
    }

    Process {
        id: accion
        environment: ({ LC_ALL: "C" })
        stderr: StdioCollector { id: errores }

        onExited: codigo => {
            const red = panel.redEnCurso;
            const nombre = panel.conectando;
            panel.conectando = "";
            panel.redEnCurso = null;

            if (codigo === 0) {
                dialogo.cerrar();
                Quickshell.execDetached(["notify-send", "-a", "Red", "-i", "network-wireless", "Wi-Fi", "Conectado a " + nombre]);
            } else {
                // Si el perfil era nuevo, borrarlo para poder reintentar
                if (panel.eraNueva)
                    Quickshell.execDetached(["nmcli", "connection", "delete", "id", nombre]);

                if (dialogo.visible) {
                    dialogo.fallo("Contraseña incorrecta o la red no respondió");
                } else if (red && red.segura) {
                    // Una red guardada cuya contrasena ya no sirve
                    dialogo.abrir(red, "La contraseña guardada no funcionó. Escríbela de nuevo.");
                } else {
                    panel.error = "No se pudo conectar a " + nombre;
                }
            }
            panel.refrescar();
        }
    }

    Timer {
        interval: 5000
        running: panel.abierto
        repeat: true
        onTriggered: panel.refrescar()
    }

    Timer {
        id: finBusqueda
        interval: 4000
        onTriggered: { panel.buscando = false; panel.refrescar(); }
    }

    Timer {
        id: refrescoDiferido
        interval: 2500
        onTriggered: panel.refrescar()
    }

    accesorio: Interruptor {
        activo: panel.wifiActivo
        onAlternado: panel.radio(!panel.wifiActivo)
    }

    // ---------- Conexion actual ----------
    FilaLista {
        visible: panel.interfazCable !== ""
        icono: "󰈀"
        colorIcono: Tema.ambar
        titulo: "Cable"
        subtitulo: panel.ip !== "" ? "Conectado · " + panel.ip : "Conectado"
        colorSubtitulo: Tema.ambar
        resaltada: true
    }

    FilaLista {
        visible: panel.conectadaA !== ""
        icono: "󰖩"
        colorIcono: Tema.ambar
        titulo: panel.conectadaA
        subtitulo: panel.interfazCable === "" && panel.ip !== "" ? "Conectado · " + panel.ip : "Conectado"
        colorSubtitulo: Tema.ambar
        resaltada: true
        detalle: "Desconectar"
        colorDetalle: Tema.error
        onClic: panel.desconectar()
    }

    Text {
        visible: !panel.wifiActivo
        width: parent.width
        text: "Wi-Fi apagado"
        color: Tema.tenue
        font.family: Tema.fuenteBarra
        font.pixelSize: 13
    }

    // ---------- Redes disponibles ----------
    TituloSeccion {
        visible: panel.wifiActivo
        texto: "Redes disponibles"
        extra: panel.buscando ? "Buscando…" : ""
    }

    Repeater {
        model: panel.wifiActivo ? panel.redes : []

        delegate: FilaLista {
            required property var modelData

            icono: panel.iconosWifi[Math.min(4, Math.floor(modelData.senal / 20))]
            titulo: modelData.ssid
            subtitulo: panel.conectando === modelData.ssid ? "Conectando…"
                     : modelData.conocida ? "Guardada"
                     : modelData.segura ? "Protegida"
                     : "Abierta"
            colorSubtitulo: panel.conectando === modelData.ssid ? Tema.ambar : Tema.tenue
            detalle: modelData.segura ? "󰌾" : ""
            onClic: panel.conectar(modelData)
        }
    }

    Text {
        visible: panel.error !== ""
        width: parent.width
        wrapMode: Text.Wrap
        text: panel.error
        color: Tema.error
        font.family: Tema.fuenteBarra
        font.pixelSize: 12
    }

    // ---------- Pie ----------
    Item { width: 1; height: 2 }

    Row {
        spacing: 8

        BotonTexto {
            visible: panel.wifiActivo
            icono: "󰑐"
            texto: "Buscar redes"
            onClic: panel.buscar()
        }

        BotonTexto {
            icono: "󰒓"
            texto: "Editor de conexiones"
            onClic: {
                Quickshell.execDetached(["nm-connection-editor"]);
                panel.cerrar();
            }
        }
    }

    // ==========================================================
    // Dialogo de contrasena, centrado en la pantalla
    // Enter: conectar · Escape o clic fuera: cancelar
    // ==========================================================
    PanelWindow {
        id: dialogo

        property var red: null
        property string mensaje: ""
        property bool mostrarClave: false

        function abrir(r, aviso) {
            red = r;
            mensaje = aviso;
            mostrarClave = false;
            campoClave.text = "";
            if (panel.ventanaBarra) screen = panel.ventanaBarra.screen;
            visible = true;
            tarjetaDialogo.opacity = 0;
            tarjetaDialogo.scale = 0.96;
            entradaDialogo.restart();
            Qt.callLater(() => campoClave.forceActiveFocus());
        }

        function cerrar() {
            visible = false;
            red = null;
        }

        function enviar() {
            if (!red || panel.conectando !== "") return;
            const clave = campoClave.text;
            if (clave === "") {
                fallo("Escribe la contraseña");
                return;
            }
            if (red.seguridad.includes("WPA") && clave.length < 8) {
                fallo("La contraseña debe tener al menos 8 caracteres");
                return;
            }
            mensaje = "";
            panel.conectarConClave(red, clave);
        }

        function fallo(texto) {
            mensaje = texto;
            campoClave.selectAll();
            sacudida.restart();
            campoClave.forceActiveFocus();
        }

        visible: false
        color: "transparent"

        WlrLayershell.namespace: "dialogo-wifi"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        exclusionMode: ExclusionMode.Ignore

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        ParallelAnimation {
            id: entradaDialogo
            NumberAnimation { target: tarjetaDialogo; property: "opacity"; to: 1; duration: 180; easing.type: Easing.OutCubic }
            NumberAnimation { target: tarjetaDialogo; property: "scale"; to: 1; duration: 200; easing.type: Easing.OutCubic }
        }

        SequentialAnimation {
            id: sacudida
            NumberAnimation { target: desplazamientoCampo; property: "x"; to: -12; duration: 50 }
            NumberAnimation { target: desplazamientoCampo; property: "x"; to: 12; duration: 70 }
            NumberAnimation { target: desplazamientoCampo; property: "x"; to: -6; duration: 60 }
            NumberAnimation { target: desplazamientoCampo; property: "x"; to: 0; duration: 50 }
        }

        // Fondo oscurecido: clic = cancelar (si no se esta conectando)
        Rectangle {
            anchors.fill: parent
            color: Tema.velo

            MouseArea {
                anchors.fill: parent
                onClicked: if (panel.conectando === "") dialogo.cerrar()
            }
        }

        Rectangle {
            id: tarjetaDialogo

            anchors.centerIn: parent
            width: 420
            height: contenidoDialogo.implicitHeight + 40
            radius: 18
            color: Tema.fondoTarjeta
            border.width: 1
            border.color: Tema.borde

            // Evita que los clics dentro cierren el dialogo
            MouseArea {
                anchors.fill: parent
            }

            Column {
                id: contenidoDialogo

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 20
                spacing: 16

                // ----- Encabezado: red elegida -----
                Row {
                    spacing: 14

                    Rectangle {
                        width: 48
                        height: 48
                        radius: 14
                        color: Tema.campo

                        Text {
                            anchors.centerIn: parent
                            text: dialogo.red ? panel.iconosWifi[Math.min(4, Math.floor(dialogo.red.senal / 20))] : ""
                            color: Tema.ambar
                            font.family: Tema.fuenteBarra
                            font.pixelSize: 24
                        }
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 3

                        Text {
                            text: "Conectar a"
                            color: Tema.tenue
                            font.family: Tema.fuenteBarra
                            font.pixelSize: 12
                        }

                        Text {
                            width: 300
                            text: dialogo.red ? dialogo.red.ssid : ""
                            color: Tema.texto
                            font.family: Tema.fuenteBarra
                            font.pixelSize: 17
                            font.bold: true
                            elide: Text.ElideRight
                        }

                        Text {
                            text: dialogo.red
                                  ? "󰌾 " + (dialogo.red.seguridad || "Protegida") + "  ·  señal " + dialogo.red.senal + "%"
                                  : ""
                            color: Tema.tenue
                            font.family: Tema.fuenteBarra
                            font.pixelSize: 11
                        }
                    }
                }

                // ----- Campo de contrasena -----
                Rectangle {
                    width: parent.width
                    height: 46
                    radius: 12
                    color: Tema.campo
                    border.width: 1
                    border.color: dialogo.mensaje !== "" && panel.conectando === "" ? Tema.error
                                : campoClave.activeFocus ? Tema.acento
                                : Tema.borde

                    Behavior on border.color { ColorAnimation { duration: 150 } }

                    transform: Translate { id: desplazamientoCampo }

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 14
                        anchors.verticalCenter: parent.verticalCenter
                        visible: campoClave.text.length === 0
                        text: "Contraseña"
                        color: Tema.tenue
                        font.family: Tema.fuenteBarra
                        font.pixelSize: 14
                        font.italic: true
                    }

                    TextInput {
                        id: campoClave

                        anchors.left: parent.left
                        anchors.right: ojo.left
                        anchors.leftMargin: 14
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        echoMode: dialogo.mostrarClave ? TextInput.Normal : TextInput.Password
                        color: Tema.texto
                        font.family: Tema.fuenteBarra
                        font.pixelSize: 15
                        clip: true
                        enabled: panel.conectando === ""

                        onTextChanged: if (panel.conectando === "") dialogo.mensaje = ""
                        onAccepted: dialogo.enviar()
                        Keys.onEscapePressed: if (panel.conectando === "") dialogo.cerrar()
                    }

                    // Mostrar / ocultar la contrasena
                    Text {
                        id: ojo
                        anchors.right: parent.right
                        anchors.rightMargin: 14
                        anchors.verticalCenter: parent.verticalCenter
                        text: dialogo.mostrarClave ? "󰈉" : "󰈈"
                        color: zonaOjo.containsMouse ? Tema.acento : Tema.tenue
                        font.family: Tema.fuenteBarra
                        font.pixelSize: 18

                        MouseArea {
                            id: zonaOjo
                            anchors.fill: parent
                            anchors.margins: -6
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                dialogo.mostrarClave = !dialogo.mostrarClave;
                                campoClave.forceActiveFocus();
                            }
                        }
                    }
                }

                // ----- Mensaje de error o estado -----
                Text {
                    visible: text !== ""
                    width: parent.width
                    wrapMode: Text.Wrap
                    text: panel.conectando !== "" ? "Conectando, esto puede tardar unos segundos…" : dialogo.mensaje
                    color: panel.conectando !== "" ? Tema.ambar : Tema.error
                    font.family: Tema.fuenteBarra
                    font.pixelSize: 12
                }

                // ----- Botones -----
                Item {
                    width: parent.width
                    height: 34

                    Row {
                        anchors.right: parent.right
                        spacing: 8

                        BotonTexto {
                            texto: "Cancelar"
                            opacity: panel.conectando === "" ? 1 : 0.5
                            onClic: if (panel.conectando === "") dialogo.cerrar()
                        }

                        BotonTexto {
                            principal: true
                            icono: panel.conectando !== "" ? "" : "󰁔"
                            texto: panel.conectando !== "" ? "Conectando…" : "Conectar"
                            onClic: dialogo.enviar()
                        }
                    }
                }
            }
        }
    }
}
