#!/usr/bin/env python3
"""Render every Cozytile dotfile template from one palette.

  render.py <theme> [--out DIR] [--palette FILE] [--wallpaper IMG]

<theme> is a key of config/palettes.json, or "wallpaper" (uses the matugen palette
cached by the shell in ~/.local/state/cozytile/wallpaper-palette.json).
Placeholders in templates/*.tpl:  {{key}}  {{key|nohash}}  {{key|rgb}}  {{key|hypr}}  {{key|rgba:AA}}
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
    val = extra.get(key) or pal.get(key)
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
             "home": str(Path.home())}
    out = Path(a.out)
    for tpl, rel in TARGETS.items():
        src = HERE / "templates" / tpl
        if not src.exists(): print(f"skip (no template) {tpl}", file=sys.stderr); continue
        text = re.sub(r"\{\{(.+?)\}\}", lambda m: sub(m, pal, extra), src.read_text())
        dst = out / rel; dst.parent.mkdir(parents=True, exist_ok=True)
        tmp = dst.with_name(dst.name + ".tmp"); tmp.write_text(text); tmp.replace(dst)   # atomic: apps never see half files
        print(f"wrote {dst}")

if __name__ == "__main__":
    main()
