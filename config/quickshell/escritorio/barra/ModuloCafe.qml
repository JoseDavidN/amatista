// Modo café: solo se ve mientras el bloqueo automático está pausado
// Clic: volver a activarlo
import QtQuick
import qs.Comun
import qs.sistema

Pildora {
    visible: !EstadoInactividad.activa
    icono: String.fromCodePoint(0xf0176)
    colorIcono: Tema.durazno
    tooltip: "Modo café: no se bloquea ni se apaga la pantalla\nClic para desactivarlo"
    onClicIzquierdo: EstadoInactividad.alternar()
}
