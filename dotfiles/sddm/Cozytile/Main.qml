import QtQuick
import QtQuick.Controls
import QtQuick.Effects

// Cozytile login. Colours come from theme.conf (rendered by dotfiles/theme-apply.sh).
Rectangle {
    id: root
    width: 1920; height: 1080
    color: config.bg || "#272E33"

    readonly property color cBg: config.bg || "#272E33"
    readonly property color cPanel: config.panel || "#232A2E"
    readonly property color cField: config.field || "#374145"
    readonly property color cFg: config.fg || "#D3C6AA"
    readonly property color cFg2: config.fg2 || "#9DA9A0"
    readonly property color cAccent: config.accent || "#A7C080"
    readonly property color cError: config.error || "#E67E80"
    readonly property string fontName: "CaskaydiaCove Nerd Font"

    property bool failed: false

    Connections {
        target: sddm
        function onLoginFailed() { root.failed = true; password.text = ""; password.forceActiveFocus(); }
    }

    Image {
        id: bg
        anchors.fill: parent
        source: (config.background && config.background !== "screenshot") ? config.background : ""
        fillMode: Image.PreserveAspectCrop
        visible: false
    }
    MultiEffect {   // soften + dim so the card stays readable on any wallpaper
        anchors.fill: parent
        source: bg
        visible: bg.status === Image.Ready
        blurEnabled: true; blur: 0.6; blurMax: 40
        brightness: -0.18; saturation: -0.1
    }

    // ---- top bar: same two-tone shape language as the desktop bar ----
    Rectangle {
        id: bar
        x: 40; y: 8; width: parent.width - 80; height: 30
        radius: 10; color: root.cField
        Rectangle {  // dark left cap
            width: 120; height: parent.height; radius: 10; color: root.cPanel
            Text { anchors.centerIn: parent; text: config.label || "Cozytile"
                color: root.cAccent; font.family: root.fontName; font.pixelSize: 12; font.bold: true }
        }
        Rectangle {  // dark right cap with clock
            anchors.right: parent.right; width: 150; height: parent.height; radius: 10; color: root.cPanel
            Text { id: clock; anchors.centerIn: parent; color: root.cFg
                font.family: root.fontName; font.pixelSize: 12; font.bold: true
                text: Qt.formatDateTime(new Date(), "hh:mm AP")
                Timer { interval: 1000; running: true; repeat: true; onTriggered: clock.text = Qt.formatDateTime(new Date(), "hh:mm AP") } }
        }
    }

    // ---- login card ----
    Rectangle {
        id: card
        anchors.centerIn: parent
        width: 380; height: 330; radius: 18
        color: root.cPanel; opacity: 0.96

        Column {
            anchors.centerIn: parent; spacing: 16; width: parent.width - 60

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 84; height: 84; radius: 42; color: root.cField
                Text { anchors.centerIn: parent; text: users.currentText ? users.currentText.charAt(0).toUpperCase() : "?"
                    color: root.cAccent; font.family: root.fontName; font.pixelSize: 36; font.bold: true }
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: users.currentText
                color: root.cFg; font.family: root.fontName; font.pixelSize: 20; font.bold: true
            }

            // username selector (hidden when only one user)
            ComboBox {
                id: users
                visible: model.count > 1
                width: parent.width
                model: userModel
                textRole: "name"
                currentIndex: userModel.lastIndex >= 0 ? userModel.lastIndex : 0
            }

            Rectangle {
                width: parent.width; height: 46; radius: 23
                color: root.cField
                border.width: root.failed ? 1 : 0; border.color: root.cError
                TextInput {
                    id: password
                    anchors { fill: parent; leftMargin: 20; rightMargin: 20 }
                    verticalAlignment: TextInput.AlignVCenter
                    echoMode: TextInput.Password
                    passwordCharacter: "●"
                    color: root.cFg
                    font.family: root.fontName; font.pixelSize: 15
                    focus: true
                    onTextChanged: root.failed = false
                    Keys.onReturnPressed: root.doLogin()
                    Keys.onEnterPressed: root.doLogin()
                    Text { visible: !password.text; anchors.verticalCenter: parent.verticalCenter
                        text: "Password"; color: root.cFg2; font: password.font }
                }
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.failed ? "Login failed" : sessions.currentText
                color: root.failed ? root.cError : root.cFg2
                font.family: root.fontName; font.pixelSize: 12
            }
        }
    }

    function doLogin() { sddm.login(users.currentText, password.text, sessions.currentIndex); }

    // session picker (kept off-screen; cycles with F-keys style click on the label)
    ComboBox { id: sessions; visible: false; model: sessionModel; textRole: "name"; currentIndex: sessionModel.lastIndex }

    // ---- power ----
    Row {
        anchors { bottom: parent.bottom; horizontalCenter: parent.horizontalCenter; bottomMargin: 36 }
        spacing: 12
        Repeater {
            model: [
                { t: "Suspend", ok: sddm.canSuspend, a: () => sddm.suspend() },
                { t: "Reboot",  ok: sddm.canReboot,  a: () => sddm.reboot() },
                { t: "Shutdown", ok: sddm.canPowerOff, a: () => sddm.powerOff() }
            ]
            delegate: Rectangle {
                required property var modelData
                visible: modelData.ok
                width: 96; height: 32; radius: 16
                color: pm.containsMouse ? root.cField : root.cPanel
                Text { anchors.centerIn: parent; text: modelData.t; color: root.cFg2
                    font.family: root.fontName; font.pixelSize: 12; font.bold: true }
                MouseArea { id: pm; anchors.fill: parent; hoverEnabled: true; onClicked: modelData.a() }
            }
        }
    }
    Component.onCompleted: password.forceActiveFocus()
}
