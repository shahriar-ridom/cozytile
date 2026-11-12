import QtQuick
import QtQuick.Effects
import "../../config"
import "../../services"
import "../../components"

// hyprlock look. Every change is saved and re-rendered to generated/hypr/hyprlock.conf by LockscreenService.
Column {
    id: page
    property var panel
    width: parent ? parent.width : 0

    readonly property var lk: LockscreenService
    readonly property string wall: { Settings.lockscreen; return LockscreenService.wallpaper(); }
    readonly property real k: preview.width / 1920          // preview scale against a 1080p screen
    readonly property var sizes: ({ large: 150, medium: 112, small: 80 })
    readonly property var fonts: ({ sans: "SF Pro Display", rounded: "SF Pro Rounded", mono: Theme.fontMono })

    // ---- live preview ----
    Item {
        width: parent.width; height: preview.height + 20
        Rectangle {
            id: preview
            anchors.horizontalCenter: parent.horizontalCenter
            y: 4
            width: Math.min(420, parent.width); height: width * 9 / 16
            radius: Theme.radius; color: Theme.surfaceAlt; clip: true
            border.width: 1; border.color: Theme.border

            Image {
                id: img
                anchors.fill: parent
                source: page.wall ? "file://" + page.wall : ""
                sourceSize.width: 640
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                visible: false
            }
            MultiEffect {
                anchors.fill: parent
                source: img
                blurEnabled: true
                blurMax: 48
                blur: lk.get("blur") / 5
                brightness: -(1 - lk.get("dim") / 100) * 0.9
            }
            // status row
            Text { visible: lk.get("showStatus"); x: 8; y: 5; text: "Artist - Track"; color: "#ccffffff"
                font.family: "SF Pro Text"; font.pixelSize: Math.max(6, 13 * page.k) }
            Text { visible: lk.get("showStatus"); anchors.right: parent.right; anchors.rightMargin: 8; y: 5; text: "US"; color: "#ccffffff"
                font.family: "SF Pro Text"; font.pixelSize: Math.max(6, 13 * page.k) }
            Text {
                id: dateT
                visible: lk.get("showDate")
                anchors.horizontalCenter: parent.horizontalCenter; y: parent.height * 0.075
                text: Qt.formatDate(new Date(), "dddd, MMMM d"); color: "#e6ffffff"
                font.family: "SF Pro Display"; font.weight: Font.DemiBold
                font.pixelSize: Math.max(7, (page.sizes[lk.get("clock")] * 0.17 + 4) * page.k)
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                y: parent.height * (lk.get("showDate") ? 0.10 : 0.075)
                text: Qt.formatTime(new Date(), (lk.get("hour24") ? "HH:mm" : "h:mm") + (lk.get("seconds") ? ":ss" : ""))
                color: "#d9ffffff"
                font.family: page.fonts[lk.get("font")]; font.bold: true
                font.pixelSize: page.sizes[lk.get("clock")] * page.k
            }
            // avatar / name / password field
            Rectangle { visible: lk.get("showAvatar"); width: 84 * page.k; height: width; radius: width / 2
                anchors.horizontalCenter: parent.horizontalCenter; y: parent.height * 0.81 - height / 2
                color: Theme.surfaceHigh; border.width: 1; border.color: "#66ffffff" }
            Text { visible: lk.get("showUser"); anchors.horizontalCenter: parent.horizontalCenter; y: parent.height * 0.88 - height / 2
                text: "you"; color: "#f2ffffff"; font.family: "SF Pro Text"; font.weight: Font.DemiBold; font.pixelSize: Math.max(6, 15 * page.k) }
            Rectangle {
                width: 240 * page.k; height: 38 * page.k; radius: height / 2
                anchors.horizontalCenter: parent.horizontalCenter; y: parent.height * 0.93 - height / 2
                color: "#55000000"; border.width: 1; border.color: "#33ffffff"
                Text { anchors.centerIn: parent; text: lk.get("hint") || "Enter password"; color: "#99ffffff"
                    font.family: "SF Pro Text"; font.pixelSize: Math.max(5, 13 * page.k) }
            }
        }
    }

    Section { text: "Background" }
    SettingRow {
        title: "Wallpaper"; desc: lk.get("wallpaper") ? "Custom image for the lock screen" : "Following the desktop wallpaper"
        Row {
            spacing: 6
            IconButton { visible: lk.get("wallpaper") !== ""; glyph: ""; label: "Use desktop"; size: 30; onClicked: lk.set("wallpaper", "") }
            IconButton { glyph: ""; label: "Choose"; size: 30; onClicked: UiState.pickWallpaper("lock") }
        }
    }
    Divider {}
    SettingRow {
        title: "Image path"; desc: "Any image file · Enter to save"
        TextField {
            width: 240
            text: lk.get("wallpaper")
            placeholder: "Follow desktop wallpaper"
            onAccepted: t => lk.set("wallpaper", t.trim())
        }
    }
    Divider {}
    SettingRow {
        title: "Blur"; desc: "How soft the wallpaper looks behind the clock"
        Row { spacing: 10
            SliderBar { width: 150; anchors.verticalCenter: parent.verticalCenter; value: lk.get("blur") / 5
                onMoved: v => { const b = Math.round(v * 5); if (b !== lk.get("blur")) lk.set("blur", b); } }
            Text { width: 26; anchors.verticalCenter: parent.verticalCenter; text: lk.get("blur") === 0 ? "Off" : lk.get("blur"); color: Theme.textMuted
                font.family: Theme.font; font.pixelSize: Theme.fontSmall + 1 } }
    }
    Divider {}
    SettingRow {
        title: "Brightness"; desc: "Dim the wallpaper so the clock stays readable"
        Row { spacing: 10
            SliderBar { width: 150; anchors.verticalCenter: parent.verticalCenter; value: (lk.get("dim") - 20) / 80
                onMoved: v => { const d = Math.round((20 + v * 80) / 5) * 5; if (d !== lk.get("dim")) lk.set("dim", d); } }
            Text { width: 26; anchors.verticalCenter: parent.verticalCenter; text: lk.get("dim") + "%"; color: Theme.textMuted
                font.family: Theme.font; font.pixelSize: Theme.fontSmall + 1 } }
    }

    Section { text: "Clock" }
    SettingRow {
        title: "Size"
        Segmented {
            model: [{ label: "Large", value: "large" }, { label: "Medium", value: "medium" }, { label: "Small", value: "small" }]
            current: lk.get("clock"); onPicked: v => lk.set("clock", v)
        }
    }
    Divider {}
    SettingRow {
        title: "Typeface"
        Segmented {
            model: [{ label: "Sans", value: "sans" }, { label: "Rounded", value: "rounded" }, { label: "Mono", value: "mono" }]
            current: lk.get("font"); onPicked: v => lk.set("font", v)
        }
    }
    Divider {}
    SettingRow {
        title: "24-hour time"
        Toggle { checked: lk.get("hour24"); onToggled: v => lk.set("hour24", v) }
    }
    Divider {}
    SettingRow {
        title: "Show seconds"
        Toggle { checked: lk.get("seconds"); onToggled: v => lk.set("seconds", v) }
    }
    Divider {}
    SettingRow {
        title: "Show date"
        Toggle { checked: lk.get("showDate"); onToggled: v => lk.set("showDate", v) }
    }

    Section { text: "Sign-in" }
    SettingRow {
        title: "Profile picture"; desc: "Uses ~/.face when it exists"
        Toggle { checked: lk.get("showAvatar"); onToggled: v => lk.set("showAvatar", v) }
    }
    Divider {}
    SettingRow {
        title: "Username"
        Toggle { checked: lk.get("showUser"); onToggled: v => lk.set("showUser", v) }
    }
    Divider {}
    SettingRow {
        title: "Status line"; desc: "Now playing, keyboard layout and battery along the top"
        Toggle { checked: lk.get("showStatus"); onToggled: v => lk.set("showStatus", v) }
    }
    Divider {}
    SettingRow {
        title: "Password hint"; desc: "Text inside the empty password field · Enter to save"
        TextField {
            width: 200
            text: lk.get("hint")
            placeholder: "Enter password"
            onAccepted: t => lk.set("hint", t.trim())
        }
    }

    Section { text: "Try it" }
    SettingRow {
        title: "Lock now"; desc: "Preview the lock screen. Type your password to come back"
        IconButton { glyph: ""; label: "Lock"; size: 30; onClicked: lk.preview() }
    }
    Divider {}
    SettingRow {
        title: "Reset"; desc: "Back to the default look"
        IconButton { glyph: ""; label: "Reset"; size: 30; onClicked: lk.reset() }
    }
}
