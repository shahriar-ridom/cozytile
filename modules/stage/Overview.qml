import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Widgets
import "../../config"
import "../../services"
import "../../components"

// Mission Control style overview. Top: every desktop (workspace) as a card. Below: the windows of the
// selected desktop, zoomed out from their real positions into a grid with live thumbnails.
// Drag a window onto a desktop card (or the +) to move it; click a window to jump to it.
PanelWindow {
    id: win
    screen: UiState.focusedScreen
    readonly property var svc: StageService
    color: "transparent"
    // Creating a window costs ~0.5 s, so this one is never hidden: while closed it is a 1x1 transparent,
    // click-through surface, and opening only resizes it (the anchors below) and plays the animation.
    anchors { top: true; left: true; bottom: busy; right: busy }
    implicitWidth: 1
    implicitHeight: 1
    mask: busy ? null : closedMask
    Region { id: closedMask }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "cozytile-overview"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: UiState.overview ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    // always loaded, hidden while closed: opening only flips this animation, nothing is created
    readonly property bool shown: UiState.overview
    // layout uses the screen size, never the surface size: the surface grows from 1x1 when it opens, and
    // the animation waits for that, so nothing ever appears to unfold from the top-left corner
    readonly property real sw: screen ? screen.width : 1920
    readonly property real sh: screen ? screen.height : 1080
    readonly property bool sized: width >= sw - 1 && height >= sh - 1
    property real p: shown && sized ? 1 : 0
    Behavior on p { NumberAnimation { duration: Math.round(220 / Math.max(0.25, svc.get("animSpeed"))); easing.type: Easing.OutQuart } }
    readonly property bool busy: UiState.overview || p > 0.002
    visible: true
    // free the window captures and tiles once fully closed
    onBusyChanged: if (!busy) { tiles.clear(); dragAddr = ""; dragOver = -1; }

    // monitor origin: window geometry from Hyprland is in layout coordinates
    readonly property var mon: Hyprland.monitorFor(screen)
    readonly property real mx: mon && mon.lastIpcObject && mon.lastIpcObject.x !== undefined ? mon.lastIpcObject.x : 0
    readonly property real my: mon && mon.lastIpcObject && mon.lastIpcObject.y !== undefined ? mon.lastIpcObject.y : 0

    property int viewId: -1                    // desktop whose windows fill the stage
    readonly property int curId: svc.activeFor(screen)
    property int dragOver: -1                  // card under a dragged window (-2 = the + card)
    property int pulse: -1
    property string dragAddr: ""
    property int renaming: -1

    readonly property real stripH: Math.round(sh * 0.2)
    readonly property real cardH: stripH - 44
    readonly property real cardW: Math.round(cardH * (screen ? screen.width / Math.max(1, screen.height) : 1.6))

    function close() { UiState.overview = false; }
    // Switch to a desktop and leave the overview. When the overview lets go of the keyboard, Hyprland re-focuses
    // the window that was focused before (on the old desktop) and would pull us back. So we focus the desktop's own
    // most recent window instead; an empty desktop has none, so it is switched once that re-focus has happened.
    function goTo(id) {
        const ws = svc.windows(id).slice().sort((a, b) => ((a.lastIpcObject ? a.lastIpcObject.focusHistoryID : 99) - (b.lastIpcObject ? b.lastIpcObject.focusHistoryID : 99)));
        if (ws.length > 0) { focusTile(svc.addr(ws[0])); return; }
        goTimer.sid = id;
        close();
        goTimer.restart();
    }
    Timer { id: goTimer; property int sid: -1; interval: 120; onTriggered: svc.activate(sid) }

    // Jump to a window, wherever it is (other desktop, off-screen in the scrolling layout). The overview holds
    // exclusive keyboard focus, so it closes first and the focus request follows once the keyboard is free.
    function focusTile(a) {
        const t = svc.byAddr(a);
        focusTimer.addr = a;
        focusTimer.ws = t && t.workspace ? t.workspace.id : -1;
        close();
        focusTimer.restart();
    }
    Timer {
        id: focusTimer
        property string addr: ""
        property int ws: -1
        interval: 30
        onTriggered: {
            if (ws > 0 && ws !== win.curId) svc.activate(ws);
            svc.focusWindow(addr);
        }
    }

    // ---------------- tiles: one per window of the viewed desktop ----------------
    ListModel { id: tiles }
    Timer { id: syncTimer; interval: 50; onTriggered: win.syncTiles() }
    Connections {
        target: svc
        function onRevChanged() { if (win.dragAddr === "") syncTimer.restart(); }
    }
    onViewIdChanged: { tiles.clear(); syncTimer.restart(); }
    // reopening within the close animation reuses this window: start from the current desktop again
    Connections {
        target: UiState
        function onOverviewChanged() {
            if (!UiState.overview) return;
            win.viewId = win.curId; win.renaming = -1; win.dragAddr = ""; win.dragOver = -1;
            win.syncTiles();                       // build the tiles right now, from what Hyprland last told us
            Hyprland.refreshToplevels();           // then correct them once fresh geometry arrives
        }
    }

    function indexOfTile(a) { for (let i = 0; i < tiles.count; i++) if (tiles.get(i).addr === a) return i; return -1; }
    function syncTiles() {
        if (viewId < 0 || !busy) return;
        const want = svc.windows(viewId).map(t => svc.addr(t));
        for (let i = tiles.count - 1; i >= 0; i--) if (want.indexOf(tiles.get(i).addr) < 0) tiles.remove(i);
        for (const a of want) if (indexOfTile(a) < 0) tiles.append({ addr: a, tx: 0, ty: 0, tw: 100, th: 100 });
        relayout();
    }
    function sizeOf(a) {
        const t = svc.byAddr(a), o = t ? t.lastIpcObject : null;
        return o && o.size && o.size[0] > 0 ? { w: o.size[0], h: o.size[1] } : { w: 900, h: 560 };
    }
    // choose the column count that shows the windows largest, then centre every row
    function relayout() {
        const n = tiles.count;
        if (n === 0) return;
        const X = 70, Y = stripH + 50, W = sw - 140, H = sh - stripH - 120, pad = 34;
        const sz = []; for (let i = 0; i < n; i++) sz.push(sizeOf(tiles.get(i).addr));
        let best = 1, bestScore = -1;
        for (let c = 1; c <= n; c++) {
            const r = Math.ceil(n / c), cw = W / c, ch = H / r;
            let score = 0;
            for (const s of sz) { const k = Math.min((cw - pad) / s.w, (ch - pad) / s.h, 1); score += s.w * k * s.h * k; }
            if (score > bestScore) { bestScore = score; best = c; }
        }
        const cols = best, rows = Math.ceil(n / cols), cw = W / cols, ch = H / rows;
        for (let i = 0; i < n; i++) {
            const row = Math.floor(i / cols), col = i % cols;
            const inRow = Math.min(cols, n - row * cols);
            const k = Math.min((cw - pad) / sz[i].w, (ch - pad) / sz[i].h, 1);
            const w = sz[i].w * k, h = sz[i].h * k;
            const ox = X + (W - inRow * cw) / 2 + col * cw + (cw - w) / 2;
            const oy = Y + (H - rows * ch) / 2 + row * ch + (ch - h) / 2;
            tiles.setProperty(i, "tx", ox); tiles.setProperty(i, "ty", oy);
            tiles.setProperty(i, "tw", w); tiles.setProperty(i, "th", h);
        }
    }

    // ---------------- drag and drop (mouse and tests share these) ----------------
    function tileFor(a) { for (let i = 0; i < field.count; i++) { const it = field.itemAt(i); if (it && it.addr === a) return it; } return null; }
    // desktop card under a point in window coordinates: stage id, -2 for the + card, -1 for none
    function cardAt(px, py) {
        for (let i = 0; i < cards.count; i++) {
            const it = cards.itemAt(i);
            if (!it) continue;
            const q = win.contentItem.mapToItem(it, px, py);
            if (q.x >= -8 && q.x <= it.width + 8 && q.y >= -8 && q.y <= it.height + 36) return i < svc.stages.length ? svc.stages[i].id : -2;
        }
        return -1;
    }
    function beginDrag(a, px, py) { const t = tileFor(a); if (!t) return; dragAddr = a; t.startDrag(px, py); }
    function moveDrag(px, py) {
        const t = tileFor(dragAddr);
        if (!t) return;
        t.dragTo(px, py);
        const c = cardAt(px, py);
        dragOver = (c === -1 || c === viewId) ? -1 : c;
        t.overCard = dragOver !== -1;
    }
    function endDrag(px, py) {
        const t = tileFor(dragAddr);
        if (!t) { dragAddr = ""; dragOver = -1; return; }
        let target = cardAt(px, py);
        if (target === viewId) target = -1;
        if (target === -1) { dragOver = -1; t.snapBack(); return; }
        const a = dragAddr;
        let c = null;
        for (let i = 0; i < cards.count; i++) if ((i < svc.stages.length ? svc.stages[i].id : -2) === target) c = cards.itemAt(i);
        const q = c ? c.mapToItem(win.contentItem, c.width / 2, c.height / 2) : Qt.point(px, py);
        t.flyTo(q.x, q.y, px, py);
        flyTimer.addr = a; flyTimer.target = target; flyTimer.restart();
    }
    Timer {
        id: flyTimer
        property string addr: ""
        property int target: -1
        interval: 300
        onTriggered: {
            let to = target;
            if (to === -2) to = svc.create("", "");
            win.pulse = to; pulseTimer.restart();
            svc.moveWindow(addr, to);
            win.dragAddr = ""; win.dragOver = -1;
            const i = win.indexOfTile(addr);
            if (i >= 0) tiles.remove(i);
            win.relayout();
            syncTimer.restart();
        }
    }
    Timer { id: pulseTimer; interval: 600; onTriggered: win.pulse = -1 }

    // ================= scene =================
    Item {
        id: root
        x: 0; y: 0; width: win.sw; height: win.sh
        visible: win.busy
        focus: true
        Component.onCompleted: forceActiveFocus()
        Keys.onEscapePressed: win.close()
        Keys.onPressed: ev => {
            if (ev.key >= Qt.Key_1 && ev.key <= Qt.Key_9) { const s = svc.stages[ev.key - Qt.Key_1]; if (s) { svc.activate(s.id); win.close(); } }
        }

        // dimmed backdrop (blurred by the compositor layer rule)
        Rectangle { anchors.fill: parent; color: Theme.veil(Theme.p.bg, win.p > 0.001 ? 0.58 : 0); opacity: Math.min(1, win.p * 3) }
        MouseArea { anchors.fill: parent; onClicked: win.close() }

        // everything zooms out together, straight about the screen centre
        Item {
            id: zoomLayer
            anchors.fill: parent
            transformOrigin: Item.Center
            scale: 1.3 - 0.3 * win.p
            opacity: Math.min(1, win.p * 3)

            // ---- desktop strip ----
            Item {
                id: strip
                width: parent.width; height: win.stripH
                Row {
                    id: cardRow
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 22
                    spacing: 18
                    Repeater {
                        id: cards
                        model: svc.stages.length + 1          // count only: cards survive Hyprland events
                        delegate: Item {
                            id: card
                            required property int index
                            readonly property bool isAdd: index >= svc.stages.length
                            readonly property var stage: isAdd ? null : svc.stages[index]
                            readonly property int sid: isAdd ? -2 : stage.id
                            readonly property var wins: isAdd ? [] : svc.windows(sid)
                            readonly property bool viewed: win.viewId === sid
                            readonly property bool current: win.curId === sid
                            readonly property bool dropHere: win.dragOver === sid || win.pulse === sid
                            readonly property real k: Math.min(1, (win.sw - 160) / Math.max(1, (svc.stages.length + 1) * (win.cardW + 18)))
                            width: Math.round(isAdd ? win.cardW * 0.5 * k : win.cardW * k); height: Math.round(win.cardH * k)
                            scale: dropHere ? 1.12 : (hv.hovered ? 1.04 : 1)
                            Behavior on scale { NumberAnimation { duration: 320; easing.type: Easing.OutBack; easing.overshoot: 2.2 } }
                            HoverHandler { id: hv }

                            Rectangle {
                                id: face
                                anchors.fill: parent
                                radius: svc.get("radius")
                                color: card.dropHere ? Theme.veil(Theme.accent, 0.28) : Theme.veil(Theme.p.bg2, 0.78)
                                border.width: card.viewed || card.dropHere ? 2 : 1
                                border.color: card.viewed || card.dropHere ? Theme.accent : Theme.veil(Theme.p.fg, 0.2)
                                Behavior on color { ColorAnimation { duration: 160 } }
                                clip: true
                                // miniature: the windows as small tiles in a grid (real positions mean little in scrolling layouts)
                                Repeater {
                                    model: card.isAdd ? 0 : card.wins
                                    delegate: Rectangle {
                                        required property var modelData
                                        required property int index
                                        readonly property int n: card.wins.length
                                        readonly property int cols: Math.max(1, Math.ceil(Math.sqrt(n * face.width / Math.max(1, face.height))))
                                        readonly property int rows: Math.max(1, Math.ceil(n / cols))
                                        readonly property real cw: (face.width - 16) / cols
                                        readonly property real ch: (face.height - 16) / rows
                                        readonly property int inRow: Math.min(cols, n - Math.floor(index / cols) * cols)
                                        x: 8 + (face.width - 16 - inRow * cw) / 2 + (index % cols) * cw + 3
                                        y: 8 + Math.floor(index / cols) * ch + 3
                                        width: cw - 6; height: ch - 6
                                        radius: 5
                                        color: Theme.veil(Theme.p.bg3, 0.95)
                                        border.width: 1; border.color: Theme.veil(Theme.accent, modelData.activated ? 0.8 : 0.3)
                                        IconImage {
                                            anchors.centerIn: parent
                                            implicitSize: Math.max(10, Math.min(parent.width, parent.height) * 0.6)
                                            source: Quickshell.iconPath(svc.iconFor(modelData), true)
                                        }
                                    }
                                }
                                Text { anchors.centerIn: parent; visible: card.isAdd; text: "+"; color: Theme.text; font.pixelSize: 30; font.family: Theme.font }
                                Text { anchors.centerIn: parent; visible: !card.isAdd && card.wins.length === 0; text: "Empty"
                                    color: Theme.textMuted; font.family: Theme.font; font.pixelSize: Theme.fontSmall + 1 }
                            }
                            // live indicator: this is the desktop you are on
                            Rectangle { visible: card.current; width: 8; height: 8; radius: 4; color: Theme.accent
                                anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.top; bottomMargin: 6 } }

                            // name (double-click to rename)
                            Item {
                                visible: !card.isAdd
                                anchors { top: parent.bottom; topMargin: 8; horizontalCenter: parent.horizontalCenter }
                                width: parent.width; height: 20
                                Text { anchors.centerIn: parent; visible: win.renaming !== card.sid; width: parent.width; horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight
                                    text: card.stage ? card.stage.name : ""; color: card.viewed ? Theme.text : Theme.textDim
                                    font.family: Theme.font; font.pixelSize: Theme.fontSmall + 1; font.bold: card.viewed }
                                TextInput {
                                    anchors.centerIn: parent; width: parent.width - 10; horizontalAlignment: TextInput.AlignHCenter
                                    visible: win.renaming === card.sid
                                    color: Theme.text; selectionColor: Theme.accent; font.family: Theme.font; font.pixelSize: Theme.fontSmall + 1
                                    onVisibleChanged: if (visible) { text = card.stage.name; forceActiveFocus(); selectAll(); }
                                    onAccepted: { svc.rename(card.sid, text); win.renaming = -1; root.forceActiveFocus(); }
                                    Keys.onEscapePressed: { win.renaming = -1; root.forceActiveFocus(); }
                                }
                            }
                            // remove (hover)
                            Rectangle {
                                visible: !card.isAdd && hv.hovered && svc.stages.length > 1 && win.dragAddr === ""
                                width: 20; height: 20; radius: 10; z: 5
                                anchors { top: parent.top; right: parent.right; margins: -6 }
                                color: rm.containsMouse ? Theme.bad : Theme.veil(Theme.p.bg, 0.9)
                                border.width: 1; border.color: Theme.veil(Theme.p.fg, 0.3)
                                Text { anchors.centerIn: parent; text: "×"; color: Theme.text; font.pixelSize: 14; font.family: Theme.font }
                                MouseArea { id: rm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    onClicked: { const was = win.viewId === card.sid; svc.remove(card.sid); if (was) win.viewId = svc.defaultId; } }
                            }
                            // click: go to that desktop (+ makes a new one); right-click: peek at its windows
                            MouseArea {
                                anchors.fill: parent; z: 1
                                cursorShape: Qt.PointingHandCursor
                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                onClicked: mouse => {
                                    if (mouse.button === Qt.RightButton) { if (!card.isAdd) win.viewId = card.sid; return; }
                                    win.goTo(card.isAdd ? svc.create("", "") : card.sid);
                                }
                                onDoubleClicked: if (!card.isAdd) win.renaming = card.sid
                            }
                        }
                    }
                }
            }

            // ---- window tiles ----
            Repeater {
                id: field
                model: tiles
                delegate: Item {
                    id: tile
                    required property int index
                    required property string addr
                    required property real tx
                    required property real ty
                    required property real tw
                    required property real th
                    readonly property var tl: svc.byAddr(addr)
                    readonly property var o: tl ? tl.lastIpcObject : null
                                    // animated copies of the targets, so a re-layout glides
                    // a new tile is appended with placeholder numbers and laid out right after: only glide once it has settled
                    property bool ready: false
                    Component.onCompleted: Qt.callLater(() => tile.ready = true)
                    property real ax: tx
                    property real ay: ty
                    property real aw: tw
                    property real ah: th
                    Behavior on ax { enabled: tile.ready; NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }
                    Behavior on ay { enabled: tile.ready; NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }
                    Behavior on aw { enabled: tile.ready; NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }
                    Behavior on ah { enabled: tile.ready; NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }
                    x: ax + dx
                y: ay + dy
                width: aw
                height: ah
                opacity: flying ? 0 : 1
                Behavior on opacity { NumberAnimation { duration: 240 } }
                property real dx: 0
                    property real dy: 0
                    property bool dragging: false
                    property bool flying: false
                    property bool settling: false
                    property bool overCard: false
                    property real _px: 0
                    property real _py: 0
                    z: dragging || flying ? 100 : 1
                    // while carried the window shrinks to a small thumbnail around the grab point, smaller still over a card
                    readonly property real carryScale: Math.min(0.5, 260 / Math.max(1, Math.max(width, height)))
                    property real grabX: 0
                    property real grabY: 0
                    property real ds: flying ? 0.08 : (overCard ? carryScale * 0.5 : (dragging ? carryScale : (hov.hovered ? 1.025 : 1)))
                    Behavior on ds { NumberAnimation { duration: tile.flying ? 300 : 280; easing.type: tile.flying ? Easing.InCubic : Easing.OutBack; easing.overshoot: 1.2 } }
                    transform: Scale {
                        origin.x: (tile.dragging || tile.flying || tile.settling) ? tile.grabX : tile.width / 2
                        origin.y: (tile.dragging || tile.flying || tile.settling) ? tile.grabY : tile.height / 2
                        xScale: tile.ds; yScale: tile.ds
                    }
                    Behavior on dx { enabled: tile.settling || tile.flying; NumberAnimation { duration: tile.flying ? 300 : 340; easing.type: tile.flying ? Easing.InOutCubic : Easing.OutBack; easing.overshoot: 1.4 } }
                    Behavior on dy { enabled: tile.settling || tile.flying; NumberAnimation { duration: tile.flying ? 300 : 340; easing.type: tile.flying ? Easing.InOutCubic : Easing.OutBack; easing.overshoot: 1.4 } }

                    function startDrag(px, py) { settling = false; flying = false; const g = mapFromItem(root, px, py); grabX = g.x; grabY = g.y; dragging = true; _px = px; _py = py; dx = 0; dy = 0; }
                    function dragTo(px, py) { dx = px - _px; dy = py - _py; }
                    function snapBack() { settling = true; dx = 0; dy = 0; overCard = false; dragging = false; win.dragAddr = ""; snapDone.restart(); }
                    // carry the grab point into the target card's centre while shrinking away
                    function flyTo(cx, cy, px, py) { flying = true; dragging = false; dx += cx - px; dy += cy - py; }
                    Timer { id: snapDone; interval: 420; onTriggered: tile.settling = false }

                    HoverHandler { id: hov }

                    Rectangle { anchors.fill: parent; anchors.topMargin: 6; anchors.margins: -2; radius: svc.get("radius") + 2; color: "black"; opacity: 0.38; z: -1 }

                    Rectangle { id: maskRect; anchors.fill: parent; radius: svc.get("radius"); layer.enabled: true; visible: false }
                    Item {
                        anchors.fill: parent
                        layer.enabled: true
                        layer.effect: MultiEffect { maskEnabled: true; maskSource: maskRect; maskThresholdMin: 0.5; maskSpreadAtMin: 1.0 }
                        Rectangle { anchors.fill: parent; color: Theme.p.bg2 }
                        ScreencopyView {
                            id: cap
                            anchors.fill: parent
                            captureSource: win.busy && tile.tl ? tile.tl.wayland : null
                            live: win.viewId === win.curId
                            paintCursor: false
                            // a failed capture ends the recording for good: re-arm the source and grab again
                            function arm() {
                                if (!tile.tl || !tile.tl.wayland) return;
                                if (!hasContent) { captureSource = null; captureSource = tile.tl.wayland; if (!live) retry.restart(); }
                            }
                            Timer { id: retry; interval: 250; onTriggered: if (cap.captureSource && !cap.live) cap.captureFrame() }
                            Timer { running: !cap.hasContent; repeat: true; interval: 600; onTriggered: cap.arm() }
                            // windows of other desktops are not live: refresh them about once a second
                            Timer { running: cap.hasContent && !cap.live && win.shown; repeat: true; interval: 1000; onTriggered: cap.captureFrame() }
                            Component.onCompleted: if (!live && captureSource) captureFrame()
                        }
                        // fallback while a window cannot be captured (e.g. fully off-screen in a scrolling layout)
                        Column {
                            anchors.centerIn: parent; visible: !cap.hasContent; spacing: 10; width: parent.width - 24
                            IconImage {
                                anchors.horizontalCenter: parent.horizontalCenter
                                implicitSize: Math.max(24, Math.min(tile.width, tile.height) * 0.3)
                                source: Quickshell.iconPath(svc.iconFor(tile.tl), true)
                            }
                            Text { width: parent.width; horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight
                                text: tile.tl ? (tile.tl.title || svc.windowClass(tile.tl)) : ""; color: Theme.textDim
                                font.family: Theme.font; font.pixelSize: Theme.fontSize }
                        }
                    }
                    Rectangle { anchors.fill: parent; radius: svc.get("radius"); color: "transparent"
                        border.width: hov.hovered || tile.dragging ? 3 : 1
                        border.color: hov.hovered || tile.dragging ? Theme.accent : Theme.veil(Theme.p.fg, 0.28) }

                    // title pill + close button (hover)
                    Rectangle {
                        visible: (hov.hovered || tile.dragging) && !tile.flying
                        anchors { horizontalCenter: parent.horizontalCenter; top: parent.bottom; topMargin: 10 }
                        width: Math.min(Math.max(tile.width, 200), ttl.implicitWidth + 50); height: 24; radius: 12
                        color: Theme.veil(Theme.p.bg, 0.86); border.width: 1; border.color: Theme.veil(Theme.p.fg, 0.18)
                        IconImage { x: 8; anchors.verticalCenter: parent.verticalCenter; implicitSize: 16; source: Quickshell.iconPath(svc.iconFor(tile.tl), true) }
                        Text { id: ttl; x: 30; width: parent.width - 38; anchors.verticalCenter: parent.verticalCenter; elide: Text.ElideRight
                            text: tile.tl ? (tile.tl.title || svc.windowClass(tile.tl)) : ""; color: Theme.text; font.family: Theme.font; font.pixelSize: Theme.fontSmall + 1 }
                    }
                    Rectangle {
                        visible: hov.hovered && !tile.dragging && !tile.flying
                        width: 24; height: 24; radius: 12; z: 5
                        anchors { left: parent.left; top: parent.top; margins: -8 }
                        color: cl.containsMouse ? Theme.bad : Theme.veil(Theme.p.bg, 0.9)
                        border.width: 1; border.color: Theme.veil(Theme.p.fg, 0.3)
                        Text { anchors.centerIn: parent; text: "×"; color: Theme.text; font.pixelSize: 16; font.family: Theme.font }
                        MouseArea { id: cl; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: svc.closeWindow(tile.addr) }
                    }

                    MouseArea {
                        id: ma
                        anchors.fill: parent
                        cursorShape: pressed && tile.dragging ? Qt.ClosedHandCursor : Qt.PointingHandCursor
                        property point press
                        onPressed: mouse => { press = mapToItem(root, mouse.x, mouse.y); }
                        onPositionChanged: mouse => {
                            if (!pressed) return;
                            const q = mapToItem(root, mouse.x, mouse.y);
                            if (!tile.dragging && Math.hypot(q.x - press.x, q.y - press.y) > 10) win.beginDrag(tile.addr, press.x, press.y);
                            if (tile.dragging) win.moveDrag(q.x, q.y);
                        }
                        onReleased: mouse => {
                            const q = mapToItem(root, mouse.x, mouse.y);
                            if (tile.dragging) win.endDrag(q.x, q.y);
                        }
                        onClicked: { if (!(tile.dragging || tile.flying || tile.settling)) win.focusTile(tile.addr); }
                    }
                }
            }

        }

        // empty desktop
        Text {
            anchors.centerIn: parent; visible: tiles.count === 0 && win.p > 0.5
            text: "No windows on this desktop"; color: Theme.textMuted; font.family: Theme.font; font.pixelSize: Theme.fontLarge
        }
    }
}
