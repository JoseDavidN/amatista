// ==========================================================
// Bateria: icono con color segun el nivel, texto segun el estado
// Clic: alterna entre porcentaje y tiempo restante
// ==========================================================
import QtQuick
import Quickshell
import Quickshell.Services.UPower
import qs.Comun

Pildora {
    id: mod

    readonly property var dispositivo: UPower.displayDevice
    readonly property bool hay: dispositivo !== null && dispositivo.isLaptopBattery
    readonly property int nivel: hay ? Math.round(dispositivo.percentage * 100) : 0
    readonly property bool cargando: hay && (dispositivo.state === UPowerDeviceState.Charging
                                          || dispositivo.state === UPowerDeviceState.PendingCharge)
    readonly property bool llena: hay && dispositivo.state === UPowerDeviceState.FullyCharged
    readonly property bool conectado: hay && !UPower.onBattery
    readonly property bool critica: nivel <= 15 && !conectado

    readonly property var iconos: ["󰂎", "󰁺", "󰁻", "󰁼", "󰁽", "󰁾", "󰁿", "󰂀", "󰂁", "󰂂", "󰁹"]
    readonly property var coloresNivel: [Tema.error, Tema.error, Tema.naranja, Tema.naranja, Tema.ambar,
                                          Tema.ambar, Tema.lima, Tema.verde, Tema.verde, Tema.verde, Tema.verde]

    property bool mostrarTiempo: false

    function formatoTiempo(segundos) {
        if (!segundos || segundos <= 0) return "--";
        const h = Math.floor(segundos / 3600);
        const m = Math.floor((segundos % 3600) / 60);
        return h > 0 ? h + "h " + m + "m" : m + "m";
    }

    visible: hay
    relleno: 14
    colorFondo: Tema.fondoTarjeta
    conHover: false

    icono: llena ? "󰁹" : cargando ? "󰂄" : conectado ? "󰚥" : iconos[Math.min(10, Math.floor(nivel / 10))]
    colorIcono: llena ? Tema.exito : cargando || conectado ? Tema.acento : coloresNivel[Math.min(10, Math.floor(nivel / 10))]

    texto: llena ? "Llena"
         : mostrarTiempo ? formatoTiempo(cargando ? dispositivo.timeToFull : dispositivo.timeToEmpty)
         : nivel + "%"

    colorTexto: cargando || conectado ? Tema.acento
              : nivel <= 15 ? Tema.error
              : nivel <= 30 ? Tema.ambar
              : Tema.exito

    readonly property string detalle: {
        if (!hay) return "";
        const partes = [];
        if (dispositivo.healthSupported && dispositivo.healthPercentage > 0)
            partes.push("Salud: " + Math.round(dispositivo.healthPercentage) + "%");
        if (dispositivo.changeRate > 0)
            partes.push("Consumo: " + dispositivo.changeRate.toFixed(1) + " W");
        return partes.join("  ·  ");
    }

    tooltip: {
        if (!hay) return "";
        const estado = llena ? "Batería llena"
                     : cargando ? "Cargando · llena en " + formatoTiempo(dispositivo.timeToFull)
                     : conectado ? "Conectado a la corriente"
                     : "Descargando · quedan " + formatoTiempo(dispositivo.timeToEmpty);
        return detalle !== "" ? estado + "\n" + detalle : estado;
    }

    onClicIzquierdo: mostrarTiempo = !mostrarTiempo

    // Critica y descargando: el fondo parpadea suavemente en rojo
    SequentialAnimation on color {
        running: mod.critica
        loops: Animation.Infinite
        ColorAnimation { to: Tema.conAlfa(Tema.error, 0.35); duration: 800; easing.type: Easing.InOutSine }
        ColorAnimation { to: Tema.fondoTarjeta; duration: 800; easing.type: Easing.InOutSine }
    }
}
