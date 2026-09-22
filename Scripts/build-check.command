#!/bin/zsh
set -u

ROOT="${1:-$(cd "$(dirname "$0")/.." && pwd)}"
PROJECT="$ROOT/App/KRALIAgentNative.xcodeproj"
SCHEME="KRALIAgentNative"
BUILD_DIR="$ROOT/.build-check"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " KRALİ BUILD CHECK"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if [ ! -d "$PROJECT" ]; then
    echo "❌ Xcode projesi bulunamadı: $PROJECT"
    exit 10
fi

ICON_SCRIPT="$ROOT/Scripts/generate-app-icon.swift"
ICON_DIR="$ROOT/App/KRALIAgentNative/Assets.xcassets/AppIcon.appiconset"
MASTER_ICON="$ICON_DIR/krali-master-1024.png"

if [ -f "$ICON_SCRIPT" ]; then
    echo "1/2  Build assetleri hazırlanıyor..."
    mkdir -p "$ICON_DIR"

    if ! xcrun swift "$ICON_SCRIPT" "$MASTER_ICON"; then
        echo "❌ KRALİ ikonu üretilemedi."
        exit 11
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
    echo "1/2  İkon scripti yok; asset hazırlığı atlandı."
fi

echo "2/2  Uygulama incremental derleniyor (kurulum yapılmaz)..."

if xcodebuild     -project "$PROJECT"     -scheme "$SCHEME"     -configuration Debug     -derivedDataPath "$BUILD_DIR"     -allowProvisioningUpdates     build
then
    echo ""
    echo "✅ Build check başarılı."
    exit 0
fi

echo ""
echo "⚠️ Incremental build check başarısız; temiz DerivedData ile bir kez tekrar deneniyor..."
rm -rf "$BUILD_DIR"

if xcodebuild     -project "$PROJECT"     -scheme "$SCHEME"     -configuration Debug     -derivedDataPath "$BUILD_DIR"     -allowProvisioningUpdates     build
then
    echo ""
    echo "✅ Temiz build check başarılı."
    exit 0
fi

echo ""
echo "❌ Build check başarısız."
exit 20
