// Tráfico en vivo de una interfaz: bajada y subida, y total desde el arranque
import QtQuick
import qs.Comun

Item {
    id: trafico

    property var valores: null   // { bajada, subida, rx, tx } en bytes

    function tamano(b) {
        const u = ["B", "KB", "MB", "GB", "TB"];
        let i = 0;
        while (b >= 1000 && i < u.length - 1) { b /= 1000; i++; }
        return (i === 0 || b >= 100 ? Math.round(b) : b.toFixed(1)) + " " + u[i];
    }

    width: parent ? parent.width : 400
    height: 44

    component Sentido: Column {
        property int glifo: 0
        property color tono: Tema.cian
        property real ritmo: 0
        property real total: 0
        spacing: 1
        Text {
            text: String.fromCodePoint(parent.glifo) + " " + trafico.tamano(parent.ritmo) + "/s"
            color: parent.tono
            font.family: Tema.fuenteBarra
            font.pixelSize: 15
            font.bold: true
        }
        Text {
            text: "total " + trafico.tamano(parent.total)
            color: Tema.tenue
            font.family: Tema.fuenteBarra
            font.pixelSize: 11
        }
    }

    Sentido {
        x: 10
        anchors.verticalCenter: parent.verticalCenter
        glifo: 0xf0045; tono: Tema.cian
        ritmo: trafico.valores ? trafico.valores.bajada : 0
        total: trafico.valores ? trafico.valores.rx : 0
    }
    Sentido {
        x: (trafico.width + 6) / 2 + 10
        anchors.verticalCenter: parent.verticalCenter
        glifo: 0xf005d; tono: Tema.rosa
        ritmo: trafico.valores ? trafico.valores.subida : 0
        total: trafico.valores ? trafico.valores.tx : 0
    }
}
