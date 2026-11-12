#!/usr/bin/env python3
"""Print the most recently used files as a JSON list of {path, name}.

Reads the freedesktop recent-files list (~/.local/share/recently-used.xbel), newest first,
skipping files that no longer exist. Usage: recent-files.py [limit]
"""
import json, os, sys, urllib.parse
import xml.etree.ElementTree as ET

limit = int(sys.argv[1]) if len(sys.argv) > 1 else 8
xbel = os.path.join(os.environ.get("XDG_DATA_HOME", os.path.expanduser("~/.local/share")), "recently-used.xbel")
items = []
try:
    for b in ET.parse(xbel).getroot().iter("bookmark"):
        href = b.get("href", "")
        if not href.startswith("file://"):
            continue
        path = urllib.parse.unquote(href[7:])
        if os.path.isfile(path):
            items.append((b.get("modified") or b.get("visited") or "", path))
except (OSError, ET.ParseError):
    pass
items.sort(reverse=True)
print(json.dumps([{"path": p, "name": os.path.basename(p)} for _, p in items[:limit]]))
