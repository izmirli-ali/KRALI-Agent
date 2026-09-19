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

echo "1/4  KRALİ kapatılıyor..."
osascript -e 'tell application "KRALİ Agent" to quit' 2>/dev/null || true
sleep 1

echo "2/4  Yeni sürüm derleniyor..."

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
    echo "⚠️ Terminal üzerinden signing henüz çalışmadı."
    echo "Projeyi Xcode'da açıyorum."
    echo ""
    echo "Xcode'da sadece ▶ Run yap."
    echo "Sonra bu scripti tekrar çalıştıracağız."
    open -a Xcode "$PROJECT"
    exit 2
fi

if [ ! -d "$PRODUCT" ]; then
    echo "❌ Derleme bitti ancak uygulama bulunamadı."
    exit 1
fi

echo "3/4  Mevcut sürüm yedekleniyor..."

if [ -d "$TARGET" ]; then
    ditto "$TARGET" "$BACKUP"
    echo "✓ Yedek: $BACKUP"
fi

echo "4/4  Yeni KRALİ kuruluyor..."

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
codesign -dv --verbose=2 "$TARGET" 2>&1 | \
grep -E "Identifier|TeamIdentifier|Authority" || true

echo ""
echo "✅ KRALİ Agent güncellendi."
echo "📍 $TARGET"
echo ""

open "$TARGET"
