#!/usr/bin/env bash
# Regenerate the iOS icon assets from the authored meow artwork.
#
# Sources:      docs/appicon.png — 1024x1024 opaque home-screen icon.
#               docs/appmark.png — 1024x1024 transparent in-app mascot.
# Destinations: App/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png
#               App/Resources/Assets.xcassets/AppMark.imageset/AppMark.png
#
# Then derives the Settings → App Icon preview thumbnails: every
# <Name>.appiconset/<Name>.png in the catalogue gets a downscaled
# <Name>Preview.imageset/<Name>Preview.png. AppIconPickerView renders those
# because UIImage(named:) cannot load the primary icon from its .appiconset.
# Run this after adding a new alternate icon; the imageset dir must exist.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ICON_SRC="${APP_ICON_SOURCE:-"$ROOT/docs/appicon.png"}"
MARK_SRC="${APP_MARK_SOURCE:-"$ROOT/docs/appmark.png"}"
ASSETS="$ROOT/App/Resources/Assets.xcassets"
ICON_DST="$ASSETS/AppIcon.appiconset/AppIcon.png"
MARK_DST="$ASSETS/AppMark.imageset/AppMark.png"
# 256 px covers the 72 pt picker row at @3x with headroom, ~100 KB per icon.
PREVIEW_PX="${APP_ICON_PREVIEW_PX:-256}"

render_icons() {
    command -v python3 >/dev/null || { echo "error: python3 not found" >&2; exit 1; }
    mkdir -p "$(dirname "$ICON_DST")" "$(dirname "$MARK_DST")"

    python3 - "$ICON_SRC" "$MARK_SRC" "$ICON_DST" "$MARK_DST" <<'PY'
import sys
from pathlib import Path
from PIL import Image

icon_source, mark_source, icon_destination, mark_destination = map(Path, sys.argv[1:])

with Image.open(icon_source) as image:
    if image.size != (1024, 1024):
        raise SystemExit(f"error: source icon must be 1024x1024, got {image.size}")
    image.convert("RGB").save(icon_destination, format="PNG", optimize=True)

with Image.open(mark_source) as image:
    if image.size != (1024, 1024):
        raise SystemExit(f"error: source mark must be 1024x1024, got {image.size}")
    if "A" not in image.getbands():
        raise SystemExit("error: source mark must have an alpha channel")
    image.convert("RGBA").save(mark_destination, format="PNG", optimize=True)

print(f"Wrote 1024x1024 opaque PNG to {icon_destination}")
print(f"Wrote 1024x1024 transparent mascot PNG to {mark_destination}")
PY
}

render_previews() {
    python3 - "$ASSETS" "$PREVIEW_PX" <<'PY'
import sys
from pathlib import Path
from PIL import Image

assets, size = Path(sys.argv[1]), int(sys.argv[2])

for icon_set in sorted(assets.glob("*.appiconset")):
    name = icon_set.stem
    source = icon_set / f"{name}.png"
    if not source.exists():
        raise SystemExit(f"error: {icon_set.name} has no {name}.png")
    destination = assets / f"{name}Preview.imageset" / f"{name}Preview.png"
    if not destination.parent.is_dir():
        raise SystemExit(
            f"error: {destination.parent.name} not found — create it with a "
            f"Contents.json listing {destination.name} before rerunning"
        )
    with Image.open(source) as image:
        image.convert("RGB").resize((size, size), Image.LANCZOS).save(
            destination, format="PNG", optimize=True
        )
    print(f"Wrote {size}x{size} preview to {destination}")
PY
}

main() {
    [[ -f "$ICON_SRC" ]] || { echo "error: source icon not found at $ICON_SRC" >&2; exit 1; }
    [[ -f "$MARK_SRC" ]] || { echo "error: source mark not found at $MARK_SRC" >&2; exit 1; }
    render_icons
    render_previews
}

main "$@"
