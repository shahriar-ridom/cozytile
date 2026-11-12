import QtQuick
import QtQuick.Shapes
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Widgets
import "../../config"
import "../../services"
import "../../components"
import "../bar"

// Dynamic island: a dark cap in the middle of the bar that shows media / notifications and
// expands (click) into a control card. Own layer window so it can grow past the bar.
PanelWindow {
    id: win

    // pill width scales with the screen so it never collides with the bar's left/right pieces
    readonly property int maxW: screen ? Math.round(Math.max(200, Math.min(Theme.islandMaxWidth, (screen.width - 2 * Theme.barMarginSide) * 0.28))) : Theme.islandMaxWidth
    color: "transparent"
    anchors { top: true }
    margins { top: Theme.barMarginTop }
    implicitWidth: Theme.islandExpandedWidth + 60
    implicitHeight: 700
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "cozytile-island"
    WlrLayershell.layer: expanded || replying ? WlrLayer.Overlay : WlrLayer.Top
    // typing a reply in the peek needs the keyboard even though the island is collapsed
    WlrLayershell.keyboardFocus: replying ? WlrKeyboardFocus.Exclusive : expanded ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    mask: Region { item: body }

    // ---- state ---------------------------------------------------------
    readonly property bool expanded: screen !== null && UiState.islandOpenOn !== "" && UiState.islandOpenOn === screen.name
    function setExpanded(v) {
        if (v) { UiState.closeAll(); UiState.islandOpenOn = screen.name; }
        else if (expanded) UiState.islandOpenOn = "";
    }
    // transient event (volume, notification, toast, alarm) takes over the collapsed pill
    readonly property var act: expanded ? null : ActivityService.current
    readonly property string mode: act ? (act.kind === "notification" ? "banner" : act.kind) : MediaService.active ? "media" : "idle"
    readonly property color actColor: act ? ActivityService.toneColor(act.tone) : Theme.accent

    onExpandedChanged: { if (expanded) content.forceActiveFocus(); }

    // notification peek: the pill grows into a card (icon, app, summary, body) like a real dynamic island
    readonly property bool peeking: mode === "banner"
    property var peekEntry: null                       // last banner payload, kept so the card can fade out intact
    onActChanged: if (act && act.kind === "notification" && act.payload) peekEntry = act.payload
    onPeekingChanged: if (!peeking) replying = false
    // `var` re-assignments fire even for the same object (hold/progress updates re-post the banner):
    // only a different notification may cancel a reply in progress
    property int peekKey: peekEntry ? peekEntry.key : -1
    onPeekKeyChanged: replying = false

    // inline reply straight from the peek; the banner is held on screen while hovered or replying
    property bool replying: false
    property bool replyGrab: false
    Timer { id: replyGrabArm; interval: 150; onTriggered: win.replyGrab = win.replying }
    property bool peekHovered: false
    function holdPeek() { ActivityService.hold("notif", peekHovered || replying); }
    onReplyingChanged: { replyGrab = false; if (replying) replyGrabArm.restart(); holdPeek(); if (replying) Qt.callLater(() => peekReply.focusInput()); }
    onPeekHoveredChanged: holdPeek()
    property real peek: peeking ? 1 : 0
    Behavior on peek { NumberAnimation { duration: Theme.animSlow + 60; easing.type: Easing.OutBack; easing.overshoot: 0.8 } }
    readonly property real pk: Math.max(0, Math.min(1, peek))
    readonly property real shapeP: Math.max(pc, pk)
    // outline: S-curved sides on the full-width bar, a plain rounded pill in the floating-islands style
    readonly property bool floating: Settings.barStyle === "islands"
    readonly property real shapeS: floating ? 0 : Theme.edgeSlant * (1 - shapeP)
    readonly property real shapeRT: floating ? 15 - 3 * shapeP : 0.01 + 12 * shapeP
    readonly property real shapeRB: floating ? 15 + (pk > pc ? 3 : 5) * shapeP : 0.01 + (pk > pc ? 18 : 20) * shapeP
    readonly property int peekW: Math.min(Theme.islandExpandedWidth - 40, Math.max(300, maxW + 40))
    property int peekH: Math.round(peekCard.implicitHeight + 24)
    Behavior on peekH { enabled: win.pk > 0.99; NumberAnimation { duration: Theme.animNormal; easing.type: Easing.OutCubic } }

    // alarm: gentle pulse while it rings (animation only runs then)
    property real pulse: 0
    SequentialAnimation on pulse {
        running: win.mode === "alarm"; loops: Animation.Infinite
        NumberAnimation { to: 1; duration: 700; easing.type: Easing.InOutSine }
        NumberAnimation { to: 0; duration: 700; easing.type: Easing.InOutSine }
    }
    readonly property color capColor: win.mode === "alarm"
        ? Qt.tint(Theme.barCap, Qt.rgba(Theme.warn.r, Theme.warn.g, Theme.warn.b, 0.14 + 0.26 * pulse)) : Theme.barCap

    HyprlandFocusGrab {
        windows: [win]
        // reply: arm only after the layer has switched to exclusive keyboard focus, or Hyprland clears it at once
        active: win.expanded || win.replyGrab
        onCleared: { win.replying = false; win.setExpanded(false); }
    }

    SystemClock { id: clock; precision: SystemClock.Minutes }

    // ---- geometry ------------------------------------------------------
    property real p: expanded ? 1 : 0
    Behavior on p { NumberAnimation { duration: Theme.animSlow + 40; easing.type: Easing.OutCubic } }
    readonly property real pc: Math.max(0, Math.min(1, p))

    property int collapsedW: Math.round(Math.min(win.maxW, Math.max(170, collapsedRow.implicitWidth + 44)))
    Behavior on collapsedW { NumberAnimation { duration: Theme.animNormal; easing.type: Easing.OutCubic } }
    property int expandedH: content.implicitHeight + 32
    // off while fully collapsed: the card loads/unloads then, and its size must not animate in
    Behavior on expandedH { enabled: win.pc > 0; NumberAnimation { duration: Theme.animNormal; easing.type: Easing.OutCubic } }

    // SVG outline: S-curved sides (collapsed, like the bar's caps) morphing into a rounded card
    function outline(w, h, s, rt, rb) {
        rt = Math.max(rt, 0.01); rb = Math.max(rb, 0.01);
        const yb = h - rb;
        return `M ${rt} 0 L ${w - rt} 0 A ${rt} ${rt} 0 0 1 ${w} ${rt} L ${w} ${rt} `
             + `C ${w} ${(yb) * 0.55} ${w - s} ${(yb) * 0.45} ${w - s} ${yb} `
             + `A ${rb} ${rb} 0 0 1 ${w - s - rb} ${h} L ${s + rb} ${h} A ${rb} ${rb} 0 0 1 ${s} ${yb} `
             + `C ${s} ${yb * 0.45} 0 ${yb * 0.55} 0 ${rt} A ${rt} ${rt} 0 0 1 ${rt} 0 Z`;
    }

    // Sonner-style stack: queued activities sit behind the front pill as smaller, dimmer layers,
    // each one peeking out below. They promote forward as the front one expires.
    Repeater {
        model: 3
        delegate: Shape {
            id: layer
            required property int index
            readonly property int depth: index + 1
            readonly property var queued: win.expanded ? null : (ActivityService.items.length > depth ? ActivityService.items[depth] : null)
            property var lastQueued: null
            onQueuedChanged: if (queued) lastQueued = queued
            property real shown: queued ? 1 : 0
            Behavior on shown { NumberAnimation { duration: Theme.animNormal; easing.type: Easing.OutCubic } }
            readonly property color tone: lastQueued ? ActivityService.toneColor(lastQueued.tone) : Theme.accent
            z: -depth
            visible: shown > 0.01
            preferredRendererType: Shape.CurveRenderer
            width: body.width * (1 - 0.07 * depth * shown)
            height: body.height
            x: body.x + (body.width - width) / 2
            y: body.y + 7 * depth * shown
            opacity: shown * (1 - 0.28 * depth)
            ShapePath {
                strokeWidth: -1
                fillColor: Qt.tint(Theme.barCap, Qt.rgba(layer.tone.r, layer.tone.g, layer.tone.b, 0.16))
                PathSvg { path: win.outline(layer.width, layer.height, win.shapeS, win.shapeRT, win.shapeRB) }
            }
        }
    }

    Item {
        id: body
        x: (win.width - width) / 2
        y: 0
        readonly property real baseW: win.collapsedW + (win.peekW - win.collapsedW) * win.pk
        readonly property real baseH: Theme.barHeight + (win.peekH - Theme.barHeight) * win.pk
        width: baseW + (Theme.islandExpandedWidth - baseW) * win.pc
        height: baseH + (win.expandedH - baseH) * win.pc

        // soft shadow only once expanded
        RectangularShadow {
            anchors.fill: parent
            radius: win.floating ? win.shapeRB : 18 * win.shapeP
            blur: Theme.shadowRadius + 6
            offset.y: 3
            color: Theme.shadow
            opacity: win.floating ? 1 : win.shapeP
            visible: win.floating || win.shapeP > 0.02
        }
        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeWidth: -1
                fillColor: win.capColor
                PathSvg { path: win.outline(body.width, body.height, win.shapeS, win.shapeRT, win.shapeRB) }
            }
        }

        // ---- collapsed content -----------------------------------------
        Item {
            id: collapsed
            anchors { top: parent.top; left: parent.left; right: parent.right }
            height: Theme.barHeight
            opacity: Math.max(0, 1 - Math.max(win.pc, win.pk) * 3)
            visible: opacity > 0.01

            Row {
                id: collapsedRow
                anchors.centerIn: parent
                spacing: 9

                // level: volume / mic / brightness / keyboard backlight (replaces the OSD)
                Row {
                    visible: win.mode === "level"
                    spacing: 10
                    Glyph { text: win.act ? win.act.glyph : ""; size: 14; width: 18; color: win.actColor; anchors.verticalCenter: parent.verticalCenter }
                    Rectangle {
                        width: 128; height: 5; radius: 3; color: Theme.osdTrack; anchors.verticalCenter: parent.verticalCenter
                        Rectangle {
                            height: parent.height; radius: 3
                            width: parent.width * Math.max(0, Math.min(1, win.act && win.act.value >= 0 ? win.act.value : 0))
                            color: win.actColor
                            Behavior on width { NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutCubic } }
                        }
                    }
                    Text { width: 52; horizontalAlignment: Text.AlignRight; anchors.verticalCenter: parent.verticalCenter
                        text: win.act && win.mode === "level" ? win.act.text : ""
                        color: win.act && win.act.muted ? Theme.textMuted : Theme.barText
                        font.family: Theme.font; font.pixelSize: Theme.fontSize; font.bold: true }
                }
                // toast / alarm: icon + short text
                Row {
                    visible: win.mode === "toast" || win.mode === "alarm"
                    spacing: 8
                    Glyph { text: win.act ? win.act.glyph : ""; size: 13; color: win.actColor; anchors.verticalCenter: parent.verticalCenter }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.min(implicitWidth, win.maxW - 70)
                        text: win.act && (win.mode === "toast" || win.mode === "alarm") ? win.act.text : ""
                        elide: Text.ElideRight; color: Theme.barText
                        font.family: Theme.font; font.pixelSize: Theme.fontSize; font.bold: true
                    }
                }
                // media
                Row {
                    visible: win.mode === "media"
                    spacing: 8
                    Rectangle {
                        width: 20; height: 20; radius: 6; color: Theme.surfaceHigh; clip: true
                        anchors.verticalCenter: parent.verticalCenter
                        Image { id: thumb; anchors.fill: parent; source: MediaService.art; fillMode: Image.PreserveAspectCrop
                            asynchronous: true; sourceSize.width: 48; visible: status === Image.Ready }
                        Glyph { anchors.centerIn: parent; visible: thumb.status !== Image.Ready; size: 9
                            text: MediaService.playing ? "" : ""; color: Theme.accent }
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.min(implicitWidth, win.maxW - 150)
                        text: MediaService.artist ? MediaService.title + " — " + MediaService.artist : MediaService.title
                        elide: Text.ElideRight; color: Theme.barText
                        font.family: Theme.font; font.pixelSize: Theme.fontSize; font.bold: true
                    }
                    // equalizer: bars dance while playing, settle to a flat line when paused
                    Row {
                        id: eq
                        visible: win.mode === "media"
                        anchors.verticalCenter: parent.verticalCenter
                        height: 14; spacing: 2
                        readonly property bool live: MediaService.playing && win.mode === "media"
                        Repeater {
                            model: [ { d: 420, lo: 0.25, hi: 1.0 }, { d: 330, lo: 0.2, hi: 0.7 }, { d: 510, lo: 0.3, hi: 0.95 }, { d: 380, lo: 0.2, hi: 0.8 } ]
                            Rectangle {
                                required property var modelData
                                property real lvl: 0.2
                                width: 2.5; radius: 1.25; color: Theme.accent
                                height: Math.max(2.5, eq.height * lvl)
                                anchors.verticalCenter: parent.verticalCenter
                                opacity: eq.live ? 1 : 0.45
                                Behavior on opacity { NumberAnimation { duration: Theme.animNormal } }
                                SequentialAnimation on lvl {
                                    running: eq.live; loops: Animation.Infinite
                                    NumberAnimation { to: modelData.hi; duration: modelData.d; easing.type: Easing.InOutSine }
                                    NumberAnimation { to: modelData.lo; duration: modelData.d; easing.type: Easing.InOutSine }
                                    onRunningChanged: if (!running) parent.lvl = 0.2
                                }
                            }
                        }
                    }
                }
                // idle: date
                Text {
                    visible: win.mode === "idle"
                    anchors.verticalCenter: parent.verticalCenter
                    text: Qt.formatDateTime(clock.date, "ddd d MMM")
                    color: Theme.barTextDim
                    font.family: Theme.font; font.pixelSize: Theme.fontSize; font.bold: true
                }
                // caps lock stays visible while on (a toast alone is easy to miss)
                Rectangle {
                    visible: LockKeysService.caps && (win.mode === "media" || win.mode === "idle")
                    height: 16; width: capsT.implicitWidth + 12; radius: 8
                    color: Qt.rgba(Theme.warn.r, Theme.warn.g, Theme.warn.b, 0.2)
                    anchors.verticalCenter: parent.verticalCenter
                    Text { id: capsT; anchors.centerIn: parent; text: "CAPS"; color: Theme.warn
                        font.family: Theme.font; font.pixelSize: Theme.fontSmall - 1; font.bold: true }
                }
                // mic / camera in use by an app
                Row {
                    visible: PrivacyService.any && (win.mode === "media" || win.mode === "idle")
                    spacing: 5
                    Rectangle { width: 6; height: 6; radius: 3; color: Theme.warn; anchors.verticalCenter: parent.verticalCenter }
                    Glyph { text: PrivacyService.video ? "\uf03d" : "\uf130"; size: 11; color: Theme.warn; anchors.verticalCenter: parent.verticalCenter }
                }
                // running timer chip (alongside media / idle date)
                Row {
                    visible: TimerService.active && (win.mode === "media" || win.mode === "idle")
                    spacing: 5
                    Glyph { text: "\uf017"; size: 11; color: TimerService.paused ? Theme.textMuted : Theme.accent; anchors.verticalCenter: parent.verticalCenter }
                    Text { anchors.verticalCenter: parent.verticalCenter; text: TimerService.format(TimerService.remaining)
                        color: TimerService.paused ? Theme.textDim : Theme.barText
                        font.family: Theme.font; font.pixelSize: Theme.fontSmall + 1; font.bold: true }
                }
                // unread badge (history) when the pill is not showing a transient event
                Row {
                    visible: NotificationService.count > 0 && (win.mode === "media" || win.mode === "idle")
                    spacing: 4
                    Glyph { text: NotificationService.dnd ? "" : ""; size: 11
                        color: NotificationService.dnd ? Theme.warn : Theme.accent; anchors.verticalCenter: parent.verticalCenter }
                    Text { anchors.verticalCenter: parent.verticalCenter; text: NotificationService.count; color: Theme.barText
                        font.family: Theme.font; font.pixelSize: Theme.fontSmall + 1; font.bold: true }
                }
            }
            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                onClicked: m => {
                    if (win.mode === "alarm") TimerService.stop();                  // silence + dismiss
                    else if (m.button === Qt.MiddleButton) MediaService.toggle();
                    else if (m.button === Qt.RightButton) NotificationService.toggleDnd();
                    else win.setExpanded(true);
                }
            }
        }

        // ---- notification peek card -------------------------------------
        Item {
            id: peekCard
            anchors { top: parent.top; left: parent.left; right: parent.right; topMargin: 12; leftMargin: 18; rightMargin: 18 }
            implicitHeight: peekCol.implicitHeight
            opacity: Math.max(0, (win.pk - 0.5) * 2) * (1 - win.pc * 3)
            visible: opacity > 0.01
            readonly property var e: win.peekEntry
            property double nowMs: Date.now()
            Timer { interval: 500; repeat: true; running: win.peeking; onTriggered: peekCard.nowMs = Date.now() }
            onEChanged: nowMs = Date.now()
            readonly property string ago: {
                if (!e || !e.time) return "now";
                const s = Math.max(0, Math.floor((nowMs - e.time.getTime()) / 1000));
                return s < 3 ? "now" : s < 60 ? s + "s ago" : s < 3600 ? Math.floor(s / 60) + "m ago" : Math.floor(s / 3600) + "h ago";
            }
            readonly property string iconSrc: !e ? "" : e.image ? e.image
                : e.appIcon ? (e.appIcon.startsWith("/") || e.appIcon.startsWith("file:") ? e.appIcon : Quickshell.iconPath(e.appIcon, true)) : ""

            readonly property bool live: !!e && e.n !== null
            readonly property var extra: !live ? [] : e.actions.filter(a => a.identifier !== "default" && a.identifier !== e.markRead).slice(0, 2)
            readonly property int fromApp: e ? NotificationService.history.filter(x => x.appName === e.appName).length : 0
            readonly property bool hasStrip: (live && (e.canReply || extra.length > 0)) || fromApp > 0

            HoverHandler { onHoveredChanged: win.peekHovered = hovered }

            // under the buttons: click opens the island, middle/right dismisses
            MouseArea {
                anchors.fill: parent; anchors.margins: -12
                cursorShape: Qt.PointingHandCursor
                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                onClicked: m => {
                    if (win.replying) return;
                    if (m.button === Qt.MiddleButton || m.button === Qt.RightButton) {
                        if (peekCard.e) NotificationService.dismissPopup(peekCard.e.key);
                        ActivityService.dismiss("notif");
                    } else win.setExpanded(true);
                }
            }

            Column {
                id: peekCol
                width: parent.width
                spacing: 10

                Item {
                    width: parent.width
                    height: Math.max(40, peekText.implicitHeight)
                    Rectangle {
                        id: peekIcon
                        width: 40; height: 40; radius: 12; color: Theme.surfaceHigh; clip: true
                        Image { id: peekImg; anchors.fill: parent; source: peekCard.iconSrc; fillMode: Image.PreserveAspectCrop
                            asynchronous: true; sourceSize.width: 96; visible: status === Image.Ready }
                        Glyph { anchors.centerIn: parent; visible: peekImg.status !== Image.Ready; text: "\uf0f3"; size: 16; color: Theme.accent }
                    }
                    Column {
                        id: peekText
                        anchors { left: peekIcon.right; leftMargin: 12; right: parent.right }
                        spacing: 2
                        Row {
                            width: parent.width; spacing: 6
                            Text { text: peekCard.e ? peekCard.e.appName : ""; color: Theme.textDim
                                width: Math.min(implicitWidth, parent.width - 50)
                                elide: Text.ElideRight; font.family: Theme.font; font.pixelSize: Theme.fontSmall }
                            Text { text: peekCard.ago; color: Theme.textMuted; font.family: Theme.font; font.pixelSize: Theme.fontSmall }
                        }
                        Text { width: parent.width; text: peekCard.e ? peekCard.e.summary : ""; color: Theme.barText
                            elide: Text.ElideRight; font.family: Theme.font; font.pixelSize: Theme.fontSize + 1; font.bold: true }
                        Text { width: parent.width; visible: text !== ""; text: peekCard.e ? peekCard.e.body : ""; color: Theme.barTextDim
                            maximumLineCount: win.replying ? 4 : 2; wrapMode: Text.Wrap; elide: Text.ElideRight
                            font.family: Theme.font; font.pixelSize: Theme.fontSmall + 1 }
                        Rectangle {
                            visible: peekCard.e && peekCard.e.progress >= 0
                            width: parent.width; height: 5; radius: 3; color: Theme.osdTrack
                            Rectangle { height: parent.height; radius: 3; color: Theme.accent
                                width: parent.width * (peekCard.e && peekCard.e.progress >= 0 ? peekCard.e.progress : 0)
                                Behavior on width { NumberAnimation { duration: Theme.animNormal } } }
                        }
                    }
                }

                // actions: reply, the app's own buttons, mark (all) read
                Flow {
                    width: parent.width
                    leftPadding: 52
                    spacing: 6
                    visible: !win.replying && peekCard.hasStrip
                    Chip {
                        visible: peekCard.live && peekCard.e.canReply
                        glyph: "\uf112"; label: "Reply"; primary: true
                        onClicked: win.replying = true
                    }
                    Repeater {
                        model: peekCard.extra
                        delegate: Chip {
                            required property var modelData
                            label: modelData.text
                            onClicked: { NotificationService.invoke(peekCard.e.key, modelData.identifier); ActivityService.dismiss("notif"); }
                        }
                    }
                    Chip {
                        visible: peekCard.fromApp > 0
                        glyph: "\uf00c"
                        label: peekCard.fromApp > 1 ? "Mark all read · " + peekCard.fromApp : "Mark as read"
                        onClicked: {
                            if (peekCard.fromApp > 1) NotificationService.markAllRead(peekCard.e.appName);
                            else NotificationService.markRead(peekCard.e.key);
                            ActivityService.dismiss("notif");
                        }
                    }
                }

                ReplyField {
                    id: peekReply
                    width: parent.width
                    visible: win.replying
                    placeholder: peekCard.e && peekCard.e.replyPlaceholder ? peekCard.e.replyPlaceholder
                                 : "Reply to " + (peekCard.e ? peekCard.e.summary || peekCard.e.appName : "") + "…"
                    onVisibleChanged: if (!visible) text = ""
                    onCancelled: win.replying = false
                    onSent: t => {
                        const ok = NotificationService.reply(peekCard.e.key, t);
                        win.replying = false;
                        ActivityService.dismiss("notif");
                        ActivityService.toast("reply", ok ? "\uf1d8" : "\uf071", ok ? "Reply sent" : "Reply failed · notification closed", ok ? "good" : "bad");
                    }
                }
            }
        }

        // ---- expanded content ------------------------------------------
        Item {
            id: content
            focus: true
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 16 }
            implicitHeight: cardLoader.implicitHeight
            opacity: Math.max(0, (win.pc - 0.45) * 2)
            visible: opacity > 0.01
            enabled: win.expanded
            Keys.onEscapePressed: win.setExpanded(false)

            // the card's contents exist only while expanded or animating; collapsed islands skip
            // the media/timer/notification panels entirely
            Loader {
                id: cardLoader
                width: parent.width
                active: win.expanded || win.pc > 0
                sourceComponent: Component {
                    Column {
                        id: col
                        width: parent.width
                        spacing: 14

                        // header: time + date + collapse
                        Item {
                            width: parent.width; height: 34
                            Column {
                                anchors.verticalCenter: parent.verticalCenter
                                Text { text: Qt.formatDateTime(clock.date, "hh:mm AP"); color: Theme.text
                                    font.family: Theme.font; font.pixelSize: Theme.fontTitle; font.bold: true }
                                Text { text: Qt.formatDateTime(clock.date, "dddd, d MMMM"); color: Theme.textDim
                                    font.family: Theme.font; font.pixelSize: Theme.fontSmall }
                            }
                            IconButton { anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                                glyph: ""; size: 28; glyphSize: 11; onClicked: win.setExpanded(false) }
                        }
                        Row {
                            visible: PrivacyService.any
                            spacing: 8
                            Rectangle { width: 7; height: 7; radius: 4; color: Theme.warn; anchors.verticalCenter: parent.verticalCenter }
                            Text { anchors.verticalCenter: parent.verticalCenter
                                text: (PrivacyService.mic ? "Microphone · " + PrivacyService.micApps : "")
                                      + (PrivacyService.mic && PrivacyService.video ? "   " : "")
                                      + (PrivacyService.video ? "Video · " + PrivacyService.videoApps : "")
                                color: Theme.warn; font.family: Theme.font; font.pixelSize: Theme.fontSmall + 1; elide: Text.ElideRight }
                        }
                        MediaPanel { width: parent.width; visible: MediaService.active; height: visible ? implicitHeight : 0 }
                        TimerPanel { width: parent.width }
                        NotificationPanel { width: parent.width; maxListHeight: MediaService.active ? 150 : 230 }
                        QuickActions { onDone: win.setExpanded(false) }
                    }
                }
            }
        }
    }
}
