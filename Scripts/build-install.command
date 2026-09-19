#!/bin/zsh
set -u

ROOT="$HOME/Developer/KRALI-Agent"
PROJECT="$ROOT/App/KRALIAgentNative.xcodeproj"
SCHEME="KRALIAgentNative"
BUILD_DIR="$ROOT/.build"
PRODUCT="$BUILD_DIR/Build/Products/Debug/KRALIAgentNative.app"

TARGET="/Applications/KRALI Agent.app"
STAMP="$(date +%Y-%m-%d_%H-%M-%S)"
BACKUP="$ROOT/Backups/KRALI-Agent_$STAMP.app"
PROCESS_NAME="KRALIAgentNative"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " KRALİ BUILD & INSTALL"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if [ ! -d "$PROJECT" ]; then
    echo "❌ Xcode projesi bulunamadı:"
    echo "$PROJECT"
    exit 1
fi

echo "1/6  KRALİ marka ikonları hazırlanıyor..."

ICON_SCRIPT="$ROOT/Scripts/generate-app-icon.swift"
ICON_DIR="$ROOT/App/KRALIAgentNative/Assets.xcassets/AppIcon.appiconset"
MASTER_ICON="$ICON_DIR/krali-master-1024.png"

mkdir -p "$ICON_DIR"

if ! xcrun swift "$ICON_SCRIPT" "$MASTER_ICON"; then
    echo "❌ KRALİ ikonu üretilemedi."
    exit 1
fi

make_icon() {
    local size="$1"
    local name="$2"

    cp "$MASTER_ICON" "$ICON_DIR/$name"

    if [ "$size" -ne 1024 ]; then
        sips -z "$size" "$size" "$ICON_DIR/$name" >/dev/null
    fi
}

make_icon 16   "icon_16x16.png"
make_icon 32   "icon_16x16@2x.png"
make_icon 32   "icon_32x32.png"
make_icon 64   "icon_32x32@2x.png"
make_icon 128  "icon_128x128.png"
make_icon 256  "icon_128x128@2x.png"
make_icon 256  "icon_256x256.png"
make_icon 512  "icon_256x256@2x.png"
make_icon 512  "icon_512x512.png"
make_icon 1024 "icon_512x512@2x.png"

echo "2/6  Yeni sürüm derleniyor..."
rm -rf "$BUILD_DIR"

if ! xcodebuild \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration Debug \
    -derivedDataPath "$BUILD_DIR" \
    -allowProvisioningUpdates \
    build
then
    echo ""
    echo "❌ Otomatik build başarısız."
    exit 2
fi

if [ ! -d "$PRODUCT" ]; then
    echo "❌ Derleme bitti ancak uygulama bulunamadı."
    exit 1
fi

echo "3/6  Mevcut sürüm yedekleniyor..."
if [ -d "$TARGET" ]; then
    ditto "$TARGET" "$BACKUP"
    echo "✓ Yedek: $BACKUP"
fi

echo "4/6  Çalışan KRALİ kapatılıyor..."
osascript -e 'tell application id "com.aliihsancanuysal.kraliagent" to quit' 2>/dev/null || true

APP_EXEC="$TARGET/Contents/MacOS/$PROCESS_NAME"

for i in 1 2 3 4 5; do
    if ! pgrep -f "$APP_EXEC" >/dev/null 2>&1; then
        break
    fi
    sleep 1
done

if pgrep -f "$APP_EXEC" >/dev/null 2>&1; then
    echo "• Uygulama kapanmadı; güvenli TERM sinyali gönderiliyor..."
    pkill -TERM -f "$APP_EXEC" 2>/dev/null || true
    sleep 1
fi

echo "5/6  Yeni KRALİ kuruluyor..."
if [ -w "/Applications" ]; then
    rm -rf "$TARGET"
    ditto "$PRODUCT" "$TARGET"
else
    sudo rm -rf "$TARGET"
    sudo ditto "$PRODUCT" "$TARGET"
fi

xattr -dr com.apple.quarantine "$TARGET" 2>/dev/null || true

echo ""
echo "İmza kontrolü:"
codesign --verify --deep --strict "$TARGET"
codesign -dv --verbose=2 "$TARGET" 2>&1 | grep -E "Identifier|TeamIdentifier|Authority" || true

echo "6/6  KRALİ yeniden açılıyor..."
/usr/bin/open -n "$TARGET"
sleep 3

APP_EXEC="$TARGET/Contents/MacOS/$PROCESS_NAME"

if pgrep -f "$APP_EXEC" >/dev/null 2>&1; then
    echo ""
    echo "✅ KRALİ güncellendi ve yeniden açıldı."
    echo "📍 $TARGET"
else
    echo ""
    echo "⚠️ Güncelleme kuruldu ancak uygulama otomatik açılamadı."
    echo "Finder > Applications > KRALİ üzerinden açabilirsin."
fi
