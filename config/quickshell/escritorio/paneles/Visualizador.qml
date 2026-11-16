// ==========================================================
// Carátula circular con un ecualizador alrededor (cava)
// - La carátula gira lentamente mientras suena (como un disco)
// - Las barras salen del borde del círculo según el audio
// - cava solo corre mientras "activo" es true (panel abierto y sonando)
// - Sin cava instalado se ve un anillo de puntos quieto
// ==========================================================
import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import qs.Comun

Item {
    id: vis

    property string caratula: ""
    property bool sonando: false
    property bool activo: false

    property int tamanoCaratula: 150
    property real largoMaximo: 42
    readonly property real radioInterior: tamanoCaratula / 2 + 8

    // cava entrega 32 bandas (graves -> agudos); se dibujan en espejo
    // para que el círculo quede simétrico: 64 barras
    readonly property int bandas: 32
    readonly property int barras: bandas * 2
    property var valores: []
    property bool hayCava: true

    implicitWidth: tamanoCaratula + 2 * (largoMaximo + 14)
    implicitHeight: implicitWidth

    Process {
        id: cava
        running: vis.activo && vis.hayCava
        // Sale con 127 si cava no está instalado
        command: ["sh", "-c", "command -v cava >/dev/null || exit 127; exec cava -p \"$1\"",
                  "cava", Quickshell.shellDir + "/paneles/cava.conf"]
        stdout: SplitParser {
            onRead: data => {
                const v = data.split(";");
                const lista = [];
                for (let i = 0; i < vis.bandas; i++)
                    lista.push(Number(v[i]) || 0);
                vis.valores = lista;
            }
        }
        onExited: code => {
            // 127: cava no está instalado; se deja de intentar
            if (code === 127)
                vis.hayCava = false;
            vis.valores = [];
        }
    }

    onActivoChanged: if (!activo) valores = []

    function valor(i) {
        if (valores.length === 0)
            return 0;
        const banda = i < bandas ? i : barras - 1 - i;
        return valores[banda] / 100;
    }

    // Color de cada barra: degradado acento -> rosa -> acento alrededor
    function colorBarra(i) {
        const t = (1 - Math.cos(i / barras * 2 * Math.PI)) / 2;
        const a = Tema.acento, b = Tema.rosa;
        return Qt.rgba(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t, a.b + (b.b - a.b) * t, 1);
    }

    // ---------- Barras ----------
    Repeater {
        model: vis.barras

        // Punto de giro en el centro; la barra sale hacia afuera
        delegate: Item {
            required property int index
            x: vis.width / 2
            y: vis.height / 2
            width: 0
            height: 0
            rotation: index * 360 / vis.barras

            Rectangle {
                width: 4
                radius: 2
                x: -2
                height: 4 + vis.valor(index) * vis.largoMaximo
                y: -vis.radioInterior - height
                color: vis.colorBarra(index)
                opacity: vis.valores.length > 0 ? 0.95 : 0.45

                Behavior on height { NumberAnimation { duration: 70 } }
                Behavior on opacity { NumberAnimation { duration: 300 } }
            }
        }
    }

    // ---------- Carátula circular ----------
    Item {
        id: disco
        anchors.centerIn: parent
        width: vis.tamanoCaratula
        height: width

        // Gira mientras suena; se detiene donde quedó al pausar
        NumberAnimation on rotation {
            from: 0
            to: 360
            duration: 20000
            loops: Animation.Infinite
            running: true
            paused: !vis.sonando
        }

        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: Tema.campo

            Text {
                anchors.centerIn: parent
                visible: imagen.status !== Image.Ready
                text: "󰎆"
                color: Tema.rosa
                font.family: Tema.fuenteBarra
                font.pixelSize: 56
            }
        }

        Image {
            id: imagen
            anchors.fill: parent
            source: vis.caratula
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: true
            visible: false
            sourceSize.width: 300
            sourceSize.height: 300
        }

        Rectangle {
            id: mascara
            anchors.fill: parent
            radius: width / 2
            visible: false
            layer.enabled: true
        }

        MultiEffect {
            anchors.fill: parent
            visible: imagen.status === Image.Ready
            source: imagen
            maskEnabled: true
            maskSource: mascara
        }

        // Borde y "agujero" central de disco
        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: "transparent"
            border.width: 2
            border.color: Tema.conAlfa(Tema.acento, 0.8)
        }

        Rectangle {
            anchors.centerIn: parent
            width: 16; height: 16; radius: 8
            color: Tema.fondo
            border.width: 2
            border.color: Tema.conAlfa(Tema.acento, 0.8)
        }
    }
}
