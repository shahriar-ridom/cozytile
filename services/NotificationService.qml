pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import "../config"

// freedesktop notification daemon (org.freedesktop.Notifications) + in-memory history.
Singleton {
    id: root

    // newest first; each: { key, n (live Notification or null), appName, appIcon, image, summary, body, time, urgency,
    //   progress, actions, canReply, replyPlaceholder, markRead (action id or ""), popup }
    property var history: []
    readonly property var popups: history.filter(e => e.popup)
    readonly property int count: history.length
    readonly property bool dnd: Settings.dnd
    property int maxHistory: 60
    signal arrived(var entry)
    signal updated(var entry)     // same notification replaced/changed (e.g. download progress)

    function _set(list) { history = list; }

    // chat apps (Telegram, WhatsApp wrappers, ...) ship a "Mark as read" action; ids vary per app
    function _markReadId(n) {
        for (const a of n.actions)
            if (/mark[-_ ]?(as[-_ ]?)?read/i.test(a.identifier) || /mark.*read/i.test(a.text)) return a.identifier;
        return "";
    }

    // progress: freedesktop "value" hint (0..100), or -1 when the app reports none
    function _entry(n, popup) {
        const h = n.hints || {};
        const v = h.value !== undefined ? Number(h.value) : -1;
        return {
            key: n.id, n: n,
            appName: n.appName || "Notification",
            appIcon: n.appIcon || "",
            image: n.image || "",
            summary: n.summary || "",
            body: n.body || "",
            time: new Date(),
            urgency: n.urgency,
            progress: isNaN(v) ? -1 : Math.max(-1, Math.min(100, v)) / 100,
            actions: n.actions.filter(a => a.identifier !== "inline-reply").map(a => ({ identifier: a.identifier, text: a.text })),
            canReply: n.hasInlineReply,
            replyPlaceholder: n.inlineReplyPlaceholder || "",
            markRead: _markReadId(n),
            popup: popup
        };
    }

    function dismissPopup(key) {
        _set(history.map(e => e.key === key ? Object.assign({}, e, { popup: false }) : e));
    }
    function remove(key) {
        const e = history.find(x => x.key === key);
        if (e && e.n) e.n.dismiss();
        _set(history.filter(x => x.key !== key));
    }
    function clearAll() {
        for (const e of history) if (e.n) e.n.dismiss();
        _set([]);
    }
    function invoke(key, identifier) {
        const e = history.find(x => x.key === key);
        if (!e || !e.n) return;
        for (const a of e.n.actions) if (a.identifier === identifier) { a.invoke(); break; }
        dismissPopup(key);
    }
    // inline reply (freedesktop "inline-reply" capability); a replied conversation counts as read
    function canReply(key) { const e = history.find(x => x.key === key); return !!(e && e.n && e.canReply); }
    function reply(key, text) {
        const e = history.find(x => x.key === key);
        if (!e || !e.n || !e.canReply || text.trim() === "") return false;
        e.n.sendInlineReply(text);      // quickshell closes the notification itself after replying
        _set(history.filter(x => x.key !== key));
        return true;
    }
    // fire the app's own "mark as read" action when it has one, then drop the entry
    function _markRead(e) {
        if (!e.n) return;
        const act = e.markRead ? e.n.actions.find(a => a.identifier === e.markRead) : null;
        if (act) { act.invoke(); if (e.n && e.n.resident) e.n.dismiss(); }
        else e.n.dismiss();
    }
    function markRead(key) {
        const e = history.find(x => x.key === key);
        if (!e) return;
        _markRead(e);
        _set(history.filter(x => x.key !== key));
    }
    // appName empty = every notification
    function markAllRead(appName) {
        const hit = e => !appName || e.appName === appName;
        for (const e of history) if (hit(e)) _markRead(e);
        _set(history.filter(e => !hit(e)));
    }
    function countFor(appName) { return history.filter(e => e.appName === appName).length; }
    function toggleDnd() { Settings.dnd = !Settings.dnd; }

    NotificationServer {
        id: server
        keepOnReload: true
        bodySupported: true
        bodyMarkupSupported: false
        actionsSupported: true
        imageSupported: true
        persistenceSupported: true
        inlineReplySupported: true      // without this, Telegram & co. never send a reply action

        onNotification: n => {
            n.tracked = true;
            const entry = root._entry(n, !Settings.dnd || n.urgency === NotificationUrgency.Critical);
            let list = root.history.filter(e => e.key !== entry.key);
            list.unshift(entry);
            if (list.length > root.maxHistory) list = list.slice(0, root.maxHistory);
            root._set(list);
            root.arrived(entry);
            // apps replace a notification in place to report progress: mirror those changes
            const refresh = () => {
                const old = root.history.find(e => e.key === n.id);
                if (!old) return;
                const fresh = root._entry(n, old.popup);
                fresh.time = old.time;
                root._set(root.history.map(e => e.key === fresh.key ? fresh : e));
                root.updated(fresh);
            };
            n.summaryChanged.connect(refresh);
            n.bodyChanged.connect(refresh);
            n.hintsChanged.connect(refresh);
            n.closed.connect(() => {
                root._set(root.history.map(e => e.key === entry.key ? Object.assign({}, e, { n: null, popup: false }) : e));
            });
        }
    }
}
