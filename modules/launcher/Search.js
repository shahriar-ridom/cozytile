.pragma library

// Pure helpers for the launcher: scoring, safe maths, conversion parsing, URLs, bangs.

// Prefix > word-prefix > substring > fuzzy-subsequence. 0 = no match.
function score(text, q) {
    const t = text.toLowerCase();
    if (t === q) return 120;
    if (t.startsWith(q)) return 100 - Math.min(t.length, 40) * 0.1;
    if (t.includes(" " + q) || t.includes("-" + q)) return 80;
    if (t.includes(q)) return 60;
    if (q.length >= 3 && t[0] === q[0]) {  // subsequence from the first letter: "ffx" -> firefox
        let i = 0;
        for (let c = 0; c < t.length && i < q.length; c++) if (t[c] === q[i]) i++;
        if (i === q.length) return 35;
    }
    return 0;
}

// ---- safe arithmetic (no eval) ------------------------------------------
const FUNCS = {
    sqrt: Math.sqrt, cbrt: Math.cbrt, abs: Math.abs, round: Math.round, floor: Math.floor, ceil: Math.ceil,
    sin: Math.sin, cos: Math.cos, tan: Math.tan, asin: Math.asin, acos: Math.acos, atan: Math.atan,
    ln: Math.log, log: Math.log10, log2: Math.log2, exp: Math.exp
};
const CONSTS = { pi: Math.PI, e: Math.E };

function safeEval(src) {
    const s = src.replace(/×/g, "*").replace(/÷/g, "/").replace(/\s+/g, "").toLowerCase();
    if (!/\d/.test(s)) return null;
    let i = 0;
    function peek() { return s[i]; }
    function num() {
        const m = /^(?:\d+\.?\d*|\.\d+)(?:e[+-]?\d+)?/.exec(s.slice(i));
        if (!m) return null;
        i += m[0].length;
        return parseFloat(m[0]);
    }
    function atom() {
        let sign = 1;
        while (peek() === "+" || peek() === "-") { if (peek() === "-") sign = -sign; i++; }
        let v;
        if (peek() === "(") {
            i++; v = expr();
            if (v === null || peek() !== ")") return null;
            i++;
        } else if (/[a-z]/.test(peek() || "")) {
            const m = /^[a-z][a-z0-9]*/.exec(s.slice(i));
            const name = m[0]; i += name.length;
            if (name in CONSTS) v = CONSTS[name];
            else if (name in FUNCS && peek() === "(") {
                i++; const a = expr();
                if (a === null || peek() !== ")") return null;
                i++; v = FUNCS[name](a);
            } else return null;
        } else {
            v = num();
        }
        if (v === null || v === undefined) return null;
        if (peek() === "!") { i++; if (v < 0 || v > 170 || v !== Math.floor(v)) return null; let f = 1; for (let k = 2; k <= v; k++) f *= k; v = f; }
        return sign * v;
    }
    function power() {
        const b = atom();
        if (b === null) return null;
        if (peek() === "^") { i++; const e = power(); return e === null ? null : Math.pow(b, e); }
        return b;
    }
    function term() {
        let v = power();
        while (v !== null && (peek() === "*" || peek() === "/" || peek() === "%")) {
            const op = s[i++];
            const r = power();
            if (r === null) return null;
            v = op === "*" ? v * r : op === "/" ? v / r : v % r;
        }
        return v;
    }
    function expr() {
        let v = term();
        while (v !== null && (peek() === "+" || peek() === "-")) {
            const op = s[i++];
            const r = term();
            if (r === null) return null;
            v = op === "+" ? v + r : v - r;
        }
        return v;
    }
    const v = expr();
    if (v === null || i !== s.length || !isFinite(v)) return null;
    return v;
}

function fmtNumber(v) {
    if (Math.abs(v) >= 1e15 || (v !== 0 && Math.abs(v) < 1e-6)) return v.toExponential(6).replace(/\.?0+e/, "e");
    const s = String(Number(v.toPrecision(12)));
    if (s.indexOf("e") >= 0) return s;
    const parts = s.split(".");
    parts[0] = parts[0].replace(/\B(?=(\d{3})+(?!\d))/g, ",");
    return parts.join(".");
}

