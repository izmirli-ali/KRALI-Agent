#!/bin/zsh
set -u

ROOT="$HOME/Developer/KRALI-Agent"
TARGET="/Applications/KRALI Agent.app"
LOG="$HOME/Library/Logs/KRALI-Agent-Updater.log"

cd "$ROOT"

reopen_existing_app() {
    if [ -d "$TARGET" ]; then
        echo ""
        echo "↩️ Güncelleme tamamlanamadı; mevcut KRALİ yeniden açılıyor..."
        /usr/bin/open -n "$TARGET" >/dev/null 2>&1 || true
    fi
}

fail() {
    local code="$1"
    local message="$2"
    echo ""
    echo "❌ $message"
    reopen_existing_app
    exit "$code"
}

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " KRALİ UPDATE"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if git remote get-url origin >/dev/null 2>&1; then
    echo "Kaynak güncellemeleri kontrol ediliyor..."
    git pull --ff-only || fail 10 "GitHub güncellemesi alınamadı."
else
    echo "ℹ️ Henüz GitHub remote bağlı değil."
fi

"$ROOT/Scripts/build-install.command" || fail $? "Build / kurulum tamamlanamadı."
