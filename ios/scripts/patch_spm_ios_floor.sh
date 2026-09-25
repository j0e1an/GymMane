#!/usr/bin/env bash
# Bump SwiftPM plugin platforms below iOS 13.0 up to 13.0 so they can
# depend on FlutterFramework (requires 13). Safe to re-run.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MIN="13.0"

python3 - "$ROOT" "$MIN" <<'PY'
import pathlib, re, sys

root = pathlib.Path(sys.argv[1])
min_s = sys.argv[2]
min_v = tuple(int(x) for x in min_s.split("."))

def patch(path: pathlib.Path) -> bool:
    text = path.read_text()
    def repl(m):
        v = tuple(int(x) for x in m.group(1).split("."))
        return f'.iOS("{min_s if v < min_v else m.group(1)}")'
    new = re.sub(r'\.iOS\("(\d+(?:\.\d+)?)"\)', repl, text)
    if new != text:
        path.write_text(new)
        print(f"patched {path}")
        return True
    return False

changed = 0
# Ephemeral copies Flutter regenerates on each build
pkgs = root / "ios/Flutter/ephemeral/Packages/.packages"
if pkgs.is_dir():
    for p in pkgs.glob("*/Package.swift"):
        if patch(p):
            changed += 1

# Pub-cache sources (so the next regenerate may already be high enough)
pub = pathlib.Path.home() / ".pub-cache/hosted/pub.dev"
if pub.is_dir():
    for pattern in (
        "app_settings-*/ios/app_settings/Package.swift",
        "file_picker-*/ios/file_picker/Package.swift",
        "share_plus-*/ios/share_plus/Package.swift",
        "flutter_local_notifications-*/ios/flutter_local_notifications/Package.swift",
    ):
        for p in pub.glob(pattern):
            if patch(p):
                changed += 1

print(f"done ({changed} file(s) updated, floor iOS {min_s})")
PY
