#!/bin/zsh
set -e

ROOT="$HOME/Developer/KRALI-Agent"

cd "$ROOT"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " KRALİ UPDATE"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if git remote get-url origin >/dev/null 2>&1; then
    echo "Kaynak güncellemeleri kontrol ediliyor..."
    git pull --ff-only
else
    echo "ℹ️ Henüz GitHub remote bağlı değil."
fi

"$ROOT/Scripts/build-install.command"
