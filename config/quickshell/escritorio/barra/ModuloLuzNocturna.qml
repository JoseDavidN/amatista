// ==========================================================
// Luz nocturna (hyprsunset)
// Clic: encender / apagar · Encendida en ámbar, apagada tenue
// ==========================================================
import QtQuick
import qs.Comun

Pildora {
    readonly property bool encendida: ServicioLuzNocturna.encendida

    icono: encendida ? "󰖔" : "󰖨"
    colorIcono: encendida ? Tema.ambar : Tema.tenue
    tooltip: !ServicioLuzNocturna.instalado ? "Luz nocturna: hyprsunset no está instalado"
           : encendida ? "Luz nocturna encendida (" + ServicioLuzNocturna.temperatura + " K)\nClic para apagarla"
           : "Luz nocturna apagada\nClic para encenderla"

    onClicIzquierdo: ServicioLuzNocturna.alternar()
}
