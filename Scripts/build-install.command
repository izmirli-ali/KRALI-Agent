#!/bin/zsh
set -u

ROOT="$HOME/Developer/KRALI-Agent"
PROJECT="$ROOT/App/KRALIAgentNative.xcodeproj"
SCHEME="KRALIAgentNative"
BUILD_DIR="$ROOT/.build"
BUILD_LOG="$HOME/Library/Logs/KRALI-Agent-Build.log"
APP_VERSION="$(/bin/cat "$ROOT/VERSION" 2>/dev/null | /usr/bin/tr -d '[:space:]')"
if [ -z "$APP_VERSION" ]; then
    echo "❌ VERSION dosyası okunamadı."
    exit 1
fi
PRODUCT="$BUILD_DIR/Build/Products/Debug/KRALIAgentNative.app"

TARGET="/Applications/KRALI Agent.app"
STAMP="$(date +%Y-%m-%d_%H-%M-%S)"
BACKUP="$ROOT/Backups/KRALI-Agent_$STAMP.app"
PROCESS_NAME="KRALIAgentNative"
BACKUP_RETENTION_COUNT=2

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

echo "1/6  Build assetleri kontrol ediliyor..."

ICON_SCRIPT="$ROOT/Scripts/generate-app-icon.swift"
ICON_DIR="$ROOT/App/KRALIAgentNative/Assets.xcassets/AppIcon.appiconset"
MASTER_ICON="$ICON_DIR/krali-master-1024.png"
ICON_SENTINEL="$ICON_DIR/icon_512x512@2x.png"

mkdir -p "$ICON_DIR"

REFRESH_ICONS=0
if [ ! -f "$MASTER_ICON" ] || [ ! -f "$ICON_SENTINEL" ]; then
    REFRESH_ICONS=1
elif [ "$ICON_SCRIPT" -nt "$MASTER_ICON" ]; then
    REFRESH_ICONS=1
fi

if [ "$REFRESH_ICONS" -eq 1 ]; then
    echo "• İkon assetleri değişmiş; yeniden üretiliyor..."

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
else
    echo "✓ İkon assetleri önbellekten kullanılacak."
fi

echo "2/6  Yeni sürüm incremental olarak derleniyor..."

mkdir -p "$HOME/Library/Logs"
: > "$BUILD_LOG"

run_build() {
    xcodebuild \
        -project "$PROJECT" \
        -scheme "$SCHEME" \
        -configuration Debug \
        -derivedDataPath "$BUILD_DIR" \
        -allowProvisioningUpdates \
        MARKETING_VERSION="$APP_VERSION" \
        build 2>&1 | /usr/bin/tee -a "$BUILD_LOG"

    return "${pipestatus[1]}"
}

run_build
BUILD_EXIT="$?"

if [ "$BUILD_EXIT" -ne 0 ]; then
    if /usr/bin/grep -E -q "\.swift:.*error:|SwiftCompile.*failed" "$BUILD_LOG"; then
        echo ""
        echo "⚠️ Kaynak kod derleme hatası algılandı; temiz build tekrarı atlanıyor."
    else
        echo ""
        echo "⚠️ Incremental build başarısız; cache kaynaklı olasılık için bir kez temiz build deneniyor..."
        rm -rf "$BUILD_DIR"
        : > "$BUILD_LOG"

        run_build
        BUILD_EXIT="$?"
    fi
fi

if [ "$BUILD_EXIT" -ne 0 ]; then
    echo ""
    echo "❌ Otomatik build başarısız."
    echo ""
    echo "Compiler hata özeti:"
    /usr/bin/grep -n -E "error:|fatal error:|SwiftCompile.*failed" "$BUILD_LOG" | /usr/bin/tail -n 40 || true
    echo ""
    echo "Tam build logu:"
    echo "$BUILD_LOG"
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

    # Keep a small, known rollback window. The rollback script selects the
    # newest archive, so pruning only older bundles preserves its contract.
    old_backups=("${(@f)$(find "$ROOT/Backups" -maxdepth 1 -type d -name 'KRALI-Agent_*.app' -print | sort | head -n -"$BACKUP_RETENTION_COUNT")}")
    if [ "${#old_backups[@]}" -gt 0 ]; then
        rm -rf -- "${old_backups[@]}"
        echo "✓ Eski yedekler temizlendi; son $BACKUP_RETENTION_COUNT geri dönüş paketi korundu."
    fi
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
    echo "❌ Yeni KRALİ build'i launch edilemedi."

    if [ -d "$BACKUP" ]; then
        echo "↩️ Son çalışan sürüm otomatik geri yükleniyor..."

        if [ -w "/Applications" ]; then
            rm -rf "$TARGET"
            ditto "$BACKUP" "$TARGET"
        else
            sudo rm -rf "$TARGET"
            sudo ditto "$BACKUP" "$TARGET"
        fi

        xattr -dr com.apple.quarantine "$TARGET" 2>/dev/null || true
        /usr/bin/open -n "$TARGET" >/dev/null 2>&1 || true
        sleep 2

        if pgrep -f "$APP_EXEC" >/dev/null 2>&1; then
            echo "✅ Önceki çalışan sürüm geri yüklendi ve açıldı."
        else
            echo "⚠️ Yedek geri yüklendi ancak otomatik launch doğrulanamadı."
        fi
    else
        echo "⚠️ Geri dönecek uygulama yedeği bulunamadı."
    fi

    exit 3
fi
