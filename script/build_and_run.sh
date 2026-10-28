#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODE="${1:-run}"
case "$MODE" in run|--build-only|--verify|--logs|--telemetry|--debug) ;; *) echo 'Usage: build_and_run.sh [run|--build-only|--verify|--logs|--telemetry|--debug]';exit 2;; esac
BUILD="$ROOT/../RESaveEditorBuild"
APP="$BUILD/Resident Evil Save Editor.app"
mkdir -p "$BUILD"
KEYS="$ROOT/Resources/VerifiedSaveKeys.json"
[[ -f "$KEYS" ]] || { echo "Bestätigte Save-Schlüssel fehlen in Resources." >&2; exit 1; }
STAGE="$(mktemp -d "$BUILD/.stage.XXXXXX")"
cleanup() {
    if [[ -d "$STAGE/previous.app" && ! -d "$APP" ]];then mv "$STAGE/previous.app" "$APP";fi
    rm -rf "$STAGE"
}
trap cleanup EXIT
CANDIDATE="$STAGE/Resident Evil Save Editor.app"
mkdir -p "$CANDIDATE/Contents/MacOS" "$CANDIDATE/Contents/Resources"
SOURCES=();while IFS= read -r file;do SOURCES+=("$file");done < <(find "$ROOT/Sources" -type f -name '*.swift' | sort)
xcrun swiftc -swift-version 5 -O -target arm64-apple-macos14.0 -module-cache-path "$BUILD/ModuleCache" "${SOURCES[@]}" -o "$CANDIDATE/Contents/MacOS/RESaveEditor"
CORE=("$ROOT/Sources/Services/SaveCrypto.swift" "$ROOT/Sources/Services/SaveParser.swift" "$ROOT/Sources/Services/SaveRebuilder.swift" "$ROOT/Sources/Services/DocumentListEditor.swift" "$ROOT/Sources/Services/RE7EasterEggCatalog.swift" "$ROOT/Sources/Services/LocalSavePolicy.swift" "$ROOT/Sources/Models/SaveModels.swift" "$ROOT/Sources/Services/SaveDiscovery.swift" "$ROOT/Sources/Services/LocalSaveWriter.swift" "$ROOT/Sources/Services/SaveKeys.swift" "$ROOT/Sources/Services/RE2Character.swift" "$ROOT/Sources/Services/SaveSchemas.swift" "$ROOT/Sources/Services/SaveInventory.swift" "$ROOT/Sources/Services/ItemNameCatalog.swift" "$ROOT/Sources/Services/DocumentFlagCatalog.swift" "$ROOT/Sources/Services/StoredDocumentCatalog.swift" "$ROOT/Sources/Models/EditableField.swift")
xcrun swiftc -D SAVE_EDITOR_TESTS -swift-version 5 -O -target arm64-apple-macos14.0 -module-cache-path "$BUILD/ModuleCache" "${CORE[@]}" "$ROOT/Tests/SaveEditorTests.swift" -o "$STAGE/SaveEditorTests"
RESAVE_TEST_KEY_FILE="$KEYS" RESAVE_ITEM_NAMES="$ROOT/Resources/ItemNames.json" RESAVE_RE2_FILE_NAMES="$ROOT/Resources/RE2FileNames.json" RESAVE_RE3_FILE_NAMES="$ROOT/Resources/RE3FileNames.json" RESAVE_RE4_DOCUMENT_NAMES="$ROOT/Resources/RE4DocumentNames.json" RESAVE_RE7_DOCUMENT_NAMES="$ROOT/Resources/RE7DocumentNames.json" RESAVE_RE8_DOCUMENT_NAMES="$ROOT/Resources/RE8DocumentNames.json" "$STAGE/SaveEditorTests"
cp "$ROOT/ThirdParty/RE4MacFormat-LICENSE" "$CANDIDATE/Contents/Resources/ThirdParty-LICENSE"
cp "$ROOT/Resources/ItemNames.json" "$CANDIDATE/Contents/Resources/ItemNames.json"
cp "$ROOT/Resources/RE2FileNames.json" "$CANDIDATE/Contents/Resources/RE2FileNames.json"
cp "$ROOT/Resources/RE3FileNames.json" "$CANDIDATE/Contents/Resources/RE3FileNames.json"
cp "$ROOT/Resources/RE4DocumentNames.json" "$CANDIDATE/Contents/Resources/RE4DocumentNames.json"
cp "$ROOT/Resources/RE7DocumentNames.json" "$CANDIDATE/Contents/Resources/RE7DocumentNames.json"
cp "$ROOT/Resources/RE8DocumentNames.json" "$CANDIDATE/Contents/Resources/RE8DocumentNames.json"
cp "$KEYS" "$CANDIDATE/Contents/Resources/VerifiedSaveKeys.json"
if [[ -f "$APP/Contents/Resources/AppIcon.icns" && ! "$ROOT/Resources/AppIcon.png" -nt "$APP/Contents/Resources/AppIcon.icns" ]];then
    cp "$APP/Contents/Resources/AppIcon.icns" "$CANDIDATE/Contents/Resources/AppIcon.icns"