// Query that deserves a calculator / converter lookup.
function mathy(q) {
    return /^[=\s]*[-+(.\d]/.test(q) && /\d/.test(q) || /^=/.test(q);
}

// "5 km to miles" -> { left: "5 km", target: "miles" } else null
function parseConversion(q) {
    const m = /^(.*\d.*?)\s+(?:to|in|as|into)\s+([^\s]+(?:\s+[^\s]+)?)$/i.exec(q.replace(/^=/, "").trim());
    return m ? { left: m[1], target: m[2] } : null;
}

function affine(q) { return /°|\bfahrenheit\b|\bcelsius\b|\bkelvin\b|\d\s*[fck]\b|\bto\s+[fck]$/i.test(q); }

// ---- web ------------------------------------------------------------------
const BANGS = {
    g:  { name: "Google",     url: "https://www.google.com/search?q=" },
    yt: { name: "YouTube",    url: "https://www.youtube.com/results?search_query=" },
    gh: { name: "GitHub",     url: "https://github.com/search?q=" },
    w:  { name: "Wikipedia",  url: "https://en.wikipedia.org/w/index.php?search=" },
    so: { name: "Stack Overflow", url: "https://stackoverflow.com/search?q=" },
    aur:{ name: "AUR",        url: "https://aur.archlinux.org/packages?K=" },
    aw: { name: "Arch Wiki",  url: "https://wiki.archlinux.org/index.php?search=" },
    mdn:{ name: "MDN",        url: "https://developer.mozilla.org/en-US/search?q=" }
};
const DEFAULT_ENGINE = { name: "DuckDuckGo", url: "https://duckduckgo.com/?q=" };

function bang(q) {
    const m = /^([a-z]+)\s+(.+)$/i.exec(q);
    if (m && BANGS[m[1].toLowerCase()]) return { engine: BANGS[m[1].toLowerCase()], term: m[2].trim() };
    return null;
}
function searchUrl(engine, term) { return engine.url + encodeURIComponent(term); }
function defaultEngine() { return DEFAULT_ENGINE; }

function asUrl(q) {
    const t = q.trim();
    if (/\s/.test(t)) return "";
    if (/^https?:\/\/\S+$/i.test(t)) return t;
    if (/^(?:[a-z0-9-]+\.)+(?:com|org|net|io|dev|app|co|me|ai|gg|tv|xyz|info|edu|gov|so|sh|cc|fm|ly|us|uk|de|fr|in|bd)(?:[\/?#]\S*)?$/i.test(t)) return "https://" + t;
    return "";
}

// ---- files ----------------------------------------------------------------
function basename(p) { const i = p.lastIndexOf("/"); return i < 0 ? p : p.slice(i + 1); }
function dirname(p) { const i = p.lastIndexOf("/"); return i <= 0 ? "/" : p.slice(0, i); }
function shortPath(p, home) { return home && p.startsWith(home) ? "~" + p.slice(home.length) : p; }
function fileIconName(path, isDir) {
    if (isDir) return "folder";
    const ext = (path.split(".").pop() || "").toLowerCase();
    if (/^(png|jpe?g|gif|webp|svg|bmp|avif|heic)$/.test(ext)) return "image-x-generic";
    if (/^(mp4|mkv|webm|mov|avi)$/.test(ext)) return "video-x-generic";
    if (/^(mp3|flac|ogg|wav|opus|m4a)$/.test(ext)) return "audio-x-generic";
    if (ext === "pdf") return "application-pdf";
    if (/^(zip|tar|gz|xz|7z|rar|zst)$/.test(ext)) return "package-x-generic";
    if (/^(sh|py|js|ts|qml|lua|rs|go|c|cpp|h|java|json|toml|yaml|yml|css|html)$/.test(ext)) return "text-x-script";
    return "text-x-generic";
}
function regexFromQuery(q) {
    return q.trim().split(/\s+/).map(w => w.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")).join(".*");
}

// "72 f to c" -> "72 fahrenheit to celsius" (qalc reads bare f/c/k as other units)
function normTemp(q) {
    const name = { f: "fahrenheit", c: "celsius", k: "kelvin" };
    return q.replace(/(\d)\s*([fck])\b/gi, (m, d, u) => d + " " + name[u.toLowerCase()])
            .replace(/\bto\s+([fck])$/i, (m, u) => "to " + name[u.toLowerCase()]);
}
