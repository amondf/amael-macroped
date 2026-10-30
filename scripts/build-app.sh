#!/bin/bash
# Builds "Amael Macroped.app" (Apple Silicon by default) into ./dist.
#   scripts/build-app.sh              -> arm64
#   scripts/build-app.sh --universal  -> arm64 + x86_64
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

VERSION="${VERSION:-1.0.0}"
APP_NAME="Amael Macroped"
BUNDLE_ID="io.github.amondf.AmaelMacroped"
DIST="$ROOT/dist"
APP="$DIST/$APP_NAME.app"

ARCH_FLAGS=(--arch arm64)
if [[ "${1:-}" == "--universal" ]]; then
    ARCH_FLAGS=(--arch arm64 --arch x86_64)
fi

echo "==> Compilando (${ARCH_FLAGS[*]})"
swift build -c release "${ARCH_FLAGS[@]}" --product AmaelMacroped
swift build -c release "${ARCH_FLAGS[@]}" --product macroped
BIN_DIR="$(swift build -c release "${ARCH_FLAGS[@]}" --show-bin-path)"

echo "==> Montando $APP"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/AmaelMacroped" "$APP/Contents/MacOS/AmaelMacroped"
cp "$BIN_DIR/macroped" "$APP/Contents/MacOS/macroped"

echo "==> Gerando ícone"
TMP="$(mktemp -d)"
swift scripts/make-icon.swift "$TMP/icon.png"
ICONSET="$TMP/AppIcon.iconset"
mkdir -p "$ICONSET"
for s in 16 32 128 256 512; do
    sips -z $s $s "$TMP/icon.png" --out "$ICONSET/icon_${s}x${s}.png" >/dev/null
    sips -z $((s * 2)) $((s * 2)) "$TMP/icon.png" --out "$ICONSET/icon_${s}x${s}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"
rm -rf "$TMP"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>$APP_NAME</string>
    <key>CFBundleDisplayName</key><string>$APP_NAME</string>
    <key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
    <key>CFBundleExecutable</key><string>AmaelMacroped</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>$VERSION</string>
    <key>CFBundleVersion</key><string>$VERSION</string>
    <key>CFBundleDevelopmentRegion</key><string>pt-BR</string>
    <key>LSMinimumSystemVersion</key><string>13.0</string>
    <key>LSApplicationCategoryType</key><string>public.app-category.utilities</string>
    <key>NSHighResolutionCapable</key><true/>
    <key>NSHumanReadableCopyright</key><string>MIT License</string>
</dict>
</plist>
PLIST

echo "==> Assinando (ad-hoc)"
codesign --force --deep --options runtime --sign - "$APP"

echo "==> Arquiteturas:"
lipo -info "$APP/Contents/MacOS/AmaelMacroped"

(cd "$DIST" && rm -f "AmaelMacroped-$VERSION.zip" && ditto -c -k --keepParent "$APP_NAME.app" "AmaelMacroped-$VERSION.zip")
echo "==> Pronto: $APP"
echo "    Pacote: $DIST/AmaelMacroped-$VERSION.zip"
