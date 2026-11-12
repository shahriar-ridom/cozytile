#!/usr/bin/env python3
"""Render every Cozytile dotfile template from one palette.

  render.py <theme> [--out DIR] [--palette FILE] [--wallpaper IMG]

<theme> is a key of config/palettes.json, or "wallpaper" (uses the matugen palette
cached by the shell in ~/.local/state/cozytile/wallpaper-palette.json).
Placeholders in templates/*.tpl:  {{key}}  {{key|nohash}}  {{key|rgb}}  {{key|hypr}}  {{key|rgba:AA}}
Blocks (not nestable):  {{#if key}}...{{/if}}  {{#unless key}}...{{/unless}}   (key is non-empty / empty)
Lock screen options come from the "lockscreen" object in ~/.local/state/cozytile/settings.json.
"""
import argparse, json, os, re, sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent
STATE = Path(os.environ.get("XDG_STATE_HOME", Path.home() / ".local/state")) / "cozytile"
CONF = Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config")) / "cozytile" / "generated"

# template -> output path (relative to --out)
TARGETS = {
    "hypr-colors.lua.tpl": "hypr/cozytile_colors.lua",
    "hyprlock.conf.tpl": "hypr/hyprlock.conf",
    "kitty-colors.conf.tpl": "kitty/colors.conf",
    "starship.toml.tpl": "starship.toml",
    "cava.conf.tpl": "cava/config",
    "gtk-colors.css.tpl": "gtk/colors.css",
    "btop.theme.tpl": "btop/cozytile.theme",
    "fastfetch.jsonc.tpl": "fastfetch/config.jsonc",
    "qt6ct-colors.conf.tpl": "qt6ct/cozytile.conf",
    "sddm-theme.conf.tpl": "sddm/theme.conf",
    "kitty-font.conf.tpl": "kitty/font.conf",
    "gsettings.sh.tpl": "gtk/fonts.sh",
}
REQUIRED = ["dim","bg","bg2","bg3","bg4","bg5","fg","fg2","muted","green","aqua","blue","yellow","orange","red","purple","accent","workspaceActive"]

def load_palette(name, palette_file):
    if name == "wallpaper":
        f = STATE / "wallpaper-palette.json"
        if not f.exists():
            sys.exit("no wallpaper palette yet: apply a wallpaper with 'Theme from wallpaper' enabled first")
        pal = json.loads(f.read_text())
        pal.setdefault("aqua", pal.get("green"))
        def mix(a, b, t):   # step from a toward b, for the stepped prompt segments
            x, y = hexrgb(a), hexrgb(b)
            return "#%02x%02x%02x" % tuple(round(i + (j - i) * t) for i, j in zip(x, y))
        pal.setdefault("bg4", mix(pal["bg3"], pal["fg"], 0.07)); pal.setdefault("bg5", mix(pal["bg3"], pal["fg"], 0.14))
        pal["label"] = "Wallpaper"
        return pal
    data = json.loads(Path(palette_file).read_text())
    if name not in data:
        sys.exit(f"unknown theme '{name}' (have: {', '.join(data)})")
    return data[name]

def hexrgb(h):
    h = h.lstrip("#"); return tuple(int(h[i:i+2], 16) for i in (0, 2, 4))

def sub(m, pal, extra):
    key, _, flt = m.group(1).strip().partition("|")
    val = extra[key] if key in extra else pal.get(key)
    if val is None: sys.exit(f"template uses unknown key '{key}'")
    flt = flt.strip()
    if flt == "": return val
    if flt == "nohash": return val.lstrip("#")
    if flt == "rgb": return "{},{},{}".format(*hexrgb(val))
    if flt == "semi": return "{};{};{}".format(*hexrgb(val))
    if flt == "argb": return "#ff" + val.lstrip("#")
    if flt == "hypr": return "rgb(" + val.lstrip("#") + ")"
    if flt.startswith("rgba:"): return "rgba(" + val.lstrip("#") + flt[5:] + ")"
    sys.exit(f"unknown filter '{flt}'")

LOCK_DEFAULTS = {"wallpaper": "", "blur": 3, "dim": 70, "clock": "large", "font": "sans", "hour24": True, "seconds": False,
                 "showDate": True, "showStatus": True, "showUser": True, "showAvatar": True, "hint": "Enter password"}
LOCK_FONTS = {"sans": "SF Pro Display Bold", "rounded": "SF Pro Rounded Bold", "mono": "CaskaydiaCove Nerd Font Bold"}
UI_FONT, MONO_FONT = "SF Pro Text", "CaskaydiaCove Nerd Font Mono"

