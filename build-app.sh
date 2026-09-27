#!/bin/zsh
set -euo pipefail

ROOT="${0:A:h}"
cd "$ROOT"

if [[ -n "${DEVELOPER_DIR:-}" ]]; then
  DEVELOPER_DIR="$DEVELOPER_DIR" swift build -c release --arch arm64
  BIN_DIR="$(DEVELOPER_DIR="$DEVELOPER_DIR" swift build -c release --arch arm64 --show-bin-path)"
else
  swift build -c release --arch arm64
  BIN_DIR="$(swift build -c release --arch arm64 --show-bin-path)"
fi

APP="$ROOT/Build/CalendarPeek.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/CalendarPeek" "$APP/Contents/MacOS/CalendarPeek"
cp Info.plist "$APP/Contents/Info.plist"
cp -R "$BIN_DIR/CalendarPeek_CalendarPeek.bundle" "$APP/Contents/Resources/"
BUNDLE="$APP/Contents/Resources/CalendarPeek_CalendarPeek.bundle"
for locale in en ko; do
  mkdir -p "$APP/Contents/Resources/$locale.lproj"
  cp "Sources/CalendarPeek/Resources/$locale.lproj/InfoPlist.strings" "$APP/Contents/Resources/$locale.lproj/"
  mkdir -p "$BUNDLE/$locale.lproj"
  cp "Sources/CalendarPeek/Resources/$locale.lproj/Localizable.strings" "$BUNDLE/$locale.lproj/"
done

codesign --force --deep --sign - "$APP"
echo "Built $APP"
