import QtQuick
import Quickshell
import Quickshell.Wayland
import "../../config"
import "../../services"
import "../../components"

// Settings app: right-click the bar (or `qs -c cozytile ipc call settings toggle`).
// Shell options write straight to Settings; Hyprland options go through HyprConfigService,
// which applies them live and saves them to generated/hypr/cozytile_settings.lua.
PanelWindow {
    id: win
    screen: UiState.focusedScreen
    visible: UiState.settings || card.opacity > 0.01
    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "cozytile-settings"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: UiState.settings ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons; onClicked: UiState.settings = false }

    property int page: 0
    readonly property var pages: [
        { name: "Appearance", icon: "", file: "PageAppearance.qml", group: "Shell" },
        { name: "Bar",        icon: "", file: "PageBar.qml",        group: "Shell" },
        { name: "General",    icon: "", file: "PageGeneral.qml",    group: "Shell" },
        { name: "Display",    icon: "", file: "PageDisplay.qml",    group: "System" },
        { name: "Windows",    icon: "", file: "PageWindows.qml",    group: "System" },
        { name: "Input",      icon: "", file: "PageInput.qml",      group: "System" },
        { name: "Autostart",  icon: "", file: "PageAutostart.qml",  group: "System" },
        { name: "Power & idle", icon: "", file: "PagePower.qml",    group: "System" },
        { name: "About",      icon: "", file: "PageAbout.qml",      group: "" }
    ]

    Connections {
        target: UiState
        function onSettingsChanged() { if (UiState.settings) HyprConfigService.refresh(); else win.closePicker(); }
        function onSettingsPageChanged() {
            const q = UiState.settingsPage.toLowerCase();
            if (q === "") return;
            const i = win.pages.findIndex(p => p.name.toLowerCase().startsWith(q) || p.file.toLowerCase() === "page" + q + ".qml");
            if (i >= 0) win.page = i;
            UiState.settingsPage = "";
        }
    }

    // ---- shared picker sheet (dropdown lists + app chooser) ----
    property var pickerDropdown: null
    property var pickerAppCb: null
    property bool pickerOpen: false
    property string pickerTitle: ""

    function openPicker(dd) {
        pickerAppCb = null;
        pickerDropdown = dd;
        pickerTitle = dd.title || "Choose";
        pickerOpen = true;
    }
    function openAppPicker(cb) {
        pickerDropdown = null;
        pickerAppCb = cb;
        pickerTitle = "Choose an app";
        search.clear();
        pickerOpen = true;
        search.focusInput();
    }
    function closePicker() { pickerOpen = false; card.forceActiveFocus(); }

    readonly property var apps: {
        if (!pickerAppCb) return [];
        const q = search.text.trim().toLowerCase();
        return DesktopEntries.applications.values
            .filter(e => !e.noDisplay && (q === "" || e.name.toLowerCase().includes(q) || (e.genericName || "").toLowerCase().includes(q)))
            .sort((a, b) => a.name.localeCompare(b.name))
            .slice(0, 80);
    }
    function appCommand(e) {
        const s = (e.execString || (e.command || []).join(" ")).replace(/\s*%[fFuUdDnNickvm]/g, "").trim();
        return e.runInTerminal ? "kitty -e " + s : s;
    }

    Rectangle {
        id: card
        width: Math.min(900, (win.screen ? win.screen.width : 1280) - 60)
        height: Math.min(620, (win.screen ? win.screen.height : 800) - 80)
        anchors.centerIn: parent
        radius: Theme.radius + 4
        color: Theme.popupBg
        border.width: 1; border.color: Theme.border
        opacity: UiState.settings ? 1 : 0
        scale: UiState.settings ? 1 : 0.97
        Behavior on opacity { NumberAnimation { duration: Theme.animNormal } }
        Behavior on scale { NumberAnimation { duration: Theme.animNormal; easing.type: Easing.OutCubic } }
        MouseArea { anchors.fill: parent; onClicked: card.forceActiveFocus() }
        Shadowed { target: card; z: -1 }
        focus: true
        Keys.onEscapePressed: { if (win.pickerOpen) win.closePicker(); else UiState.settings = false; }
        Keys.onPressed: e => {
            if ((e.modifiers & Qt.ControlModifier) && e.key === Qt.Key_Tab) { win.page = (win.page + 1) % win.pages.length; e.accepted = true; }
            else if ((e.modifiers & Qt.ControlModifier) && e.key === Qt.Key_Backtab) { win.page = (win.page + win.pages.length - 1) % win.pages.length; e.accepted = true; }
        }

        // ---- sidebar ----
        Rectangle {
            id: side
            width: 196; height: parent.height
            radius: Theme.radius + 4
            color: Theme.surfaceAlt
            Rectangle { anchors { right: parent.right; top: parent.top; bottom: parent.bottom } width: parent.radius; color: parent.color }

            Text { x: 20; y: 22; text: "Settings"; color: Theme.text
                font.family: Theme.font; font.pixelSize: Theme.fontLarge + 2; font.bold: true }

            Column {
                x: 10; y: 62; width: parent.width - 20; spacing: 3
                Repeater {
                    model: win.pages
                    delegate: Column {
                        id: navItem
                        required property var modelData
                        required property int index
                        readonly property bool on: win.page === index
                        readonly property bool newGroup: index === 0 || win.pages[index - 1].group !== modelData.group
                        width: parent.width
                        Text {
                            visible: navItem.newGroup && navItem.modelData.group !== ""
                            height: visible ? 26 : 0; leftPadding: 12; verticalAlignment: Text.AlignBottom; bottomPadding: 5
                            text: navItem.modelData.group; color: Theme.textMuted
                            font.family: Theme.font; font.pixelSize: Theme.fontSmall; font.bold: true
                            font.capitalization: Font.AllUppercase; font.letterSpacing: 1.1
                        }
                        Item { visible: navItem.newGroup && navItem.modelData.group === ""; width: 1; height: visible ? 12 : 0 }
                        Rectangle {
                            width: parent.width; height: 34; radius: Theme.radiusSmall + 3
                            color: navItem.on ? Theme.surfaceHigh : (m.containsMouse ? Theme.hover : "transparent")
                            Behavior on color { ColorAnimation { duration: Theme.animFast } }
                            Rectangle { visible: navItem.on; width: 3; height: 16; radius: 2; color: Theme.accent
                                anchors.verticalCenter: parent.verticalCenter; x: 0 }
                            Glyph { x: 14; anchors.verticalCenter: parent.verticalCenter; width: 16; size: 13
                                text: navItem.modelData.icon; color: navItem.on ? Theme.accent : Theme.textDim }
                            Text { x: 40; anchors.verticalCenter: parent.verticalCenter; text: navItem.modelData.name
                                color: navItem.on ? Theme.text : Theme.textDim
                                font.family: Theme.font; font.pixelSize: Theme.fontSize + 1; font.bold: navItem.on }
                            MouseArea { id: m; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: { win.page = navItem.index; card.forceActiveFocus(); } }
                        }
                    }
                }
            }
            Text { x: 20; anchors.bottom: parent.bottom; anchors.bottomMargin: 18; text: "Esc close  ·  Ctrl+Tab next"
                color: Theme.textMuted; font.family: Theme.font; font.pixelSize: Theme.fontSmall + 1 }
        }

        // ---- page ----
        Item {
            id: content
            anchors { left: side.right; right: parent.right; top: parent.top; bottom: parent.bottom; leftMargin: 26; rightMargin: 10; topMargin: 22; bottomMargin: 12 }

            Text { id: heading; text: win.pages[win.page].name; color: Theme.text
                font.family: Theme.font; font.pixelSize: Theme.fontTitle; font.bold: true }

            Flickable {
                id: flick
                anchors { top: heading.bottom; topMargin: 6; left: parent.left; right: parent.right; bottom: parent.bottom }
                contentWidth: width
                contentHeight: loader.height + 20
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                Loader {
                    id: loader
                    width: flick.width - 16
                    source: win.pages[win.page].file
                    onLoaded: { item.panel = win; flick.contentY = 0; }
                }
            }
            // scrollbar
            Rectangle {
                visible: flick.contentHeight > flick.height
                anchors.right: parent.right; anchors.rightMargin: 0
                y: flick.y + flick.visibleArea.yPosition * flick.height
                width: 4; radius: 2
                height: Math.max(24, flick.visibleArea.heightRatio * flick.height)
                color: Theme.surfaceHigh
            }
        }

        // ---- picker sheet ----
        Rectangle {
            anchors.fill: parent
            radius: card.radius
            color: Qt.rgba(0, 0, 0, 0.35)
            visible: opacity > 0.01
            opacity: win.pickerOpen ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: Theme.animFast } }
            MouseArea { anchors.fill: parent; onClicked: win.closePicker() }

            Rectangle {
                id: sheet
                anchors.centerIn: parent
                width: 380
                height: Math.min(parent.height - 80, sheetHead.height + list.contentHeight + 24)
                radius: Theme.radius + 2
                color: Theme.popupBg
                border.width: 1; border.color: Theme.border
                MouseArea { anchors.fill: parent }

                Column {
                    id: sheetHead
                    x: 14; y: 14; width: parent.width - 28; spacing: 10
                    Item {
                        width: parent.width; height: 26
                        Text { anchors.verticalCenter: parent.verticalCenter; text: win.pickerTitle; color: Theme.text
                            font.family: Theme.font; font.pixelSize: Theme.fontLarge; font.bold: true }
                        IconButton { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                            glyph: ""; size: 26; onClicked: win.closePicker() }
                    }
                    TextField {
                        id: search
                        visible: win.pickerAppCb !== null
                        width: parent.width; placeholder: "Search apps…"
                        onAccepted: { if (win.apps.length) list.choose(win.apps[0]); }
                    }
                }
                ListView {
                    id: list
                    anchors { top: sheetHead.bottom; topMargin: 8; left: parent.left; right: parent.right; bottom: parent.bottom; margins: 8; leftMargin: 8 }
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    model: win.pickerAppCb ? win.apps : (win.pickerDropdown ? win.pickerDropdown.model : [])
                    function choose(v) {
                        if (win.pickerAppCb) {
                            const cb = win.pickerAppCb;
                            cb({ name: v.name, command: win.appCommand(v) });
                        } else if (win.pickerDropdown) {
                            win.pickerDropdown.picked(v.value);
                        }
                        win.closePicker();
                    }
                    delegate: Rectangle {
                        required property var modelData
                        readonly property bool sel: !win.pickerAppCb && win.pickerDropdown && win.pickerDropdown.current === modelData.value
                        width: list.width; height: win.pickerAppCb ? 42 : 34
                        radius: Theme.radiusSmall + 2
                        color: sel ? Theme.surfaceHigh : (hm.containsMouse ? Theme.hover : "transparent")
                        Image {
                            id: ico
                            visible: !!win.pickerAppCb
                            x: 10; anchors.verticalCenter: parent.verticalCenter
                            width: 24; height: 24; sourceSize: Qt.size(48, 48)
                            source: win.pickerAppCb ? Quickshell.iconPath(modelData.icon, "application-x-executable") : ""
                        }
                        Column {
                            x: win.pickerAppCb ? 44 : 12; anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - x - 30
                            Text { width: parent.width; elide: Text.ElideRight
                                text: win.pickerAppCb ? modelData.name : modelData.label
                                color: Theme.text; font.family: Theme.font; font.pixelSize: Theme.fontSize + 1; font.bold: parent.parent.sel }
                            Text { visible: !!win.pickerAppCb; width: parent.width; elide: Text.ElideRight
                                text: win.pickerAppCb ? win.appCommand(modelData) : ""
                                color: Theme.textMuted; font.family: Theme.fontMono; font.pixelSize: Theme.fontSmall }
                        }
                        Glyph { visible: parent.sel; anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
                            text: ""; size: 11; color: Theme.accent }
                        MouseArea { id: hm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: list.choose(modelData) }
                    }
                }
            }
        }
    }
}
