// ==========================================================
// Luz nocturna (hyprsunset)
// Clic: panel (encender y horario) · Derecho: encender / apagar
// Encendida en ámbar, apagada tenue
// ==========================================================
import QtQuick
import qs.Comun

Pildora {
    id: mod

    readonly property bool encendida: ServicioLuzNocturna.encendida

    icono: encendida ? "󰖔" : "󰖨"
    colorIcono: encendida ? Tema.ambar : Tema.tenue
    tooltip: !ServicioLuzNocturna.instalado ? "Luz nocturna: hyprsunset no está instalado"
           : "Luz nocturna " + (encendida ? "encendida (" + ServicioLuzNocturna.temperatura + " K)" : "apagada")
             + "\nClic derecho para " + (encendida ? "apagarla" : "encenderla")

    PanelLuzNocturna {
        id: panel
        objetivo: mod
    }

    activa: panel.abierto
    onClicIzquierdo: panel.alternar()
    onClicDerecho: ServicioLuzNocturna.alternar()
}
