// ==========================================================
// Perfil de energía: solo en portátiles con power-profiles-daemon
// Clic: ahorro → equilibrado → rendimiento
// ==========================================================
import QtQuick
import qs.Comun

Pildora {
    readonly property string perfil: ServicioPerfilEnergia.perfil

    visible: ServicioPerfilEnergia.hayBateria && ServicioPerfilEnergia.disponible

    icono: perfil === "power-saver" ? "󰌪"
         : perfil === "performance" ? "󰓅"
         : "󰾅"
    colorIcono: perfil === "power-saver" ? Tema.verde
              : perfil === "performance" ? Tema.naranja
              : Tema.cian

    tooltip: "Perfil de energía: "
           + (perfil === "power-saver" ? "ahorro"
            : perfil === "performance" ? "rendimiento"
            : "equilibrado")
           + "\nClic para cambiar"

    onClicIzquierdo: ServicioPerfilEnergia.ciclar()
}
