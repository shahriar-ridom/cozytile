import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import "../../config"
import "../../services"
import "../../components"

// macOS-style dock: a floating pill at the bottom edge. Icons magnify in a smooth wave around the cursor and push
// their neighbours aside; growth is upward only, so the baseline never moves. One window per screen.
// Pinned apps come first, running apps that aren't pinned follow a separator. Items fade and grow in and out.
// Hiding (Settings.dockHide): "never" reserves the space so windows tile above the dock, "intelli" slides it away
// while a window touches it, "always" keeps it away. Touching the bottom edge under it brings it back.
// Dwelling on a running app opens its Window Peek (live thumbnails) above it.
// Drag: pinned icons reorder (a gap slides to the drop spot), running apps dragged left of the separator get pinned,
// pinned icons dragged up off the dock are unpinned with a poof. Escape snaps back. Files dropped on an icon open in it.
// Folder stacks follow the running apps behind their own separator. Clicking one opens its FolderStack (fan, grid or
// list); a folder dropped on the empty dock becomes a stack.
PanelWindow {
    id: win

    readonly property real maxScale: Math.max(1, Settings.dockMagnification)
    readonly property int pad: 10
    readonly property int gap: 6
    readonly property int sepW: 14             // room taken by the pinned / running separator
    readonly property int margin: 8            // gap between the pill and the screen edge
    readonly property int labelRoom: 34        // headroom for the hover label
    // transparent room above, to pull an icon off the dock. Fixed: resizing the window mid-drag desyncs Qt's and the
    // compositor's pointer coordinates for a few frames.
    readonly property real dragRoom: iconSize * 2.2

    // ---- items ----
    // slots: DockService items plus the ones still animating out. { key, info, t (0..1 shown), target }.
    // slotKeys only changes when membership changes, so delegates (and their bounce state) survive updates.
    property var slots: []
    property var slotKeys: []
    function setSlots(list) {
        slots = list;
        const k = list.map(s => s.key);
        if (k.join("\n") !== slotKeys.join("\n")) slotKeys = k;
    }
    // carry: key -> starting t for new slots; drop: a leftover key removed at once instead of fading out
    function sync(instant, carry, drop) {
        const items = preview(), old = slots;
        const out = items.map(it => {
            const o = old.find(s => s.key === it.key);
            const t = carry && carry[it.key] !== undefined ? carry[it.key] : instant ? 1 : (o ? o.t : 0);
            return { key: it.key, info: it, t: t, target: 1 };
        });
        old.forEach((s, i) => {
            if (s.key !== drop && !items.some(it => it.key === s.key) && s.t > 0)
                out.splice(Math.min(i, out.length), 0, { key: s.key, info: s.info, t: s.t, target: 0 });
        });
        setSlots(out);
    }
    Connections {
        target: DockService
        function onItemsChanged() {
            if (win.dragging && !DockService.items.some(it => it.key === win.dragKey)) win.endDrag();
            else win.sync(false);
        }
    }
    Component.onCompleted: sync(true)
    FrameAnimation {
        running: win.slots.some(s => s.t !== s.target)
        onTriggered: {
            const step = frameTime / 0.24;
            const out = [];
            for (const s of win.slots) {
                const t = s.target > s.t ? Math.min(s.target, s.t + step) : Math.max(s.target, s.t - step);
                if (s.target === 0 && t <= 0) continue;
                out.push({ key: s.key, info: s.info, t: t, target: s.target });
            }
            win.setSlots(out);
        }
    }
    readonly property int count: slots.length
    readonly property int shownCount: DockService.items.length

    // separator before the first unpinned item, when pinned ones precede it; sepAt keeps its place while fading out
    readonly property int sepIndex: {
        const i = slots.findIndex(s => !s.info.pinned && !s.info.stack && !s.info.tool);
        return i > 0 && slots.slice(0, i).some(s => s.info.pinned && s.target > 0) && slots.slice(i).some(s => !s.info.stack && !s.info.tool && s.target > 0) ? i : -1;
    }
    property int sepAt: -1
    onSepIndexChanged: if (sepIndex >= 0) sepAt = sepIndex
    property real sepT: sepIndex >= 0 ? 1 : 0
    Behavior on sepT { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
    // more separators before the folder stacks, the quick tools and the Trash; each grows and shrinks with its first
    // item's own enter / leave. cuts: [{ at: slot index or -1, t: 0..1 }]
    readonly property var cuts: ["stack", "tool", "trash"].map(k => {
        const i = slots.findIndex(s => s.info[k] && (k === "trash" || !s.info.trash));
        const ok = i > 0 && slots.slice(0, i).some(s => s.target > 0);
        return { at: ok ? i : -1, t: ok ? Math.min(1, slots[i].t) : 0 };
    })
    function cutWidth(i) { return cuts.reduce((w, c) => w + (c.at === i ? sepW * c.t : 0), 0); }

    // adaptive size: from the screen width, then shrunk until the magnified row still fits. The row grows away from
    // the cursor, so at the far end one side takes up to ~1.65 icons of growth: budget for that on both sides.
    readonly property real screenW: screen ? screen.width : 1920
    readonly property real screenH: screen ? screen.height : 1080
    readonly property int iconSize: {
        const n = Math.max(1, shownCount);
        const want = Settings.dockIconSize > 0 ? Settings.dockIconSize : Math.max(40, Math.min(72, screenW * 0.027));
        const fit = (screenW * 0.9 - 2 * pad - n * gap - sepW) / (n + 3.3 * (maxScale - 1));
        return Math.round(Math.max(24, Math.min(want, fit)));
    }
    readonly property real wave: iconSize * 2.6            // reach of the magnification curve, px
    readonly property real pillH: iconSize + 2 * 8
    readonly property real baseY: height - margin - 8      // bottom edge of every icon

    // resting row (no magnification): left edge and width of each slot from the row's start, and the row's width
    readonly property var rest: {
        const rx = [];
        let r = 0, last = 0;
        for (let i = 0; i < slots.length; ++i) {
            if (i === sepAt) r += sepW * sepT;
            r += cutWidth(i);
            rx.push(r);
            r += (iconSize + gap) * slots[i].t;
            last = slots[i].t;
        }
        return { rx: rx, sepX: sepAt >= 0 && sepAt < slots.length ? rx[sepAt] - sepW * sepT : -1, width: Math.max(0, r - gap * last) };
    }
    readonly property real restW: rest.width + 2 * pad
    readonly property real restLeft: Math.round((width - restW) / 2)

    // cursor tracking, in resting-row coordinates (0 = the pill's resting left edge): `cursorX` is the pointer,
    // `smoothX` follows it with critically damped easing (no overshoot), so the wave trails and settles
    property bool dropHover: false             // a file drag from another app is over the dock
    readonly property bool hovering: area.containsMouse || dropHover
    property real cursorX: 0
    property real smoothX: 0
    // the pointer is on the dock or on its peek: the magnified wave holds still while it is over the peek
    readonly property bool engaged: hovering || peekHovered
    property real amount: engaged && !hidden && !unpinZone ? 1 : 0
    Behavior on amount { NumberAnimation { duration: Theme.animNormal; easing.type: Easing.OutCubic } }
    FrameAnimation {
        running: win.smoothX !== win.cursorX
        onTriggered: {
            const d = win.cursorX - win.smoothX;
            win.smoothX = Math.abs(d) < 0.2 ? win.cursorX : win.smoothX + d * (1 - Math.exp(-frameTime * 22));
        }
    }

    // one pass per frame: every icon's size factor and left edge (window coordinates). Neighbours are pushed apart by
    // their growth, and the whole row is shifted so the point under the cursor stays put: the icon you point at never
    // slides away, and the pill's edge meets the cursor exactly where the resting pill's edge was.
    readonly property var lay: {
        const f = [], x = [];
        let acc = 0, sepX = -1, last = 0;
        const cutX = cuts.map(() => -1);
        const c = smoothX - pad;
        let mag = null;
        const n = Math.min(slots.length, rest.rx.length);
        for (let i = 0; i < n; ++i) {
            const t = slots[i].t;
            const own = i === sepAt ? sepW * sepT : 0, sw = own + cutWidth(i);
            if (sw > 0 || i === sepAt) {
                const s0 = rest.rx[i] - sw;
                if (mag === null && c < rest.rx[i]) mag = acc + Math.max(0, c - s0) - Math.max(0, s0 - c);
                if (i === sepAt) sepX = acc;
                let at = acc + own;
                cuts.forEach((k, n) => { if (k.at === i) { cutX[n] = at; at += sepW * k.t; } });
                acc += sw;
            }
            const d = Math.abs(smoothX - (pad + rest.rx[i] + iconSize / 2)) / wave;
            const k = d >= 1 ? 0 : (1 + Math.cos(Math.PI * d)) / 2;
            const fi = 1 + (maxScale - 1) * k * amount;
            const w0 = (iconSize + gap) * t, w1 = (iconSize * fi + gap) * t;
            // where the cursor's resting position lands in the magnified row
            if (mag === null && c < rest.rx[i] + w0) mag = c < rest.rx[i] ? acc - (rest.rx[i] - c) : acc + (w0 > 0 ? (c - rest.rx[i]) / w0 * w1 : 0);
            f.push(fi); x.push(acc);
            acc += w1;
            last = t;
        }
        if (mag === null) mag = c + acc - (rest.width + gap * last);
        const left = restLeft + c - mag;
        for (let i = 0; i < n; ++i) x[i] += left + pad;
        return { f: f, x: x, left: left, sepX: sepX >= 0 ? sepX + left + pad : -1, cutX: cutX.map(x => x >= 0 ? x + left + pad : -1), total: Math.max(0, acc - gap * last) };
    }

    // the icon under the pointer, from the laid-out row (its slot spans half a gap either side)
    property real mouseX: 0
    property real mouseY: 0
    readonly property int hoverIndex: {
        if (!hovering || hidden) return -1;
        for (let i = 0; i < Math.min(slots.length, lay.x.length); ++i) {
            if (slots[i].target === 0 || slots[i].info.gap) continue;
            const l = lay.x[i] - gap / 2, w = (iconSize * lay.f[i] + gap) * slots[i].t;
            if (mouseX >= l && mouseX < l + w) return mouseY >= baseY - iconSize * lay.f[i] - 4 ? i : -1;
        }
        return -1;
    }
    property string labelText: ""
    onHoverIndexChanged: {
        if (hoverIndex < 0) return;
        labelText = slots[hoverIndex].info.name;
        if (slots[hoverIndex].key !== peekMute) peekMute = "";
    }

    // while files are dragged over the dock, only the icons that can take them stay lit: apps that open files, and the Trash
    function dropTarget(it) { return it.trash === true || DockService.canOpen(it); }

    // ---- hovering Downloads ---- opens its stack after a dwell, once per visit to the icon
    readonly property string dwellKey: {
        const i = hoverIndex;
        if (i < 0 || !Settings.dockContext || DockService.modeOverride === "normal" || dragging || dropHover) return "";
        const s = slots[i].info;
        return s.stack && !s.trash && s.path !== "recent" && s.dir.split("/").pop() === "Downloads" ? slots[i].key : "";
    }
    onDwellKeyChanged: if (dwellKey !== "") dwell.restart(); else dwell.stop()
    Timer {
        id: dwell; interval: 600
        onTriggered: {
            const i = win.slots.findIndex(s => s.key === win.dwellKey);
            if (i < 0 || stackPanel.open || menu.open || toolPanel.open) return;
            win.hidePeek();
            stackPanel.openFor(win.slots[i].info, win.lay.x[i] + win.iconSize * win.lay.f[i] / 2, win.baseY - win.iconSize * win.lay.f[i]);
        }
    }

    // ---- window peek ----
    // Dwell ~250 ms on a running app to open it; once open, moving to another running app switches at once (the
    // card slides and cross-fades). Leaving starts a grace period, so the gap between icon and card can be crossed.
    readonly property string screenName: screen ? screen.name : ""
    property string peekKey: ""
    property real peekCx: 0                    // centre of the peeked icon, window x
    property bool peekHovered: false
    readonly property bool peekOpen: UiState.dockPeek !== "" && UiState.dockPeek === screenName && peekKey !== ""
    readonly property string peekCandidate: hoverIndex >= 0 && !menu.open && !stackPanel.open && !toolPanel.open && !dragging && !dropHover && slots[hoverIndex].info.windows.length > 0
        && slots[hoverIndex].key !== peekMute ? slots[hoverIndex].key : ""
    // the icon just dropped: no peek for it until the pointer moves to another icon
    property string peekMute: ""
    function showPeek(key) {
        const i = slots.findIndex(s => s.key === key);
        if (i < 0) return;
        peekCx = lay.x[i] + iconSize * lay.f[i] / 2;
        peekKey = key;
        UiState.dockPeek = screenName;
    }
    function hidePeek() { peekDwell.stop(); peekLeave.stop(); if (UiState.dockPeek === screenName) UiState.dockPeek = ""; }
    onPeekCandidateChanged: {
        if (peekCandidate !== "") { peekLeave.stop(); if (peekOpen) showPeek(peekCandidate); else peekDwell.restart(); }
        else { peekDwell.stop(); if (peekOpen && !peekHovered) peekLeave.restart(); }
    }
    onPeekHoveredChanged: {
        if (peekHovered) peekLeave.stop();
        else if (peekCandidate === "" && peekOpen) peekLeave.restart();
    }
    Timer { id: peekDwell; interval: 250; onTriggered: if (win.peekCandidate !== "") win.showPeek(win.peekCandidate) }
    Timer { id: peekLeave; interval: 320; onTriggered: if (!win.peekHovered && win.peekCandidate === "") win.hidePeek() }
    // creating a layer window costs ~0.5 s, so the peek stays mapped (transparent and click-through while closed)
    WindowPeek { dock: win }

    // the Trash's "Empty Trash" asks first, in the Trash popup, like Luma Files does
    function askEmptyTrash() {
        const i = slots.findIndex(s => s.info.trash);
        if (i < 0) return;
        hidePeek();
        stackPanel.openFor(slots[i].info, lay.x[i] + iconSize * lay.f[i] / 2, baseY - iconSize * lay.f[i], true);
    }

    // ---- drag and drop ----
    // While dragging, the dragged item leaves the row and a gap slot (`gap: true`, a fresh key per position so the old
    // gap shrinks while the new one grows) marks where it will land. gapAt indexes the row without the dragged item;
    // -1 means no gap (a pinned app held above the dock: dropping unpins it).
    property string dragKey: ""
    property var dragInfo: null
    readonly property bool dragging: dragKey !== ""
    property int dragFrom: -1
    property int gapAt: -1
    property bool gapPinned: false
    property string gapKey: ""
    property int gapSerial: 0
    property real grabDX: 0                    // pointer offset from the icon's bottom centre
    property real grabDY: 0
    property bool settling: false              // released: the icon flies into its slot
    property bool settleCommit: false
    property real settle: 0
    property real relX: 0
    property real relY: 0
    property real relF: 1
    readonly property bool unpinZone: dragging && !settling && mouseY < baseY - iconSize * maxScale - 16
    property real liftF: unpinZone ? 1 : 1 + (maxScale - 1) * 0.85
    Behavior on liftF { NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutCubic } }

    function preview() {
        const items = DockService.items;
        if (!dragging) return items;
        const out = items.filter(it => it.key !== dragKey);
        if (gapKey !== "")
            out.splice(Math.min(gapAt, out.length), 0, { key: gapKey, gap: true, pinned: gapPinned, name: "", icon: "", windows: [] });
        return out;
    }
    function setGap(at, pin) {
        if (at === gapAt && pin === gapPinned) return;
        gapAt = at; gapPinned = pin;
        gapKey = at >= 0 ? "\u0001gap" + (++gapSerial) : "";
        sync(false);
    }
    function startDrag(i) {
        const s = slots[i];
        if (!s || s.info.gap || s.info.stack || s.info.tool || s.target === 0) return;
        hidePeek();
        grabDX = mouseX - (lay.x[i] + iconSize * lay.f[i] / 2);
        grabDY = mouseY - baseY;
        dragInfo = s.info;
        dragFrom = DockService.items.findIndex(it => it.key === s.key);
        gapAt = dragFrom; gapPinned = s.info.pinned;
        gapKey = "\u0001gap" + (++gapSerial);
        dragKey = s.key;
        const c = {}; c[gapKey] = s.t;
        sync(false, c, s.key);
    }
    // the drop spot from the icons left of the pointer. Pinned apps stay in the pinned section; a running app is
    // pinned once the pointer is left of the separator, otherwise it goes back where it was.
    function updateDrop() {
        const pinned = dragInfo.pinned;
        let at = pinned ? -1 : dragFrom, pin = pinned;
        if (!unpinZone) {
            const gx = mouseX - grabDX;        // the dragged icon's centre
            let k = 0;
            for (let i = 0; i < Math.min(slots.length, lay.x.length); ++i)
                if (!slots[i].info.gap && slots[i].target > 0 && lay.x[i] + iconSize * lay.f[i] / 2 < gx) ++k;
            const nPinned = DockService.items.filter(it => it.pinned && it.key !== dragKey).length;
            if (pinned) at = Math.min(k, nPinned);
            else if (dragInfo.entry && (k < nPinned || (k === nPinned && lay.sepX >= 0 && gx < lay.sepX + sepW * sepT / 2))) { at = k; pin = true; }
        }
        setGap(at, pin);
    }
    function drop() {
        if (gapAt < 0) {
            poof.play(mouseX - grabDX, Math.max(iconSize * liftF + 4, mouseY - grabDY), liftF, dragInfo);
            DockService.unpin(dragInfo);
            endDrag();
            return;
        }
        startSettle(gapPinned && (!dragInfo.pinned || gapAt !== dragFrom));
    }
    function cancelDrag() {
        if (!dragging || settling) return;
        setGap(dragFrom, dragInfo.pinned);
        startSettle(false);
    }
    function startSettle(commit) {
        relX = mouseX - grabDX; relY = Math.max(iconSize * liftF + 4, mouseY - grabDY); relF = liftF;
        settleCommit = commit;
        settling = true;
        settleAnim.restart();
    }
    function endDrag() {
        if (!dragging) return;
        settleAnim.stop();
        const g = slots.find(s => s.key === gapKey), c = {}, d = gapKey;
        c[dragKey] = g ? g.t : 0;
        peekMute = dragKey;
        dragKey = ""; dragInfo = null; gapKey = ""; gapAt = -1; settling = false; settle = 0;
        sync(false, c, d);
    }
    NumberAnimation {
        id: settleAnim
        target: win; property: "settle"; from: 0; to: 1
        duration: 220; easing.type: Easing.OutCubic
        onFinished: {
            if (win.settleCommit) DockService.placePinned(win.dragInfo, win.gapAt);
            win.endDrag();
        }
    }
    // keyboard focus is offered while the pointer is on the dock (for Escape). It must not change mid-press: Hyprland
    // answers a focus change with a pointer leave, which cancels the press and the drag with it.
    WlrLayershell.keyboardFocus: area.containsMouse || dragging ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    Item { focus: true; Keys.onEscapePressed: win.cancelDrag() }

    // ---- hiding ----
    readonly property string hideMode: Settings.dockHide
    // context: a fullscreen window on this screen (or the "hidden" mode) puts the dock away. The state settles for 200 ms so
    // rapid fullscreen toggles don't make it flap. A game's minimal dock stays on top of the game, away until the edge is touched.
    readonly property bool fullscreenRaw: DockService.modeOverride === "hidden" || (DockService.auto && WindowService.fullscreenOn(screen, false))
    property bool fullscreen: false
    onFullscreenRawChanged: fsSettle.restart()
    Timer { id: fsSettle; interval: 200; onTriggered: win.fullscreen = win.fullscreenRaw }
    readonly property bool gameDock: DockService.gaming
    readonly property bool contextHide: fullscreen || gameDock
    readonly property bool overlapped: hideMode === "intelli"
        && WindowService.overlaps(screen, restLeft, screenH - margin - pillH, restW, margin + pillH)
    // stays out a moment after the pointer leaves, so brushing past the edge doesn't flicker it
    readonly property bool revealed: engaged || dragging || linger.running || menu.open || stackPanel.open || toolPanel.open || peekOpen
    Timer { id: linger; interval: 450 }
    onEngagedChanged: if (!engaged) linger.restart()
    readonly property bool hidden: contextHide || hideMode === "always" ? !revealed : hideMode === "intelli" ? overlapped && !revealed : false
    property real shift: hidden ? margin + pillH + 6 : 0
    Behavior on shift { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }

    visible: count > 0
    anchors { bottom: true; left: true; right: true }
    implicitHeight: margin + pillH + iconSize * (maxScale - 1) + labelRoom + dragRoom
    exclusiveZone: hideMode === "never" && !contextHide ? Math.round(margin + pillH) : 0
    color: "transparent"
    WlrLayershell.namespace: "cozytile-dock"
    WlrLayershell.layer: gameDock ? WlrLayer.Overlay : WlrLayer.Top

    // input region: the resting pill down to the screen edge; while hovered it also covers the magnified icons above.
    // Hidden, it is a thin strip at the screen edge under the pill. It changes only on enter/leave and hide/show,
    // never per frame, so magnifying cannot make the pointer fall out of it.
    mask: Region { item: hit }
    Item {
        id: hit
        x: win.restLeft; width: win.restW
        // 6 px while hidden: during a drag-and-drop Hyprland never puts the pointer over the screen's last pixel row,
        // so a 2 px strip could not catch a file dragged to the edge
        y: win.dragging ? 0 : win.hidden ? win.height - 6
            : win.hovering ? win.baseY - win.iconSize * win.maxScale - 4 : win.height - win.margin - win.pillH
        height: win.height - y

        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
            preventStealing: true
            cursorShape: win.dragging ? Qt.ClosedHandCursor : win.hoverIndex >= 0 ? Qt.PointingHandCursor : Qt.ArrowCursor
            property int pressIndex: -1
            property real pressX: 0
            property real pressY: 0
            property bool moved: false
            function track(m) {
                win.mouseX = m.x + hit.x; win.mouseY = m.y + hit.y;
                win.cursorX = m.x + hit.x - win.restLeft;
            }
            onEntered: { track({ x: mouseX, y: mouseY }); win.smoothX = win.cursorX; }
            onPressed: m => {
                track(m);
                moved = false;
                pressIndex = m.button === Qt.LeftButton ? win.hoverIndex : -1;
                pressX = m.x; pressY = m.y;
            }
            onPositionChanged: m => {
                track(m);
                if (win.dragging) { if (!win.settling) win.updateDrop(); return; }
                if (pressIndex >= 0 && (m.buttons & Qt.LeftButton) && Math.hypot(m.x - pressX, m.y - pressY) > 8) {
                    moved = true;
                    win.startDrag(pressIndex);
                    pressIndex = -1;           // one drag per press, even after Escape cancels it
                }
            }
            onReleased: { pressIndex = -1; if (win.dragging && !win.settling) win.drop(); }
            onClicked: m => {
                if (moved) return;
                const i = win.hoverIndex;
                if (i < 0) return;
                const item = win.slots[i].info;
                win.hidePeek();
                const cx = win.lay.x[i] + win.iconSize * win.lay.f[i] / 2, topY = win.baseY - win.iconSize * win.lay.f[i];
                if (m.button === Qt.RightButton) { menu.openFor(item, cx, topY); return; }
                icons.itemAt(i).pulse();
                if (item.tool) {
                    if (DockService.tools[item.id].action) DockService.openTool(item.id);
                    else if (m.button !== Qt.MiddleButton) toolPanel.openFor(item.id, cx, topY);
                    return;
                }
                if (item.stack) {
                    if (m.button === Qt.MiddleButton) { if (!item.trash) FolderService.openFolder(item.path); }
                    else stackPanel.openFor(item, cx, topY);
                    return;
                }
                if (m.button === Qt.MiddleButton) DockService.launch(item);
                else DockService.activate(item);
            }
        }

        // files and URLs dragged from other apps: drop on an icon to open them with that app. Only icons whose app
        // can take them accept the drop. (Drags that start in XWayland apps never reach native Wayland surfaces.)
        DropArea {
            anchors.fill: parent
            function target() {
                const i = win.hoverIndex;
                return i >= 0 && DockService.canOpen(win.slots[i].info) ? i : -1;
            }
            // off any icon, dropped folders become stacks
            function spare() { return win.hoverIndex < 0; }
            // files dropped on the Trash are trashed
            function overTrash() { return win.hoverIndex >= 0 && !!win.slots[win.hoverIndex].info.trash; }
            onEntered: d => { win.dropHover = true; area.track(d); win.smoothX = win.cursorX; d.accepted = d.hasUrls; }
            onPositionChanged: d => { area.track(d); d.accepted = d.hasUrls && (target() >= 0 || spare() || overTrash()); }
            onExited: win.dropHover = false
            onDropped: d => {
                const i = target();
                win.dropHover = false;
                if (overTrash() && d.hasUrls) { DockService.trashUrls(d.urls); icons.itemAt(win.hoverIndex).pulse(); d.accept(Qt.CopyAction); return; }
                if (i < 0 && spare() && d.hasUrls) { DockService.addFolders(d.urls); d.accept(Qt.CopyAction); return; }
                if (i < 0 || !d.hasUrls || !DockService.openWith(win.slots[i].info, d.urls)) { d.accepted = false; return; }
                icons.itemAt(i).pulse();
                d.accept(Qt.CopyAction);
            }
        }
    }

    // ---- the dock itself; slides down off the edge while hidden ----
    Item {
        id: content
        width: win.width; height: win.height
        y: win.shift
        opacity: win.shift > win.margin + win.pillH ? 0 : 1

        Rectangle {
            id: pill
            x: win.lay.left
            width: win.lay.total + 2 * win.pad
            height: win.pillH
            y: win.height - win.margin - height
            radius: Math.round(win.iconSize * 0.34)
            // the bar's dark "cap" tone, so the dock reads as part of the same desktop
            color: Theme.barCapFill
            border.width: Theme.frost ? 0 : 1
            border.color: Theme.slash
            Behavior on color { ColorAnimation { duration: Theme.animNormal } }
        }
        Shadowed { target: pill; z: -1 }

        // pinned | running separator: the bar's "/" between sections
        Slash {
            visible: win.sepT > 0 && win.lay.sepX >= 0
            opacity: win.sepT
            height: Math.round(win.iconSize * 0.6)
            x: Math.round(win.lay.sepX + win.sepW * win.sepT / 2 - win.gap / 2 - width / 2)
            y: win.baseY - win.iconSize / 2 - height / 2
        }
        // separators before the stacks and the tools
        Repeater {
            model: win.cuts
            Slash {
                required property var modelData
                required property int index
                readonly property real x0: win.lay.cutX[index] ?? -1
                visible: modelData.t > 0 && x0 >= 0
                opacity: modelData.t
                height: Math.round(win.iconSize * 0.6)
                x: Math.round(x0 + win.sepW * modelData.t / 2 - win.gap / 2 - width / 2)
                y: win.baseY - win.iconSize / 2 - height / 2
            }
        }

        Repeater {
            id: icons
            model: ScriptModel { values: win.slotKeys }
            DockItem {
                required property int index
                visible: !info.gap
                readonly property var slot: win.slots[index] ?? null
                info: slot ? slot.info : ({ icon: "", windows: [] })
                appear: slot ? slot.t : 0
                bouncing: slot !== null && slot.target > 0
                    && (slot.info.urgent || (DockService.launching[slot.key] !== undefined && slot.info.windows.length === 0))
                base: win.iconSize
                dim: win.dropHover && !win.dropTarget(info)
                factor: win.lay.f[index] ?? 1
                // box is `base` wide and scales from its bottom centre; centre it in the slot the magnified icon occupies
                x: (win.lay.x[index] ?? 0) + (win.iconSize * factor - win.iconSize) / 2
                y: win.baseY - win.iconSize
            }
        }

        // ---- hover label above the icon ----
        Rectangle {
            id: tip
            readonly property int idx: menu.open || stackPanel.open || toolPanel.open || win.peekOpen || win.dragging ? -1 : win.hoverIndex
            property real cx: 0
            property real topY: 0
            onIdxChanged: place()
            Connections { target: win; function onLayChanged() { tip.place(); } }
            function place() {
                if (idx < 0) return;           // keep the last place while fading out
                cx = win.lay.x[idx] + win.iconSize * win.lay.f[idx] / 2;
                topY = win.baseY - win.iconSize * win.lay.f[idx];
            }
            opacity: idx >= 0 ? 1 : 0
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: Theme.animFast } }
            width: tipText.implicitWidth + 20; height: tipText.implicitHeight + 10
            radius: Theme.radiusSmall + 2
            color: Theme.barMidFill   // the bar's "mid" tone over the cap-toned pill
            x: Math.max(4, Math.min(win.width - width - 4, cx - width / 2))
            y: topY - height - 8
            Text {
                id: tipText
                anchors.centerIn: parent
                text: win.labelText
                color: Theme.text
                font.family: Theme.font; font.pixelSize: Theme.fontSize
            }
        }

        // the dragged icon: follows the pointer, then flies into its gap on release
        DockItem {
            readonly property int gi: win.slots.findIndex(s => s.key === win.gapKey)
            readonly property bool flying: win.settling && gi >= 0 && gi < win.lay.x.length
            visible: win.dragging
            opacity: win.unpinZone ? 0.6 : 1
            Behavior on opacity { NumberAnimation { duration: Theme.animFast } }
            info: win.dragInfo ?? ({ icon: "", windows: [] })
            base: win.iconSize
            factor: flying ? win.relF + (win.lay.f[gi] - win.relF) * win.settle : win.liftF
            readonly property real cx: flying ? win.relX + (win.lay.x[gi] + win.iconSize * win.lay.f[gi] / 2 - win.relX) * win.settle
                : win.mouseX - win.grabDX
            readonly property real by: flying ? win.relY + (win.baseY - win.relY) * win.settle
                : Math.max(win.iconSize * win.liftF + 4, win.mouseY - win.grabDY)   // stays inside the window
            x: cx - win.iconSize / 2
            y: by - win.iconSize
        }

        // unpinned: the icon swells and fades while a ring of puffs scatters
        Item {
            id: poof
            property real p: 1
            property real f: 1
            property var info: ({ icon: "", windows: [] })
            visible: p < 1
            function play(cx, by, f, it) {
                x = cx; y = by - win.iconSize * f / 2;
                poof.f = f; info = { icon: it.icon, windows: [] };
                poofAnim.restart();
            }
            NumberAnimation { id: poofAnim; target: poof; property: "p"; from: 0; to: 1; duration: 420; easing.type: Easing.OutCubic }
            DockItem {
                info: poof.info
                base: win.iconSize
                factor: poof.f * (1 + 0.3 * poof.p)
                opacity: Math.max(0, 1 - poof.p * 2.2)
                x: -win.iconSize / 2
                y: win.iconSize * poof.f / 2 - win.iconSize
            }
            Repeater {
                model: 8
                Rectangle {
                    required property int index
                    readonly property real a: index / 8 * 2 * Math.PI
                    readonly property real d: win.iconSize * poof.f * (0.2 + 0.5 * poof.p)
                    width: win.iconSize * 0.26 * (1 - poof.p) + 2; height: width; radius: width / 2
                    x: Math.cos(a) * d - width / 2
                    y: Math.sin(a) * d - width / 2
                    color: Theme.textMuted
                    opacity: 1 - poof.p
                }
            }
        }
    }

    DockContext { id: menu; dock: win }
    FolderStack { id: stackPanel; dock: win }
    ToolPanel { id: toolPanel; dock: win }
    // IPC / keybind requests (DockService.openTool) go to the dock of the focused screen
    Connections {
        target: DockService
        function onToolRequestChanged() {
            const id = DockService.toolRequest.id;
            if (!id || (Hyprland.focusedMonitor && Hyprland.focusedMonitor.name !== win.screenName)) return;
            const i = win.slots.findIndex(s => s.info.tool && s.info.id === id);
            win.hidePeek();
            toolPanel.openFor(id, i >= 0 ? win.lay.x[i] + win.iconSize * win.lay.f[i] / 2 : win.width / 2,
                              i >= 0 ? win.baseY - win.iconSize * win.lay.f[i] : win.baseY - win.iconSize);
        }
    }
}
