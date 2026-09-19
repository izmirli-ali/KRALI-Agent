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

echo "1/5  Yeni sürüm derleniyor..."
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

echo "2/5  Mevcut sürüm yedekleniyor..."
if [ -d "$TARGET" ]; then
    ditto "$TARGET" "$BACKUP"
    echo "✓ Yedek: $BACKUP"
fi

echo "3/5  Çalışan KRALİ kapatılıyor..."
osascript -e 'tell application "KRALİ Agent" to quit' 2>/dev/null || true

for i in 1 2 3 4 5; do
    if ! pgrep -x "$PROCESS_NAME" >/dev/null 2>&1; then
        break
    fi
    sleep 1
done

if pgrep -x "$PROCESS_NAME" >/dev/null 2>&1; then
    echo "• Uygulama kapanmadı; güvenli TERM sinyali gönderiliyor..."
    pkill -TERM -x "$PROCESS_NAME" 2>/dev/null || true
    sleep 1
fi

echo "4/5  Yeni KRALİ kuruluyor..."
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

echo "5/5  KRALİ yeniden açılıyor..."
open "$TARGET"
sleep 2

if pgrep -x "$PROCESS_NAME" >/dev/null 2>&1; then
    echo ""
    echo "✅ KRALİ Agent güncellendi ve yeniden açıldı."
    echo "📍 $TARGET"
else
    echo ""
    echo "⚠️ Güncelleme kuruldu ancak uygulama otomatik açılamadı."
    echo "Finder > Applications > KRALİ Agent üzerinden açabilirsin."
fi