else
    ICONSET="$STAGE/AppIcon.iconset"
    mkdir -p "$ICONSET"
    for size in 16 32 128 256 512;do
        sips -z "$size" "$size" "$ROOT/Resources/AppIcon.png" --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
        double=$((size*2))
        sips -z "$double" "$double" "$ROOT/Resources/AppIcon.png" --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
    done
    iconutil -c icns "$ICONSET" -o "$CANDIDATE/Contents/Resources/AppIcon.icns"
fi
python3 -B - "$CANDIDATE" <<'PY'
from pathlib import Path
import plistlib,sys
p=Path(sys.argv[1])/'Contents/Info.plist'
p.write_bytes(plistlib.dumps({'CFBundleIdentifier':'local.residentevil.saveeditor','CFBundleExecutable':'RESaveEditor','CFBundleName':'Resident Evil Save Editor','CFBundlePackageType':'APPL','CFBundleShortVersionString':'0.8.4','CFBundleVersion':'28','CFBundleIconFile':'AppIcon','LSMinimumSystemVersion':'14.0','NSHighResolutionCapable':True,'NSPrincipalClass':'NSApplication'}))
PY
codesign --force --sign - --options runtime --timestamp=none "$CANDIDATE"
codesign --verify --deep --strict "$CANDIDATE"
if [[ "$MODE" != "--build-only" ]];then
    # Only this editor is stopped; no game or trainer process is touched.
    set +e;pgrep -x RESaveEditor >/dev/null 2>&1;probe_status=$?;set -e
    if (( probe_status > 1 ));then echo 'Process list unavailable; current app retained. Build with --build-only after closing the editor.' >&2;exit 1;fi
    if (( probe_status == 0 ));then
        pkill -TERM -x RESaveEditor >/dev/null 2>&1
        for attempt in {1..20};do
            set +e;pgrep -x RESaveEditor >/dev/null 2>&1;probe_status=$?;set -e
            if (( probe_status == 1 ));then break;fi
            if (( probe_status > 1 ));then echo 'Process list unavailable; current app retained.' >&2;exit 1;fi
            sleep 0.1
        done
        if (( probe_status == 0 ));then echo 'Save Editor is still running; current app retained.' >&2;exit 1;fi
    fi
fi
if [[ -d "$APP" ]];then mv "$APP" "$STAGE/previous.app";fi
mv "$CANDIDATE" "$APP"
rm -rf "$STAGE/previous.app"
printf 'Build successful: %s\n' "$APP"
case "$MODE" in
    --build-only) ;;
    run) /usr/bin/open -n "$APP" ;;
    --verify) /usr/bin/open -n "$APP";sleep 1;pgrep -x RESaveEditor >/dev/null;echo 'Editor process is running.' ;;
    --logs|--telemetry) /usr/bin/open -n "$APP";/usr/bin/log stream --info --style compact --predicate 'process == "RESaveEditor"' ;;
    --debug) /usr/bin/open -n "$APP";lldb -n RESaveEditor ;;
esac
