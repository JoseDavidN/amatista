// ==========================================================
// Grabación de pantalla: solo se ve mientras se graba.
// Punto rojo que late suavemente + tiempo transcurrido (mm:ss)
// Clic: detener y guardar
// ==========================================================
import QtQuick
import qs.Comun

Pildora {
    id: mod

    readonly property bool grabando: ServicioGrabacion.grabando
    property int segundos: 0

    function actualizar() {
        segundos = Math.max(0, Math.floor(Date.now() / 1000 - ServicioGrabacion.inicio));
    }

    function formato(s) {
        const m = Math.floor(s / 60);
        const r = s % 60;
        return (m < 10 ? "0" : "") + m + ":" + (r < 10 ? "0" : "") + r;
    }

    visible: grabando
    onGrabandoChanged: if (grabando) actualizar()

    icono: "●"
    colorIcono: Tema.error
    tamanoIcono: 14
    texto: formato(segundos)
    colorTexto: Tema.error
    colorHover: Tema.pildoraPeligro
    tooltip: "Grabando pantalla\n" + ServicioGrabacion.destino + "\nClic para detener"

    onClicIzquierdo: ServicioGrabacion.detener()

    // Latido suave del punto (solo mientras se ve)
    SequentialAnimation on colorIcono {
        running: mod.grabando
        loops: Animation.Infinite
        ColorAnimation { to: Tema.conAlfa(Tema.error, 0.25); duration: 900; easing.type: Easing.InOutSine }
        ColorAnimation { to: Tema.error; duration: 900; easing.type: Easing.InOutSine }
    }

    // El reloj solo corre mientras se graba
    Timer {
        interval: 1000
        repeat: true
        running: mod.grabando
        onTriggered: mod.actualizar()
    }
}
