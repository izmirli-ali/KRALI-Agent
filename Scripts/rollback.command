#!/bin/zsh

ROOT="$HOME/Developer/KRALI-Agent"
TARGET="/Applications/KRALI Agent.app"

LAST="$(find "$ROOT/Backups" -maxdepth 1 -name 'KRALI-Agent_*.app' -print | sort | tail -1)"

if [ -z "$LAST" ]; then
    echo "❌ Geri dönülecek yedek yok."
    exit 1
fi

echo "KRALİ kapatılıyor..."
osascript -e 'tell application "KRALİ Agent" to quit' 2>/dev/null || true

echo "Geri dönülüyor:"
echo "$LAST"

sudo rm -rf "$TARGET"
sudo ditto "$LAST" "$TARGET"

echo "✅ Önceki sürüm geri yüklendi."

open "$TARGET"
