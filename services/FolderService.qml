pragma Singleton
import QtQuick
import Quickshell

// Helpers for the dock's folder stacks: path expansion, file kinds and icons, opening things.
Singleton {
    readonly property var imageSuffixes: ["png", "jpg", "jpeg", "webp", "gif", "bmp", "svg"]
    readonly property var kinds: ({
        audio: ["mp3", "flac", "ogg", "opus", "wav", "m4a"],
        video: ["mp4", "mkv", "webm", "mov", "avi"],
        pdf: ["pdf"],
        archive: ["zip", "tar", "gz", "xz", "zst", "7z", "rar"]
    })
    readonly property var kindIcons: ({ audio: "audio-x-generic", video: "video-x-generic", pdf: "application-pdf", archive: "package-x-generic" })

    function expand(p) { return p.startsWith("~") ? Quickshell.env("HOME") + p.slice(1) : p; }
    function isImage(e) { return !!e && !e.dir && imageSuffixes.indexOf(e.suffix) >= 0; }
    function iconName(e) {
        if (e.dir) return "folder";
        for (const k in kinds) if (kinds[k].indexOf(e.suffix) >= 0) return kindIcons[k];
        return "text-x-generic";
    }
    function iconPath(name) { return Quickshell.iconPath(name, true) || Quickshell.iconPath("text-x-generic", true); }
    function sizeText(n) {
        if (n < 1024) return n + " B";
        const u = ["KB", "MB", "GB", "TB"];
        let i = -1;
        do { n /= 1024; ++i; } while (n >= 1024 && i < u.length - 1);
        return (n < 10 ? n.toFixed(1) : Math.round(n)) + " " + u[i];
    }
    function url(p) { return "file://" + p.split("/").map(encodeURIComponent).join("/"); }
    function open(path) { Quickshell.execDetached(["xdg-open", path]); }
    function openFolder(path) { open(expand(path)); }
}
