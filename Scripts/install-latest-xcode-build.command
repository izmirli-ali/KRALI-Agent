#!/bin/zsh
set -e

TARGET="/Applications/KRALI Agent.app"

APP="$(find "$HOME/Library/Developer/Xcode/DerivedData" \
-type d \
-path '*/Build/Products/Debug/KRALIAgentNative.app' \
-print0 2>/dev/null | xargs -0 ls -td 2>/dev/null | head -1)"

if [ -z "$APP" ] || [ ! -d "$APP" ]; then
    echo "❌ Xcode tarafından derlenmiş KRALİ bulunamadı."
    exit 1
fi

echo ""
echo "Bulunan build:"
echo "$APP"
echo ""

echo "İmza doğrulanıyor..."
codesign --verify --deep --strict "$APP"

echo "KRALİ kapatılıyor..."
osascript -e 'tell application "KRALİ Agent" to quit' 2>/dev/null || true
sleep 1

echo "Applications klasörüne kuruluyor..."

rm -rf "$TARGET"
ditto "$APP" "$TARGET"

echo ""
echo "Kurulan uygulamanın imzası:"
codesign -dv --verbose=4 "$TARGET" 2>&1 | \
egrep 'Identifier=|TeamIdentifier=|Authority='

echo ""
echo "✅ Standalone KRALİ kuruldu."
echo "$TARGET"

open "$TARGET"
