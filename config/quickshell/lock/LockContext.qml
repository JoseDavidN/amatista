// ================================================
// Logica de autenticacion (PAM), compartida por todos los monitores
// ================================================
import QtQuick
import Quickshell
import Quickshell.Services.Pam

Scope {
    id: root

    signal unlocked()
    signal failed()

    property string currentText: ""
    property bool unlockInProgress: false
    property bool showFailure: false

    onCurrentTextChanged: showFailure = false

    function tryUnlock() {
        if (currentText === "" || unlockInProgress)
            return;
        unlockInProgress = true;
        pam.start();
    }

    PamContext {
        id: pam

        // Usa pam/password.conf de esta misma carpeta
        configDirectory: "pam"
        config: "password.conf"

        onPamMessage: {
            if (this.responseRequired)
                this.respond(root.currentText);
        }

        onCompleted: result => {
            if (result == PamResult.Success) {
                root.unlocked();
            } else {
                root.currentText = "";
                root.showFailure = true;
                root.failed();
            }
            root.unlockInProgress = false;
        }
    }
}
