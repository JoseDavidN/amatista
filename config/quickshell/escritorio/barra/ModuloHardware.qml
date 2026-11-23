// ==========================================================
// Hardware en una sola capsula: uso de CPU
//   Clic:    panel con todo el hardware
//   Derecho: la capsula se alarga hacia la izquierda con Disco / RAM / GPU
// Se actualiza cada 10 s.
// ==========================================================
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Comun

Rectangle {
    id: mod

    property int cpu: 0
    property int ram: 0
    // Uso de la GPU en %; -1 si el equipo no permite leerlo (se oculta)
    property int gpu: -1
    property string discoUsado: "-"
    property string discoTotal: "-"
    property real totalAnterior: 0
    property real ocioAnterior: 0

    // Se despliega con el clic derecho
    property bool abierto: false
    readonly property int relleno: 10

    implicitWidth: extra.width + segCpu.implicitWidth + relleno * 2
    implicitHeight: Tema.altoPildora
    radius: Tema.radioPildora
    color: hover.hovered || panel.abierto ? Tema.pildoraHover : Tema.pildora

    Behavior on color { ColorAnimation { duration: 120 } }

    // Bytes -> "123G" (en GiB, igual que df -h)
    function gb(bytes) {
        return Math.round(bytes / 1073741824) + "G";
    }

    function procesar(salida) {
        const lineas = salida.trim().split("\n");

        // "cpu  user nice system idle iowait irq softirq steal ..."
        const v = lineas[0].trim().split(/\s+/).slice(1).map(Number);
        const ocio = v[3] + (v[4] || 0);
        const total = v.reduce((a, b) => a + b, 0);
        if (totalAnterior > 0 && total > totalAnterior)
            cpu = Math.round(100 * (1 - (ocio - ocioAnterior) / (total - totalAnterior)));
        totalAnterior = total;
        ocioAnterior = ocio;

        let memTotal = 0, memDisponible = 0;
        let gpuLeida = -1;
        for (const l of lineas) {
            // "GPU <porcentaje>" (solo aparece si hay una GPU legible)
            if (l.startsWith("GPU ")) {
                const g = parseInt(l.split(/\s+/)[1]);
                if (!isNaN(g)) gpuLeida = g;
            }
            if (l.startsWith("MemTotal:")) memTotal = parseInt(l.split(/\s+/)[1]);
            if (l.startsWith("MemAvailable:")) memDisponible = parseInt(l.split(/\s+/)[1]);
            // "DISCO <usados> <total>" (bytes de la particion raiz)
            if (l.startsWith("DISCO")) {
                const d = l.trim().split(/\s+/);
                discoUsado = gb(Number(d[1]));
                discoTotal = gb(Number(d[2]));
            }
        }
        if (memTotal > 0)
            ram = Math.round(100 * (memTotal - memDisponible) / memTotal);
        gpu = gpuLeida;
    }

    // Uso de la GPU, segun lo que haya en el equipo:
    //  - NVIDIA: nvidia-smi (driver propietario)
    //  - AMD (amdgpu) e Intel Xe: /sys/class/drm/cardN/device/gpu_busy_percent
    //  - Otra (p. ej. Intel i915 antigua): no imprime nada y el bloque se oculta
    readonly property string scriptGpu:
        "u=''; " +
        "if command -v nvidia-smi >/dev/null 2>&1; then " +
        "  u=$(nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits 2>/dev/null | head -1); " +
        "fi; " +
        "case \"$u\" in ''|*[!0-9\\ ]*) u=''; for f in /sys/class/drm/card*/device/gpu_busy_percent; do " +
        "  [ -r \"$f\" ] && u=$(cat \"$f\" 2>/dev/null) && break; done;; esac; " +
        "[ -n \"$u\" ] && echo GPU $u; true"

    Process {
        id: lectura
        command: ["sh", "-c",
            "head -1 /proc/stat; grep -E '^(MemTotal|MemAvailable):' /proc/meminfo; " +
            "echo DISCO $(df -B1 --output=used,size / | tail -1); " + mod.scriptGpu]
        stdout: StdioCollector {
            onStreamFinished: mod.procesar(this.text)
        }
    }

    // Una lectura rapida al inicio (la CPU necesita dos muestras) y luego cada 10 s
    Timer {
        interval: 1000
        running: true
        onTriggered: if (!lectura.running) lectura.running = true
    }

    Timer {
        interval: 10000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: if (!lectura.running) lectura.running = true
    }

    HoverHandler {
        id: hover
        cursorShape: Qt.PointingHandCursor
    }

    TapHandler {
        acceptedButtons: Qt.LeftButton
        onTapped: panel.alternar()
    }

    TapHandler {
        acceptedButtons: Qt.RightButton
        onTapped: mod.abierto = !mod.abierto
    }

    PanelHardware {
        id: panel
        objetivo: mod
    }

    // Icono + texto, con el mismo estilo que Pildora
    component Segmento: Row {
        property string icono
        property color colorIcono
        property string texto
        spacing: 8

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: parent.icono
            color: parent.colorIcono
            font.family: Tema.fuenteBarra
            font.pixelSize: 16
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: parent.texto
            color: Tema.textoBarra
            font.family: Tema.fuenteBarra
            font.pixelSize: 14
            font.bold: true
        }
    }

    component Separador: Text {
        anchors.verticalCenter: parent.verticalCenter
        leftPadding: 10
        rightPadding: 10
        text: "/"
        color: Tema.tenue
        font.family: Tema.fuenteBarra
        font.pixelSize: 14
        font.bold: true
    }

    Row {
        anchors.right: parent.right
        anchors.rightMargin: mod.relleno
        anchors.verticalCenter: parent.verticalCenter

        // Disco / RAM / GPU: se despliega hacia la izquierda dentro de la capsula
        Item {
            id: extra
            anchors.verticalCenter: parent.verticalCenter
            height: Tema.altoPildora
            width: mod.abierto ? filaExtra.implicitWidth : 0
            clip: true

            Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }

            Row {
                id: filaExtra
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter

                Segmento {
                    anchors.verticalCenter: parent.verticalCenter
                    icono: "󰋊"
                    colorIcono: Tema.cian
                    texto: mod.discoUsado
                }
                Separador {}

                Segmento {
                    anchors.verticalCenter: parent.verticalCenter
                    icono: ""
                    colorIcono: Tema.durazno
                    texto: mod.ram + "%"
                }
                Separador {}

                // GPU: solo aparece si el equipo permite leer su uso
                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: mod.gpu >= 0

                    Segmento {
                        anchors.verticalCenter: parent.verticalCenter
                        icono: "󰢮"
                        colorIcono: Tema.verde
                        texto: mod.gpu + "%"
                    }
                    Separador {}
                }
            }
        }

        Segmento {
            id: segCpu
            anchors.verticalCenter: parent.verticalCenter
            icono: ""
            colorIcono: Tema.rosa
            texto: mod.cpu + "%"
        }
    }
}