def font_extras():
    """System-wide typefaces chosen in Settings > Appearance ("" = the defaults above)."""
    try: cfg = json.loads((STATE / "settings.json").read_text())
    except Exception: cfg = {}
    clean = lambda v: re.sub(r"[\"'\\\n$`]", "", str(v or "")).strip()
    ui = clean(cfg.get("uiFont")) or UI_FONT
    mono = clean(cfg.get("monoFont")) or MONO_FONT
    return {"ui_font": ui, "mono_font": mono, "custom_ui_font": "1" if ui != UI_FONT else ""}
LOCK_SIZES = {"large": 150, "medium": 112, "small": 80}

def lock_extras(wallpaper):
    """Flatten the lockscreen settings into template keys; empty string = off (for {{#if}} blocks)."""
    try: cfg = json.loads((STATE / "settings.json").read_text()).get("lockscreen") or {}
    except Exception: cfg = {}
    c = {**LOCK_DEFAULTS, **cfg}
    fe = font_extras()
    wall = os.path.expanduser(str(c["wallpaper"] or ""))
    if not (wall and Path(wall).is_file()): wall = wallpaper or "screenshot"
    face = next((str(p) for p in (Path.home() / ".face", Path.home() / ".face.icon") if p.is_file()), "")
    size = LOCK_SIZES.get(c["clock"], 150)
    bat = bool(list(Path("/sys/class/power_supply").glob("BAT*")))
    on = lambda v: "1" if v else ""
    hint = re.sub(r'[<>&\n]', "", str(c["hint"] or "")).strip()
    return {
        "lock_wallpaper": wall,
        "lock_blur": str(max(0, min(5, int(c["blur"])))),
        "lock_dim": "%.2f" % (max(10, min(100, int(c["dim"]))) / 100),
        "lock_clock_size": str(size), "lock_date_size": str(round(size * 0.17 + 4)),
        "lock_font": (fe["ui_font"] + " Bold") if (c["font"] == "sans" and fe["custom_ui_font"]) else LOCK_FONTS.get(c["font"], LOCK_FONTS["sans"]),
        "lock_time_fmt": ("%H:%M" if c["hour24"] else "%-I:%M") + (":%S" if c["seconds"] else ""),
        "lock_date": on(c["showDate"]), "lock_status": on(c["showStatus"]),
        "lock_user": on(c["showUser"]), "lock_avatar": face if c["showAvatar"] else "",
        "lock_clock_y": "-10%" if c["showDate"] else "-7.5%",
        "lock_battery": on(bat and c["showStatus"]), "lock_layout_x": "-60" if bat else "-18",
        "lock_hint": hint or "Enter password",
    }

def blocks(text, extra):
    def one(m):
        keep = bool(extra.get(m.group(2))) == (m.group(1) == "if")
        return m.group(3) if keep else ""
    return re.sub(r"\{\{#(if|unless) (\w+)\}\}(.*?)\{\{/\1\}\}\n?", one, text, flags=re.S)

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("theme"); ap.add_argument("--out", default=str(CONF))
    ap.add_argument("--palette", default=str(next((p for p in (HERE / "config/palettes.json", ROOT / "config/palettes.json") if p.exists()), ROOT / "config/palettes.json")))
    ap.add_argument("--wallpaper", default="")
    a = ap.parse_args()
    pal = load_palette(a.theme, a.palette)
    miss = [k for k in REQUIRED if k not in pal]
    if miss: sys.exit("palette missing keys: " + ", ".join(miss))
    extra = {"theme": a.theme, "label": pal.get("label", a.theme), "wallpaper": a.wallpaper or "screenshot",
             "home": str(Path.home()), **font_extras(), **lock_extras(a.wallpaper)}
    out = Path(a.out)
    for tpl, rel in TARGETS.items():
        src = HERE / "templates" / tpl
        if not src.exists(): print(f"skip (no template) {tpl}", file=sys.stderr); continue
        text = re.sub(r"\{\{(.+?)\}\}", lambda m: sub(m, pal, extra), blocks(src.read_text(), extra))
        dst = out / rel; dst.parent.mkdir(parents=True, exist_ok=True)
        tmp = dst.with_name(dst.name + ".tmp"); tmp.write_text(text); tmp.replace(dst)   # atomic: apps never see half files
        print(f"wrote {dst}")

if __name__ == "__main__":
    main()
